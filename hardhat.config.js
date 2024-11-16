require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');
require('hardhat-dependency-compiler');
require('hardhat-contract-sizer');

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, './.env') });

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  dependencyCompiler: {
    paths: [
        "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol",
    ],
    keep: true
  },
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999
          }
        }
      },
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999
          }
        }
      },
    ]
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    // strict: true,
  },
  networks: {
    chain: {
      url: `${process.env.NETWORK_URL}`,
    },
  }
};
