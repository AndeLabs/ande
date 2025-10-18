// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {AndeChainBridge} from "../src/bridge/AndeChainBridge.sol";

/**
 * @title DeployAndeBridge
 * @author Ande Labs
 * @notice This script deploys the AndeChainBridge contract.
 * It requires the following environment variables to be set:
 * - BRIDGE_ADMIN_ADDRESS: The address that will be the owner of the bridge.
 * - BLOBSTREAM_VERIFIER_ADDRESS: The address of the Celestia Blobstream verifier contract.
 * - MIN_CONFIRMATIONS: The minimum number of confirmations required before bridging.
 * - FORCE_INCLUSION_PERIOD: The time period after which users can force transactions (in seconds).
 * - PRIVATE_KEY: The private key of the deployer.
 */
contract DeployAndeBridge is Script {
    address private bridgeAdminAddress;
    address private blobstreamVerifierAddress;
    uint256 private minConfirmations;
    uint256 private forceInclusionPeriod;

    function setUp() public {
        bridgeAdminAddress = vm.envAddress("BRIDGE_ADMIN_ADDRESS");
        blobstreamVerifierAddress = vm.envAddress("BLOBSTREAM_VERIFIER_ADDRESS");
        minConfirmations = vm.envUint("MIN_CONFIRMATIONS");
        forceInclusionPeriod = vm.envUint("FORCE_INCLUSION_PERIOD");

        require(bridgeAdminAddress != address(0), "BRIDGE_ADMIN_ADDRESS env var not set");
        require(blobstreamVerifierAddress != address(0), "BLOBSTREAM_VERIFIER_ADDRESS env var not set");
    }

    function run() public returns (AndeChainBridge) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the AndeChainBridge
        AndeChainBridge bridge =
            new AndeChainBridge(bridgeAdminAddress, blobstreamVerifierAddress, minConfirmations, forceInclusionPeriod);

        console.log("AndeChainBridge deployed to:", address(bridge));

        vm.stopBroadcast();

        return bridge;
    }
}
