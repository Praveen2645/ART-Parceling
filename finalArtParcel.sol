// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "ERC721.sol";  

contract ArtPaarell is ERC1155 {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    uint proposalId;

    struct MasterNFT {
        uint proposalId;
        uint masterNFTId;
        string nftUrl;
        // string[] docNames;
        // string[] docUrl;
        uint parcellingPrice;
        uint minimumInvestment;
        uint noOfParcels;
        address artist;
    }

    struct Parcels {
        uint parcelId;
        uint parcelPrice;
        address parcelToken;
        bool isForSale;
    }

    
    modifier onlyArtist(uint masterNFTId) {
    require(msg.sender == idToMasterNftDetails[masterNFTId].artist, "Only artist allowed");
    _;
}


    mapping(uint256 masterId=> MasterNFT) public idToMasterNftDetails;
    mapping(uint256 masterId=> Parcels[]) public masterNftIdToParcels;

    constructor() ERC1155("https://myapi.com/api/token/{id}.json") {}


    function mintNFT(
        string memory NftUrl,
        // string[] memory docNames,
        // string[] memory docUrls,
        uint256 ParcellingPrice,
        uint256 minimumInvestment,
        uint256 noOfParcel
    ) external {
        // Mint Master NFT (ERC1155)
        uint256 masterId = _tokenIdCounter.current();
        _mint(msg.sender, masterId, 1, "");
        proposalId++;

        MasterNFT memory masterNft;
        masterNft.proposalId = proposalId;
        masterNft.masterNFTId = masterId;
        masterNft.nftUrl = NftUrl;
        // masterNft.docNames = docNames;
        // masterNft.docUrl = docUrls; 
        masterNft.parcellingPrice = ParcellingPrice;
        masterNft.minimumInvestment = minimumInvestment;
        masterNft.noOfParcels = noOfParcel;
        masterNft.artist = msg.sender;

        idToMasterNftDetails[masterId] = masterNft;

        // Mint subNfts(721)
        ParcelToken parcelToken = new ParcelToken();
        parcelToken.mintParcel(msg.sender, noOfParcel);

        for (uint256 i = 0; i < noOfParcel; i++) {
            Parcels memory parcel;
            parcel.parcelId = _tokenIdCounter.current() + 1;
            parcel.parcelPrice = ParcellingPrice;
            parcel.parcelToken = address(parcelToken);
            parcel.isForSale = true; 

            masterNftIdToParcels[masterId].push(parcel);
            _tokenIdCounter.increment();
        }
    }

    function setPriceForMultipleParcels(uint256 masterNFTId, uint256[] memory prices) external onlyArtist(masterNFTId) {
        require(prices.length == masterNftIdToParcels[masterNFTId].length, "Invalid prices array length");

        for (uint256 i = 0; i < prices.length; i++) {
            masterNftIdToParcels[masterNFTId][i].parcelPrice = prices[i];
        }
    }


    // function storeDocument(uint256 masterNFTId, string memory docName, string memory docUrl)
    //     external
    //     onlyArtist(masterNFTId)
    // {
    //     masterNftIdToDocuments[masterNFTId][docName] = docUrl;
    // }

    // function getDocument(uint256 masterNFTId, string memory docName) external view returns (string memory) {
    //     return masterNftIdToDocuments[masterNFTId][docName];
    // }

    // function storeCertificate(uint256 masterNFTId, string memory certificateName, string memory certificateUrl)
    //     external
    //     onlyArtist(masterNFTId)
    // {
    //     masterNftIdToCertificates[masterNFTId][certificateName] = certificateUrl;
    // }

    // function getCertificate(uint256 masterNFTId, string memory certificateName)
    //     external
    //     view
    //     returns (string memory)
    // {
    //     return masterNftIdToCertificates[masterNFTId][certificateName];
    // }

}
//1000000000000000000
//100000000000000000
