// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Core contracts
import {ANDETokenDuality} from "../src/ANDETokenDuality.sol";
import {AndeNativeStaking} from "../src/staking/AndeNativeStaking.sol";
import {AndeGovernor} from "../src/governance/AndeGovernor.sol";
import {AndeTimelockController} from "../src/governance/AndeTimelockController.sol";

/**
 * @title DeployCore
 * @notice Standard deployment script for AndeChain core contracts
 * @dev This script deploys:
 *      1. ANDE Token (Implementation + Proxy)
 *      2. AndeNativeStaking (Implementation + Proxy)
 *      3. AndeTimelockController (Implementation + Proxy)
 *      4. AndeGovernor (Implementation + Proxy)
 *      5. Configures roles and permissions
 * 
 * Usage:
 *   # Deploy to local testnet
 *   forge script script/DeployCore.s.sol --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast --verify
 *
 *   # Deploy to AndeChain Testnet
 *   forge script script/DeployCore.s.sol --rpc-url $ANDECHAIN_RPC --private-key $PRIVATE_KEY --broadcast --verify
 *
 *   # Dry run (no broadcast)
 *   forge script script/DeployCore.s.sol --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY
 */
contract DeployCore is Script {
    // ============================================================================
    // CONFIGURATION
    // ============================================================================
    
    // Network configuration
    uint256 public constant ANDECHAIN_TESTNET_ID = 6174;  // Updated to actual chain ID
    uint256 public constant LOCAL_TESTNET_ID = 1234;
    
    // Governance parameters
    uint256 public constant PROPOSAL_THRESHOLD = 1000 ether; // 1000 ANDE
    uint256 public constant VOTING_DELAY = 1; // 1 block
    uint256 public constant VOTING_PERIOD = 21600; // ~12 hours with 2s blocks
    uint256 public constant TIMELOCK_DELAY = 1 hours;
    
    // Staking parameters
    uint256 public constant MIN_STAKE = 100 ether; // 100 ANDE minimum
    
    // Initial supply for testnet (1B ANDE)
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 ether;
    
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================
    
    // Deployed contract addresses
    address public andeImplementation;
    address public andeProxy;
    address public stakingImplementation;
    address public stakingProxy;
    address public timelockImplementation;
    address payable public timelockProxy;
    address public governorImplementation;
    address public governorProxy;
    
    // Deployer address
    address public deployer;
    
    // ============================================================================
    // MAIN DEPLOYMENT FUNCTION
    // ============================================================================
    
    function run() external {
        // Get deployer from private key
        deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        
        console2.log("==========================================================");
        console2.log("              AndeChain Core Deployment");
        console2.log("==========================================================");
        console2.log("Network Chain ID:", block.chainid);
        console2.log("Deployer Address:", deployer);
        console2.log("Deployer Balance:", deployer.balance / 1 ether, "ANDE");
        console2.log("");
        
        // Validate network
        require(
            block.chainid == ANDECHAIN_TESTNET_ID || block.chainid == LOCAL_TESTNET_ID,
            "Invalid network - only AndeChain Testnet (2019) or Local (1234) supported"
        );
        
        // Validate deployer has sufficient balance
        require(deployer.balance >= 10 ether, "Insufficient balance for deployment");
        
        vm.startBroadcast();
        
        // Step 1: Deploy ANDE Token
        _deployAndeToken();
        
        // Step 2: Deploy Staking Contract
        _deployStaking();
        
        // Step 3: Deploy Timelock Controller
        _deployTimelock();
        
        // Step 4: Deploy Governor
        _deployGovernor();
        
        // Step 5: Configure roles and permissions
        _configureRoles();
        
        vm.stopBroadcast();
        
        // Step 6: Output deployment summary
        _outputDeploymentSummary();
        
        // Step 7: Generate deployment JSON
        _generateDeploymentJson();
    }
    
    // ============================================================================
    // DEPLOYMENT STEPS
    // ============================================================================
    
    function _deployAndeToken() internal {
        console2.log("=== Step 1: Deploying ANDE Token ===");
        
        // Deploy implementation
        andeImplementation = address(new ANDETokenDuality());
        console2.log("ANDE Implementation:", andeImplementation);
        
        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address)",
            deployer,      // defaultAdmin
            deployer,      // minter
            address(0xFD)  // precompile address for native ANDE
        );
        
        // Deploy proxy
        andeProxy = address(new ERC1967Proxy(andeImplementation, initData));
        console2.log("ANDE Proxy:", andeProxy);
        
        // Mint initial supply for testnet
        if (block.chainid != 1) { // Not mainnet
            ANDETokenDuality(andeProxy).mint(deployer, INITIAL_SUPPLY);
            console2.log("Minted initial supply:", INITIAL_SUPPLY / 1 ether, "ANDE");
        }
        
        console2.log("[SUCCESS] ANDE Token deployed successfully");
        console2.log("");
    }
    
    function _deployStaking() internal {
        console2.log("=== Step 2: Deploying Staking Contract ===");
        
        // Deploy implementation
        stakingImplementation = address(new AndeNativeStaking());
        console2.log("Staking Implementation:", stakingImplementation);
        
        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address)",
            andeProxy,  // ANDE token
            deployer,   // defaultAdmin
            deployer    // treasury
        );
        
        // Deploy proxy
        stakingProxy = address(new ERC1967Proxy(stakingImplementation, initData));
        console2.log("Staking Proxy:", stakingProxy);
        
        console2.log("[SUCCESS] Staking Contract deployed successfully");
        console2.log("");
    }
    
    function _deployTimelock() internal {
        console2.log("=== Step 3: Deploying Timelock Controller ===");
        
        // Deploy implementation
        timelockImplementation = address(new AndeTimelockController());
        console2.log("Timelock Implementation:", timelockImplementation);
        
        // Prepare proposers and executors arrays (empty for now, Governor will be added later)
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // Anyone can execute
        
        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature(
            "initialize(uint256,address[],address[],address)",
            TIMELOCK_DELAY,
            proposers,
            executors,
            deployer  // admin (will be transferred to Governor later)
        );
        
        // Deploy proxy
        timelockProxy = payable(address(new ERC1967Proxy(timelockImplementation, initData)));
        console2.log("Timelock Proxy:", timelockProxy);
        
        console2.log("[SUCCESS] Timelock Controller deployed successfully");
        console2.log("");
    }
    
    function _deployGovernor() internal {
        console2.log("=== Step 4: Deploying Governor ===");
        
        // Deploy implementation
        governorImplementation = address(new AndeGovernor());
        console2.log("Governor Implementation:", governorImplementation);
        
        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address,uint256,uint256,uint256,address)",
            andeProxy,          // token
            stakingProxy,       // stakingContract
            timelockProxy,      // timelock
            VOTING_PERIOD,      // votingPeriod
            VOTING_DELAY,       // votingDelay
            PROPOSAL_THRESHOLD, // proposalThreshold
            deployer           // emergencyCouncil
        );
        
        // Deploy proxy
        governorProxy = address(new ERC1967Proxy(governorImplementation, initData));
        console2.log("Governor Proxy:", governorProxy);
        
        console2.log("[SUCCESS] Governor deployed successfully");
        console2.log("");
    }
    
    function _configureRoles() internal {
        console2.log("=== Step 5: Configuring Roles and Permissions ===");
        
        // Grant PROPOSER_ROLE to Governor in Timelock
        bytes32 PROPOSER_ROLE = AndeTimelockController(timelockProxy).PROPOSER_ROLE();
        AndeTimelockController(timelockProxy).grantRole(PROPOSER_ROLE, governorProxy);
        console2.log("[SUCCESS] Granted PROPOSER_ROLE to Governor");
        
        // Grant MINTER_ROLE to Staking contract for rewards
        bytes32 MINTER_ROLE = ANDETokenDuality(andeProxy).MINTER_ROLE();
        ANDETokenDuality(andeProxy).grantRole(MINTER_ROLE, stakingProxy);
        console2.log("[SUCCESS] Granted MINTER_ROLE to Staking contract");
        
        // Optional: Transfer admin roles to Governor for full decentralization
        if (block.chainid == ANDECHAIN_TESTNET_ID) {
            console2.log("[INFO] Keeping admin roles with deployer for testnet");
        }
        
        console2.log("[SUCCESS] Roles configured successfully");
        console2.log("");
    }
    
    // ============================================================================
    // OUTPUT AND REPORTING
    // ============================================================================
    
    function _outputDeploymentSummary() internal view {
        console2.log("==========================================================");
        console2.log("              DEPLOYMENT SUMMARY");
        console2.log("==========================================================");
        console2.log("Network:", _getNetworkName());
        console2.log("Chain ID:", block.chainid);
        console2.log("Block Number:", block.number);
        console2.log("Deployer:", deployer);
        console2.log("");
        console2.log("[CONTRACTS] Contract Addresses:");
        console2.log("  ANDE Implementation:", andeImplementation);
        console2.log("  ANDE Proxy:", andeProxy);
        console2.log("  Staking Implementation:", stakingImplementation);
        console2.log("  Staking Proxy:", stakingProxy);
        console2.log("  Timelock Implementation:", timelockImplementation);
        console2.log("  Timelock Proxy:", timelockProxy);
        console2.log("  Governor Implementation:", governorImplementation);
        console2.log("  Governor Proxy:", governorProxy);
        console2.log("");
        console2.log("[CONFIG] Configuration:");
        console2.log("  Proposal Threshold:", PROPOSAL_THRESHOLD / 1 ether, "ANDE");
        console2.log("  Voting Delay:", VOTING_DELAY, "blocks");
        console2.log("  Voting Period:", VOTING_PERIOD, "blocks");
        console2.log("  Timelock Delay:", TIMELOCK_DELAY / 1 hours, "hours");
        console2.log("");
        console2.log("[NEXT] Next Steps:");
        console2.log("  1. Verify contracts on block explorer");
        console2.log("  2. Update frontend with new addresses");
        console2.log("  3. Test governance flow");
        console2.log("  4. Delegate voting power");
        console2.log("==========================================================");
    }
    
    function _generateDeploymentJson() internal {
        string memory json = string(abi.encodePacked(
            '{\n',
            '  "network": "', _getNetworkName(), '",\n',
            '  "chainId": ', vm.toString(block.chainid), ',\n',
            '  "timestamp": ', vm.toString(block.timestamp), ',\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "blockNumber": ', vm.toString(block.number), ',\n',
            '  "contracts": {\n',
            '    "ANDE": {\n',
            '      "implementation": "', vm.toString(andeImplementation), '",\n',
            '      "proxy": "', vm.toString(andeProxy), '"\n',
            '    },\n',
            '    "AndeNativeStaking": {\n',
            '      "implementation": "', vm.toString(stakingImplementation), '",\n',
            '      "proxy": "', vm.toString(stakingProxy), '"\n',
            '    },\n',
            '    "AndeTimelockController": {\n',
            '      "implementation": "', vm.toString(timelockImplementation), '",\n',
            '      "proxy": "', vm.toString(timelockProxy), '"\n',
            '    },\n',
            '    "AndeGovernor": {\n',
            '      "implementation": "', vm.toString(governorImplementation), '",\n',
            '      "proxy": "', vm.toString(governorProxy), '"\n',
            '    }\n',
            '  }\n',
            '}'
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/",
            vm.toString(block.chainid),
            "-",
            vm.toString(block.timestamp),
            ".json"
        ));
        
        vm.writeFile(filename, json);
        console2.log("[SAVED] Deployment JSON saved to:", filename);
    }
    
    function _getNetworkName() internal view returns (string memory) {
        if (block.chainid == ANDECHAIN_TESTNET_ID) {
            return "AndeChain Testnet";
        } else if (block.chainid == LOCAL_TESTNET_ID) {
            return "Local Testnet";
        } else {
            return "Unknown Network";
        }
    }
}