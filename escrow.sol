// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Escrow is Ownable(msg.sender) {
    mapping(address bidder => uint256 amount) public deposits;

    function deposit(address _beneficiary, uint256 _amount) external payable {
        require(msg.value == _amount, "Incorrect deposit amount");
        deposits[_beneficiary] += _amount;
    }

    function refund(address _beneficiary, uint256 _amount) external onlyOwner {
        require(deposits[_beneficiary] >= _amount, "Insufficient funds");
        payable(_beneficiary).transfer(_amount);
        deposits[_beneficiary] -= _amount;
    }

    function withdraw(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "Insufficient contract balance");
        payable(owner()).transfer(_amount);
    }
}
