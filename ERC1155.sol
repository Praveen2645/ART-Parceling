
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "@openzeppelin/contracts/utils/Address.sol";


// contract MyNFTContract is ERC1155, Ownable(msg.sender) {
//     using SafeMath for uint256;
//     using Counters for Counters.Counter;
//     Counters.Counter private tokenId;

//     struct NftDetails {
//         uint tokenId;
//         uint totalParcels;
//         address NFT;
//     }

//     struct InvestorDetails {
//         uint tokenId;
//         uint parcelHolds;
//     }

//     mapping(uint => NftDetails) public idToNftDetails;
//     mapping(uint => mapping(address => uint)) public investorToParcels;

//     constructor() ERC1155("https://game.example/api/item/{id}.json") {}

//     function mintArtNft() external {
//         tokenId.increment();
//         _mint(msg.sender, tokenId.current(), 1, "");
//         NftDetails storage nft = idToNftDetails[tokenId.current()];
//         nft.tokenId = tokenId.current();
//         nft.totalParcels = 1;
//         nft.NFT = msg.sender;
//     }
//    //make a function which will break the minted nft into ERC20 tokens so investors can buy the pieces of NFT
// }

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MyNFTContract is ERC1155, Ownable(msg.sender),IERC20 {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private tokenId;

    struct NftDetails {
        uint tokenId;
        uint totalParcels;
        address NFT;
    }

    struct InvestorDetails {
        uint tokenId;
        uint parcelHolds;
    }

    mapping(uint => NftDetails) public idToNftDetails;
    mapping(uint => mapping(address => uint)) public investorToParcels;

    // ERC20 token address for the NFT pieces
    address public erc20TokenAddress;

    constructor(address _erc20TokenAddress) ERC1155("https://game.example/api/item/{id}.json") {
        erc20TokenAddress = _erc20TokenAddress;
    }

    function mintArtNft() external {
        tokenId.increment();
        _mint(msg.sender, tokenId.current(), 1, "");
        NftDetails storage nft = idToNftDetails[tokenId.current()];
        nft.tokenId = tokenId.current();
        nft.totalParcels = 1;
        nft.NFT = msg.sender;
    }

    function splitNFT(uint _tokenId, uint _numPieces) external {
        require(_numPieces > 1, "Number of pieces must be greater than 1");
        require(owner(_tokenId) == msg.sender, "You are not the owner of this NFT");

        NftDetails storage nft = idToNftDetails[_tokenId];
        require(nft.totalParcels == 1, "NFT is already split");

        // Transfer the NFT to this contract
        safeTransferFrom(msg.sender, address(this), _tokenId, 1, "");

        // Mint ERC20 tokens for each piece
        for (uint i = 0; i < _numPieces; i++) {
            uint tokenIdForPiece = tokenId.current();
            tokenId.increment();
            _mint(address(this), tokenIdForPiece, 1, "");

            // Update NFT details
            NftDetails storage piece = idToNftDetails[tokenIdForPiece];
            piece.tokenId = tokenIdForPiece;
            piece.totalParcels = 1;
            piece.NFT = msg.sender;

            // Update investor details
            investorToParcels[tokenIdForPiece][msg.sender] = 1;
        }

        // Update the original NFT details
        nft.totalParcels = _numPieces;
    }

    // Add a function to allow investors to buy pieces using ERC20 tokens
    function buyNFTPiece(uint _tokenId, uint _numPieces) external {
        require(_numPieces > 0, "Number of pieces must be greater than 0");
        require(idToNftDetails[_tokenId].totalParcels > _numPieces, "Not enough pieces available");

        // Calculate the total cost for the pieces
        uint totalCost = _numPieces * COST_PER_PIECE; // You need to define COST_PER_PIECE

        // Transfer ERC20 tokens from the buyer to this contract
        IERC20(erc20TokenAddress).transferFrom(msg.sender, address(this), totalCost);

        // Transfer the pieces to the buyer
        safeBatchTransferFrom(address(this), msg.sender, piecesForSale, _numPieces, "");

        // Update investor details
        investorToParcels[_tokenId][msg.sender] += _numPieces;

        // Update NFT details
        idToNftDetails[_tokenId].totalParcels -= _numPieces;
    }
}
