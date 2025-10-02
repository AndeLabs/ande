import { HardhatUserConfig } from "hardhat/config";
import "dotenv/config"; // Load .env variables

// import "@nomicfoundation/hardhat-ignition-ethers"; // Temporarily disabled to resolve module issue
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

// Read private keys from environment
const privateKey = process.env.PRIVATE_KEY;
const privateKeyUser1 = process.env.PRIVATE_KEY_USER1;

const accounts = [];
if (privateKey) {
  accounts.push(privateKey);
}
if (privateKeyUser1) {
  accounts.push(privateKeyUser1);
}

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
    ignition: "./ignition"
  },
  networks: {
    localhost: {
      url: "http://ev-reth-sequencer:8545",
      chainId: 1234,
      // Use the private keys from .env file for the test accounts
      accounts: accounts
    }
  }
};

export default config;