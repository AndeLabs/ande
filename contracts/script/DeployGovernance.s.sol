// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {AndeGovernor} from "../src/governance/AndeGovernor.sol";
import {AndeTimelockController} from "../src/governance/AndeTimelockController.sol";
import {ANDETokenDuality} from "../src/ANDETokenDuality.sol";
import {AndeNativeStaking} from "../src/staking/AndeNativeStaking.sol";
import {AndeFeeDistributor} from "../src/tokenomics/AndeFeeDistributor.sol";
import {CommunityTreasury} from "../src/community/CommunityTreasury.sol";
import {AndeRollupGovernance} from "../src/governance/AndeRollupGovernance.sol";
import {AndeSequencerRegistry} from "../src/sequencer/AndeSequencerRegistry.sol";
import {IAndeNativeStaking} from "../src/governance/extensions/GovernorDualTokenVoting.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployGovernance
 * @notice Deployment script para el sistema completo de governance de AndeChain
 * @dev Deploy orden: Token → Staking → Timelock → Governor → Ecosystem contracts
 */
contract DeployGovernance is Script {
    // Deployment addresses
    ANDETokenDuality public andeToken;
    AndeNativeStaking public staking;
    AndeTimelockController public timelock;
    AndeGovernor public governor;
    AndeFeeDistributor public feeDistributor;
    CommunityTreasury public communityTreasury;
    AndeRollupGovernance public rollupGovernance;
    AndeSequencerRegistry public sequencerRegistry;
    
    // Configuration
    uint32 public constant VOTING_PERIOD = 50400; // ~7 days at 12s blocks
    uint48 public constant VOTING_DELAY = 1; // 1 block
    uint256 public constant PROPOSAL_THRESHOLD = 100_000 ether;
    uint256 public constant TIMELOCK_DELAY = 2 days;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address emergencyCouncil = vm.envOr("EMERGENCY_COUNCIL", deployer);
        address guardian = vm.envOr("GUARDIAN", deployer);
        address protocolTreasury = vm.envOr("PROTOCOL_TREASURY", deployer);
        
        console.log("========================================");
        console.log("ANDECHAIN GOVERNANCE DEPLOYMENT");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("Emergency Council:", emergencyCouncil);
        console.log("Guardian:", guardian);
        console.log("Protocol Treasury:", protocolTreasury);
        console.log("========================================");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy ANDE Token (if not already deployed)
        console.log("\n1. Deploying ANDE Token...");
        andeToken = deployAndeToken(deployer);
        console.log("   Token deployed at:", address(andeToken));
        
        // 2. Deploy Staking
        console.log("\n2. Deploying AndeNativeStaking...");
        staking = deployStaking(address(andeToken), deployer);
        console.log("   Staking deployed at:", address(staking));
        
        // 3. Deploy Timelock
        console.log("\n3. Deploying AndeTimelockController...");
        timelock = deployTimelock(deployer);
        console.log("   Timelock deployed at:", address(timelock));
        
        // 4. Deploy Governor
        console.log("\n4. Deploying AndeGovernor...");
        governor = deployGovernor(
            address(andeToken),
            address(staking),
            address(timelock),
            emergencyCouncil,
            guardian
        );
        console.log("   Governor deployed at:", address(governor));
        
        // 5. Setup Timelock Roles
        console.log("\n5. Setting up Timelock roles...");
        setupTimelockRoles();
        console.log("   Roles configured");
        
        // 6. Deploy Sequencer Registry
        console.log("\n6. Deploying AndeSequencerRegistry...");
        sequencerRegistry = deploySequencerRegistry(address(andeToken), deployer);
        console.log("   SequencerRegistry deployed at:", address(sequencerRegistry));
        
        // 7. Deploy Community Treasury
        console.log("\n7. Deploying CommunityTreasury...");
        communityTreasury = deployCommunityTreasury(address(andeToken), address(timelock));
        console.log("   CommunityTreasury deployed at:", address(communityTreasury));
        
        // 8. Deploy Fee Distributor
        console.log("\n8. Deploying AndeFeeDistributor...");
        feeDistributor = deployFeeDistributor(
            address(andeToken),
            address(sequencerRegistry),
            address(staking),
            protocolTreasury,
            address(communityTreasury),
            address(timelock)
        );
        console.log("   FeeDistributor deployed at:", address(feeDistributor));
        
        // 9. Deploy Rollup Governance
        console.log("\n9. Deploying AndeRollupGovernance...");
        rollupGovernance = deployRollupGovernance(address(sequencerRegistry), address(timelock));
        console.log("   RollupGovernance deployed at:", address(rollupGovernance));
        
        // 10. Setup Governance Roles
        console.log("\n10. Setting up governance roles in ecosystem contracts...");
        setupGovernanceRoles();
        console.log("   Governance roles configured");
        
        vm.stopBroadcast();
        
        // Output deployment addresses
        console.log("\n========================================");
        console.log("DEPLOYMENT COMPLETE");
        console.log("========================================");
        printDeploymentSummary();
        
        // Save deployment addresses to file
        saveDeploymentAddresses();
    }
    
    function deployAndeToken(address admin) internal returns (ANDETokenDuality) {
        // Check if token already exists
        address existingToken = vm.envOr("ANDE_TOKEN", address(0));
        if (existingToken != address(0)) {
            console.log("   Using existing token at:", existingToken);
            return ANDETokenDuality(existingToken);
        }
        
        ANDETokenDuality implementation = new ANDETokenDuality();
        bytes memory initData = abi.encodeWithSelector(
            ANDETokenDuality.initialize.selector,
            admin,
            admin,
            address(0) // Precompile will be set later
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        return ANDETokenDuality(address(proxy));
    }
    
    function deployStaking(address token, address admin) internal returns (AndeNativeStaking) {
        AndeNativeStaking implementation = new AndeNativeStaking();
        bytes memory initData = abi.encodeWithSelector(
            AndeNativeStaking.initialize.selector,
            token,
            admin,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        return AndeNativeStaking(address(proxy));
    }
    
    function deployTimelock(address admin) internal returns (AndeTimelockController) {
        address[] memory proposers = new address[](1);
        proposers[0] = admin;
        address[] memory executors = new address[](1);
        executors[0] = address(0); // Anyone can execute
        
        AndeTimelockController implementation = new AndeTimelockController();
        bytes memory initData = abi.encodeWithSelector(
            AndeTimelockController.initialize.selector,
            TIMELOCK_DELAY,
            proposers,
            executors,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        return AndeTimelockController(payable(address(proxy)));
    }
    
    function deployGovernor(
        address token,
        address stakingContract,
        address timelockAddr,
        address emergencyCouncil,
        address guardian
    ) internal returns (AndeGovernor) {
        AndeGovernor implementation = new AndeGovernor();
        bytes memory initData = abi.encodeWithSelector(
            AndeGovernor.initialize.selector,
            IVotes(token),
            IAndeNativeStaking(stakingContract),
            AndeTimelockController(payable(timelockAddr)),
            VOTING_PERIOD,
            VOTING_DELAY,
            PROPOSAL_THRESHOLD,
            emergencyCouncil,
            guardian
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        return AndeGovernor(payable(address(proxy)));
    }
    
    function deploySequencerRegistry(address token, address admin) internal returns (AndeSequencerRegistry) {
        AndeSequencerRegistry implementation = new AndeSequencerRegistry();
        bytes memory initData = abi.encodeWithSelector(
            AndeSequencerRegistry.initialize.selector,
            token,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        return AndeSequencerRegistry(address(proxy));
    }
    
    function deployCommunityTreasury(address token, address admin) internal returns (CommunityTreasury) {
        CommunityTreasury implementation = new CommunityTreasury();
        bytes memory initData = abi.encodeWithSelector(
            CommunityTreasury.initialize.selector,
            token,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        return CommunityTreasury(address(proxy));
    }
    
    function deployFeeDistributor(
        address token,
        address registry,
        address stakingContract,
        address protocolTreasuryAddr,
        address communityTreasuryAddr,
        address admin
    ) internal returns (AndeFeeDistributor) {
        AndeFeeDistributor implementation = new AndeFeeDistributor();
        bytes memory initData = abi.encodeWithSelector(
            AndeFeeDistributor.initialize.selector,
            token,
            registry,
            stakingContract,
            protocolTreasuryAddr,
            communityTreasuryAddr,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        return AndeFeeDistributor(address(proxy));
    }
    
    function deployRollupGovernance(address registry, address admin) internal returns (AndeRollupGovernance) {
        AndeRollupGovernance implementation = new AndeRollupGovernance();
        bytes memory initData = abi.encodeWithSelector(
            AndeRollupGovernance.initialize.selector,
            registry,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        return AndeRollupGovernance(address(proxy));
    }
    
    function setupTimelockRoles() internal {
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();
        
        // Grant proposer role to governor
        timelock.grantRole(proposerRole, address(governor));
        
        // Grant executor role to anyone (address(0))
        timelock.grantRole(executorRole, address(0));
        
        // Revoke admin role from deployer (timelock becomes self-governing)
        timelock.revokeRole(adminRole, msg.sender);
    }
    
    function setupGovernanceRoles() internal {
        // Grant GOVERNOR_ROLE to timelock in all governed contracts
        communityTreasury.grantRole(communityTreasury.GOVERNOR_ROLE(), address(timelock));
        feeDistributor.grantRole(feeDistributor.GOVERNOR_ROLE(), address(timelock));
        rollupGovernance.grantRole(rollupGovernance.EMERGENCY_ROLE(), address(timelock));
    }
    
    function printDeploymentSummary() internal view {
        console.log("\nCore Governance:");
        console.log("  ANDE Token:", address(andeToken));
        console.log("  Staking:", address(staking));
        console.log("  Timelock:", address(timelock));
        console.log("  Governor:", address(governor));
        
        console.log("\nEcosystem Contracts:");
        console.log("  Sequencer Registry:", address(sequencerRegistry));
        console.log("  Community Treasury:", address(communityTreasury));
        console.log("  Fee Distributor:", address(feeDistributor));
        console.log("  Rollup Governance:", address(rollupGovernance));
        
        console.log("\nGovernance Parameters:");
        console.log("  Voting Period:", VOTING_PERIOD, "blocks (~7 days)");
        console.log("  Voting Delay:", VOTING_DELAY, "block");
        console.log("  Proposal Threshold:", PROPOSAL_THRESHOLD / 1e18, "ANDE");
        console.log("  Timelock Delay:", TIMELOCK_DELAY / 1 days, "days");
    }
    
    function saveDeploymentAddresses() internal {
        string memory json = "deployment";
        
        vm.serializeAddress(json, "andeToken", address(andeToken));
        vm.serializeAddress(json, "staking", address(staking));
        vm.serializeAddress(json, "timelock", address(timelock));
        vm.serializeAddress(json, "governor", address(governor));
        vm.serializeAddress(json, "sequencerRegistry", address(sequencerRegistry));
        vm.serializeAddress(json, "communityTreasury", address(communityTreasury));
        vm.serializeAddress(json, "feeDistributor", address(feeDistributor));
        string memory finalJson = vm.serializeAddress(json, "rollupGovernance", address(rollupGovernance));
        
        string memory outputPath = string.concat(vm.projectRoot(), "/deployments/governance_", vm.toString(block.chainid), ".json");
        vm.writeJson(finalJson, outputPath);
        
        console.log("\nDeployment addresses saved to:", outputPath);
    }
}
