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
//import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

import "ERC721.sol";
import "escrow.sol";
import "hardhat/console.sol";

contract ArtParcel is ERC1155, Ownable(msg.sender) {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
  

    //address public owner;
    address payable  escrowContract;
    uint256 public voterId;
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
        uint256 parcelOwned;
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
        bool isActive;
    }

  struct Voters {
        uint256 proposalId;
        uint256 voterId;
        address[] voters;
        mapping(address => bool) voted;
    }

    struct BidDetails{
        uint bidId;
        uint proposalId;
        uint reservePrice;
        uint startAt;
        uint endAt;
        uint duration;
        uint highestBid;
        address highestBidder;
        address payable[] bidders; 
        bool isOnSale;
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
    mapping(uint256 proposalId => Voters) private idToVoters;
    mapping(uint256 bidId => BidDetails) public bidIdToBidDetails;
    mapping(uint256 bidId => bool) public isBidProposalApproved;
   // mapping(address parcelHolder=> uint256 tokens) private tokensPerHolder;
    

    constructor()
        
        ERC1155("https://myapi.com/api/token/{id}.json")
    {
      
    }

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
            parcel.parcelOwned=0;
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
        parcel.parcelOwned = parcelId.length;
        parcel.isForSale = false;
    }

    // Update investor details
    Investor storage investorDetails = addressToInvestorDetails[msg.sender];
    investorDetails.proposalId = _proposalId;
    investorDetails.parcelId = parcelId;
    investorDetails.InvestorAddress = payable(msg.sender);
    
}

// function to create  bidProposals for masterNFT and set the reservePrice
function createBidProposal(uint256 _proposalId, uint256 _reservePrice) //reservePrice=> minimum amount the seller will accept
    external
    onlyOwner
{
    require(_reservePrice > 0, "reserve amount should not be zero");

    bidProposals[] storage proposals = idToBidProposalDetails[_proposalId];

    for (uint256 i = 0; i < proposals.length; i++) {
        require(!(proposals[i].proposalId == _proposalId && proposals[i].isActive), "proposal already exists");
    }

    bidId++;

    idToBidProposalDetails[_proposalId].push(
        bidProposals({
            proposalId: _proposalId,
            bidId: bidId,
            reservePrice: _reservePrice,
            approved: false,// proposal is approved for sale or not
            isActive: true //proposal is active or not
        })
    );
}

 function voteForBidProposal(uint256 _proposalId, bool _voteStatus) external {
        address _parcelHolderAddress = msg.sender;

        require(isParcelHolder(_proposalId, _parcelHolderAddress), "Not a parcel holder for the proposal");

        Voters storage voters = idToVoters[_proposalId];

        require(!voters.voted[_parcelHolderAddress], "Already voted");

        // Mark the voter as voted
        voters.voted[_parcelHolderAddress] = true;
        voters.voters.push(_parcelHolderAddress);
        voters.voterId = voterId;
        voterId++;

        // Check if the proposal has received enough votes for the majority
        if (hasMajorityVotes(_proposalId)) {
            if (_voteStatus) {
                approveBidProposal(_proposalId);
            } else {
                rejectBidProposal(_proposalId);
            }
             isBidProposalApproved[_proposalId] = true;
        }
    }


    function isParcelHolder(uint256 _proposalId, address _address) internal view returns (bool) {
        Parcels[] storage parcels = proposalIdToParcels[_proposalId];
        for (uint256 i = 0; i < parcels.length; i++) {
            if (parcels[i].parcelOwner == _address) {
                return true;
            }
        }
        return false;
    }

  function hasMajorityVotes(uint256 _proposalId) internal view returns (bool) {
        Voters storage voters = idToVoters[_proposalId];
        uint256 totalVoters = voters.voters.length;
        uint256 majorityVotes = (totalVoters * 51) / 100;

        return totalVoters >= majorityVotes;
    }

function approveBidProposal(uint256 _proposalId) internal {
    bidProposals[] storage proposals = idToBidProposalDetails[_proposalId];
    for (uint256 i = 0; i < proposals.length; i++) {
        if (proposals[i].isActive) {
            proposals[i].approved = true;
            proposals[i].isActive = false;
           
        }
    }
}

function rejectBidProposal(uint256 _proposalId) internal {
    bidProposals[] storage proposals = idToBidProposalDetails[_proposalId];
    for (uint256 i = 0; i < proposals.length; i++) {
        if (proposals[i].isActive) {
            proposals[i].approved = false;
            proposals[i].isActive = true;
            
        }
    }
}

    function parcelClaim(address _parcelToken, uint256 _proposalId, uint _reservePrice) external payable onlyArtist(_proposalId){
        require(isBidProposalApproved[_proposalId], "Bid proposal not approved by majority");
        Parcels[] storage parcels = proposalIdToParcels[_proposalId];
        require(parcels.length > 0, "No parcels for the proposal");

        bool isValidParcel = false;
        for (uint256 i = 0; i < parcels.length; i++) {
            if (_parcelToken == parcels[i].parcelToken &&
                _proposalId == parcels[i].proposalId &&
                _reservePrice == idToBidProposalDetails[_proposalId][bidId-1].reservePrice) {
                isValidParcel = true;
                break;
            }
        }
        require(isValidParcel, "Invalid parcel details");

  // Calculate total number of parcels for a proposalId
uint256 totalParcels = 0;
for (uint256 i = 0; i < parcels.length; i++) {
    if (parcels[i].proposalId == _proposalId) {
        totalParcels = totalParcels.add(1);
    }
}
console.log("Total Parcels for Proposal ID:", totalParcels);


    //   // Distribute the reserve price among parcel holders and burn tokens
    // for (uint256 i = 0; i < parcels.length; i++) {
    //     address parcelHolder = parcels[i].parcelOwner;
    //     uint256 holderTokens = parcels[i].parcelOwned;
    //     uint256 share = (_reservePrice * holderTokens) / totalParcels;

    //     // Transfer funds to parcel holder
    //     payable(parcelHolder).transfer(share);
    // console.log("holderTokens:",holderTokens);
    // }
    }
// function for setting the escrow contract address 
function setEscrowContract(address payable _escrowContract) external onlyOwner{
    escrowContract = _escrowContract;
}

/*start the bid for the masterNFT*/

function startBid(uint256 _proposalId,uint256 _bidId, uint256 _reservePrice,uint256 _duration) external onlyOwner {
require(_bidId>0,"invaid bid Id");
require(_duration >0, "duration can't be zero.");
require(_reservePrice >0,"reserve price cant be zero");

bidIdToBidDetails[_bidId].proposalId = _proposalId;
bidIdToBidDetails[_bidId].bidId=_bidId;
bidIdToBidDetails[_bidId].reservePrice=_reservePrice;
bidIdToBidDetails[_bidId].duration= _duration;
bidIdToBidDetails[_bidId].startAt= block.timestamp;
bidIdToBidDetails[_bidId].endAt=_duration+block.timestamp;
bidIdToBidDetails[_bidId].highestBid=0;
bidIdToBidDetails[_bidId].highestBidder=payable(address(0));

}

//function to bid 
/*
1. anyone can bid on master above the reserve price.
2. bidders bid save in escrow contract
3. previos bid amount will transfer back to the bidder incase other bidder makes the highestBid.
4. continue bidding till the bids duration

*/
function bidOnMasterNft(uint _bidId, uint _bidAmount, address _walletAddress) external payable {
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

   function getParcelContractAddress(uint256 _proposalId) public view returns (address) {
    Parcels[] memory parcels = proposalIdToParcels[_proposalId];

    require(parcels.length > 0, "No parcels for the proposal");
    address parcelTokenAddress = parcels[0].parcelToken;

    return parcelTokenAddress;
}


    function getAllVotersWithStatus(uint256 _proposalId) external view returns (address[] memory, bool[] memory) {
    Voters storage voters = idToVoters[_proposalId];
    
    uint256 numVoters = voters.voters.length;
    address[] memory voterAddresses = new address[](numVoters);
    bool[] memory voteStatuses = new bool[](numVoters);

    for (uint256 i = 0; i < numVoters; i++) {
        address voterAddress = voters.voters[i];
        bool voteStatus = voters.voted[voterAddress];
        
        voterAddresses[i] = voterAddress;
        voteStatuses[i] = voteStatus;
    }

    return (voterAddresses, voteStatuses);
}




}


//1000000000000000000


//pinata: https://gateway.pinata.cloud/ipfs/QmcCLszT5NDEJsmYbg8bnFibt75yfY5P5bcqJZNoRK9cu8

// // Burn tokens of subholders and update the Parcels struct
// for (uint i = 0; i < parcels.length; i++) {
//     if (voters.subHolder == parcels[i].parcelOwner) {
//         uint256[] memory tokenIds = new uint256[](1);
//         tokenIds[0] = parcels[i].parcelId;
//         ParcelToken(parcels[i].parcelToken).burnTokens(tokenIds);

//         // Update Parcels struct for the specific index
//         parcels[i].proposalId = _proposalId;
//         parcels[i].parcelId = 0;
//         parcels[i].parcelPrice = 0;
//         parcels[i].parcelToken = address(0);
//         parcels[i].parcelOwner = address(0);
//         parcels[i].isForSale = false;
//     }
// }

/*
function to share the profit to parcelHolders and burn the parcel tokens
1.checks
2.transfer and distribution of funds 
3.burning of parcel tokens
*/
// function parcelClaim(address _parcelToken, uint256 _proposalId, uint256 _reservePrice) external payable onlyArtist(_proposalId) {
//     require(isBidProposalApproved[_proposalId], "Bid proposal not approved by majority");
//     Parcels[] storage parcels = proposalIdToParcels[_proposalId];
//     require(parcels.length > 0, "No parcels for the proposal");

//     // Calculate total tokens held by all parcel holders
//     uint256 totalTokens = 0;
//     for (uint256 i = 0; i < parcels.length; i++) {
//         totalTokens = totalTokens.add(tokensPerHolder[parcels[i].parcelOwner]);
//     }

//     // Distribute the reserve price among parcel holders and burn tokens
//     for (uint256 i = 0; i < parcels.length; i++) {
//         address parcelHolder = parcels[i].parcelOwner;
//         uint256 holderTokens = tokensPerHolder[parcelHolder];
//         uint256 share = (_reservePrice * holderTokens) / totalTokens;

//         // Transfer funds to parcel holder
//         payable(parcelHolder).transfer(share);

//         // Burn tokens from the parcelToken contract
//         ParcelToken(_parcelToken).burnTokens(parcelHolder, holderTokens);

//         // Update parcel details
//         parcels[i].isForSale = false;
//     }

