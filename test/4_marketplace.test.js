const {assert} = require('chai');
const { it } = require('mocha');
const { default: Web3 } = require('web3');

const NFT = artifacts.require('NFT');
const Collections = artifacts.require('Collections');
const Businesses = artifacts.require('Businesses');
const Marketplace = artifacts.require('Marketplace');

contract('Marketplace', ([deployer, investor]) => {

    let nftContract;
    let collectionsContract;
    let businessesContract;
    let marketplaceContract;
    let accounts;
    let marketplaceSuperAdmin;

    before(async() => {
        nftContract = await NFT.deployed();
        collectionsContract = await Collections.deployed();
        businessesContract = await Businesses.deployed();
        marketplaceContract = await Marketplace.deployed();
        accounts = await web3.eth.getAccounts();
        marketplaceSuperAdmin = await marketplaceContract.superAdmin();
    })

    describe('Marketplace contract deployment basics', async() => {
        it('Super admin address is correct', async() => {
            const _marketplaceSuperAdmin = await marketplaceContract.superAdmin();
            const _accounts  = await web3.eth.getAccounts();
            assert.equal(_marketplaceSuperAdmin, _accounts[0]);
        })

        it('No nft is put to auction at the time of deployment', async() => {
            const nfts = await marketplaceContract.getNftsInAuction();
            assert.equal(nfts.length, 0);
        })
    })

    describe('Selling of NFTs owned by individual sellers', async() => {
        let oldMarketplaceBalance;
        it('Nft listed successfully', async() => {
            await nftContract.createNft('Hello World', '1000000000000000000',
            'Fun',  accounts[1]);
            await nftContract.listNft(accounts[1], '1', {from : accounts[1]});
            const _nft = await nftContract.getNftByTokenId('1');
            assert.equal(_nft.details.isListed, true);
        })

        it('Nft sold successfully', async() => {
            let _nft = await nftContract.getNftByTokenId('1');
            let _price = _nft.details.price;
            oldMarketplaceBalance = await web3.eth.getBalance(accounts[0]);
            await marketplaceContract.buyNftAndChangeOwner('1', {from : accounts[2], value : _price});
            _nft = await nftContract.getNftByTokenId('1');
            assert.equal(_nft.details.isSold, true);
        })

        it('Owner changed successfully', async() => {
            let _newOwner = await nftContract.ownerOf('1');
            assert.equal(_newOwner, accounts[2]);
        })

        it('Marketplace fee transferred successfully', async() => {
            let _nft = await nftContract.getNftByTokenId('1');
            let _price = _nft.details.price;
            let newMarketplaceBalance = await web3.eth.getBalance(accounts[0]);
            assert.equal(newMarketplaceBalance - oldMarketplaceBalance, (2*_price)/100);
        })
    })

    describe('Selling of NFT by a business', async() => {
        let oldMarketplaceBalance;
        let oldBusinessAdminBalance;
        it('Nft listed and added to business successfully', async() => {
            await businessesContract.addBusiness('NoneOfYourBusiness', 'MyBusinessURI', 5, 
            accounts[1], [], {from : marketplaceSuperAdmin});
            await nftContract.createNft('Hello World', '1000000000000000000',
            'Fun',  accounts[2]);
            await nftContract.listNft(accounts[2], '2', {from : accounts[2]});
            await businessesContract.addEmployee('1', accounts[2],
            {from : accounts[1]});
            await businessesContract.addNftToBusiness('1','2', {from : accounts[1]});
            const _nft = await nftContract.getNftByTokenId('2');
            const _business = await businessesContract.businesses(0);
            assert.equal(_nft.details.isListed, true);
            assert.equal(_business.singleNftCount, 1);
        })

        it('NFT sold successfully', async()=>{
            let _nft = await nftContract.getNftByTokenId('2');
            let _price = _nft.details.price;
            oldMarketplaceBalance = await web3.eth.getBalance(accounts[0]);
            oldBusinessAdminBalance = await web3.eth.getBalance(accounts[1]);
            await marketplaceContract.buyNftAndChangeOwner('2', {from : accounts[3], value : _price});
            _nft = await nftContract.getNftByTokenId('2');
            assert.equal(_nft.details.isSold, true);
        })

        it('Owner changed successfully', async() => {
            let _newOwner = await nftContract.ownerOf('2');
            assert.equal(_newOwner, accounts[3]);
        })

        it('Marketplace fee and business fee transferred successfully', async() => {
            let _nft = await nftContract.getNftByTokenId('2');
            let _price = _nft.details.price;
            let _business = await businessesContract.businesses(0);
            let _businessFee = _business.feePercent;
            let newMarketplaceBalance = await web3.eth.getBalance(accounts[0]);
            let newBusinessAdminBalance = await web3.eth.getBalance(accounts[1]);
            assert.equal(newMarketplaceBalance - oldMarketplaceBalance, (2*_price)/100);
            assert.equal(newBusinessAdminBalance - oldBusinessAdminBalance, (_businessFee*_price)/100);
        })
    })

    describe('Auction functionalites', async() => {
        let _timeLeft;
        it('Nft put on auction successfully', async() => {
            await nftContract.createNft('Hello World', '1000000000000000000',
            'Fun',  accounts[1]);
            await nftContract.listNft(accounts[1], '3', {from : accounts[1]});
            await marketplaceContract.putAnNftOnAuction('3', '1100000000000000000',
            '30', {from : accounts[1]});
            const _nfts = await marketplaceContract.getNftsInAuction();
            assert.equal(_nfts.length, 1);
        })

        it('Bid placed successfully', async() => {
            await marketplaceContract.placeBid('3', '1200000000000000000', {from : accounts[3]});
            const _auction = await marketplaceContract.onGoingAuctions('3');
            assert.equal(_auction.highestBid, '1200000000000000000');
            assert.equal(_auction.highestBidder, accounts[3]);
        })

        it('Claiming of nft by the highest bidder after the completion of the auction', async() => {
            let _nft = await nftContract.getNftByTokenId('3');
            let _price = _nft.details.price;
            _timeLeft = await marketplaceContract.getTimeLeftInAuctionCompletion('3');
            console.log('Wait for ' + _timeLeft.words[0] + ' seconds for the auction to end.');
            await setTimeout( async() => {
                await marketplaceContract.claimNftAndTransferOwnershipAfterAuction('3', {from : accounts[3], value : _price});
                const _newOwner = await nftContract.ownerOf('3');
                assert.equal(_newOwner, accounts[3]);
            }, _timeLeft.words[0]*1000 + 5000);
        })
    })
})