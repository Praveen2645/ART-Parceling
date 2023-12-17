// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "ERC721.sol";
import "hardhat/console.sol";

contract ArtPaarell is ERC1155, Ownable(msg.sender) {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    //address public owner;
    uint256 proposalId;
    uint256 bidId;
    uint256 adminCommissionPercentage = 5; //admin commision eg:5%

    struct MasterNFT {
        uint256 proposalId;
        uint256 masterNFTId;
        string nftUrl;
        string[] docNames;
        string[] docUrls;
        uint256 parcellingPrice;
        uint256 minimumInvestment;
        uint256 noOfParcels;
        address artist;
        address parcelTokenAddress;
        bool isOnSale;
    }

    struct Parcels {
        uint256 masterNFTId;
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
        address InvestorAddress;
    }

    struct bidProposals {
        uint256 proposalId;
        uint256 bidId;
        uint256 masterNFtId;
        uint256 amount;
        bool approved;
        bool active;
    }

    struct Voters{
        uint voteId;
        uint proposalId;
        address subHolder;
        bool voteStatus;
    }

    modifier onlyArtist(uint256 masterNFTId) {
        require(
            msg.sender == idToMasterNftDetails[masterNFTId].artist,
            "Only artist allowed"
        );
        _;
    }

    mapping(uint256 masterId=> MasterNFT) public idToMasterNftDetails;
    mapping(uint256 masterId=> Parcels[]) public masterNftIdToParcels;
    mapping(address investor=> Investor) public addressToInvestorDetails;
    mapping(uint256 proposalId=> bidProposals[]) public idTobidProposalDetails;
    mapping(uint256 proposalId=> Voters) public idToVoters;
    mapping(uint256 => address) public masterNftToParcelToken;


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
        uint256 masterId = _tokenIdCounter.current();
        _mint(msg.sender, masterId, 1, "");
        

        MasterNFT memory masterNft;
        masterNft.proposalId = proposalId;
        masterNft.masterNFTId = masterId;
        masterNft.nftUrl = NftUrl;
        masterNft.docNames = docNames;
        masterNft.docUrls = docUrls;
        masterNft.parcellingPrice = ParcellingPrice;
        masterNft.minimumInvestment = minimumInvestment;
        masterNft.noOfParcels = noOfParcel;
        masterNft.artist = msg.sender;
        masterNft.isOnSale = true;

        idToMasterNftDetails[masterId] = masterNft;
        proposalId++;

        // Mint subNfts(721)
        ParcelToken parcelToken = new ParcelToken();
        parcelToken.mintParcel(msg.sender, noOfParcel);

        for (uint256 i = 0; i < noOfParcel; i++) {
            Parcels memory parcel;
            parcel.masterNFTId = masterId;
            parcel.parcelId = _tokenIdCounter.current()+1;
            parcel.parcelPrice = ParcellingPrice;
            parcel.parcelToken = address(parcelToken);
            parcel.parcelOwner=msg.sender;
            parcel.isForSale = true;//need to confirm sale after voting?

            masterNftIdToParcels[masterId].push(parcel);
            _tokenIdCounter.increment();
        }
    }

    function setPriceForMultipleParcels(
        uint256 masterNFTId,
        uint256[] memory prices
    ) external onlyArtist(masterNFTId) {
        require(
            prices.length == masterNftIdToParcels[masterNFTId].length,
            "Invalid prices array length"
        );

        for (uint256 i = 0; i < prices.length; i++) {
            masterNftIdToParcels[masterNFTId][i].parcelPrice = prices[i];
        }
    }

    // complete this function so investor can make investment with the desired parcel amount.
    //when investor will pay the amount he will not only pay the parcel amount but also the admin comminsion fee assume it 5%.
    //as investor pay the parcel price and the admin commision fee, the commission fee will transfer to the contract and parcel amount to the parcel owner
    //after this the parcel nft will transfer to the address investor mention in the parameter
/*NOTE: need to improve*/


    function makeInvestment(
    uint256 _proposalId,
    uint256[] memory parcelIds,
    uint256[] memory parcelAmounts,
    address subNftContract,
    address walletAddress
) external payable {
    require(parcelIds.length == parcelAmounts.length, "Invalid input lengths");
    
    MasterNFT storage masterNft = idToMasterNftDetails[_proposalId];
    //require(masterNft.isOnSale, "Master NFT is not on sale");
    
    uint256 totalInvestment = 0;
    for (uint256 i = 0; i < parcelIds.length; i++) {
        uint256 parcelId = parcelIds[i];
        uint256 parcelAmount = parcelAmounts[i];
        
        // Validate the parcel details
        require(masterNftIdToParcels[_proposalId][parcelId].isForSale, "Parcel is not for sale");
        require(msg.sender != masterNft.artist, "Artist cannot buy their own parcels");
        require(msg.value >= parcelAmount, "Insufficient funds");

        // Transfer the parcel amount to the parcel owner
        address payable parcelOwner = payable(masterNftIdToParcels[_proposalId][parcelId].parcelOwner);
        parcelOwner.transfer(parcelAmount);

        // Add the parcel amount to the total investment
        totalInvestment = totalInvestment.add(parcelAmount);
        console.log("Total investment:", totalInvestment);

        // Transfer the parcel NFT to the investor
        ERC721(subNftContract).safeTransferFrom(address(this), walletAddress, parcelId);
        console.log("Contract balance:", address(this).balance);
        
        // Update parcel details
        masterNftIdToParcels[_proposalId][parcelId].parcelOwner = msg.sender;
        masterNftIdToParcels[_proposalId][parcelId].isForSale = false;
        
    }

    // Calculate and transfer the admin commission fee
    uint256 adminCommission = (totalInvestment * adminCommissionPercentage) / 100;
    console.log("commision:",adminCommission );
    require(msg.value >= totalInvestment.add(adminCommission), "Insufficient funds");

    address payable adminWallet = payable(owner());
    adminWallet.transfer(adminCommission);

}
function getTotalPriceToPay(
    uint256 _proposalId,
    uint256[] memory parcelIds,
    uint256[] memory parcelAmounts
) public view returns (uint256 totalPrice) {
    require(parcelIds.length == parcelAmounts.length, "Invalid input lengths");

//MasterNFT storage masterNft = idToMasterNftDetails[_proposalId];
    require(idToMasterNftDetails[_proposalId].isOnSale, "Master NFT is not on sale");

    uint256 totalInvestment = 0;
    for (uint256 i = 0; i < parcelIds.length; i++) {
        uint256 parcelId = parcelIds[i];
        uint256 parcelAmount = parcelAmounts[i];

        // Validate the parcel details
        require(masterNftIdToParcels[_proposalId][parcelId].isForSale, "Parcel is not for sale");

        // Add the parcel amount to the total investment
        totalInvestment = totalInvestment.add(parcelAmount);
    }

    // Calculate the admin commission fee
    uint256 adminCommission = (totalInvestment * adminCommissionPercentage) / 100;

    // Calculate the total amount including the admin commission
    totalPrice = totalInvestment.add(adminCommission);

    return totalPrice;
}




function createBidProposal(uint256 _proposalId, uint256 _reservePrice)
    external
    onlyOwner
{
    require(_proposalId > 0, "Invalid proposal id");
    require(_reservePrice > 0, "Invalid amount");
    require(_proposalId <= proposalId, "Invalid proposal id");

    bidProposals[] storage proposals = idTobidProposalDetails[_proposalId];

    for (uint256 i = 0; i < proposals.length; i++) {
        require(!(proposals[i].proposalId == _proposalId && proposals[i].active), "proposal already exists");
    }

    bidId++;

    idTobidProposalDetails[_proposalId].push(
        bidProposals({
            proposalId: _proposalId,
            bidId: bidId,
            masterNFtId: idToMasterNftDetails[_proposalId].masterNFTId,
            amount: _reservePrice,
            approved: false,
            active: true
        })
    );
}

    function voteForBidProposal(uint _proposalId, address parcelHolderAddress, bool voteStatus) external {
    require(_proposalId > 0 && _proposalId <= proposalId, "Invalid proposal id");
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

    for (uint i = 0; i < idTobidProposalDetails[_proposalId].length; i++) {
        bidProposals storage proposal = idTobidProposalDetails[_proposalId][i];

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
        for (uint i = 0; i < idTobidProposalDetails[_proposalId].length; i++) {
            bidProposals storage proposal = idTobidProposalDetails[_proposalId][i];
            if (proposal.active) {
                proposal.approved = true;
                proposal.active = false;
            }
        }

       /* transfer of nft to bidder and profits to the subHolders */
    }
}

function bidOnAsset() external {}

function claimPhysicalAsset() external {}


    function viewNftDetail(uint256 masterNFTId)
        public
        view
        returns (MasterNFT memory)
    {
        return idToMasterNftDetails[masterNFTId];
    }

    function viewParcelDetails(uint256 parcelId)
        public
        view
        returns (Parcels[] memory)
    {
        return masterNftIdToParcels[parcelId];
    }

    function viewBidProposals(uint256 _proposalId)
        public
        view
        returns (bidProposals[] memory)
    {
        return idTobidProposalDetails[_proposalId];
    }
}

// function storeDocument(uint256 masterNFTId, string memory docName, string memory docUrl)
//     external
//     onlyArtist(masterNFTId)
// {
//     masterNftIdToDocuments[masterNFTId][docName] = docUrl;
// }

// function getDocument(uint256 masterNFTId, string memory docName) external view returns (string memory) {
//     return masterNftIdToDocuments[masterNFTId][docName];
// }

// function storeCertificate(uint256 masterNFTId, string memory certificateName, string memory certificateUrl)
//     external
//     onlyArtist(masterNFTId)
// {
//     masterNftIdToCertificates[masterNFTId][certificateName] = certificateUrl;
// }

// function getCertificate(uint256 masterNFTId, string memory certificateName)
//     external
//     view
//     returns (string memory)
// {
//     return masterNftIdToCertificates[masterNFTId][certificateName];
// }

//1000000000000000000
//100000000000000000

//pinata: https://gateway.pinata.cloud/ipfs/QmcCLszT5NDEJsmYbg8bnFibt75yfY5P5bcqJZNoRK9cu8

// complete this function so investor can make investment with the desired parcel amount.
//when investor will pay the amount he will not only pay the parcel amount but also the admin comminsion fee assume it 5%.
//as investor pay the parcel price and the admin commision fee, the commission fee will transfer to the contract and parcel amount to the parcel owner
//after this the parcel nft will transfer to the address investor mention in the parameter
