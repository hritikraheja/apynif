//SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;

import './Definitions.sol';
import './Collections.sol';
import './NFT.sol';
import './Marketplace.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

/**
This contract stores the details of all the businesses, that are defined by the
Definitions smart contract, generates ids for new businesses and maintains which 
collection/nft is owned by which business. It supports the admin to add/remove 
collections/nfts and manipulating the same.

@author : Hritik Raheja
*/

contract Businesses is ReentrancyGuard{

    /**
    1. _businessIdGenerator - allots a business Id to every newly created business.
    2. nftContractInstance - is an instance of the NFT contract, i.e., used to call
    the methods of the NFT contract.
    3. collectionsContractInstance - is an instance of the Collections contract, i.e.,
    used to call the methods of the Collections contract.
    4. businesses - is array that stores the details of all businesses.
    5. businessCount - is the current count of businesses in the contract.
    6. businessIdToIndex - stores that which business is stored at which index in the
    businesses array.
    7. nftIdToIndex - stores which nft is stored at which index in its corresponding business.
    8. nftIdToBusinessId - stores which nft is stored in which business.
    9. collectionIdToIndex - stores which collection is stored at which index
    in its corresponding business.
    10. collectionIdToBusinessId - stores which collection is stored in which business.
    11. employeesAddressToIndex - stores which employee is stored at which index in the 
    employees array defined in the Business struct in the Definitions smart contract.
    12. employeeAddressToBusinessId - stores which employee belongs to which business.
    13. marketPlaceContractAddress - The address of the deployed marketplace contract.
    14. marketplaceContractInstance - is an instance of the Marketplace contract, i.e., used to
    fetch the superadmin address.
    */
    using Counters for Counters.Counter;
    Counters.Counter public _businessIdGenerator;
    NFT nftContractInstance;
    Collections collectionsContractInstance;
    Definitions.Business[] public businesses;
    uint256 public businessCount;
    mapping(uint256 => uint256) public businessIdToIndex;
    mapping(uint256 => uint256) public nftIdToIndex;
    mapping(uint256 => uint256) public nftIdToBusinessId;
    mapping(uint256 => uint256) public collectionIdToIndex;
    mapping(uint256 => uint256) public collectionIdToBusinessId;
    mapping(address => uint256) public employeeAddressToIndex;
    mapping(address => uint256) public employeeAddressToBusinessId;
    address marketplaceContractAddress;
    Marketplace marketplaceContractInstance;

    event businessCreated(uint businessId, string businessName, uint feeePercent, address adminAddress);
    event businessRemoved(uint businessId, address adminAddress);
    event employeeAddedToBusiness(uint bId, address employeeAddress, address adminAddress);
    event employeeRemovedFromBusiness(uint bId, address employeeAddress, address adminAddress);  
    event collectionAddedToBusiness(uint bId, uint collectionId, address adminAddress);
    event nftAddedToBusiness(uint bId, uint nftId, address adminAddress);
    event collectionRemovedFromBusiness(uint bId, uint collectionId, address adminAddress);
    event nftRemovedFromBusiness(uint bId, uint nftId, address adminAddress);
    event businessFeeUpdated(uint bId, uint newFeePercent, address adminAddress);


    /**
    This modifier specifies that only super admin can add/delete a  business.
    */
    modifier onlySuperAdmin(){
        require(msg.sender == marketplaceContractInstance.superAdmin(), 
        "Businesses can only be created or removed by the marketplace super admin.");
        _;
    }

    /**
    This method sets the marketplace contract address for super admin validations.
    This method is called for the first time when the marketplace contract is created, and 
    can be called again but only by the super admin itself.
    @param _marketplaceContractAddress - The address of the deployed marketplace contract. 
    */
    function setMarketplaceAddress(address _marketplaceContractAddress) public nonReentrant{
        if(marketplaceContractAddress != address(0)){
            require(msg.sender == marketplaceContractInstance.superAdmin() || 
            msg.sender == marketplaceContractAddress, 
            "Only super admin can set the marketplace address.");
        } 
        marketplaceContractAddress = _marketplaceContractAddress;
        marketplaceContractInstance = Marketplace(marketplaceContractAddress);
    }

    /**
    The deployed NFT and Collections smart contract's addresses are provided as parameters
    in the constructor in order to create the instances of the contracts.
    */
    constructor(address _nftContractAddress, address _collectionsContractAddress){
        nftContractInstance = NFT(_nftContractAddress);
        collectionsContractInstance = Collections(_collectionsContractAddress);
    }

    /**
    This method creates a business, increments the businessCount, generates a new and unique
    business Id, adds the business to the businesses array and maintains the mapping of 
    business Id to its corresponding index in the businesses array.
    @param _bName - The name of the business to be created.
    @param _bLogoUri - The logo uri of the business to be created.
    @param _feePercent - The fee percentage charged by the business to be created.
    @param _adminAddress - The address of the business admin.
    @param _employees - An array consisting of addresses of all employees in the business.
    @return This method returns the id of the newly created business.
    */
    function addBusiness(string memory _bName, string memory _bLogoUri,
    uint256 _feePercent, address _adminAddress, address[] memory _employees) public onlySuperAdmin returns(uint256){
        _businessIdGenerator.increment();
        uint256[] memory _emptyArray;
        Definitions.Business memory _newBusiness = Definitions.Business(_businessIdGenerator.current(),
     _bName, _bLogoUri, _feePercent, _adminAddress, 0, 0, _emptyArray,
        new uint256[](0),_employees);
        businesses.push(_newBusiness);
        businessIdToIndex[_businessIdGenerator.current()] = businesses.length - 1;
        for(uint256 _i = 0; _i < _employees.length; _i++){
           addEmployee(_businessIdGenerator.current(), _employees[_i]);
        }
        businessCount++;
        emit businessCreated(_businessIdGenerator.current(), _bName, _feePercent, _adminAddress);
        return _businessIdGenerator.current();
    }

    /**
    This method removes a business from the marketplace, i.e., it removes the business
    from the businesses array, decrements the businessCount and removes the businessIdToindex 
    mapping for the particular business Id.
    @param _businessId - The id of the business to be removed.
    */
    function removeBusiness(uint256 _businessId) public onlySuperAdmin{
        uint256 _index  = businessIdToIndex[_businessId];
        require(_index != 0 || businesses[_index].businessId == _businessId, "Business doesn't exist");
        uint256 _employeeCount = businesses[_index].employees.length;
        address admin = businesses[_index].adminAddress;
        for(uint256 _i = 0; _i < _employeeCount; _i++){
            address _employeeAddress = businesses[_index].employees[_employeeCount - _i - 1];
            businesses[_index].employees.pop();
            delete employeeAddressToIndex[_employeeAddress];
            delete employeeAddressToBusinessId[_employeeAddress];
        }
        if(businesses.length > 1){
            Definitions.Business memory _temp = businesses[_index];
            businesses[_index] = businesses[businesses.length - 1]; 
            businesses[businesses.length - 1] = _temp;
            businessIdToIndex[businesses[_index].businessId] = _index;
        }
        delete businessIdToIndex[_businessId];
        businesses.pop();
        businessCount--;
        emit businessRemoved(_businessId, admin);
    }

    /**
    This method adds an already listed collection to a business.
    @param _businessId - The id of the business in which the collection is to be added.
    @param _collectionId - The id of the collection which is to be added.
    */
    function addCollectionToBusiness(uint256 _businessId, uint256 _collectionId) public{
        uint256 _index = businessIdToIndex[_businessId];
        require(msg.sender == businesses[_index].adminAddress, "Only admin can add a collection to the business.");
        require(collectionOrNftOwnedByOwnerOrEmployee(_businessId, _collectionId, false), "You can add only collections owned by the admin or the employees.");
        businesses[_index].collectionIds.push(_collectionId);
        businesses[_index].collectionCount = businesses[_index].collectionCount + 1;
        collectionIdToBusinessId[_collectionId] = _businessId;
        collectionIdToIndex[_collectionId] = businesses[_index].collectionIds.length - 1;
        emit collectionAddedToBusiness(_businessId, _collectionId, businesses[_index].adminAddress);
    }

    /**
    This methods adds a number of already listed collections to a business.
    @param _businessId - The id of the business in which the collections are to be added.
    @param _collectionIds - An array of ids of all collections which are to be added.
    */
    function addMultipleCollectionsToBusiness(uint256 _businessId, uint256[] memory _collectionIds) public{
        for(uint256 _i = 0; _i < _collectionIds.length; _i++){
            addCollectionToBusiness(_businessId, _collectionIds[_i]);
        }
    }

    /**
    This methods creates a new collection and adds it to a business.
    @param _businessId - The id of the business in which the collection is to be created.
    @param _collectionName - The name of the collection which is to be created in the business.
    @param _collectionCoverImageUri - The uri of the collection's cover image.
    @param _collectionDescription - The description of the collection which is to be created.
    @param _collectionOwnerName - The name of the collection's owner.
    @param _tokenIds - An array containing ids of all nfts that are present in the collection.
    @param _category - The category of the collection to be created.
    */
    function createCollectionInBusiness(uint256 _businessId, string memory _collectionName, 
        string memory _collectionCoverImageUri, string memory _collectionDescription, 
        string memory _collectionOwnerName, uint256[] memory _tokenIds, string memory _category) public nonReentrant{
        uint256 _index = businessIdToIndex[_businessId];
        require(msg.sender == businesses[_index].adminAddress, "Only admin can create a collection in the business.");
        uint256 _newCollectionId = collectionsContractInstance.createCollection(_collectionName,
        _collectionCoverImageUri, _collectionDescription, _collectionOwnerName, 
        _tokenIds, _category, msg.sender);
        addCollectionToBusiness(_businessId, _newCollectionId);
    }

    /**
    This method adds an already listed NFT to a business.
    @param _businessId - The id of the business in which the nft is to be added.
    @param _nftId - The id of the nft which is to be added.
    */
    function addNftToBusiness(uint256 _businessId, uint256 _nftId) public nonReentrant{
        uint256 _index = businessIdToIndex[_businessId];
        address ownerAddress = nftContractInstance.getOwnerByNftId(_nftId);
        require(msg.sender == businesses[_index].adminAddress || employeeAddressToBusinessId[ownerAddress] == _businessId, "Only admin or an employee can add an nft to the business.");
        require(collectionOrNftOwnedByOwnerOrEmployee(_businessId, _nftId, true), "You can add only nfts owned by the admin or the employees.");
        businesses[_index].nftIds.push(_nftId);
        businesses[_index].singleNftCount = businesses[_index].singleNftCount + 1;
        nftIdToBusinessId[_nftId] = _businessId;
        nftIdToIndex[_nftId] = businesses[_index].nftIds.length - 1;
        emit nftAddedToBusiness(_businessId, _nftId, businesses[_index].adminAddress);
    }

    /**
    This methods adds a number of already listed nfts to a business.
    @param _businessId - The id of the business in which the nfts are to be added.
    @param _nftIds - An array of ids of all nfts which are to be added.
    */
    function addMultipleNftsToBusiness(uint256 _businessId, uint256[] memory _nftIds) public{
        for(uint256 _i = 0; _i < _nftIds.length; _i++){
            addNftToBusiness(_businessId, _nftIds[_i]);
        }
    }

    /**
    This methods creates a new nft and adds it to a business.
    @param _businessId - The id of the business in which the nft is to be added.
    @param _tokenUri - The token uri of the nft that is to be minted and added to the business.
    @param _price -  The price of the nft that is to be minted and added to the business.
    @param _category - The category of the nft that is to be minted and added to the business.
    */
    function createNftInBusiness(uint256 _businessId ,string memory _tokenUri, uint256 _price,
        string memory _category) public{
            uint256 _index = businessIdToIndex[_businessId];
            require(msg.sender == businesses[_index].adminAddress || employeeAddressToBusinessId[msg.sender] == _businessId, "Only admin or employee can create an nft to the business.");
            uint256 _newNftId = nftContractInstance.createNft(_tokenUri,
            _price, _category, msg.sender);
            addNftToBusiness(_businessId, _newNftId);
    }

    /**
    This method removes a collection from the business.
    @param _businessId - The id of the business from which the collection is to be removed.
    @param _collectionId - The id of the collection which is to be removed.
    */
    function removeCollectionFromBusiness(uint256 _businessId, uint256 _collectionId) public nonReentrant{
        uint256 _index = businessIdToIndex[_businessId];
        address collectionOwner = collectionsContractInstance.getOwnerByCollectionId(_collectionId);
        require(msg.sender == businesses[_index].adminAddress || msg.sender == marketplaceContractAddress || msg.sender == collectionOwner, "Only admin can remove a collection from a business.");
        require(_businessId == collectionIdToBusinessId[_collectionId], "This collection doesn't belong to this business.");
        uint256 _collectionIndex = collectionIdToIndex[_collectionId];
        if(businesses[_index].collectionCount > 1){
            uint256 _temp = businesses[_index].collectionIds[_collectionIndex];
            businesses[_index].collectionIds[_collectionIndex] = businesses[_index].collectionIds[businesses[_index].collectionCount - 1];
            businesses[_index].collectionIds[businesses[_index].collectionCount - 1] = _temp;
            collectionIdToIndex[businesses[_index].collectionIds[_collectionIndex]] = _collectionIndex;
        }
        businesses[_index].collectionIds.pop();
        businesses[_index].collectionCount = businesses[_index].collectionCount - 1;
        delete collectionIdToIndex[_collectionId];
        delete collectionIdToBusinessId[_collectionId];
        emit collectionRemovedFromBusiness(_businessId, _collectionId, businesses[_index].adminAddress);
    }

    /**
    This method removes a nft from the business.
    @param _businessId - The id of the business from which the nft is to be removed.
    @param _nftId - The tokenId of the nft which is to be removed.
    */
    function removeNftFromBusiness(uint256 _businessId, uint256 _nftId) public nonReentrant{
        uint256 _index = businessIdToIndex[_businessId];
        address nftOwner = nftContractInstance.getOwnerByNftId(_nftId);
        require(msg.sender == businesses[_index].adminAddress || msg.sender == marketplaceContractAddress || msg.sender == nftOwner, "Only admin can remove an nft from a business.");
        require(_businessId == nftIdToBusinessId[_nftId], "This NFT doesn't belongs to this business.");
        uint256 _nftIndex = nftIdToIndex[_nftId];
        if(businesses[_index].singleNftCount > 1){
            uint256 _temp = businesses[_index].nftIds[_nftIndex];
            businesses[_index].nftIds[_nftIndex] = businesses[_index].nftIds[businesses[_index].nftIds.length - 1];
            businesses[_index].nftIds[businesses[_index].nftIds.length - 1] = _temp;
            nftIdToIndex[businesses[_index].nftIds[_nftIndex]] = _nftIndex;
        }
        businesses[_index].nftIds.pop();
        businesses[_index].singleNftCount = businesses[_index].singleNftCount - 1;
        delete nftIdToIndex[_nftId];
        delete nftIdToBusinessId[_nftId];
        emit nftRemovedFromBusiness(_businessId, _nftId, businesses[_index].adminAddress);
    }

    /**
    This methods updates the feePercent of the business by the provided fee percent.
    @param _businessId - The id of the business whose fee percentage is to be updated.
    @param _newFee - The updated fee percent.
    */
    function updateFeePercent(uint256 _businessId, uint256 _newFee) public{
        uint256 _index = businessIdToIndex[_businessId];
        require(msg.sender == businesses[_index].adminAddress, "Only admin can update the fee percent.");
        businesses[_index].feePercent = _newFee; 
        emit businessFeeUpdated(_businessId, _newFee, businesses[_index].adminAddress);
    }

    /**
    This method adds an employee to a business.
    @param _businessId - The id of the business in which an employee is to be added.
    @param _newEmployee - The address of the new eployee.
    */
    function addEmployee(uint256 _businessId, address _newEmployee) public {
        uint256 _index = businessIdToIndex[_businessId];
        require(msg.sender == businesses[_index].adminAddress, "Only admin can add an employee in the business.");
        require(employeeAddressToBusinessId[_newEmployee] == 0, "This address is already an employee in a business.");
        businesses[_index].employees.push(_newEmployee);
        employeeAddressToBusinessId[_newEmployee] = _businessId;
        employeeAddressToIndex[_newEmployee] = businesses[_index].employees.length - 1;
        emit employeeAddedToBusiness(_businessId, _newEmployee, businesses[_index].adminAddress);
    }

    /**
    This methods removes an employeee from a business.
    @param _businessId - The id of the business from which employee is to be removed.
    @param _employeeAddress - The address of the employee which is to be removed.
    */
    function removeEmployee(uint256 _businessId, address _employeeAddress) public {
        uint256 _index = businessIdToIndex[_businessId];
        require(msg.sender == businesses[_index].adminAddress, "Only admin can remove an employee from the business.");
        require(_businessId == employeeAddressToBusinessId[_employeeAddress], "Employee doesn't exist in this business.");
        uint256 _employeeIndex = employeeAddressToIndex[_employeeAddress];
        address _temp = businesses[_index].employees[_employeeIndex];
        businesses[_index].employees[_employeeIndex] = businesses[_index].employees[businesses[_index].employees.length - 1];
        businesses[_index].employees[businesses[_index].employees.length - 1] = _temp;
        businesses[_index].employees.pop();
        delete employeeAddressToIndex[_employeeAddress];
        delete employeeAddressToBusinessId[_employeeAddress];
        if(businesses[_index].employees.length != 0){
            employeeAddressToIndex[businesses[_index].employees[_employeeIndex]] = _employeeIndex;
        }
        emit employeeRemovedFromBusiness(_businessId, _employeeAddress, businesses[_index].adminAddress);
    }

    /**
    This method fetches the collections owned by a business.
    @param _businessId - The id of the business whose collections are to be fetched.
    @return - An array containing ids of all collections owned by the business.
    */
    function getCollectionsInBusiness(uint256 _businessId) public view returns(uint256[] memory){
        require(businessCount != 0, "Invalid business ID.");
        uint256 _index = businessIdToIndex[_businessId];
        return businesses[_index].collectionIds;
    }

    /**
    This method fetches the nfts owned by a business.
    @param _businessId - The id of the business whose nfts are to be fetched.
    @return - An array containing ids of all single nfts owned by the business.
    */
    function getNftsInBusiness(uint256 _businessId) public view returns(uint256[] memory){
        require(businessCount != 0, "Invalid business ID.");
        uint256 _index = businessIdToIndex[_businessId];
        return businesses[_index].nftIds;
    }

    /**
    This method fetches all the employee addresses that are working in a business.
    @param _businessId - The id of the business from which employee addresses are to be fetched.
    @return - An array containing addresses of all employees in the business.
    */
    function getEmployeesinBusiness(uint256 _businessId) public view returns(address[] memory){
        require(businessCount != 0, "Invalid business ID.");
        uint256 _index = businessIdToIndex[_businessId];
        return businesses[_index].employees;
    }

    /**
    This method checks whether a collection or an nft is owned by the admin or any of the employees or not.
    @param _bId - The id of the business to be checked.
    @param _id - The id of the collection or NFT to checked.
    @param isNft - The id is an nft or a collection. True values signifies nft and false signifies collection.
    @return - Whether the id belongs to the business admin or an employee or not.
    */
    function collectionOrNftOwnedByOwnerOrEmployee(uint256 _bId, uint256 _id, bool isNft) public view returns(bool){
        address _owner;
        if(isNft){
            _owner = nftContractInstance.getOwnerByNftId(_id);
        } else {
            _owner = collectionsContractInstance.getOwnerByCollectionId(_id);
        }
        if(businessCount == 0){
            return false;
        }
        uint256 _index = businessIdToIndex[_bId];
        if(_owner == businesses[_index].adminAddress){
            return true;
        }
        for(uint256 _i = 0; _i < businesses[_index].employees.length; _i++){
            if(_owner == businesses[_index].employees[_i]){
                return true;
            }
        }
        return false;
    }
}