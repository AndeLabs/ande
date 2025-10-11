// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract DeploySimpleToken is Script {
    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying Simple Token...");
        MockERC20 token = new MockERC20("Ande Test Token", "ATT", 18);
        console.log("Token deployed to:", address(token));

        // Mint some tokens to deployer
        token.mint(msg.sender, 1000 * 1e18);
        console.log("Minted 1000 ATT to deployer");

        vm.stopBroadcast();
    }
}