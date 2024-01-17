async function main() {
    const ArtParcelling = await hre.ethers.getContractFactory('ArtParcelling');
    const artParcelling = await ArtParcelling.deploy();

    const ParcelToken = await hre.ethers.getContractFactory('ParcelToken');
    const parcelToken = await ParcelToken.deploy();

    await artParcelling.waitForDeployment();
    await parcelToken.waitForDeployment();

    console.log(`art parcel contract deployed to: $(artParcelling.address)`);
    console.log(`parcel token contract deployed to: $(parcelToken.address)`);

}
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });


  
