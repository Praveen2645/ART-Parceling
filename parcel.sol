// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ArtParceling is ERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    uint public totalProposal;

    event BidProposalCreated(uint indexed bidId, uint indexed parentId, uint proposedPrice, address indexed proposer);

    
    struct Art{
        uint id;
        uint salePrice;
        uint noOfParcel;
        uint pricePerParcel;
        bool onSale;
        address artist;
    }

    struct Investor {
        uint ids;
        address investor;
    }

    struct Parcel {
        uint parentId;
        uint parcelId;
        uint parcelPrice;
        address owner;
        bool isForSale;
    }

    struct Proposal{
        uint parentId;
        uint proposedPrice;
        address Proposer;
        bool status;
    }

    struct Voters{
        uint parentId;
        address voterAddress;
        bool status;
    }

    modifier onlyArtist(uint parentId){
        require(msg.sender==_artDetails[parentId].artist,"only artist allowed");
        _;
    }

    mapping(uint256 parentId=> Art) public _artDetails;
    mapping(uint256 => Investor) public _investorDetails;
    mapping(uint256 parcelId=> Parcel) public _parcelDetails;
    mapping(uint256 parentId => Proposal) public viewProposals;

    constructor() ERC1155("https://game.example/api/item/{id}.json") {}


/*
1- mint parentNft
2- next parentId should depend on noOfParcels of the token eg:parentId=0 noOfParcel =10=> next parentId= 11
*/

 function mintNFT(uint256 salePrice, uint256 noOfParcels, uint _pricePerParcel) external {
        require(salePrice > 0, "Please set some amount for your NFT");
        require(noOfParcels > 0, "Number of parcels must be greater than zero");

        uint256 parentId = _tokenIdCounter.current();
        _mint(msg.sender, parentId, 1, "");

        _artDetails[parentId] = Art({
            id: parentId,
            salePrice: salePrice,
            noOfParcel: noOfParcels,
            pricePerParcel: _pricePerParcel,
            onSale:true,
            artist: msg.sender
        });

       for (uint256 i = 0; i < noOfParcels + 1; i++) {
        _tokenIdCounter.increment();
    }

    }
   
   /*
   1- set price for each child nft
   */
  function setPriceForMultipleParcels(uint256 parentId, uint256[] memory prices) external onlyArtist(parentId) {
    require(prices.length == _artDetails[parentId].noOfParcel, "Length mismatch");

    for (uint256 i = 0; i < prices.length; i++) {
        uint256 childTokenId = parentId + i + 1; 

        _mint(msg.sender, childTokenId, 1, "");

        _parcelDetails[childTokenId] = Parcel({
            parentId: parentId,
            parcelId: childTokenId,
            parcelPrice: prices[i],
            owner: msg.sender,
            isForSale: true
        });
    }
}

/*
This method enables investors to invest in Art Parcel(s). 
Once the investor completes the payment, the corresponding parcel(s) will be transferred to their wallet as an NFT.
 This NFT will be locked and cannot be transferred to anyone else, ensuring the investor's ownership and security of the assets they have invested in

 Input Parameters:Proposal Id,Parcel Id(multiple),Parcel Amount,Wallet Address,
Output Parameters:Investor Detail,Proposal Id,Investor Id,Investor Address,Parcel Contract Address,Parcel Id(multiple),Parcel Amount

Action
Transfer Admin Commision into Parcel Amount,
Transfer Remaining Parcel Sub NFT Amount to Proposer,
Smart Contract transfer Sub NFT tokens to Investor,
Store Preferred Investor Detail,
*/
//NOTE: need to be tested

function makeInvestment(uint parentId, uint parcelId) external payable { //make parcelId [] 
    require(parentId >= 0 && parentId <= _tokenIdCounter.current(), "Invalid parentId");
    require(parcelId > parentId && parcelId <= parentId + _artDetails[parentId].noOfParcel, "Invalid parcelId");
    require(_artDetails[parentId].onSale, "Parent NFT is not on sale");
    require(_parcelDetails[parcelId].isForSale,"parcel already purchased");
    require(_parcelDetails[parcelId].owner == _artDetails[parentId].artist, "Invalid parcel ownership");
    require(msg.value == _parcelDetails[parcelId].parcelPrice, "Incorrect payment amount");

    // // Ensure that the contract has approval to transfer the token on behalf of the owner
    // setApprovalForAll(_artDetails[parentId].artist, true);

    // Transfer ownership of the parcel NFT to the investor
    safeTransferFrom(_artDetails[parentId].artist, msg.sender, parcelId, 1, "");

    // // Remove approval after the transfer is complete (optional, depending on your requirements)
    // setApprovalForAll(_artDetails[parentId].artist, false);

    // Lock the transferred NFT (make it non-transferable)
    _parcelDetails[parcelId].owner = msg.sender;
     _parcelDetails[parcelId].isForSale= false;

    _investorDetails[parcelId] = Investor({
        ids: parcelId,
        investor: msg.sender
    });

}


/*Create Bid Proposal-This method enables a artist to create a bid proposal for a Parent NFT. 
 The proposal will be sent to all Sub NFT holders for voting purposes.
 The voting process allows for collective decision-making by the community of Sub NFT holders to approve or reject the bid proposal and reserve price.

 Input Parameters: Proposal Id,Amount
 Output Parameters:Bid Detail,Bid Id,Proposal Id, Bid Amount,Bid Winner
 Use by :Admin

Action		
Store Bid Detail for proposal		

*/
 function createBidProposal(uint parentId, uint price) public onlyArtist(parentId) {
    require(parentId >= 0 && parentId <= _tokenIdCounter.current(), "Invalid parentId");
    require(_artDetails[parentId].onSale, "Parent NFT is not on sale");

    totalProposal++;
    viewProposals[parentId] = Proposal({
        parentId: parentId,
        proposedPrice: price,
        Proposer: msg.sender,
        status: false
    });

    emit BidProposalCreated(totalProposal, parentId, price, msg.sender);
}

/*
Voting
Parcel holders have the voting power to approve or reject bid requests for the Master NFT. 
If the majority of parcel holders accept the proposal, the Master NFT will be sold to the selected bidder. 
Parcel holders will receive their profits, and the corresponding Master NFT will be transferred to the bidder. 
Sub NFTs (parcels) will be burned, ensuring a seamless and transparent transaction process for all parties involved
	
Input Parameters:Proposal Id,Sub-NFT Holder  Address,Vote Status		
Output Parameters:Vote Id,Proposal Id,Vote Status,Sub-NFT Holder Address
Use by: Token Holders
		
Action		
Store Master NFT Biding Voting Detail		

*/
    function votingOnBidProposal() external{

    }
    
    
    function viewArtDetail(uint256 parentId) public view returns(Art memory) {
        return _artDetails[parentId];
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

