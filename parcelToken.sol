// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ParcelToken is ERC721URIStorage{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("ParcelToken", "PT") {}


    function mintParcel(address to, uint256 noOfParcel) public {
        for (uint256 i = 0; i < noOfParcel; i++) {
            _mint(to, _tokenIds.current());
            _tokenIds.increment();
        }
    }
    function TotalSupply() external view returns (uint256) {
        return _tokenIds.current();
    }
}

