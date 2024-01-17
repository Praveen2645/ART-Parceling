const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("ArtParcelling", function () {
  async function deployArtParcelling() {
    const [owner, otherAccount] = await ethers.getSigners();
    const artParcelling = await ethers.deployContract("ArtParcelling");
    await artParcelling.waitForDeployment();
    return { artParcelling, owner, otherAccount };
  }

  describe("Mint NFT", function () {
    it("should mint NFT and associated ERC721 tokens", async function () {
      const { artParcelling, owner, otherAccount } = await loadFixture(deployArtParcelling);

      // Mint ERC1155 NFT and associated ERC721 tokens
      await artParcelling.mintNFT(
        "abc",
        ["abc"],
        ["xyz"],
        100,
        100,
        3
      );

    //   // Check NFT details
    //   const nftDetails = await artParcelling.idToNftDetails(0); // Assuming proposalCounter starts from 0
    //   expect(nftDetails.nftUrl).to.equal("abc");
    //   expect(nftDetails.docNames).to.equal(["abc"]);
    //   expect(nftDetails.docUrls).to.equal(["xyz"]);
    //   expect(nftDetails.parcellingPrice).to.equal(100);
    //   expect(nftDetails.minimumInvestment).to.equal(100);
    //   expect(nftDetails.noOfParcels).to.equal(3);
    //   expect(nftDetails.artist).to.equal(owner.address);
    //   expect(nftDetails.isOnSale).to.equal(false);

    //   // Check ERC721 tokens minted
    //   const parcelDetails = await artParcelling.idToParcels(0, 0); // Assuming proposalCounter starts from 0 and parcelId from 0
    //   const parcelTokenContract = await ethers.getContractAt("ParcelToken", parcelDetails.parcelToken);
    //   const totalSupply = await parcelTokenContract.TotalSupply();
    //   expect(totalSupply).to.equal(3);

    //   // Check Parcel details
    //   expect(parcelDetails.proposalId).to.equal(0);
    //   expect(parcelDetails.parcelId).to.equal(1);
    //   expect(parcelDetails.parcelOwned).to.equal(0);
    //   expect(parcelDetails.parcelPrice).to.equal(100);
    //   expect(parcelDetails.parcelToken).to.equal(parcelTokenContract.address);
    //   expect(parcelDetails.parcelOwner).to.equal(artParcelling.address);
    //   expect(parcelDetails.isForSale).to.equal(true);
    });
  });
});
