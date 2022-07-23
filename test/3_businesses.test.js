const {assert} = require('chai');
const { it } = require('mocha');

const NFT = artifacts.require('NFT');
const Collections = artifacts.require('Collections');
const Businesses = artifacts.require('Businesses');
const Marketplace = artifacts.require('Marketplace');

contract('Businesses', async([deployer, investor]) => {

    let nftContract;
    let collectionsContract;
    let businessesContract;
    let marketplaceContract;
    let marketplaceSuperAdmin;

    before(async() => {
        nftContract = await NFT.deployed();
        collectionsContract = await Collections.deployed();
        businessesContract = await Businesses.deployed();
        marketplaceContract = await Marketplace.deployed();
        marketplaceSuperAdmin = await marketplaceContract.superAdmin();
    })

    describe('Addition and removal of businesses to the marketplace', async() => {
        it('Business count is zero at the time of contract creation', async() => {
            const _businessCount = await businessesContract.businessCount();
            assert.equal(_businessCount, 0);
        })

        it('Business created successfully', async() => {
            await businessesContract.addBusiness('NoneOfYourBusiness', 'MyBusinessURI', 5, 
            investor, [], {from : marketplaceSuperAdmin});
            const _businessCount = await businessesContract.businessCount();
            assert.equal(_businessCount, 1);
        })

        it('Created business has the correct details', async() => {
            const _admin = await businessesContract.getBusinessAdminByBusinessId('1');
            const _fee = await businessesContract.getBusinessFeePercentByBusinessId('1');
            assert.equal(_admin, investor);
            assert.equal(_fee, '5');
        })

        it('Business removed from marketplace successfully', async() => {
            await businessesContract.removeBusiness('1', {from : marketplaceSuperAdmin});
            const _businessCount = await businessesContract.businessCount();
            assert.equal(_businessCount, 0);
        })
    })

    describe('Addition and creation of NFTs and Collections in a business', async() => {
        it('NFT added to business successfully', async() => {
            await nftContract.createNft('Hello World', '1000000000000000000',
            'Fun',  investor);
            await businessesContract.addBusiness('NoneOfYourBusiness', 'MyBusinessURI', 5, 
            investor, [], {from : marketplaceSuperAdmin});
            await businessesContract.addNftToBusiness('2','1', {from : investor});
            const _businesses = await businessesContract.businesses(0);
            assert.equal(_businesses.singleNftCount, 1);
        })

        it('NFT created in business successfully', async() => {
            await businessesContract.createNftInBusiness('2', 'ABC', '1000000000000000000', 'Fun', 
            {from : investor});
            const _businesses = await businessesContract.businesses(0);
            assert.equal(_businesses.singleNftCount, 2);
        })

        it('Collection added to business successfully', async() => {
            await collectionsContract.createCollection('MyCollection1', 'imageURI!',
            'This is my first collection', 'Hritik', [], 'ABC', {from : investor});
            await businessesContract.addCollectionToBusiness('2', '1', {from : investor});
            const _businesses = await businessesContract.businesses(0);
            assert.equal(_businesses.collectionCount, 1);
        })

        it('Collection created in business successfully', async() => {
            await businessesContract.createCollectionInBusiness('2', 'MyCollection1', 'imageURI!',
            'This is my first collection', 'Hritik', [], 'ABC', {from : investor});
            const _businesses = await businessesContract.businesses(0);
            assert.equal(_businesses.collectionCount, 2);
        })
    })

    describe('Removal of nfts and collections from business and business fee updation', async() => {
        it('Nft removed from business successfully', async() => {
            await businessesContract.removeNftFromBusiness('2', '2', {from : investor});
            const _businesses = await businessesContract.businesses(0);
            assert.equal(_businesses.singleNftCount, 1);
        })

        it('Collection removed from business successfully', async() => {
            await businessesContract.removeCollectionFromBusiness('2', '2', {from : investor});
            const _businesses = await businessesContract.businesses(0);
            assert.equal(_businesses.collectionCount, 1);
        })

        it('Business fee updated successfully', async() => {
            await businessesContract.updateFeePercent('2', '10', {from : investor});
            const _fee = await businessesContract.getBusinessFeePercentByBusinessId('2');
            assert.equal(_fee, 10);
        })
    })

    describe('Addition and removal of employees to and from business', async() => {
        it('Employee added to business successfully', async() => {
            await businessesContract.addEmployee('2', '0xb7c175608738e6bD39053577E64BF5BEe53E7F1E',
            {from : investor});
            const _employees = await businessesContract.getEmployeesinBusiness('2');
            assert.equal(_employees[0], '0xb7c175608738e6bD39053577E64BF5BEe53E7F1E');
        })

        it('Employee removed from business successfully', async() => {
            await businessesContract.removeEmployee('2', '0xb7c175608738e6bD39053577E64BF5BEe53E7F1E', 
            {from : investor});
            const _employees = await businessesContract.getEmployeesinBusiness('2');
            assert.equal(_employees.length, 0);
        })
    })
})