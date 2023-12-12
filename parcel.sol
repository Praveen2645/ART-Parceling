// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ArtParceling is ERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    struct Artist {
        uint ids;
        uint salePrice;
        uint pricePerParcel;
        address artist;
    }

    struct Investor {
        uint ids;
        address investor;
    }

    struct Parcel {
        uint parentId;
        uint price;
        address owner;
    }

    modifier onlyArtist(uint tokenId){
        require(msg.sender==_tokenDetails[tokenId].artist,"only artist allowed");
        _;
    }

    mapping(uint256 => Artist) public _tokenDetails;
    mapping(uint256 => Investor) public _investorDetails;
    mapping(uint256 => Parcel) public _parcelDetails;

    constructor() ERC1155("https://game.example/api/item/{id}.json") {}

    function mintNFT(uint256 salePrice, uint256 noOfParcels, uint _pricePerParcel) external {
        require(salePrice > 0, "Please set some amount for your NFT");
        require(noOfParcels > 0, "Number of parcels must be greater than zero");

        uint256 parentId = _tokenIdCounter.current();

        _mint(msg.sender, parentId, 1, "");

        _tokenDetails[parentId] = Artist({
            ids: parentId,
            salePrice: salePrice,
            pricePerParcel: _pricePerParcel,
            artist: msg.sender
        });

        // _parcelDetails[parentId] = Parcel({
        //     // parentId: 0, 
        //     price: _pricePerParcel,
        //     owner: msg.sender
        // });

        for (uint256 i = 1; i <= noOfParcels; i++) {
            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();

            _mint(msg.sender, tokenId, 1, "");

            _tokenDetails[tokenId] = Artist({
                ids: tokenId,
                salePrice: salePrice,
                pricePerParcel: _pricePerParcel,
                artist: msg.sender
            });

            _parcelDetails[tokenId] = Parcel({
                parentId: parentId,
                price: _pricePerParcel,
                owner: msg.sender
            });
        }
    }
//run for loop to set price 
    // function setPriceForEachParcel(uint id, uint price) external onlyOwner {
    //     require(_tokenDetails[id].artist != address(0), "Invalid NFT ID");
    //     require(price > 0, "Price must be greater than zero");

    //     _tokenDetails[id].pricePerParcel = price;
    // }

     function setPriceForMultipleParcels(uint[] memory ids, uint[] memory prices) external onlyArtist(ids[0]) {
        require(ids.length == prices.length, "length mismatch");

        for (uint i = 0; i < ids.length; i++) {
            uint id = ids[i];
            uint price = prices[i];

            require(_tokenDetails[id].artist != address(0), "Invalid NFT ID");
            require(price > 0, "Price must be greater than zero");

            _tokenDetails[id].pricePerParcel = price;
        }
    }

    function makeInvestmentOffer(uint id, uint price) external payable {
    require(id > 0, "Enter valid id"); //changes here
    require(_tokenDetails[id].pricePerParcel == price, "Pay the exact amount");
   
    require(_parcelDetails[id].parentId == 0, "Parent token cannot be purchased by investors");

    // Transfer the NFT to investor
    address nftOwner = _tokenDetails[id].artist;
    _safeTransferFrom(nftOwner, msg.sender, id, 1, "");

    // Transfer the amount to NFT owner
    payable(nftOwner).transfer(price);

    // Update investor details
    require(_investorDetails[id].investor == address(0), "Investor already exists for this NFT");

    _investorDetails[id] = Investor({
        ids: id,
        investor: msg.sender
    });
}


    function createBid (uint id) external {

    }

    function viewArtDetails(uint256 tokenId) public view returns(Artist memory) {
        return _tokenDetails[tokenId];
    }

    function viewParcelDetails(uint256 tokenId) public view returns(Parcel memory){
        return _parcelDetails[tokenId];
    }

    function viewInvestorsDetails(uint256 tokenId) public view returns(Investor memory ){
        return _investorDetails[tokenId];
    }

} 
//10000000000000000000
//1000000000000000000

//condition for parentId
