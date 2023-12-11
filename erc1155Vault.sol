// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MyNFTVault is ERC1155, Ownable {
    using SafeMath for uint256;

    // ERC20 token address for the vault
    address public vaultToken;

    // Mapping to track the ownership of NFTs
    mapping(uint256 => address) private nftOwners;

    constructor(string memory uri, address _vaultToken) ERC1155(uri) {
        vaultToken = _vaultToken;
    }

    function mintNFT(uint256 tokenId, uint256 amount, address to) external onlyOwner {
        _mint(to, tokenId, amount, "");
        nftOwners[tokenId] = to;
    }

    function mintBasket(uint256[] memory tokenIds, uint256[] memory amounts, address to) external onlyOwner {
        _mintBatch(to, tokenIds, amounts, "");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nftOwners[tokenIds[i]] = to;
        }
    }

    function approveVault(uint256 tokenId) external {
        require(msg.sender == nftOwners[tokenId], "Not the owner of the NFT");
        setApprovalForAll(vaultToken, true);
    }

    function transferNFTToVault(uint256 tokenId, uint256 amount) external {
        require(msg.sender == nftOwners[tokenId], "Not the owner of the NFT");
        safeTransferFrom(msg.sender, vaultToken, tokenId, amount, "");
    }

    function fractionalizeVault(uint256[] memory tokenIds, uint256[] memory amounts, address to) external onlyOwner {
        // Assuming that the vault token is ERC20
        IERC20(vaultToken).transferFrom(msg.sender, address(this), amounts[0]);
        _mintBatch(to, tokenIds, amounts, "");
    }
}

//pinata: https://gateway.pinata.cloud/ipfs/QmcCLszT5NDEJsmYbg8bnFibt75yfY5P5bcqJZNoRK9cu8
