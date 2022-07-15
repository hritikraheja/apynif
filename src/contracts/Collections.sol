//SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;

import './NFT.sol';
import './Definitions.sol';
import './Marketplace.sol';
import "@openzeppelin/contracts/utils/Counters.sol";
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

/**
This contract stores the details of collections defined by the Definitions smart contract, which 
includes collection id, name, description, owner's name, owner's address, number of nfts, category, etc

@author : Hritik Raheja
*/

contract Collections is ReentrancyGuard{

    /**
    1. _collectionIdGenerator allots a new collection Id to every newly created collection.
    2. collectionCount maintains the count of the total number of collection.
    3. allCollections array contains the details of all the collections.
    4. idToIndex mapping maps the every collection id to its corresponding index 
    in the allCollections array.
    5. nftContractInstance is the instance of the deployed NFT contract, required 
    to call the methods of the same.
    */
    using Counters for Counters.Counter;
    Counters.Counter public _collectionIdGenerator;
    uint256 public collectionCount;
    Definitions.Collection[] public allCollections;
    mapping(uint256 => uint256) public idToIndex;
    mapping(uint256 => uint256) public nftIdToCollectionId;
    NFT nftContractInstance;
    address marketplaceContractAddress;
    Marketplace marketplaceContractInstance;

    /**
    The deployed NFT contract's address is provided as a parameter in the constructor, 
    in order to create an instance.
    */
    constructor(address _nftContractAddress) {
        nftContractInstance = NFT(_nftContractAddress);
    }

    /**
    This method sets the marketplace contract address for super admin validations.
    This method is called for the first time when the marketplace contract is created, and 
    can be called again but only by the super admin itself.
    @param _contractAddress - The address of the deployed marketplace contract. 
    */
    function setMarketplaceContractAddress(address _contractAddress) public nonReentrant{
        if(marketplaceContractAddress != address(0)){
            require(msg.sender == marketplaceContractInstance.superAdmin() || 
            msg.sender == marketplaceContractAddress, 
            "Only super admin can set the marketplace address.");
        }
        marketplaceContractAddress = _contractAddress;
        marketplaceContractInstance = Marketplace(_contractAddress); 
    }

    /**
    This method creates a collection, increments the collectionCount accordingly, generates a new collectionID for it, 
    and adds it to the allCollections array.
    @param _collectionName - The name of the collection to be created.
    @param _collectionCoverImageUri - The cover image uri of the collection to be created.
    @param _collectionDescription - The description of the collection to be created.
    @param _collectionOwnerName - The official name of the collection's owner, to be created.
    @param _tokenIds - The tokenIds of the listed single NFTs to be added in the collection.
    @param _category - The category of the collection to be created.
    @return - The collection Id of the newly created collection. 
    */
    function createCollection(string memory _collectionName, string memory _collectionCoverImageUri,
        string memory _collectionDescription, string memory _collectionOwnerName,
        uint256[] memory _tokenIds, string memory _category) public returns(uint256){
            _collectionIdGenerator.increment();
            address payable _a = payable(msg.sender);
            allCollections.push(Definitions.Collection(_collectionIdGenerator.current(), 
            _collectionName, _collectionCoverImageUri, _collectionDescription, _collectionOwnerName, _a, _tokenIds.length, _tokenIds, false, _category));
            collectionCount++;
            idToIndex[_collectionIdGenerator.current()] = allCollections.length - 1;
            return (_collectionIdGenerator.current());
    }


    /**
    This method creates a collection, increments the collectionCount accordingly, generates a new collectionID for it, 
    and adds it to the allCollections array.
    @param _collectionName - The name of the collection to be created.
    @param _collectionCoverImageUri - The cover image uri of the collection to be created.
    @param _collectionDescription - The description of the collection to be created.
    @param _collectionOwnerName - The official name of the collection's owner, to be created.
    @param _tokenIds - The tokenIds of the listed single NFTs to be added in the collection.
    @param _category - The category of the collection to be created.
    @param _sender - The seller of the collection to be created.
    @return - The collection Id of the newly created collection. 
    */
    function createCollection(string memory _collectionName, string memory _collectionCoverImageUri,
        string memory _collectionDescription, string memory _collectionOwnerName,
        uint256[] memory _tokenIds, string memory _category, address _sender) public returns(uint256){
            _collectionIdGenerator.increment();
            allCollections.push(Definitions.Collection(_collectionIdGenerator.current(), 
            _collectionName, _collectionCoverImageUri, _collectionDescription, _collectionOwnerName, 
            payable(_sender), _tokenIds.length, _tokenIds, false, _category));
            collectionCount++;
            idToIndex[_collectionIdGenerator.current()] = allCollections.length - 1;
            return (_collectionIdGenerator.current());
    }

    /**
    This method returns an array containing the tokenIds of all the NFTs 
    that are present in the collection.
    @param _collectionId - The id of the collection whose tokenIds are to be fetched.
    @return - A uint256 array containing the tokenIds of all the NFTs.
    */
    function getNftIdsByCollectionId(uint256 _collectionId) public view returns(uint256[] memory){
        uint256 _index = idToIndex[_collectionId];
        require(_index != 0 || allCollections[_index].collectionId == _collectionId, "Collectiion doesn't exist.");
        return allCollections[_index].nftIds;
    }

    /**
    This method deletes a collection, decrements the collectionCount and 
    removes it from the idToIndex mapping.
    @param _collectionId - The id of the collection to be deleted.
    */
    function deleteCollection(uint256 _collectionId) public {
        uint256 _index = idToIndex[_collectionId];
        require(allCollections[_index].nftCount == 0, "Collection isn't empty, cannot be deleted.");
        require(_index != 0 || allCollections[_index].collectionId == _collectionId, "Collection doesn't exist.");
        if(allCollections.length > 1){
            Definitions.Collection memory _temp = allCollections[_index];
            allCollections[_index] = allCollections[collectionCount-1];
            allCollections[collectionCount - 1] = _temp;
            idToIndex[allCollections[_index].collectionId] = _index;
        }
        allCollections.pop();
        collectionCount--;
        delete idToIndex[_collectionId];
    }

    /**
    This method sets the isListed field of the collection to be true, i.e. it lists the 
    collection to the marketplace.
    @param _sender - The caller of the function.
    @param _collectionId - The id of the collection to be listed to the marketplace.
    */
    function listCollection(address _sender, uint256 _collectionId) public{
        uint256 _index = idToIndex[_collectionId];
        require(_index != 0 || allCollections[_index].collectionId == _collectionId, "Collection doesn't exist.");
        require(_sender == allCollections[_index].collectionOwnerAddress, "Only owner can list a collection.");
        allCollections[_index].isListed = true;
    }

    /**
    This method sets the isListed field of the collection to be false, i.e. it unlists the 
    collection from the marketplace.
    @param _sender - The caller of the function.
    @param _collectionId - The id of the collection to be unlisted from the marketplace.
    */
    function unlistCollection(address _sender, uint256 _collectionId) public{
        uint256 _index = idToIndex[_collectionId];
        require(_index != 0 || allCollections[_index].collectionId == _collectionId, "Collection doesn't exist.");
        require(_sender == allCollections[_index].collectionOwnerAddress, "Only owner can unlist a collection.");
        allCollections[_index].isListed = false;
    }

    /**
    This method adds an nft into the collection, i.e. it adds the tokenId of the NFT
    to the nftIds array of the collection and increments the nftCount.
    @param _collectionId - The id of the collection in which NFT is to be added.
    @param _listedNftId - The id of the listed NFT which is to be added to the collection.
    */
    function addNftToCollection(uint256 _collectionId, uint256 _listedNftId) public nonReentrant{
        uint256 _index = idToIndex[_collectionId];
        require(_index != 0 || allCollections[_index].collectionId == _collectionId, "Collection doesn't exist.");
        require(msg.sender == allCollections[_index].collectionOwnerAddress, "Only owner can add nfts to a collection.");
        require(nftContractInstance.isListedSingleNftorNot(_listedNftId), "Unlisted nfts cannnot be added to a collection.");
        nftContractInstance.removeNftFromSingleNftsArray(msg.sender, _listedNftId);
        allCollections[_index].nftIds.push(_listedNftId);
        allCollections[_index].nftCount = allCollections[_index].nftCount + 1;
        nftIdToCollectionId[_listedNftId] = _collectionId;
    }
    
    /**
    This method adds multiple NFTs into the collection, i.e. it adds the tokenIds of the NFTs
    to the nftIds array of the collection and updates the nftCount accordingly.
    @param _collectionId - The id of the collection in which NFTs are to be added.
    @param _listedNftIds - A uint256 array containing the tokenIds of all NFTs that
    are to be added to the collection.
    */
    function addMultipleNftsToCollection(uint256 _collectionId, uint256[] memory _listedNftIds) public{
        for(uint256 _i = 0; _i < _listedNftIds.length; _i++){
            addNftToCollection(_collectionId, _listedNftIds[_i]);
        }
    }

    /**
    This method removes the provided nft from the collection, i.e. it finds the index
    at which the nft is stored, removes it and decrements the value of nftCount.
    @param _collectionId - The id of the collection from which NFT is to be removed.
    @param _nftId - The id of the nft to be removed from the collecition.
    */
    function removeNftFromCollection(uint256 _collectionId, uint256 _nftId) public{
        uint256 _index = idToIndex[_collectionId];
        require(_index != 0 || allCollections[_index].collectionId == _collectionId, "Collection doesn't exist.");
        require(msg.sender == allCollections[_index].collectionOwnerAddress, "Only owner can add nfts to a collection.");
        uint256 _nftIndex;
        bool _nftFound = false;
        for(uint _i = 0; _i < allCollections[_index].nftCount; _i++){
            if(allCollections[_index].nftIds[_i] == _nftId){
                _nftIndex = _i;
                _nftFound = true;
                break;
            }
        }
        require(_nftFound, "NftId doesn't belongs to this collection.");
        if(allCollections[_index].nftCount > 1){
            uint256 _temp = allCollections[_index].nftIds[_nftIndex];
            allCollections[_index].nftIds[_nftIndex] = allCollections[_index].nftIds[allCollections[_index].nftCount - 1];
            allCollections[_index].nftIds[allCollections[_index].nftCount - 1] = _temp;
        }
        allCollections[_index].nftIds.pop();
        allCollections[_index].nftCount = allCollections[_index].nftCount - 1;
        nftContractInstance.addNftToSingleNftsArray(marketplaceContractAddress, _nftId);
        delete nftIdToCollectionId[_nftId];
    }

    /**
    This method returns a list of all the collections owned by the provided address.
    @param _owner - The address of the owner whose collections are to be fetched.
    */
    function getAllCollectionsByOwnerAddress(address _owner) public view returns(uint256[] memory){
        uint256[] memory result;
        uint _j = 0;
        for(uint _i = 0; _i < allCollections.length; _i++){
            if(allCollections[_i].collectionOwnerAddress == _owner){
                result[_j] = allCollections[_i].collectionId;
                _j++;
            }
        }
        return result;
    }

    /**
    This method returns the address of the respective collection.
    @param _collId - The id of the collection whose owner's address is to be fetched.
    @return - The collection owner's address.
    */
    function getOwnerByCollectionId(uint256 _collId) public view returns (address){
        uint256 _index = idToIndex[_collId];
        return allCollections[_index].collectionOwnerAddress;
    }
}