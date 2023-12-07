// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";


contract artParceling is ERC721,ERC721URIStorage,Ownable(msg.sender){

struct ArtParcel{
    uint ArtId;
    uint sellingPrice;
    address ParcelToken;
    uint individualParcelPrice;
    uint totalParcels;
    address seller;
}

struct Investors{
    uint Artid;
    uint parcelOwned;
    address Investor;
    address FractionalNFT;
}

mapping(uint artId => ArtParcel) public artIdToParcelDetails;
mapping(uint artId => Investors[]) public artIdToInvestorDetails;

    using Counters for Counters.Counter;
    Counters.Counter private tokenId;



constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    //  function addArtParcelDetails(uint sellingPrice, uint individualParcelPrice, uint noOfParcels) external onlyOwner {
    //     require(sellingPrice > 0, "Selling price must be greater than zero");
    //     require(individualParcelPrice > 0, "Individual parcel price can't be zero");

        //tokenId.increment();
        //uint currentTokenId = tokenId.current();

    //     ArtParcel memory newParcel = ArtParcel({
    //         ArtId: 0,
    //         sellingPrice: sellingPrice,
    //         ParcelToken: address(0),
    //         individualParcelPrice: individualParcelPrice,
    //         totalParcels: noOfParcels,
    //         seller: msg.sender
    //     });

    //     artIdToParcelDetails[currentTokenId] = newParcel;
    // }

     function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

        function tokenURI(uint256 _tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
    return super.tokenURI(_tokenId);
}

   function mintArtNFT(uint sellingPrice, uint individualParcelPrice, string memory tokenURI_, uint256 _totalParcelTokens) external onlyOwner() {
        require(sellingPrice > 0, "Selling price must be greater than zero");
        require(individualParcelPrice > 0, "Individual parcel price can't be zero");

        tokenId.increment();
        //uint currentTokenId = tokenId.current();

        _safeMint(msg.sender, tokenId.current());
        _setTokenURI(tokenId.current(), tokenURI_);

        // Create a ERC20 Token Contract for this newly minted NFT
        ERCParcelToken parcelToken = new ERCParcelToken(); // initialize
        parcelToken.mintERC20Tokens(msg.sender, _totalParcelTokens * 10**18); // now mint the fractional tokens and send it to the owner of this NFT

        ArtParcel storage artParcel = artIdToParcelDetails[tokenId.current()];
        artParcel.ArtId = tokenId.current();
        artParcel.sellingPrice = sellingPrice;
        artParcel.ParcelToken = address(parcelToken);
        artParcel.individualParcelPrice = individualParcelPrice;
        artParcel.totalParcels = _totalParcelTokens;
        artParcel.seller = msg.sender;
        artIdToParcelDetails[tokenId.current()] = artParcel; // bind the fractional token address to this NFT token just minted
        tokenId.increment();
    }
    // function makeInvestmentOffer()external{}
     function viewArtDetails()public view returns(uint){}
//     function viewArtTokenDetails() public{


    
    function viewArtParcelDetail(uint _tokenId) public view returns (ArtParcel memory) {
    return artIdToParcelDetails[_tokenId];
}


    // function makeInvestment(uint tokenId) external{}

    // function viewInvestorsDetails(uint tokenId) external {}

    // function BidMasterNft(uint tokenId) external{}

    // function viewBids() public{}

    // function voteOnBid() external{}

    // function viewVoteDetails() external {}

    // function claimPhysicalAsset() external{}//dont know

    // function  burnNFT(uint tokenId)external{}

}

contract ERCParcelToken is ERC20, ERC20Burnable, Ownable(msg.sender) {
    constructor() ERC20("ParcelToken", "PT") {}

    function mintERC20Tokens(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}


///
//pinata: https://gateway.pinata.cloud/ipfs/QmcCLszT5NDEJsmYbg8bnFibt75yfY5P5bcqJZNoRK9cu8
