const HDWalletProvider = require('@truffle/hdwallet-provider');
const fs = require('fs');
const mnemonic = fs.readFileSync(".secret").toString().trim();
require('babel-register');
require('babel-polyfill');

module.exports = {
  networks: {
    ganache: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    },
    polygon_testnet : {
      provider: () => new HDWalletProvider(mnemonic, `https://rpc-mumbai.maticvigil.com/v1/dc9af840c47be53f65836c18f8d2731b3353338f`),
      network_id: 80001,
      skipDryRun: true
    },
    ropsten_test_network : {
      provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/f377034d226a48ed974891435e2d336d`),
      network_id : 3,
    }
  },
  contracts_directory: './src/contracts/',
  contracts_build_directory: './src/abis/',
  compilers: {
    solc: {
      version : "0.8.7",
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
}
