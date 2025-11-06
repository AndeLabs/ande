// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {WAndeVault} from "../src/vaults/WAndeVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployWAndeVault
 * @author Gemini
 * @notice This script deploys the WAndeVault contract.
 * It requires the ANDE_TOKEN_ADDRESS environment variable to be set to the
 * address of the underlying ANDEToken contract.
 */
contract DeployWAndeVault is Script {
    address private andeTokenAddress;

    function setUp() public {
        // Load the ANDEToken address from environment variables.
        // You must set this environment variable before running the script.
        // Example: export ANDE_TOKEN_ADDRESS=0x...
        andeTokenAddress = vm.envAddress("ANDE_TOKEN_ADDRESS");
        require(andeTokenAddress != address(0), "ANDE_TOKEN_ADDRESS env var not set");
    }

    function run() public returns (WAndeVault) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the WAndeVault with the specified ANDEToken address.
        WAndeVault vault = new WAndeVault(IERC20(andeTokenAddress));

        vm.stopBroadcast();

        console.log("WAndeVault deployed to:", address(vault));
        return vault;
    }
}
