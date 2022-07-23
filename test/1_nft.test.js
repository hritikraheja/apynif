const {assert} = require('chai');
const { it } = require('mocha');

const NFT = artifacts.require('NFT');
const Collections = artifacts.require('Collections');
const Businesses = artifacts.require('Businesses');
const Marketplace = artifacts.require('Marketplace');

contract('NFT', ([deployer, investor]) => {

    let nftContract;
    let collectionsContract;
    let businessesContract;
    let marketplaceContract;

    before(async() => {
        nftContract = await NFT.deployed();
        collectionsContract = await Collections.deployed();
        businessesContract = await Businesses.deployed();
        marketplaceContract = await Marketplace.deployed();
    })

    describe('Basics', async() => {
        it('Contract has correct name', async() => {
            const name = await nftContract.name();
            assert.equal(name, 'Non-Fungible Token');
        })

        it('Contract has correct symbol', async() => {
            const symbol = await nftContract.symbol();
            assert.equal(symbol, 'NFT');
        })

        it('NFT count is zero at the beginning', async() => {
            const nftCount = await nftContract.nftCount();
            assert.equal(nftCount, 0);
        })
    })

    describe('Creation and deletion of nfts', async() => {
        it('NFT created succesfully', async() => {
            await nftContract.createNft('Hello World', '1000000000000000000',
            'Fun',  investor);
            const nftCount = await nftContract.nftCount();
            assert.equal(nftCount, 1);
        })

        it('Correct nft token uri', async() => {
            const uri = await nftContract.tokenURI('1');
            assert.equal(uri, 'Hello World');
        })

        it('Nft deleted successfully', async() => {
            await nftContract.deleteNft(investor, '1');
            const nftCount = await nftContract.nftCount();
            assert.equal(nftCount, 0);
        })
    })

    describe('Manipulation of nft details', async() => {
        it('Nft listed succesfully', async() => {
            await nftContract.createNft('Hello World', '1000000000000000000',
            'Fun',  investor);
            await nftContract.listNft(investor, '2', {from : investor});
            const marketplaceContractAddress = await marketplaceContract.address;
            const nftOwner = await nftContract.ownerOf('2');
            assert.equal(marketplaceContractAddress, nftOwner);
        })

        it('NFT price updated successfully', async() => {
            await nftContract.updatePrice(investor, '2', '1500000000000000000', {from : investor});
            const _nft = await nftContract.getNftByTokenId('2');
            const _price = _nft.details.price;
            assert.equal(_price, '1500000000000000000');
        })

        it('Nft unlisted successfully', async() => {
            await nftContract.unlistNft(investor, '2', {from : investor});
            const owner = await nftContract.ownerOf('2');
            assert.equal(owner, investor);
        })
    })
})