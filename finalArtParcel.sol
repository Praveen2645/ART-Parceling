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
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

import "ERC721.sol";
import "escrow.sol";
import "hardhat/console.sol";

contract ArtParcel is ERC1155, Ownable(msg.sender) {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    Escrow escrow;

    //address public owner;
    address payable escrowContract;
    uint256 voterId;
    uint256 bidId;
    uint256 adminCommissionPercentage = 5; //admin commision eg:5% change later
    uint256 constant serviceFees = 100; //change later
    uint256 constant DICmemberFees = 100; //change later
    uint256 constant custodianFees = 100; //change later
    uint256 shippingFees = 100; //change later

    struct NftDetails {
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
        address payable parcelOwner;
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

    struct BidDetails {
        uint256 bidId;
        uint256 proposalId;
        uint256 reservePrice;
        uint256 startAt;
        uint256 endAt;
        uint256 duration;
        uint256 highestBid;
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

    mapping(uint256 => NftDetails) public idToNftDetails;
    mapping(uint256 => Parcels[]) public proposalIdToParcels;
    mapping(address => Investor) public addressToInvestorDetails;
    mapping(uint256 => bidProposals) public idToBidProposalDetails;
    mapping(uint256 => Voters) private idToVoters;
    mapping(uint256 => BidDetails) public bidIdToBidDetails;
    mapping(uint256 => bool) public isBidProposalApproved;

    // mapping(address parcelHolder=> uint256 tokens) private tokensPerHolder;

    constructor() ERC1155("https://myapi.com/api/token/{id}.json") {}


  /* 
  *@param NftUrl- url of the NFT
  *@param docNames - docs of the nft
  *@param docUrls- doc urls
  *@param ParcellingPrice - this is the price for all parcels
  *@param minimumInvestment- minimum investment
  *@param noOfParcel- parcel count to break a masterNFT into pieces
  *@notice this function will mint the master NFT and the new ERC721 conract for parcels.
  */
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
            parcel.parcelId = i + 1;
            parcel.parcelOwned = 0;
            parcel.parcelPrice = ParcellingPrice;
            parcel.parcelToken = address(parcelToken);
            parcel.parcelOwner = payable(address(this));
            parcel.isForSale = true;

            proposalIdToParcels[proposalCounter].push(parcel);
        }
    }

    /*
   * @param _proposalId- proposal id for the master and parcel NFTs
   * @notice this function tells the owner of the master Nft
    */
    function ownerOfMasterNft(uint256 _proposalId)
        external
        view
        returns (address)
    {
        return idToNftDetails[_proposalId].artist;
    }

    
    /*
    @param _proposalId- proposal id for the master and parcel NFTs
    @param prices- price of the single parcel
    @notice this function sets the price for single or multiple parcels
    */
    function setPriceForParcels(uint256 _proposalId, uint256[] memory prices)
        external
        onlyArtist(_proposalId)
    {
        require(
            prices.length == proposalIdToParcels[_proposalId].length,
            "Invalid prices array length"
        );

        for (uint256 i = 0; i < prices.length; i++) {
            proposalIdToParcels[_proposalId][i].parcelPrice = prices[i];
        }
    }

 
    /*
    @param _proposalId- proposal id for the master and parcel NFTs
    @param parcelId- parcel Id for the parcels 
    @notice this function helps the investors to buy the single or multiple parcels
    */

    function makeInvestment(uint256 _proposalId, uint256[] memory parcelId)
        external
        payable
    {
        Parcels[] storage parcels = proposalIdToParcels[_proposalId];
        require(msg.value > 0, "Invalid investment amount");
        require(parcelId.length > 0, "Invalid parcelIndices array");

        uint256 totalInvestment = 0;
        for (uint256 i = 0; i < parcelId.length; i++) {
            require(parcelId[i] <= parcels.length, "Invalid parcelIndex");
            require(parcels[parcelId[i] - 1].isForSale, "Parcel not for sale");

            totalInvestment = totalInvestment.add(
                parcels[parcelId[i] - 1].parcelPrice
            );
        }

        require(msg.value >= totalInvestment, "Insufficient funds");

        // Transfer parcels to investor
        for (uint256 i = 0; i < parcelId.length; i++) {
            uint256 parcelIndex = parcelId[i] - 1;
            Parcels storage parcel = parcels[parcelIndex];

            // Transfer parcel NFT to investor
            ParcelToken(parcel.parcelToken).safeTransferFrom(
                address(this),
                msg.sender,
                parcel.parcelId
            );

            // Update parcel details
            parcel.parcelOwner = payable(msg.sender);
            parcel.parcelOwned = parcelId.length;
            parcel.isForSale = false;
        }

        // Update investor details
        Investor storage investorDetails = addressToInvestorDetails[msg.sender];
        investorDetails.proposalId = _proposalId;
        investorDetails.parcelId = parcelId;
        investorDetails.InvestorAddress = payable(msg.sender);
    }

 
    /*
    @param _proposalId- proposal id for the master and parcel NFTs
    @param _reservePrice- minimum amount for the maserNft
    @notice this function helps the artist to creating a proposal so the parcelHolders will come to know about the selling of the master NFT
    */
    function createBidProposal(
        uint256 _proposalId,
        uint256 _reservePrice //reservePrice=> minimum amount the seller will accept
    ) external onlyOwner {
        require(_reservePrice > 0, "reserve amount should not be zero");

        bidProposals storage proposals = idToBidProposalDetails[_proposalId];

        require(
            !(proposals.proposalId == _proposalId && proposals.isActive),
            "proposal already exists"
        );

        proposals.proposalId = _proposalId;
        proposals.bidId = bidId;
        proposals.reservePrice = _reservePrice;
        proposals.approved = false; // proposal is approved for sale or not
        proposals.isActive = true; //proposal is active or not
        bidId++;
    }

    /*
    @param _proposalId- proposal id for the master and parcel NFTs
    @param _voteStatus- voting for the master NFT by the nftHolders
    @notice this function helps the the parcel holders to vote on the proposals to approve or to reject it.
    */
    function voteForBidProposal(uint256 _proposalId, bool _voteStatus)
        external
    {
        address _parcelHolderAddress = msg.sender;

        require(
            isParcelHolder(_proposalId, _parcelHolderAddress),
            "Not a parcel holder for the proposal"
        );

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
        }else{
            isBidProposalApproved[_proposalId] = false;
        }
    }

    function isParcelHolder(uint256 _proposalId, address _address)
        internal
        view
        returns (bool)
    {
        Parcels[] storage parcels = proposalIdToParcels[_proposalId];
        for (uint256 i = 0; i < parcels.length; i++) {
            if (parcels[i].parcelOwner == _address) {
                return true;
            }
        }
        return false;
    }

    function hasMajorityVotes(uint256 _proposalId)
        internal
        view
        returns (bool)
    {
        Voters storage voters = idToVoters[_proposalId];
        uint256 totalVoters = voters.voters.length;
        uint256 majorityVotes = (totalVoters * 51) / 100;

        return totalVoters >= majorityVotes;
    }

    function approveBidProposal(uint256 _proposalId) internal {
        bidProposals storage proposal = idToBidProposalDetails[_proposalId];
        if (proposal.isActive) {
            proposal.approved = true;
            proposal.isActive = false;
        }
    }

    function rejectBidProposal(uint256 _proposalId) internal {
        bidProposals storage proposal = idToBidProposalDetails[_proposalId];
        if (proposal.isActive) {
            proposal.approved = false;
            proposal.isActive = true;
        }
    }

    /*
    @param _proposalId- proposal id for the master and parcel NFTs
    @param _parcelToken- address of parcel token
    @param _reservePrice- reseve price for master NFT
    @notice this function burn the parcel tokens and distributes the profit amount amoung the parcelHolders.
    NOTE: the bid proposal should be passed by majority.
    */
    function parcelClaim(
        address _parcelToken,
        uint256 _proposalId,
        uint256 _reservePrice
    ) external payable onlyArtist(_proposalId) {
        require(
            idToBidProposalDetails[_proposalId].approved ==true,
            "Bid proposal not approved by majority"
        );
        Parcels[] storage parcels = proposalIdToParcels[_proposalId];
        require(parcels.length > 0, "No parcels for the proposal");

        bool isValidParcel = false;
        for (uint256 i = 0; i < parcels.length; i++) {
            if (
                _parcelToken == parcels[i].parcelToken &&
                _proposalId == parcels[i].proposalId &&
                _reservePrice ==
                idToBidProposalDetails[_proposalId].reservePrice
            ) {
                isValidParcel = true;
                break;
            }
        }
        require(isValidParcel, "Invalid parcel details");

        uint256 totalTokens = 0;

        // Calculate total number of tokens for the proposalId
        for (uint256 i = 0; i < parcels.length; i++) {
            if (parcels[i].proposalId == _proposalId) {
                totalTokens = totalTokens.add(parcels[i].parcelOwned);
            }
        }
        require(totalTokens > 0, "No tokens to distribute");

        // Distribute reserve price among parcel holders
        for (uint256 i = 0; i < parcels.length; i++) {
            if (parcels[i].proposalId == _proposalId) {
                uint256 distributionAmount = (parcels[i].parcelOwned *
                    idToBidProposalDetails[_proposalId].reservePrice) /
                    totalTokens;

                // Transfer the distribution amount to the parcel holder
                parcels[i].parcelOwner.transfer(distributionAmount);
            }
        }
        //NOTE:burn the parcel tokens
    }


    /*
    @param _escrowContract- address of the escrow contract
    @notice this function helps in setting up the Escrow Contract
    */
    function setEscrowContract(address payable _escrowContract)
        external
        onlyOwner
    {
        escrowContract = _escrowContract;
    }

  
    /*
    @param _proposalId- proposal id for the master and parcel NFTs
    @param _bidId- bid id of the particular NFt 
    @param _reservePrice- minimum price for the master NFT
    @param _duration- duration for the bid
    @notice this function start the bid and stores the details
    */

    function startBid(
        uint256 _proposalId,
        uint256 _bidId,
        uint256 _reservePrice,
        uint256 _duration
    ) external onlyOwner {
        bidProposals storage bids = idToBidProposalDetails[_proposalId];

        require(_proposalId == bids.proposalId, "proposalId dont exist");
        require(_bidId == bids.bidId, " please enter valid bidId");
        require(_duration > 0, "duration can't be zero.");
        require(_reservePrice > 0, "reserve price cant be zero");

        bidIdToBidDetails[_bidId].proposalId = _proposalId;
        bidIdToBidDetails[_bidId].bidId = _bidId;
        bidIdToBidDetails[_bidId].reservePrice = _reservePrice;
        bidIdToBidDetails[_bidId].duration = _duration;
        bidIdToBidDetails[_bidId].startAt = block.timestamp;
        bidIdToBidDetails[_bidId].endAt = _duration + block.timestamp;
        bidIdToBidDetails[_bidId].highestBid = 0;
        bidIdToBidDetails[_bidId].highestBidder = payable(address(0));
        bidIdToBidDetails[_bidId].isOnSale = true;
    }

    /*
    @param _bidId- bid id of the particular NFt 
    @param _bidAmount - bidding amount for the Master Nft by the investors
    @param _walletAddress- wallet address of the caller so Nft can be transfered to their wallet address
    @notice this function allows bidders to bid on the particular masterNft.The amount bidded by the bidderrs will be send to the escrow contract,
    the highest bid kept in the escrow contract and previous bid send back to the respective bidder
    */
    function bidOnMasterNft(
        uint256 _bidId,
        uint256 _bidAmount,
        address _walletAddress
    ) external payable {
        BidDetails storage bidDetails = bidIdToBidDetails[_bidId];
        require(block.timestamp < bidDetails.endAt, "Bidding has ended");
        require(
            _bidAmount > bidDetails.reservePrice,
            "Bid amount must be above reserve price"
        );
        require(
            _bidAmount > bidDetails.highestBid,
            "Bid amount must be higher than current highest bid"
        );

        //Deposit the new bid amount into the escrow
        escrow.deposit{value: msg.value}(_walletAddress, _bidAmount);

        // Return funds to the previous highest bidder
        if (bidDetails.highestBidder != address(0)) {
            escrow.refund(bidDetails.highestBidder, bidDetails.highestBid);
        }

        // Update the highest bid and bidder
        bidDetails.highestBid = _bidAmount;
        bidDetails.highestBidder = payable(_walletAddress);
    }

    /*
In case the bid winner wants to claim Artwork, they need to pay the necessary service fees, DIC member fees,
custodian fees and shipping charges. Once these fees are settled, the Artwork will be shipped to the buyer's location,
and all the corresponding NFTs will be burned.
*/

    /*
    @param _proposalId- proposal id for the master and parcel NFTs
    @param _bidId- bid id of the particular NFt 
    @notice this function helps the new owner of masterNft to claim the art in physical, for this one has to pay some fees and then MasterNft will burn.
    and physical art will deliver to the owner
    */

    function claimPhysicalAsset(uint256 _proposalId, uint256 _bidId)
        external
        payable
    {
        BidDetails storage bidDetails = bidIdToBidDetails[_bidId];

        require(
            msg.sender == bidDetails.highestBidder,
            "You don't own this NFT"
        );
        require(
            _proposalId == bidDetails.proposalId,
            "Please enter a valid proposalId"
        );
        require(_bidId == bidDetails.bidId, "Please enter a valid bidId");

        // Calculate the total amount including fees
        uint256 totalAmount = msg.value +
            serviceFees +
            DICmemberFees +
            custodianFees +
            shippingFees;

        // Ensure that the sent amount matches the calculated total amount
        require(msg.value == totalAmount, "Incorrect amount sent");

        // Burn ERC-1155 token
        ERC1155Burnable(address(this)).burn(msg.sender, _proposalId, 1);
    }

    /*
If there are no suitable offers, the proposer(artis) can redeem their NFT back to the platform, 
but this process incurs platform fees and custodianship charges, deducted from the stacking amount.
*/
    function requestToReleaseAsset(uint256 _proposalId)
        external
        onlyArtist(_proposalId)
    {}

    function getBidProposalDetails(uint256 _proposalId, uint256 _bidId)
        internal
        view
        returns (bidProposals memory)
    {
        bidProposals storage proposals = idToBidProposalDetails[_proposalId];
        require(_bidId > 0 && _bidId <= proposals.bidId, "Invalid bid ID");
        return proposals;
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
        returns (bidProposals memory)
    {
        return idToBidProposalDetails[_proposalId];
    }

    function getParcelContractAddress(uint256 _proposalId)
        public
        view
        returns (address)
    {
        Parcels[] memory parcels = proposalIdToParcels[_proposalId];

        require(parcels.length > 0, "No parcels for the proposal");
        address parcelTokenAddress = parcels[0].parcelToken;

        return parcelTokenAddress;
    }

    function getAllVotersWithStatus(uint256 _proposalId)
        external
        view
        returns (address[] memory, bool[] memory)
    {
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
