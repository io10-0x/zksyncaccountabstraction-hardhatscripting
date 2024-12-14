//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "mock-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {Transaction, MemoryTransactionHelper} from "mock-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from "mock-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {NONCE_HOLDER_SYSTEM_CONTRACT, BOOTLOADER_FORMAL_ADDRESS, DEPLOYER_SYSTEM_CONTRACT} from "mock-era-contracts/src/system-contracts/contracts/Constants.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Utils} from "mock-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";

contract Zkminimalaccount is IAccount, Ownable {
    error Zkminimalaccount__notfrombootloader();
    error Zkminimalaccount__notenoughbalance();
    error Zkminimalaccount__invalidsignature();
    error Zkminimalaccount__failedexecution();
    error Zkminimalaccount__notfrombootloaderorowner();

    constructor() Ownable() {}

    modifier onlyFromBootloader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert Zkminimalaccount__notfrombootloader();
        }
        _;
    }

    modifier onlyFromBootloaderorOwner() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert Zkminimalaccount__notfrombootloaderorowner();
        }
        _;
    }

    /*
    * @dev Validates the transaction and returns the magic number.
    @notice This function will update the nonce by calling the `incrementMinNonceIfEquals` function in the nonceholder system contract.
    @notice This function will check if the smart contract account has enough balance to pay for the transaction.
    @notice This function will check if the transaction is signed by the correct key.


    */
    function validateTransaction(
        bytes32 /*_txHash */,
        bytes32 /*_suggestedSignedHash*/,
        Transaction memory _transaction
    ) external payable onlyFromBootloader returns (bytes4 magic) {
        magic = _validateTransaction(_transaction);
        return magic;
    }

    function executeTransaction(
        bytes32 /*_txHash */,
        bytes32 /*_suggestedSignedHash*/,
        Transaction memory _transaction
    ) external payable onlyFromBootloaderorOwner {
        _executeTransaction(_transaction);
    }

    receive() external payable {}

    // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
    // since it typically should not be trusted.
    function executeTransactionFromOutside(
        Transaction memory _transaction
    ) external payable {
        bytes32 magic = _validateTransaction(_transaction);
        if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) {
            revert Zkminimalaccount__invalidsignature();
        }
        _executeTransaction(_transaction);
    }

    function payForTransaction(
        bytes32 /*_txHash */,
        bytes32 /*_suggestedSignedHash*/,
        Transaction memory _transaction
    ) external payable {
        bool success = MemoryTransactionHelper.payToTheBootloader(_transaction);
        if (!success) {
            revert Zkminimalaccount__failedexecution();
        }
    }

    function prepareForPaymaster(
        bytes32 _txHash,
        bytes32 _possibleSignedHash,
        Transaction memory _transaction
    ) external payable {}

    function _validateTransaction(
        Transaction memory _transaction
    ) internal returns (bytes4 magic) {
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(
                NONCE_HOLDER_SYSTEM_CONTRACT.incrementMinNonceIfEquals,
                (_transaction.nonce)
            )
        );

        if (
            address(this).balance <
            MemoryTransactionHelper.totalRequiredBalance(_transaction)
        ) {
            revert Zkminimalaccount__notenoughbalance();
        }

        bytes32 signedHash = MemoryTransactionHelper.encodeHash(_transaction);
        address signer = ECDSA.recover(signedHash, _transaction.signature);
        if (signer != owner()) {
            revert Zkminimalaccount__invalidsignature();
        }

        return ACCOUNT_VALIDATION_SUCCESS_MAGIC;
    }

    function _executeTransaction(Transaction memory _transaction) internal {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;
        bool success;
        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            SystemContractsCaller.systemCallWithPropagatedRevert(
                uint32(gasleft()),
                to,
                0,
                data
            );
        } else {
            assembly {
                success := call(
                    gas(),
                    to,
                    value,
                    add(data, 0x20),
                    mload(data),
                    0,
                    0
                )
            }
        }
        if (!success) {
            revert Zkminimalaccount__failedexecution();
        }
    }
}
