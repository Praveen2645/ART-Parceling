//Mint Art for Parceling, 
// View Art Parceling Detail, 
// View Parcel Token Detail,
// Make Investment Offer,
// View Investor Detail,
// Create Bid Proposal
//View Bid Proposal,
// Voting on Bid Proposal,
// View Voting Detail,
// Bid on Asset (Master NFT),
// View Bidder Detail,
// Claim Physical Asset,
//Request To Release Asset (Burn  NFT)

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";


contract ArtParcelling is ERC721,Ownable(msg.sender),ERC721URIStorage{

constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

  struct frationalNftDetails{
        uint256 tokenId;
        address fractionalToken;
    }

    mapping(uint256 tokenId=> frationalNftDetails) public tokenIdToFractionDetails;
 
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

     function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
    return super.tokenURI(tokenId);
}

    function mintArt(address _to, string memory tokenURI_, uint256 _totalFractionalTokens ) external onlyOwner() {
        _safeMint(_to, _tokenIdCounter.current());
        _setTokenURI(_tokenIdCounter.current(), tokenURI_);

        //Create a ERC20 Token Contract for this newly minted NFT
        FractionalToken _fnftoken = (new FractionalToken)();   //initialize
        _fnftoken.mint(msg.sender, _totalFractionalTokens * 1000000000000000000); //now mint the fractional tokens and send it to the owner of this NFT           
        frationalNftDetails memory fnft;                                                         
        fnft.tokenId = _tokenIdCounter.current();                           
        fnft.fractionalToken = address(_fnftoken);
        tokenIdToFractionDetails[_tokenIdCounter.current()]  = fnft;  //bind the fractional token address to this NFT token just minted
        _tokenIdCounter.increment();
    }

    //     function makeInvestmentOffer()external{}
//     function viewArtDetails()public{}
//     function viewArtTokenDetails() public{}
}

contract FractionalToken is ERC20, ERC20Burnable, Ownable(msg.sender) {
    constructor() ERC20("FractionalToken", "FT") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
    

//pinata: https://gateway.pinata.cloud/ipfs/QmcCLszT5NDEJsmYbg8bnFibt75yfY5P5bcqJZNoRK9cu8
