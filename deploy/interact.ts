import * as hre from "hardhat";
import { getWallet } from "./utils";
import { ethers } from "ethers";
import * as fs from "fs";

// Address of the contract to interact with
const CONTRACT_ADDRESS = "0x4Aa797E2ba4632C2ED30A35ae62218C6963f5716";
const NONCEHOLDER_ADDRESS = "0x0000000000000000000000000000000000008003";
if (!CONTRACT_ADDRESS)
  throw "⛔️ Provide address of the contract to interact with!";

// An example of a script to interact with the contract
export default async function () {
  console.log(`Running script to interact with contract ${CONTRACT_ADDRESS}`);

  // Load compiled contract info
  const contractArtifact = await hre.artifacts.readArtifact("Zkminimalaccount");

  // Reading a file synchronously
  const data = fs.readFileSync(
    "/home/io10-0x/hardhatjavascript/zksyncaccountabstraction-hardhat/artifacts-zk/mock-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol/INonceHolder.json",
    "utf-8"
  );

  const jsonContent = JSON.parse(data);

  // Access the ABI property
  const abi = jsonContent.abi;

  // Initialize contract instance for interaction
  const contract = new ethers.Contract(
    CONTRACT_ADDRESS,
    contractArtifact.abi,
    getWallet() // Interact with the contract on behalf of this wallet
  );

  const nonceholdercontract = new ethers.Contract(
    NONCEHOLDER_ADDRESS,
    abi,
    getWallet() // Interact with the contract on behalf of this wallet
  );

  interface Transaction {
    txType: number;
    from: ethers.BigNumberish; // Address in uint256 format as string
    to: ethers.BigNumberish; // Address in uint256 format as string
    gasLimit: number;
    gasPerPubdataByteLimit: ethers.BigNumberish;
    maxFeePerGas: ethers.BigNumberish;
    maxPriorityFeePerGas: ethers.BigNumberish;
    paymaster: number;
    nonce: number;
    value: ethers.BigNumberish;
    reserved: number[];
    data: string;
    signature: string;
    factoryDeps: string[];
    paymasterInput: string;
    reservedDynamic: string;
  }

  function _getUnsignedTransaction(
    txType: number,
    from: ethers.BigNumberish,
    dest: ethers.BigNumberish,
    value: ethers.BigNumberish,
    nonce: number,
    functData: string
  ): Transaction {
    // Reserved field as an array of four zeros
    const reserved: number[] = [0, 0, 0, 0];

    // Factory dependencies is an empty array
    const factoryDeps: string[] = [];

    // Construct the transaction object
    const transaction: Transaction = {
      txType: txType,
      from: ethers.getBigInt(from), // Convert address to uint256-like string
      to: ethers.getBigInt(dest), // Convert address to uint256-like string
      gasLimit: 16777216,
      gasPerPubdataByteLimit: 16777216,
      maxFeePerGas: 16777216,
      maxPriorityFeePerGas: 16777216,
      paymaster: 0,
      nonce: nonce,
      value: value,
      reserved: reserved,
      data: functData,
      signature: "0x", // Empty signature as a hex string
      factoryDeps: factoryDeps,
      paymasterInput: "0x", // Empty byte string
      reservedDynamic: "0x", // Empty byte string
    };

    return transaction;
  }

  const txType = 113;
  const from = CONTRACT_ADDRESS;
  const dest = "0x97492728f9cF41D7Bbe6D38385921308e5032C49";
  const value = 1000000000000000; // Example value in wei
  const nonce = await nonceholdercontract.getMinNonce(CONTRACT_ADDRESS);
  const functData = "0x"; // Example function data
  const unsignedtransaction = _getUnsignedTransaction(
    txType,
    from,
    dest,
    value,
    nonce,
    functData
  );

  console.log(nonce);

  //Run contract write function
  const EMPTYBYTES32 = ethers.zeroPadBytes("0x", 32);
  const transaction = await contract.executeTransaction(
    EMPTYBYTES32,
    EMPTYBYTES32,
    unsignedtransaction
  );

  // Wait until transaction is processed
  await transaction.wait();
}
