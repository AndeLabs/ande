// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {TestToken} from "../src/TestToken.sol";

contract TestBlobSubmission is Script {
    TestToken public token;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with address:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy test token
        token = new TestToken("Ande Test Token", "ANDE");
        console.log("TestToken deployed at:", address(token));
        
        // Mint some tokens to deployer
        token.mint(deployer, 1000 * 10**18);
        console.log("Minted 1000 ANDE to deployer");
        
        vm.stopBroadcast();
        
        // Verify deployment
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Total supply:", token.totalSupply());
        console.log("Deployer balance:", token.balanceOf(deployer));
    }
}