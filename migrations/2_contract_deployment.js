const definitionsContract = artifacts.require("Definitions");
const nftContract = artifacts.require("NFT");
const collectionsContract = artifacts.require("Collections");
const businessesContract = artifacts.require("Businesses");
const marketplaceContract = artifacts.require("Marketplace");

module.exports = async function(deployer) {
  await deployer.deploy(definitionsContract);
  
  await deployer.deploy(nftContract);
  const deployedNftContract = await nftContract.deployed();

  await deployer.deploy(collectionsContract, deployedNftContract.address);
  const deployedCollectionsContract = await collectionsContract.deployed();

  await deployer.deploy(businessesContract, deployedNftContract.address,
     deployedCollectionsContract.address);
  const deployedBusinessesContract = await businessesContract.deployed();

  await deployer.deploy(marketplaceContract, "0xEaF164fF8d074040bf877bb8cd249F838116Ed49",
   "0xEaF164fF8d074040bf877bb8cd249F838116Ed49", 2, deployedNftContract.address, 
   deployedCollectionsContract.address, deployedBusinessesContract.address);
};
