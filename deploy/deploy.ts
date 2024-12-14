import { deployContract } from "./utils";

export default async function () {
  const contractArtifactName = "Zkminimalaccount";
  await deployContract(contractArtifactName);
}
