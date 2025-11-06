// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {AndeGovernor} from "../src/governance/AndeGovernor.sol";
import {AndeTimelockController} from "../src/governance/AndeTimelockController.sol";
import {AndeNativeStaking} from "../src/staking/AndeNativeStaking.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployGovernanceManual
 * @notice Script para deploy governance usando contratos existentes
 * @dev Usa las direcciones ya deployadas de ANDE Token y Staking
 */
contract DeployGovernanceManual is Script {
    // Direcciones ya deployadas
    address public constant ANDE_TOKEN_PROXY = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    address public constant STAKING_PROXY = 0x0165878A594ca255338adfa4d48449f69242Eb8F;
    
    // Configuration
    uint32 public constant VOTING_PERIOD = 50400; // ~7 days at 12s blocks
    uint48 public constant VOTING_DELAY = 1; // 1 block
    uint256 public constant PROPOSAL_THRESHOLD = 100_000 ether;
    uint256 public constant TIMELOCK_DELAY = 2 days;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("========================================");
        console.log("ANDECHAIN GOVERNANCE DEPLOYMENT (MANUAL)");
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
        
        // 2. Deploy Governor
        console.log("\n2. Deploying AndeGovernor...");
        address governorImpl = address(new AndeGovernor());
        console.log("   Governor Implementation:", governorImpl);
        
        bytes memory governorInitData = abi.encodeWithSignature(
            "initialize(address,address,address,uint32,uint48,uint256,address)",
            ANDE_TOKEN_PROXY,    // token
            STAKING_PROXY,      // stakingContract
            timelockProxy,      // timelock
            VOTING_PERIOD,      // votingPeriod (uint32)
            VOTING_DELAY,       // votingDelay (uint48)
            PROPOSAL_THRESHOLD, // proposalThreshold
            deployer           // emergencyCouncil
        );
        
        address governorProxy = address(new ERC1967Proxy(governorImpl, governorInitData));
        console.log("   Governor Proxy:", governorProxy);
        
        // 3. Configure roles
        console.log("\n3. Configuring roles...");
        
        // Grant PROPOSER_ROLE to Governor in Timelock
        bytes32 PROPOSER_ROLE = AndeTimelockController(timelockProxy).PROPOSER_ROLE();
        AndeTimelockController(timelockProxy).grantRole(PROPOSER_ROLE, governorProxy);
        console.log("   Granted PROPOSER_ROLE to Governor");
        
        // Grant MINTER_ROLE to Staking contract (if needed)
        // This should already be set from previous deployment
        
        vm.stopBroadcast();
        
        console.log("\n========================================");
        console.log("GOVERNANCE DEPLOYMENT COMPLETE!");
        console.log("========================================");
        console.log("Timelock Implementation:", timelockImpl);
        console.log("Timelock Proxy:", timelockProxy);
        console.log("Governor Implementation:", governorImpl);
        console.log("Governor Proxy:", governorProxy);
        console.log("========================================");
        
        console.log("\nUpdate your frontend with:");
        console.log("TIMELOCK_ADDRESS =", timelockProxy);
        console.log("GOVERNOR_ADDRESS =", governorProxy);
    }
}