//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import './NFT.sol';

/**
This contract defines various structs that are used in the other contracts (NFT.sol, Collections.sol, 
Businesses.sol and Marketplace.sol).
 */

contract Definitions{
    struct NftDetails{
        uint256 nftId;
        uint256 price;
        address seller;
        bool isSold;
        bool isListed;
        string category;
    }

    struct Nft{
        NftDetails details;
        string uri;
    }

    struct Collection{
        uint256 collectionId;
        string collectionName;
        string collectionCoverImageUri;
        string collectionDescription;
        string collectionOwnerName;
        address payable collectionOwnerAddress;
        uint256 nftCount;
        uint256[] nftIds;
        bool isListed;
        string category;
    }

    struct Business{
        uint256 businessId;
        string businessName;
        string businessLogoUri;
        uint256 feePercent;
        address adminAddress;
        uint256 collectionCount;
        uint256 singleNftCount;
        uint256[] nftIds;
        uint256[] collectionIds;
        address[] employees;
    }

    struct NftOnAuction{
        uint256 nftId;
        address highestBidder;
        uint256 highestBid;
        uint256 bid_end_time;
    }
}