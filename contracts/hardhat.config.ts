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
    ignition: "./ignition",
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
  },
};

export default config;
