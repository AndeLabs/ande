// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {TestToken} from "../src/TestToken.sol";

contract DeployANDEToken is Script {
    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Deploying ANDE Token ===");

        // Deploy simple ERC20 token for testing
        TestToken andeToken = new TestToken("ANDE Token", "ANDE");
        console.log("ANDE Token deployed to:", address(andeToken));

        // Mint some initial tokens to deployer
        address deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        andeToken.mint(deployer, 1000000 * 10**18); // 1M AND tokens
        console.log("Minted 1,000,000 AND tokens to deployer:", deployer);

        vm.stopBroadcast();
    }
}