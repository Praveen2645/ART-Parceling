// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "ERC721.sol";
//import "escrow.sol";
import "hardhat/console.sol";

contract ArtParcel is ERC1155, Ownable(msg.sender) {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _proposalCounter;

    //address public owner;
    address payable  escrowContract;
    //uint256 public proposalId;
    uint256 bidId;
    uint256 adminCommissionPercentage = 5; //admin commision eg:5% change later
    uint256 serviceFees = 100; //change later 
    uint256 DICmemberFees = 100;//change later
    uint256 custodianFees = 100;//change later
    uint256 shippingFees = 100;//change later

    struct NftDetails{
        uint256 proposalId;
        string nftUrl;
        string[] docNames;
        string[] docUrls;
        uint256 parcellingPrice;
        uint256 minimumInvestment;
        uint256 noOfParcels;
        address artist;
        bool isOnSale;
    }

    struct Parcels {
        uint256 proposalId;
        uint256 parcelId;
        uint256 parcelPrice;
        address parcelToken;
        address parcelOwner;
        bool isForSale;
    }

    struct Investor {
        uint256 proposalId;
        uint256[] parcelId;
        address[] parcelToken;
        address payable InvestorAddress;
    }

    struct bidProposals {
        uint256 proposalId;
        uint256 bidId;
        uint256 reservePrice;
        bool approved;
        bool active;
    }

    struct Voters{
        uint voteId;
        uint proposalId;
        address subHolder;
        address[] voters;
        bool voteStatus;
    }

    struct BidDetails{
        uint bidId;
        uint reservePrice;
        uint startAt;
        uint endAt;
        uint duration;
        uint highestBid;
        address highestBidder;
        address payable[] bidders; 
    }

    modifier onlyArtist(uint256 _proposalId) {
    require(
        msg.sender == idToNftDetails[_proposalId].artist,
        "Only the artist can perform this action"
    );
    _;
}



    mapping(uint256 proposalId => NftDetails) public idToNftDetails;
    mapping(uint256 proposalId => Parcels[]) public proposalIdToParcels;
    mapping(address investor => Investor) public addressToInvestorDetails;
    mapping(uint256 proposalId => bidProposals[]) public idToBidProposalDetails;
    mapping(uint256 proposalId => Voters) public idToVoters;
    mapping(uint256 bidId => BidDetails) public bidIdToBidDetails;


    constructor()
        /*address _owner*/
        ERC1155("https://myapi.com/api/token/{id}.json")
    {
        //owner=_owner;
    }

    // function setOwner(address _newOwner) external {
    //     owner= _newOwner;
    // }

    function mintNFT(
        string memory NftUrl,
        string[] memory docNames,
        string[] memory docUrls,
        uint256 ParcellingPrice,
        uint256 minimumInvestment,
        uint256 noOfParcel
    ) external {
        // Mint Master NFT (ERC1155)
        uint256 proposalCounter = _tokenIdCounter.current();
        _mint(msg.sender, proposalCounter, 1, "");
        
        NftDetails memory nftDetails;
        nftDetails.proposalId = proposalCounter;
        nftDetails.nftUrl = NftUrl;
        nftDetails.docNames = docNames;
        nftDetails.docUrls = docUrls;
        nftDetails.parcellingPrice = ParcellingPrice;
        nftDetails.minimumInvestment = minimumInvestment;
        nftDetails.noOfParcels = noOfParcel;
        nftDetails.artist = msg.sender;
        nftDetails.isOnSale = false;

        idToNftDetails[proposalCounter] = nftDetails;
        _tokenIdCounter.increment();

        // Mint subNfts(721)
        ParcelToken parcelToken = new ParcelToken();
        parcelToken.mintParcel(address(this), noOfParcel);

        for (uint256 i = 0; i < noOfParcel; i++) {
            Parcels memory parcel;
            parcel.proposalId = proposalCounter;
            parcel.parcelId =i+1;
            parcel.parcelPrice = ParcellingPrice;
            parcel.parcelToken = address(parcelToken);
            parcel.parcelOwner= address(this);
            parcel.isForSale = true;

           proposalIdToParcels[proposalCounter].push(parcel);
        }
    }
    
// to get the owner of the master nft
  function ownerOfMasterNft(uint _proposalId) external view returns (address) {
    return  idToNftDetails[_proposalId].artist;
}

// to set the price for parcels
    function setPriceForMultipleParcels(
        uint256 _proposalId,
        uint256[] memory prices
    ) external onlyArtist(_proposalId) {
        require(
            prices.length == proposalIdToParcels[_proposalId].length,
            "Invalid prices array length"
        );

        for (uint256 i = 0; i < prices.length; i++) {
            proposalIdToParcels[_proposalId][i].parcelPrice = prices[i];
        }
    }

// investor can make investment with the decided parcel amount+commision fee(5%)eg parclePrice=100wei. investor will pay 100+5%.
// as investor pay the parcel amount transfer commision to
// than transfer the parcel Nft to investor

function makeInvestment(uint256 _proposalId, uint256[] memory parcelId) external payable {
    
    Parcels[] storage parcels = proposalIdToParcels[_proposalId];
    require(msg.value > 0, "Invalid investment amount");
    require(parcelId.length > 0, "Invalid parcelIndices array");

    uint256 totalInvestment = 0;
    for (uint256 i = 0; i < parcelId.length; i++) {
        require(parcelId[i] <= parcels.length, "Invalid parcelIndex");
        require(parcels[parcelId[i] - 1].isForSale, "Parcel not for sale");

        totalInvestment = totalInvestment.add(parcels[parcelId[i] - 1].parcelPrice);
    }

    require(msg.value >= totalInvestment, "Insufficient funds");

    // Transfer parcels to investor
    for (uint256 i = 0; i < parcelId.length; i++) {
        uint256 parcelIndex = parcelId[i] - 1;
        Parcels storage parcel = parcels[parcelIndex];

        // Transfer parcel NFT to investor
        ParcelToken(parcel.parcelToken).safeTransferFrom(address(this), msg.sender, parcel.parcelId);

        // Update parcel details
        parcel.parcelOwner = msg.sender;
        parcel.isForSale = false;
    }

    // Update investor details
    Investor storage investorDetails = addressToInvestorDetails[msg.sender];
    investorDetails.proposalId = _proposalId;
    investorDetails.parcelId = parcelId;
    investorDetails.InvestorAddress = payable(msg.sender);
    
}


//calculate the total price for make investment for the parcelNFt
// function totalPriceToPayForParcel(
//     uint256 _proposalId,
//     uint256[] memory parcelIds,
//     uint256[] memory parcelAmounts
// ) public view returns (uint256 totalPrice) {
//     require(parcelIds.length == parcelAmounts.length, "Invalid input lengths");


//     uint256 totalInvestment = 0;
//     for (uint256 i = 0; i < parcelIds.length; i++) {
//         uint256 parcelId = parcelIds[i];
//         uint256 parcelAmount = parcelAmounts[i];

//         // Validate the parcel details
//         require(proposalIdToParcels[_proposalId][parcelId].isForSale, "Parcel already sold");

//         // Add the parcel amount to the total investment
//         totalInvestment = totalInvestment.add(parcelAmount);
//         console.log("totalnvestment is:",totalInvestment);
//     }

//     // Calculate the admin commission fee
//     uint256 adminCommission = (totalInvestment * adminCommissionPercentage) / 100;

//     // Calculate the total amount including the admin commission
//     totalPrice = totalInvestment.add(adminCommission);
//     console.log("totalPrice:",totalPrice);

//     return totalPrice;
// }


// function to create  bidProposals
function createBidProposal(uint256 _proposalId, uint256 _reservePrice) //reservePrice=> minimum amount the seller will accept
    external
    onlyOwner
{
    require(_reservePrice > 0, "reserve amount should not be zero");

    bidProposals[] storage proposals = idToBidProposalDetails[_proposalId];

    for (uint256 i = 0; i < proposals.length; i++) {
        require(!(proposals[i].proposalId == _proposalId && proposals[i].active), "proposal already exists");
    }

    bidId++;

    idToBidProposalDetails[_proposalId].push(
        bidProposals({
            proposalId: _proposalId,
            bidId: bidId,
            reservePrice: _reservePrice,
            approved: false,
            active: true
           
        })
    );
}

//parcel holders will vote for the proposal to sold the master Nft

    function voteForBidProposal(uint _proposalId, address parcelHolderAddress, bool voteStatus) external {
   //require(_proposalId <= proposalId, "Invalid proposal id");
    require(parcelHolderAddress != address(0), "Invalid parcel holder address");

    Voters storage voter = idToVoters[_proposalId];

    // Check if the voter has not voted for the proposal
    require(!voter.voteStatus, "Already voted for this proposal");

    // Update voter details
    voter.voteId++;
    voter.proposalId = _proposalId;
    voter.subHolder = parcelHolderAddress;
    voter.voteStatus = voteStatus;

    // Count the votes
    uint yesVotes = 0;
    uint noVotes = 0;

    for (uint i = 0; i < idToBidProposalDetails[_proposalId].length; i++) {
        bidProposals storage proposal = idToBidProposalDetails[_proposalId][i];

        // Check if the proposal is active
        if (proposal.active) {
            // Check if the voter is a parcel holder and voted
            if (voter.subHolder == parcelHolderAddress) {
                if (voteStatus) {
                    yesVotes++;
                } else {
                    noVotes++;
                }
            }
        }
    }

    // Check if 51% or more voted "yes"
    if (yesVotes * 100 >= 51 * (yesVotes + noVotes)) {
        // Majority voted "yes", approve the bid proposal
        for (uint i = 0; i < idToBidProposalDetails[_proposalId].length; i++) {
            bidProposals storage proposal = idToBidProposalDetails[_proposalId][i];
            if (proposal.active) {
                proposal.approved = true;
                proposal.active = false;
            }
        }

       /* transfer of nft to bidder and profits to the subHolders */ 
       //need to complete
    }
}

// function for setting the escrow conttract address 
function setEscrowContract(address payable _escrowContract) external onlyOwner{
    escrowContract = _escrowContract;
}

/*start the bid for the masterNFT*/

function startBid(uint _bidId, uint _reservePrice,uint _duration) external onlyOwner {
require(_bidId>0,"invaid bid Id");
require(_duration >0, "duration can't be zero.");
require(_reservePrice >0,"reserve price cant be zero");

bidIdToBidDetails[_bidId].bidId=_bidId;
// bidIdToBidDetails[_bidId].masterNftId=_masterNftId;
bidIdToBidDetails[_bidId].reservePrice=_reservePrice;
bidIdToBidDetails[_bidId].duration= _duration;
bidIdToBidDetails[_bidId].startAt= block.timestamp;
bidIdToBidDetails[_bidId].endAt=_duration+block.timestamp;
bidIdToBidDetails[_bidId].highestBid=0;
bidIdToBidDetails[_bidId].highestBidder=payable(address(0));

}

//function to bid 
function bidOnMasterNft(uint _proposalId, uint _bidId, uint _bidAmount/*, address _walletAddress*/) external payable {
    BidDetails storage bidDetails = bidIdToBidDetails[_bidId];

    require(_bidId > 0, "Invalid bid id");
    //require(bidDetails.masterNftId == idToBidProposalDetails[_proposalId][_bidId].masterNFtId, "Invalid masterNftId");
    require(block.timestamp >= bidDetails.startAt && block.timestamp <= bidDetails.endAt, "Bidding not allowed or bidding ended");
    require(_bidAmount > bidDetails.highestBid, "Bid amount should be higher than the current highest bid");

}

/*
In case the buyer (selected bidder) wants to claim their Artwork, they need to pay the necessary service fees, DIC member fees,
custodian fees and shipping charges. Once these fees are settled, the Artwork will be shipped to the buyer's location,
and all the corresponding NFTs will be burned.
*/

function claimPhysicalAsset(uint _proposalId, uint _bidId) external {}


/*
If there are no suitable offers, the proposer can redeem their NFT back to the platform, 
but this process incurs platform fees and custodianship charges, deducted from the stacking amount.
*/

function requestToReleaseAsset(/*uint proposalId*/) external /*onlyArtist*/{ 

}

function getBidProposalDetails(uint _proposalId, uint _bidId) internal view returns (bidProposals storage) {
    bidProposals[] storage proposals = idToBidProposalDetails[_proposalId];
    require(_bidId <= proposals.length, "Invalid bid ID");
    return proposals[_bidId - 1];
}

    function viewNftDetail(uint256 _proposalId)
        public
        view
        returns (NftDetails memory)
    {
        return idToNftDetails[_proposalId];
    }

    function viewParcelDetails(uint256 _proposalId)
        public
        view
        returns (Parcels[] memory)
    {
        return proposalIdToParcels[_proposalId];
    }

    function viewBidProposals(uint256 _proposalId)
        public
        view
        returns (bidProposals[] memory)
    {
        return idToBidProposalDetails[_proposalId];
    }

    function getAllParcelHolders()0

}


//1000000000000000000
//100000000000000000

//pinata: https://gateway.pinata.cloud/ipfs/QmcCLszT5NDEJsmYbg8bnFibt75yfY5P5bcqJZNoRK9cu8

//bidOnMasterNft update this function so anyone can bid for masterNft and bidders can bid from this function the bidded amount will transfer to the
//escrowContract address and if other bidder bid and his amount is greater than the privios bidder transfer the previous bidders bid amount back to
//him from escrow contract to his account.and keep the highest bidders amount in the contract.untill the bidding is going on
//then transfer the masterNft to the bidder and
