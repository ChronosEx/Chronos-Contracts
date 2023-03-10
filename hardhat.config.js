require("@nomiclabs/hardhat-waffle");

require('@openzeppelin/hardhat-upgrades');

require("@nomiclabs/hardhat-etherscan");

require("@nomiclabs/hardhat-web3");

const { PRIVATEKEY, APIKEY } = require("./pvkey.js")

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

  networks: {

    arbitrumOne: {
      url: "https://arb1.arbitrum.io/rpc",
      chainId: 42161,
      accounts: PRIVATEKEY
    },

    arbitrumOneTestnet: {
      url: "https://goerli-rollup.arbitrum.io/rpc",
      chainId: 421613,
      accounts: PRIVATEKEY
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