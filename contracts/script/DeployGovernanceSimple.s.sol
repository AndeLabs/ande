// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {AndeTimelockController} from "../src/governance/AndeTimelockController.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployGovernanceSimple
 * @notice Script simple para deploy solo Timelock (sin Governor por tamaño)
 */
contract DeployGovernanceSimple is Script {
    // Direcciones ya deployadas
    address public constant ANDE_TOKEN_PROXY = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    address public constant STAKING_PROXY = 0x0165878A594ca255338adfa4d48449f69242Eb8F;
    
    // Configuration
    uint256 public constant TIMELOCK_DELAY = 2 days;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("========================================");
        console.log("ANDECHAIN TIMELOCK DEPLOYMENT (SIMPLE)");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("ANDE Token:", ANDE_TOKEN_PROXY);
        console.log("Staking:", STAKING_PROXY);
        console.log("========================================");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy Timelock
        console.log("\n1. Deploying AndeTimelockController...");
        address timelockImpl = address(new AndeTimelockController());
        console.log("   Timelock Implementation:", timelockImpl);
        
        // Prepare timelock initialization
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // Anyone can execute
        
        bytes memory timelockInitData = abi.encodeWithSignature(
            "initialize(uint256,address[],address[],address)",
            TIMELOCK_DELAY,
            proposers,
            executors,
            deployer  // admin
        );
        
        address payable timelockProxy = payable(address(new ERC1967Proxy(timelockImpl, timelockInitData)));
        console.log("   Timelock Proxy:", timelockProxy);
        
        vm.stopBroadcast();
        
        console.log("\n========================================");
        console.log("TIMELOCK DEPLOYMENT COMPLETE!");
        console.log("========================================");
        console.log("Timelock Implementation:", timelockImpl);
        console.log("Timelock Proxy:", timelockProxy);
        console.log("========================================");
        
        console.log("\nUpdate your frontend with:");
        console.log("TIMELOCK_ADDRESS =", timelockProxy);
        console.log("\nNOTE: Governor deployment skipped due to contract size limit");
        console.log("Consider using GovernorCountingSimple instead of AndeGovernor");
    }
}