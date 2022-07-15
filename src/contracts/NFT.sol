//SPDX-License-Identifier: Unlicensed.

pragma solidity ^0.8.4;

import './Definitions.sol';
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './Marketplace.sol';

/**
This contract mints and stores the NFTS with their necesary details in a struct defined 
in the Definitions contract, and provides all the necessary methods for manipulating the same.

@author : Hritik Raheja
*/

contract NFT is ERC721URIStorage, ERC721Burnable, ReentrancyGuard{

    /**
    1. _tokenIdGenerator allots a new token Id to every newly minted nft.
    2. nftCount stores the number of nfts.
    3. nfts mapping maps tokenIds to NFT Tokens defined in Definitions contract.
    4. singleNfts stores all the nfts that are not part of any collection.
    5. idToIndex mapping maps the nftIds to their index in the single nfts array, if present.
    */
    using Counters for Counters.Counter;
    Counters.Counter _tokenIdGenerator;
    uint256 public nftCount;
    mapping(uint256 => Definitions.NftDetails) public nfts;
    uint256[] public singleNfts;
    mapping(uint256 => uint256) public idToIndex;
    address marketplaceContractAddress;
    Marketplace marketplaceContractInstance;

    /**
    ERC721 constructor is called with the provided token name and symbol.
    */
    constructor() ERC721("Non-Fungible Token", "NFT"){

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
    This method mints an nft, increments the nftCount accordingly, generates a new nftID for it, 
    and adds it as an independent nft by default.
    @param _tokenUri - This argument is the URI of the newly minted NFT.
    @param price - This argument is the price of the newly minted NFT.
    @param _category - This argument is the category of the newly minted NFT.
    @param _sender - The caller of the function.
    @return - Returns the unique nftId of the newly minted token.
    */
    function createNft(string memory _tokenUri, uint256 price, string memory _category, address _sender) external returns(uint256){
        nftCount++;
        _tokenIdGenerator.increment();
        _mint(_sender, _tokenIdGenerator.current());
        _setTokenURI(_tokenIdGenerator.current(), _tokenUri);
        singleNfts.push(_tokenIdGenerator.current());
        nfts[_tokenIdGenerator.current()] = Definitions.NftDetails(_tokenIdGenerator.current(),
        price, _sender, false, false, _category);
        idToIndex[_tokenIdGenerator.current()] = singleNfts.length - 1;
        setApprovalForAll(marketplaceContractAddress, true);
        return _tokenIdGenerator.current();
    }

    /**
    This method burns an nft, decrements the nft count and removes it from the idToIndex mapping.
    @param sender - The address of the caller or sender to be verified.
    @param _nftId - The id of the nft to be burned or deleted.
    */
    function deleteNft(address sender, uint256 _nftId) external {
        require(sender == nfts[_nftId].seller, "Only owner can delete the NFT");
        _burn(_nftId);
        removeNftFromSingleNftsArray(sender , _nftId);
        delete nfts[_nftId];
        nftCount--;
    }

    /**
    This method removes an nft from the singleNfts array. It is called whenever an nft is added
    to a collection.
    @param _nftId - The id of the NFT to be removed from the single NFTs array.
    */
    function removeNftFromSingleNftsArray(address _sender, uint256 _nftId) public {
        require(_sender == nfts[_nftId].seller, "Only owner can delete the NFT");
        uint256 _index = idToIndex[_nftId];
        uint _lastIndex = singleNfts.length - 1;
        if(_lastIndex != 0){
            uint256 _temp = singleNfts[_index];
            singleNfts[_index] = singleNfts[_lastIndex];
            singleNfts[_lastIndex] = _temp;
            idToIndex[singleNfts[_index]] = _index;
        }
        singleNfts.pop();
        delete idToIndex[_nftId];
    }

    /**
    This method adds an NFT to the single NFTs array. This method is called whenever is removed
    from a collection and is to be listed as an individual array.
    @param _nftId - The id of the NFT to added to the single NFTs array.
    */
    function addNftToSingleNftsArray(address sender, uint256 _nftId) public{
        uint256 _id = nfts[_nftId].nftId;
        address owner = nfts[_nftId].seller;
        require(_nftId > 0 && _nftId <= _tokenIdGenerator.current() && _nftId == _id && sender == owner, "Invalid NFT ID");
        singleNfts.push(_nftId);
        idToIndex[_nftId] = singleNfts.length - 1;
    }

    /**
    This method returns the NFT according to the provided nftId.
    @param _nftId - The id of the nft to be fetched.
    @return - It returns the NFT with the provided _nftId.
    */
    function getNftByTokenId(uint256 _nftId) public view returns(Definitions.Nft memory){
        return Definitions.Nft(nfts[_nftId], tokenURI(_nftId));
    }

    /**
    This method returns an array of all the listed single NFTs.
    @return - A uint256 array of listed single NFTs. 
    */
    function getListedSingleNftIds() public view returns(uint256[] memory){
        uint256 n = 0;
         for(uint i = 0; i < singleNfts.length; i++){
            if(nfts[singleNfts[i]].isListed){
               n++;
            }
        }
        uint256[] memory _temp = new uint256[](n);
        uint _i = 0;
        for(uint j = 0; j < singleNfts.length; j++){
            if(nfts[singleNfts[j]].isListed){
               _temp[_i] = singleNfts[j];
               _i++;
            }
        }
        return _temp;
    }

    /**
    This method sets the value of isListed parameter for the given nftId to be true.
    @param _nftId - The id of the nft to be listed to the marketplace.
    */
    //@param sender - The address of the caller or sender to be verified.
    function listNft(address sender, uint256 _nftId) public {
        require(sender == nfts[_nftId].seller, "Only owner can list the NFT");
        nfts[_nftId].isListed = true;
        nfts[_nftId].isSold = false;
        safeTransferFrom(msg.sender, marketplaceContractAddress, _nftId);
    }

    /**
    This method sets the value of isListed parameter for the given nftId to be false.
    @param sender - The address of the caller or sender to be verified.
    @param _nftId - The id of the nft to be unlisted from the marketplace.
    */
    function unlistNft(address sender, uint256 _nftId) public {
        require(sender == nfts[_nftId].seller, "Only owner can unlist an NFT");
        nfts[_nftId].isListed = false;
        marketplaceContractInstance.transferNftBackToOwner(_nftId, sender);
    }

    /**
    This method sets the value of isSold parameter for the given nftId to be true.
    @param _nftId - The id of the nft to be set as sold.
    @param _newOwner - The address of the buyer of the nft.
    */
    function setSold(uint256 _nftId, address _newOwner) public{
        nfts[_nftId].isSold = true;
        nfts[_nftId].isListed = false;
        nfts[_nftId].seller = _newOwner;
    }

    /**
    This methods sets the isSold parameter of the provided nftId to be false. It is called when
    the newOwner again wants to sell the NFT.
    @param _nftId - The id of the nft to set as unsold. 
    */
    function setUnsold(uint256 _nftId) external{
        nfts[_nftId].isSold = false;
    }

    /**
    This method updates the price of the provided _nftId with the new price.
    @param sender - The address of the sender or seller for verification.
    @param _nftId - The id of the NFT whose price is to be updated.
    @param _price - The new price of the NFT.
    */
    function updatePrice(address sender, uint256 _nftId, uint256 _price) external{
        require(msg.sender == nfts[_nftId].seller || (msg.sender == marketplaceContractAddress && sender == nfts[_nftId].seller), "Only owner can change price of the NFT");
        nfts[_nftId].price = _price;
    }

    /**
    This method returns a list of all the nfts owned by the provided address.
    @param _owner - The address of the owner whose nfts are to be fetched.
    */
    function getAllSingleNftsByOwnerAddress(address _owner) public view returns(uint256[] memory){
        uint _k = 0;
        for(uint _i = 0; _i < singleNfts.length; _i++){
            if(nfts[singleNfts[_i]].seller == _owner){
                _k++;
            }
        }
        uint256[] memory result = new uint256[](_k);
        uint _j = 0;
        for(uint _i = 0; _i < singleNfts.length; _i++){
            if(nfts[singleNfts[_i]].seller == _owner){
                result[_j] = nfts[singleNfts[_i]].nftId;
                _j++;
            }
        }
        return result;
    }

    /**
    This function checks whether an nft belongs to single nfts array and is listed or not.
    @param _nftId - The id of the nft to be checked.
    @return - The provided nft is a listed single nft or not.
    */
    function isListedSingleNftorNot(uint256 _nftId) public view returns(bool){
        uint256 _index = idToIndex[_nftId];
        if(singleNfts.length == 0 || singleNfts[_index] != nfts[_nftId].nftId || !nfts[_nftId].isListed){
            return false;
        }

        return true;
    }

    /**
    This method fetches the address of the seller of the respective NFT.
    @param _nftId - The id of the nft whose seller's address is to be fetched.
    @return - The address of the NFT's seller.
    */
    function getOwnerByNftId(uint256 _nftId) public view returns(address){
        return nfts[_nftId].seller;
    }

    /**
    This function overrides the _burn function of ERC721Burnable contract.
    It is necessary to be overriden in order to burn an NFT.
    */
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    /**
    This function overrides the tokenURI function of ERC721URIStorage contract.
    It is necessary to be overriden in order to set the token URI of an NFT.
    */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory){
        return super.tokenURI(tokenId);
    }
}