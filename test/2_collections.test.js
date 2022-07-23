const {assert} = require('chai');
const { it } = require('mocha');

const NFT = artifacts.require('NFT');
const Collections = artifacts.require('Collections');
const Businesses = artifacts.require('Businesses');
const Marketplace = artifacts.require('Marketplace');

contract('Collections', async([deployer, investor]) => {

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

    describe('Creation and Deletion of collections', async() => {
        it('Collection created successfully', async() => {
            await collectionsContract.createCollection('MyCollection1', 'imageURI!',
            'This is my first collection', 'Hritik', [], 'ABC', {from : investor});
            const collectionCount = await collectionsContract.collectionCount();
            assert.equal(collectionCount, 1);
        })

        it('Created collection has correct details', async() => {
            const _collection = await collectionsContract.allCollections(0);
            assert.equal(_collection.collectionId, 1);
            assert.equal(_collection.collectionName, 'MyCollection1');
            assert.equal(_collection.collectionOwnerName, 'Hritik');
        })

        it('Collection deleted successfully', async() => {
            await collectionsContract.deleteCollection('1', {from : investor});
            const collectionCount = await collectionsContract.collectionCount();
            assert.equal(collectionCount, 0);
        })
    })

    describe('Adding and removing nfts from and to a collection', async() => {
        it('NFT added to collection successfully', async() => {
            await collectionsContract.createCollection('MyCollection1', 'imageURI!',
            'This is my first collection', 'Hritik', [], 'ABC', {from : investor});
            await nftContract.createNft('Hello World', '1000000000000000000',
            'Fun',  investor, {from : investor});
            await nftContract.listNft(investor, '1', {from : investor});
            await collectionsContract.addNftToCollection('2', '1', {from : investor});
            const a = await collectionsContract.allCollections(0);
            const _nftCount = a.nftCount;
            assert.equal(_nftCount, 1);
        })

        it('Multiple nfts added to collection', async() => {
            await nftContract.createNft('MyNft2', '1000000000000000000',
            'Fun',  investor, {from : investor});
            await nftContract.listNft(investor, '2', {from : investor});
            await nftContract.createNft('MyNFT3', '1000000000000000000',
            'Fun',  investor, {from : investor});
            await nftContract.listNft(investor, '3', {from : investor});
            await collectionsContract.addMultipleNftsToCollection('2', ['2', '3'], {from : investor});
            const a = await collectionsContract.allCollections(0);
            const _nftCount = a.nftCount;
            assert.equal(_nftCount, 3);

        })

        it('Nft removed from the collection successfully', async() => {
            await collectionsContract.removeNftFromCollection('2', '2', {from : investor});
            const a = await collectionsContract.allCollections(0);
            const _nftCount = a.nftCount;
            assert.equal(_nftCount, 2);
        })
    })

    describe("Listing and unlisting of collections", async() => {
        it("Collection is already listed at the time of creation", async() => {
            const collection = await collectionsContract.allCollections(0);
            assert.equal(collection.isListed, true);
        })

        it("Collection unlisted successfully", async() => {
            await collectionsContract.unlistCollection(investor, '2', {from : investor});
            const collection = await collectionsContract.allCollections(0);
            assert.equal(collection.isListed, false);
        })

        it("Collection listed back again", async() => {
            await collectionsContract.listCollection(investor, '2', {from : investor});
            const collection = await collectionsContract.allCollections(0);
            assert.equal(collection.isListed, true);
        })
    })
})