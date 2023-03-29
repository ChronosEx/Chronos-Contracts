require("@nomiclabs/hardhat-waffle");

require('@openzeppelin/hardhat-upgrades');

require("@nomiclabs/hardhat-etherscan");
require("hardhat-interface-generator");

require("@nomiclabs/hardhat-web3");

const { PRIVATEKEY, TESTPRIVATEKEY, APIKEY } = require("./pvkey.js")

module.exports = {
  // latest Solidity version
  solidity: {
    compilers: [
      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ]
  },
  defaultNetwork: 'arbitrumOne',

  networks: {

    arbitrumOne: {
      url: "https://arb1.arbitrum.io/rpc",
      chainId: 42161,
      accounts: PRIVATEKEY
    },

    bscScan: {
      url: "https://bsc-dataseed4.binance.org",
      chainId: 56,
      accounts: TESTPRIVATEKEY
    },
   

    hardhat: {
      forking: {
          url: "https://arb1.arbitrum.io/rpc",
          chainId: 42161,
      },
      //accounts: []
    }
  
  },

  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: APIKEY
  },

  mocha: {
    timeout: 100000000
  }

}