// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract ArtParcelling is ERC1155, Ownable(msg.sender) {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    constructor() ERC1155("") {}

    struct FractionalNftDetails {
        uint256 tokenId;
        address fractionalToken;
    }

    mapping(uint256 => FractionalNftDetails) public tokenIdToFractionDetails;

    function mintArt(address _to, uint256 _totalFractionalTokens) external onlyOwner() {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _mint(_to, tokenId, _totalFractionalTokens * 1000000000000000000, "");
        
        // Create an ERC20 Token Contract for this newly minted NFT
        FractionalToken fnftoken = new FractionalToken();
        fnftoken.mint(msg.sender, _totalFractionalTokens * 1000000000000000000);
        FractionalNftDetails memory fnft;
        fnft.tokenId = tokenId;
        fnft.fractionalToken = address(fnftoken);
        tokenIdToFractionDetails[tokenId] = fnft;
        
        // Assuming you want to associate some metadata with each tokenId
        //_setURI(tokenId, tokenURI_);
    }
}

contract FractionalToken is ERC20, ERC20Burnable, Ownable(msg.sender) {
    constructor() ERC20("FractionalToken", "FT") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
