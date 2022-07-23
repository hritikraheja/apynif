//SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;

import './NFT.sol';
import './Collections.sol';
import './Definitions.sol';
import './Businesses.sol';
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

/**
This contract is responsible for the whole functioning of the marketplace and it has access
to the all the other contract instances.

@author : Hritik Raheja
*/

contract Marketplace is IERC721Receiver, ReentrancyGuard{

    /**
    1. superAdmin - The address of the super admin that can be seen by everyone.
    2. feeAccount - The account address in which fee is to be deposited for the marketplace.
    3. marketplaceFeePercent - The fee percent charged by the marketplace.
    4. nftContractInstance - The instance of the nft contract used to call the methods of the same.
    5. collectionsContractInstance - The instance of the collections contract used to call the methods of the same.
    6. businessesContractInstance - The instance of the businesses contract used to call the methods of the same.
    7. onGoingAuctions - This mapping maps the nft ids with their corresponding auction details.
    8. nftsOnAuction - This array keeps track of the nft ids that are on auction.
    9. nftIdToAuctionIndex - This mappings keep track of the index at which each nft id in the 
       nftsOnAuction array is stored.  
    */
    address public superAdmin;
    address payable feeAccount;
    uint public marketplaceFeePercent;
    NFT nftContractInstance;
    Collections collectionsContractInstance;
    Businesses businessesContractInstance;
    mapping(uint256 => Definitions.NftOnAuction) public onGoingAuctions;
    uint256[] nftsOnAuction;
    mapping (uint256 => uint256) nftIdToAuctionIndex;


    event itemListed(address operator, address from, uint nftId, bytes v);

    /**
    This modifier allows only super admin to perform a specific task.
    */
    modifier onlySuperAdmin(){
        require(msg.sender == superAdmin, "Only super admin can perform this task.");
        _;
    }

    /**
    The following parameters are passed to the constructor at the time of contract creation :-
    1. _superAdmin - The address of the super admin.
    2. _feeAccount - The account address in which the charged fee is to be deposited.
    3. _fee - The fee percentage that is to be charged by the marketplace.
    4. nftContractAddress - The address of the deployed NFT contract.
    5. collectionsContractAddress - The address of the deployed Collections contract.
    6. businessesContractAddress - The address of the deployed Businesses contract. 
    */
    constructor(address _superAdmin, address payable _feeAccount, uint _fee, 
    address nftContractAddress, address collectionsContractAddress,
    address businessesContractAddress) {
        superAdmin = _superAdmin;
        feeAccount = _feeAccount;
        marketplaceFeePercent = _fee;
        nftContractInstance = NFT(nftContractAddress);
        collectionsContractInstance = Collections(collectionsContractAddress);
        businessesContractInstance = Businesses(businessesContractAddress);
        businessesContractInstance.setMarketplaceAddress(address(this));
        nftContractInstance.setMarketplaceContractAddress(address(this));
        collectionsContractInstance.setMarketplaceContractAddress(address(this));
    }

    /**
    This method is oveeridden in order to create an implementation of the IERC721Receiver.
    */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns(bytes4){
        emit itemListed(operator, from, tokenId, data);
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
    This method is used to update the fee account address.
    This method can only be called by the super admin.
    @param _newFeeAccount - The new fee account address that is to be updated.
    */
    function updateFeeAccount(address _newFeeAccount) public onlySuperAdmin{
        feeAccount = payable(_newFeeAccount);
    }

    /**
    This method is used to update the super admin address.
    This method can only be called by the super admin.
    @param _newSuperAdmin - The new super admin address that is to be updated.
    */
    function changeSuperAdmin(address _newSuperAdmin) public onlySuperAdmin{
        superAdmin = _newSuperAdmin;
    }

    /**
    This method is used to update the fee percent.
    This method can only be called by the super admin.
    @param _newFee - The new fee percentage that is to be upadted.
    */
    function changeFeePercent(uint _newFee) public onlySuperAdmin{
        marketplaceFeePercent = _newFee;
    }

    /**
    This method sells the nft to the caller, transfers the ownership and performs the
    various required manipulations in the businesses, collections and nfts contract.
    @param _nftId - The id of the nft that is to be bought.
    */
    function buyNftAndChangeOwner(uint256 _nftId) public payable{
        uint _bId = businessesContractInstance.nftIdToBusinessId(_nftId);
        uint256 _cId = collectionsContractInstance.nftIdToCollectionId(_nftId);
        Definitions.Nft memory _nft = nftContractInstance.getNftByTokenId(_nftId);
        uint256 _price = _nft.details.price;
        address _seller = _nft.details.seller;
        require(msg.value == _price, "Please submit the asking price in order to complete the purchase");
        uint256 feeAmount = marketplaceFeePercent * _price / 100;
        uint256 businessFee = 0;
        feeAccount.transfer(feeAmount);
        if(_bId != 0){
            businessFee = businessesContractInstance.getBusinessFeePercentByBusinessId(_bId) * _price / 100;
            address businessAdmin = businessesContractInstance.getBusinessAdminByBusinessId(_bId);
            payable(businessAdmin).transfer(businessFee);
            businessesContractInstance.removeNftFromBusiness(_bId, _nftId);
        }
        if(_cId != 0){
            collectionsContractInstance.removeNftFromCollection(_cId, _nftId);
        }
        payable(_seller).transfer(_price - feeAmount - businessFee);
        IERC721(address(nftContractInstance)).safeTransferFrom(address(this), msg.sender,
        _nftId);
        nftContractInstance.setSold(_nftId, msg.sender);
    }

    /**
    This method is called by the highest bidder of the nft after the completion of the auction.
    It transfers the ownership to the bidder and performs various required manipulations
    in the businesses, collections and nfts contract. It also calculates and transfers the marketplace and
    business fees.
    @param _nftId - The id of the nft that is to be claimed.
    */
    function claimNftAndTransferOwnershipAfterAuction(uint256 _nftId) public payable{
        Definitions.NftOnAuction memory  _n = onGoingAuctions[_nftId];
        require (block.timestamp > _n.bid_end_time, "Auction has not ended yet.");
        require (msg.sender == _n.highestBidder, "Only highest bidder can claim the NFT after auction.");
        uint _bId = businessesContractInstance.nftIdToBusinessId(_nftId);
        uint256 _cId = collectionsContractInstance.nftIdToCollectionId(_nftId);
        Definitions.Nft memory _nft = nftContractInstance.getNftByTokenId(_nftId);
        uint256 _price = _n.highestBid;
        address _seller = _nft.details.seller;
        require(msg.value == _price, "Please submit the asking price in order to complete the purchase");
        uint256 feeAmount = marketplaceFeePercent * _price / 100;
        uint256 businessFee = 0;
        feeAccount.transfer(feeAmount);
        if(_bId != 0){
            businessFee = businessesContractInstance.getBusinessFeePercentByBusinessId(_bId) * _price / 100;
            address businessAdmin = businessesContractInstance.getBusinessAdminByBusinessId(_bId);
            payable(businessAdmin).transfer(businessFee);
            businessesContractInstance.removeNftFromBusiness(_bId, _nftId);
        }
        if(_cId != 0){
            collectionsContractInstance.removeNftFromCollection(_cId, _nftId);
        }
        payable(_seller).transfer(_price - feeAmount - businessFee);
        nftContractInstance.updatePrice(_seller, _nftId, _price);
        IERC721(address(nftContractInstance)).safeTransferFrom(address(this), _n.highestBidder,
        _nftId);
        nftContractInstance.setSold(_nftId, msg.sender);
        delete onGoingAuctions[_nftId];
        uint256 _temp = nftIdToAuctionIndex[_nftId];
        nftsOnAuction[_temp] = nftsOnAuction[nftsOnAuction.length - 1];
        nftIdToAuctionIndex[nftsOnAuction[_temp]] = _temp;
        nftsOnAuction.pop();
        delete nftIdToAuctionIndex[_nftId];
    }

    /**
    This method returns the balance of the fee account.
    */
    function getBalance() public view returns(uint256){
        return feeAccount.balance;
    }

    /**
    This method is called at the time when an nft is unlisted from the marketplace and the ownership
    is transfered back to the seller of the NFT.
    @param _nftId - The id of the NFT to be transfered back.
    @param seller - The seller of the nft.
    */
    function transferNftBackToOwner(uint256 _nftId, address seller) external{
        address nftSeller = nftContractInstance.getOwnerByNftId(_nftId);
        require(seller == nftSeller, "Nft can only be transfered back to the seller.");
        IERC721(address(nftContractInstance)).safeTransferFrom(address(this), seller, 
        _nftId);
    }

    /**
    This method puts an nft up in the auction. This method can only be called by the seller 
    of the nft.
    @param _nftId - The id of the nft to be auctioned.
    @param basePrice - The base price of the nft at the starting of the auction.
    @param biddingTimeInSec - Time period upto which the nft will be up for selling.
    */
    function putAnNftOnAuction(uint256 _nftId, uint256 basePrice, uint256 biddingTimeInSec) public nonReentrant{
        Definitions.Nft memory _nft = nftContractInstance.getNftByTokenId(_nftId);
        require (msg.sender == _nft.details.seller, "Only owner can put an nft on auction.");
        require (_nft.details.isListed, "Only listed nfts can be put to auction.");
        require (onGoingAuctions[_nftId].bid_end_time == 0, "Nft is already put on auction");
        onGoingAuctions[_nftId] = Definitions.NftOnAuction(_nftId, address(0), basePrice, block.timestamp + biddingTimeInSec);
        nftsOnAuction.push(_nftId);
        nftIdToAuctionIndex[_nftId] = nftsOnAuction.length-1;
    }

    /**
    This method allows the seller of the nft to withdraw it from the auction.
    @param _nftId - The id of the nft to be withdrawn from the auction.
    */
    function withdrawAnNftFromAuction(uint256 _nftId) public nonReentrant{
        require (msg.sender == nftContractInstance.getNftByTokenId(_nftId).details.seller, "Only owner can withdraw an nft from auction.");
        require(nftsOnAuction.length != 0 || nftIdToAuctionIndex[_nftId] != 0 || nftsOnAuction[0] == _nftId, "The provided nft is not on auction currently.");
        delete onGoingAuctions[_nftId];
        uint256 _temp = nftIdToAuctionIndex[_nftId];
        nftsOnAuction[_temp] = nftsOnAuction[nftsOnAuction.length - 1];
        nftIdToAuctionIndex[nftsOnAuction[_temp]] = _temp;
        nftsOnAuction.pop();
        delete nftIdToAuctionIndex[_nftId];
    }

    /**
    This method extends the bidding period of the particular nft in the auction.
    @param _nftId - The id of the nft whose bidding period is to be extended.
    @param _timeToBeAddedInSeconds - The time interval upto which the bidding period is to be extended.
    */
    function extendAuction(uint256 _nftId, uint256 _timeToBeAddedInSeconds) public nonReentrant{
        require(nftsOnAuction.length != 0 || nftIdToAuctionIndex[_nftId] != 0 || nftsOnAuction[0] == _nftId, "The provided nft is not on auction currently.");
        require (msg.sender == nftContractInstance.getNftByTokenId(_nftId).details.seller, "Only owner can extend the time of an auction.");
        onGoingAuctions[_nftId].bid_end_time = onGoingAuctions[_nftId].bid_end_time + _timeToBeAddedInSeconds;
    }

    /**
    This method places a higher bid for a particular nft in the auction.
    @param _nftId - The id of the nft for which the bid is to be placed.
    @param _bid - The higher bid to be placed by the sender.
    */
    function placeBid(uint256 _nftId, uint256 _bid) public nonReentrant{
        require(nftsOnAuction.length != 0 || nftIdToAuctionIndex[_nftId] != 0 || nftsOnAuction[0] == _nftId, "The provided nft is not on auction currently.");
        require (msg.sender != nftContractInstance.getNftByTokenId(_nftId).details.seller, "Owner cannot place bid for his own NFT.");
        require (msg.sender != onGoingAuctions[_nftId].highestBidder, "You are already the highest bidder!");
        require (_bid > onGoingAuctions[_nftId].highestBid, "You have to bid higher than the previous bid.");
        require (block.timestamp <= onGoingAuctions[_nftId].bid_end_time, "The auction has ended. You cannot bid now.");
        onGoingAuctions[_nftId].highestBidder = msg.sender;
        onGoingAuctions[_nftId].highestBid = _bid;
    }

    /**
    This method returns the auction details of the particular nft.
    @param _nftId - The id of the nft whose details are to be fetched.
    */
    function getNftAuctionDetails(uint256 _nftId) public view returns(Definitions.NftOnAuction memory){
        require(nftsOnAuction.length != 0 || nftIdToAuctionIndex[_nftId] != 0 || nftsOnAuction[0] == _nftId, "The provided nft is not on auction currently.");
        return onGoingAuctions[_nftId];
    }

    /**
    This method returns the ids of all the nfts that are currently in auction.
    @return - An array containing list of all nft ids.
    */
    function getNftsInAuction() public view returns(uint256[] memory){
        return nftsOnAuction;
    }

    /**
    This method returns the time duration left before the closing of the auction
    for the particular nft is seconds.
    @param _nftId - The id of the nft whose time duration left is to be fetched.
    */
    function getTimeLeftInAuctionCompletion(uint256 _nftId) public view returns(uint256){
        require(nftsOnAuction.length != 0 || nftIdToAuctionIndex[_nftId] != 0 || nftsOnAuction[0] == _nftId, "The provided nft is not on auction currently.");
        if(block.timestamp >=  onGoingAuctions[_nftId].bid_end_time){
            return 0;
        }
        return onGoingAuctions[_nftId].bid_end_time - block.timestamp;
    }
}