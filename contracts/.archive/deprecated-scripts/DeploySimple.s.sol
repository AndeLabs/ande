// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {ANDEToken} from "../src/ANDEToken.sol";

contract DeploySimple is Script {
    function run() external {
        vm.startBroadcast();

        console.log("Deploying ANDE Token...");
        ANDEToken token = new ANDEToken();
        console.log("ANDE Token deployed to:", address(token));

        vm.stopBroadcast();
    }
}