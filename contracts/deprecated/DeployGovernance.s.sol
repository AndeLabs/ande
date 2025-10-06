// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// Import all the contracts we need to deploy or interact with
import {ANDEToken} from "../src/ANDEToken.sol";
import {WAndeVault} from "../src/vaults/WAndeVault.sol";
import {StakingVault} from "../src/staking/StakingVault.sol";
import {AndeTimelockController} from "../src/governance/AndeTimelockController.sol";
import {AndeGovernor} from "../src/governance/AndeGovernor.sol";

contract DeployGovernance is Script {
    // Governance Parameters (can be adjusted)
    uint256 constant TIMELOCK_MIN_DELAY = 2 days; // 2-day delay for executing proposals
    uint256 constant GOVERNOR_QUORUM_PERCENTAGE = 4; // 4% quorum
    uint256 constant GOVERNOR_VOTING_PERIOD = 201600; // 1 week in blocks (assuming 3s block time)
    uint256 constant GOVERNOR_VOTING_DELAY = 28800; // 1 day in blocks (assuming 3s block time)
    uint256 constant GOVERNOR_PROPOSAL_THRESHOLD = 0; // No minimum votes to create a proposal

    function run() external {
        vm.startBroadcast();

        // === 1. DEPLOY OR LOAD DEPENDENCIES ===
        // For this script, we'll deploy new instances of the vaults.
        // In a real scenario, you might load existing ones.

        console.log("Deploying ANDEToken...");
        ANDEToken andeToken = new ANDEToken();
        // We need to initialize it to be able to use it as an asset
        andeToken.initialize(address(this), address(this)); 
        console.log("ANDEToken deployed at:", address(andeToken));

        console.log("Deploying WAndeVault...");
        WAndeVault wAndeVault = new WAndeVault(andeToken);
        console.log("WAndeVault (vaANDE) deployed at:", address(wAndeVault));

        console.log("Deploying StakingVault...");
        StakingVault stakingVault = new StakingVault();
        stakingVault.initialize(address(this), wAndeVault, 1 days); // 1 day unbonding period
        console.log("StakingVault (stANDE) deployed at:", address(stakingVault));

        // === 2. DEPLOY GOVERNANCE CONTRACTS ===

        console.log("Deploying AndeTimelockController...");
        AndeTimelockController timelock = new AndeTimelockController();
        // Initializer requires proposers and executors. Governor will be the proposer.
        // Anyone can be an executor initially.
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // address(0) means anyone can execute
        timelock.initialize(TIMELOCK_MIN_DELAY, proposers, executors, address(this));
        console.log("AndeTimelockController deployed at:", address(timelock));

        console.log("Deploying AndeGovernor...");
        AndeGovernor governor = new AndeGovernor();
        governor.initialize(
            stakingVault, // The IVotes token is stANDE (StakingVault)
            timelock,
            GOVERNOR_QUORUM_PERCENTAGE,
            GOVERNOR_VOTING_PERIOD,
            GOVERNOR_VOTING_DELAY,
            GOVERNOR_PROPOSAL_THRESHOLD
        );
        console.log("AndeGovernor deployed at:", address(governor));

        // === 3. CONFIGURE ROLES ===

        console.log("Configuring roles...");
        // The Governor needs to be a PROPOSER on the Timelock
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        timelock.grantRole(proposerRole, address(governor));

        // The Timelock needs to be the new owner/admin of other contracts
        // For example, transferring ownership of ANDEToken to the Timelock
        // so only governance can call `mint` or other admin functions.
        // NOTE: This requires the original contract to have a `transferOwnership` or similar function.
        // For AccessControlUpgradeable, we transfer the DEFAULT_ADMIN_ROLE.
        
        bytes32 adminRole = andeToken.DEFAULT_ADMIN_ROLE();
        
        // First, grant the Timelock the admin role
        andeToken.grantRole(adminRole, address(timelock));
        
        // Then, renounce the deployer's admin role, leaving the Timelock as the sole admin
        andeToken.renounceRole(adminRole, address(this));

        console.log("Governance deployment and configuration complete!");

        vm.stopBroadcast();
    }
}
