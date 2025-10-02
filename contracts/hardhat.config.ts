import { HardhatUserConfig } from "hardhat/config";
import "dotenv/config"; // Load .env variables

// import "@nomicfoundation/hardhat-ignition-ethers"; // Temporarily disabled to resolve module issue
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

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
      chainId: 1234
    }
  }
};

export default config;