// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ANDEToken} from "../src/token/ANDEToken.sol";
import {AndeNativeStaking} from "../src/staking/AndeNativeStaking.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployEcosystem
 * @notice Script completo para desplegar el ecosistema de staking
 * @dev Despliega ANDEToken, AndeNativeStaking y fondea con rewards iniciales
 *
 * Usage:
 *   forge script script/DeployEcosystem.s.sol:DeployEcosystem --rpc-url http://localhost:8545 --broadcast --private-key $PRIVATE_KEY
 */
contract DeployEcosystem is Script {
    // Parámetros de deployment
    uint256 constant INITIAL_SUPPLY = 1_000_000_000 * 1e18; // 1B ANDE
    uint256 constant STAKING_REWARDS = 30_000_000 * 1e18;   // 30M ANDE para rewards (3%)
    
    // Direcciones desplegadas
    ANDEToken public andeToken;
    AndeNativeStaking public stakingImplementation;
    AndeNativeStaking public staking;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("==============================================");
        console2.log("Deploying ANDE Staking Ecosystem");
        console2.log("==============================================");
        console2.log("Deployer:", deployer);
        console2.log("Network: AndeChain (localhost)");
        console2.log("==============================================");
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // ============================================
        // 1. Deploy ANDEToken
        // ============================================
        console2.log("1. Deploying ANDEToken...");
        andeToken = new ANDEToken(
            "ANDE Token",
            "ANDE",
            INITIAL_SUPPLY,
            deployer
        );
        console2.log("   ANDEToken deployed at:", address(andeToken));
        console2.log("   Total Supply:", INITIAL_SUPPLY / 1e18, "ANDE");
        console2.log("   Deployer Balance:", andeToken.balanceOf(deployer) / 1e18, "ANDE");
        console2.log("");
        
        // ============================================
        // 2. Deploy AndeNativeStaking (Implementation)
        // ============================================
        console2.log("2. Deploying AndeNativeStaking Implementation...");
        stakingImplementation = new AndeNativeStaking();
        console2.log("   Implementation deployed at:", address(stakingImplementation));
        console2.log("");
        
        // ============================================
        // 3. Deploy Proxy and Initialize
        // ============================================
        console2.log("3. Deploying Proxy and Initializing...");
        bytes memory initData = abi.encodeWithSelector(
            AndeNativeStaking.initialize.selector,
            address(andeToken),
            deployer, // admin
            deployer, // rewardDistributor
            deployer, // sequencerManager
            deployer  // pauser
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(stakingImplementation),
            initData
        );
        
        staking = AndeNativeStaking(payable(address(proxy)));
        console2.log("   Proxy deployed at:", address(staking));
        console2.log("   Staking contract initialized");
        console2.log("");
        
        // ============================================
        // 4. Verify Initialization
        // ============================================
        console2.log("4. Verifying Staking Configuration...");
        console2.log("   ANDE Token:", address(staking.andeToken()));
        console2.log("   MIN_LIQUIDITY_STAKE:", staking.MIN_LIQUIDITY_STAKE() / 1e18, "ANDE");
        console2.log("   MIN_GOVERNANCE_STAKE:", staking.MIN_GOVERNANCE_STAKE() / 1e18, "ANDE");
        console2.log("   MIN_SEQUENCER_STAKE:", staking.MIN_SEQUENCER_STAKE() / 1e18, "ANDE");
        console2.log("");
        
        // ============================================
        // 5. Fund Staking with Rewards
        // ============================================
        console2.log("5. Funding Staking Contract with Rewards...");
        console2.log("   Approving", STAKING_REWARDS / 1e18, "ANDE...");
        andeToken.approve(address(staking), STAKING_REWARDS);
        
        console2.log("   Distributing rewards...");
        staking.distributeRewards(STAKING_REWARDS);
        
        console2.log("   Rewards distributed:");
        console2.log("   - Sequencer (40%):", (STAKING_REWARDS * 4000 / 10000) / 1e18, "ANDE");
        console2.log("   - Governance (30%):", (STAKING_REWARDS * 3000 / 10000) / 1e18, "ANDE");
        console2.log("   - Liquidity (30%):", (STAKING_REWARDS * 3000 / 10000) / 1e18, "ANDE");
        console2.log("");
        
        // ============================================
        // 6. Verify Final State
        // ============================================
        console2.log("6. Final Verification...");
        uint256 stakingBalance = andeToken.balanceOf(address(staking));
        uint256 deployerBalance = andeToken.balanceOf(deployer);
        
        console2.log("   Staking Contract Balance:", stakingBalance / 1e18, "ANDE");
        console2.log("   Deployer Balance:", deployerBalance / 1e18, "ANDE");
        console2.log("   Active Sequencers:", staking.getActiveSequencersCount());
        console2.log("");
        
        vm.stopBroadcast();
        
        // ============================================
        // 7. Save Deployment Info
        // ============================================
        _saveDeployment(
            address(andeToken),
            address(stakingImplementation),
            address(staking)
        );
        
        // ============================================
        // 8. Summary
        // ============================================
        console2.log("==============================================");
        console2.log("Deployment Summary");
        console2.log("==============================================");
        console2.log("ANDEToken:", address(andeToken));
        console2.log("AndeNativeStaking (Proxy):", address(staking));
        console2.log("AndeNativeStaking (Implementation):", address(stakingImplementation));
        console2.log("==============================================");
        console2.log("");
        console2.log("Update andefrontend/src/contracts/addresses.ts:");
        console2.log("```typescript");
        console2.log("const LOCAL_CONTRACTS: ContractAddresses = {");
        console2.log("  ANDEToken: '%s' as Address,", address(andeToken));
        console2.log("  AndeNativeStaking: '%s' as Address,", address(staking));
        console2.log("  AndeGovernor: ZERO_ADDRESS,");
        console2.log("  AndeSequencerRegistry: ZERO_ADDRESS,");
        console2.log("  WAndeVault: ZERO_ADDRESS,");
        console2.log("};");
        console2.log("```");
        console2.log("");
        console2.log("✅ Ecosystem deployed successfully!");
        console2.log("✅ Users can now stake and earn rewards");
        console2.log("==============================================");
    }
    
    function _saveDeployment(
        address tokenAddress,
        address implementationAddress,
        address proxyAddress
    ) internal {
        string memory deploymentInfo = string(
            abi.encodePacked(
                "{\n",
                '  "network": "andechain-local",\n',
                '  "chainId": 1234,\n',
                '  "deployer": "', vm.toString(msg.sender), '",\n',
                '  "timestamp": ', vm.toString(block.timestamp), ',\n',
                '  "blockNumber": ', vm.toString(block.number), ',\n',
                '  "contracts": {\n',
                '    "ANDEToken": "', vm.toString(tokenAddress), '",\n',
                '    "AndeNativeStaking": {\n',
                '      "proxy": "', vm.toString(proxyAddress), '",\n',
                '      "implementation": "', vm.toString(implementationAddress), '"\n',
                '    }\n',
                '  },\n',
                '  "config": {\n',
                '    "initialSupply": "', vm.toString(INITIAL_SUPPLY), '",\n',
                '    "stakingRewards": "', vm.toString(STAKING_REWARDS), '",\n',
                '    "minLiquidityStake": "100000000000000000000",\n',
                '    "minGovernanceStake": "1000000000000000000000",\n',
                '    "minSequencerStake": "100000000000000000000000"\n',
                '  }\n',
                "}\n"
            )
        );
        
        vm.writeFile("deployments/ecosystem-latest.json", deploymentInfo);
        console2.log("Deployment info saved to: deployments/ecosystem-latest.json");
        console2.log("");
    }
}

/**
 * @title QuickDeploy
 * @notice Deployment rápido sin output verbose
 */
contract QuickDeploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy ANDEToken
        ANDEToken andeToken = new ANDEToken(
            "ANDE Token",
            "ANDE",
            1_000_000_000 * 1e18,
            deployer
        );
        
        // Deploy Staking
        AndeNativeStaking implementation = new AndeNativeStaking();
        
        bytes memory initData = abi.encodeWithSelector(
            AndeNativeStaking.initialize.selector,
            address(andeToken),
            deployer,
            deployer,
            deployer,
            deployer
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        AndeNativeStaking staking = AndeNativeStaking(payable(address(proxy)));
        
        // Fund staking
        uint256 rewards = 30_000_000 * 1e18;
        andeToken.approve(address(staking), rewards);
        staking.distributeRewards(rewards);
        
        vm.stopBroadcast();
        
        console2.log("==============================================");
        console2.log("Quick Deploy Complete!");
        console2.log("==============================================");
        console2.log("ANDEToken:", address(andeToken));
        console2.log("AndeNativeStaking:", address(staking));
        console2.log("==============================================");
    }
}

/**
 * @title CheckDeployment
 * @notice Script para verificar el estado del deployment
 */
contract CheckDeployment is Script {
    function run() public view {
        // Leer direcciones desde argumentos o archivo
        address tokenAddress = vm.envAddress("ANDE_TOKEN_ADDRESS");
        address stakingAddress = vm.envAddress("STAKING_ADDRESS");
        
        ANDEToken token = ANDEToken(tokenAddress);
        AndeNativeStaking staking = AndeNativeStaking(payable(stakingAddress));
        
        console2.log("==============================================");
        console2.log("Deployment Status Check");
        console2.log("==============================================");
        console2.log("ANDEToken:", tokenAddress);
        console2.log("  Name:", token.name());
        console2.log("  Symbol:", token.symbol());
        console2.log("  Total Supply:", token.totalSupply() / 1e18, "ANDE");
        console2.log("");
        console2.log("AndeNativeStaking:", stakingAddress);
        console2.log("  ANDE Token:", address(staking.andeToken()));
        console2.log("  Contract Balance:", token.balanceOf(stakingAddress) / 1e18, "ANDE");
        console2.log("  Active Sequencers:", staking.getActiveSequencersCount());
        console2.log("  MIN_LIQUIDITY_STAKE:", staking.MIN_LIQUIDITY_STAKE() / 1e18, "ANDE");
        console2.log("  MIN_GOVERNANCE_STAKE:", staking.MIN_GOVERNANCE_STAKE() / 1e18, "ANDE");
        console2.log("  MIN_SEQUENCER_STAKE:", staking.MIN_SEQUENCER_STAKE() / 1e18, "ANDE");
        console2.log("==============================================");
    }
}