// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {AndeNativeStaking} from "../src/staking/AndeNativeStaking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FundStaking
 * @notice Script para fondear el contrato de staking con rewards iniciales
 * @dev Transfiere ANDE tokens al contrato y configura el sistema de rewards
 *
 * Usage:
 *   forge script script/FundStaking.s.sol:FundStaking --rpc-url $RPC_URL --broadcast
 *   
 * Local:
 *   forge script script/FundStaking.s.sol:FundStaking --rpc-url http://localhost:8545 --broadcast --private-key $PRIVATE_KEY
 */
contract FundStaking is Script {
    // Direcciones conocidas
    address constant ANDE_TOKEN_ADDRESS = 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853;
    address constant STAKING_PROXY_ADDRESS = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    
    // Cantidades de funding (ajustar según necesidad)
    uint256 constant INITIAL_LIQUIDITY_REWARDS = 1_000_000 * 1e18; // 1M ANDE
    uint256 constant INITIAL_GOVERNANCE_REWARDS = 500_000 * 1e18;  // 500K ANDE
    uint256 constant INITIAL_SEQUENCER_REWARDS = 1_500_000 * 1e18; // 1.5M ANDE
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        IERC20 andeToken = IERC20(ANDE_TOKEN_ADDRESS);
        AndeNativeStaking staking = AndeNativeStaking(payable(STAKING_PROXY_ADDRESS));
        
        console2.log("==============================================");
        console2.log("Funding AndeNativeStaking");
        console2.log("==============================================");
        console2.log("Funder:", deployer);
        console2.log("Staking Contract:", STAKING_PROXY_ADDRESS);
        console2.log("ANDE Token:", ANDE_TOKEN_ADDRESS);
        console2.log("");
        console2.log("Funding Amounts:");
        console2.log("- Liquidity Pool:", INITIAL_LIQUIDITY_REWARDS / 1e18, "ANDE");
        console2.log("- Governance Pool:", INITIAL_GOVERNANCE_REWARDS / 1e18, "ANDE");
        console2.log("- Sequencer Pool:", INITIAL_SEQUENCER_REWARDS / 1e18, "ANDE");
        console2.log("- Total:", (INITIAL_LIQUIDITY_REWARDS + INITIAL_GOVERNANCE_REWARDS + INITIAL_SEQUENCER_REWARDS) / 1e18, "ANDE");
        console2.log("==============================================");
        
        uint256 balance = andeToken.balanceOf(deployer);
        console2.log("Deployer ANDE balance:", balance / 1e18, "ANDE");
        
        uint256 totalNeeded = INITIAL_LIQUIDITY_REWARDS + INITIAL_GOVERNANCE_REWARDS + INITIAL_SEQUENCER_REWARDS;
        require(balance >= totalNeeded, "Insufficient ANDE balance for funding");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Approve staking contract
        console2.log("");
        console2.log("Approving staking contract...");
        andeToken.approve(STAKING_PROXY_ADDRESS, totalNeeded);
        console2.log("Approved:", totalNeeded / 1e18, "ANDE");
        
        // 2. Distribute rewards to all pools
        // The distributeRewards function splits the total amount among pools based on:
        // - SEQUENCER_SHARE: 40% (4000/10000)
        // - GOVERNANCE_SHARE: 30% (3000/10000)
        // - LIQUIDITY_SHARE: 30% (3000/10000)
        console2.log("");
        console2.log("Distributing rewards to all pools...");
        staking.distributeRewards(totalNeeded);
        console2.log("Total rewards distributed:", totalNeeded / 1e18, "ANDE");
        console2.log("- Sequencer (40%):", (totalNeeded * 4000 / 10000) / 1e18, "ANDE");
        console2.log("- Governance (30%):", (totalNeeded * 3000 / 10000) / 1e18, "ANDE");
        console2.log("- Liquidity (30%):", (totalNeeded * 3000 / 10000) / 1e18, "ANDE");
        
        vm.stopBroadcast();
        
        // 5. Verify funding
        console2.log("");
        console2.log("==============================================");
        console2.log("Funding Verification");
        console2.log("==============================================");
        
        uint256 contractBalance = andeToken.balanceOf(STAKING_PROXY_ADDRESS);
        console2.log("Staking contract balance:", contractBalance / 1e18, "ANDE");
        console2.log("Active Sequencers:", staking.getActiveSequencersCount());
        console2.log("==============================================");
        
        console2.log("");
        console2.log("Staking contract successfully funded!");
        console2.log("Users can now stake and earn rewards.");
    }
}

/**
 * @title FundStakingSmall
 * @notice Script para fondear con cantidades pequeñas para testing
 */
contract FundStakingSmall is Script {
    address constant ANDE_TOKEN_ADDRESS = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
    address constant STAKING_PROXY_ADDRESS = 0x0165878A594ca255338adfa4d48449f69242Eb8F;
    
    // Cantidades pequeñas para testing
    uint256 constant LIQUIDITY_REWARDS = 10_000 * 1e18;  // 10K ANDE
    uint256 constant GOVERNANCE_REWARDS = 5_000 * 1e18;   // 5K ANDE
    uint256 constant SEQUENCER_REWARDS = 15_000 * 1e18;   // 15K ANDE
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        IERC20 andeToken = IERC20(ANDE_TOKEN_ADDRESS);
        AndeNativeStaking staking = AndeNativeStaking(payable(STAKING_PROXY_ADDRESS));
        
        console2.log("Funding staking (small amounts for testing)...");
        console2.log("Total to fund:", (LIQUIDITY_REWARDS + GOVERNANCE_REWARDS + SEQUENCER_REWARDS) / 1e18, "ANDE");
        
        uint256 totalNeeded = LIQUIDITY_REWARDS + GOVERNANCE_REWARDS + SEQUENCER_REWARDS;
        
        vm.startBroadcast(deployerPrivateKey);
        
        andeToken.approve(STAKING_PROXY_ADDRESS, totalNeeded);
        staking.distributeRewards(totalNeeded);
        
        vm.stopBroadcast();
        
        console2.log("Staking funded successfully!");
        console2.log("Contract balance:", andeToken.balanceOf(STAKING_PROXY_ADDRESS) / 1e18, "ANDE");
    }
}

/**
 * @title CheckStakingStatus
 * @notice Script para verificar el estado del contrato de staking
 */
contract CheckStakingStatus is Script {
    address constant ANDE_TOKEN_ADDRESS = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
    address constant STAKING_PROXY_ADDRESS = 0x0165878A594ca255338adfa4d48449f69242Eb8F;
    
    function run() public view {
        IERC20 andeToken = IERC20(ANDE_TOKEN_ADDRESS);
        AndeNativeStaking staking = AndeNativeStaking(payable(STAKING_PROXY_ADDRESS));
        
        console2.log("==============================================");
        console2.log("AndeNativeStaking Status");
        console2.log("==============================================");
        console2.log("Contract Address:", STAKING_PROXY_ADDRESS);
        console2.log("ANDE Token:", address(staking.andeToken()));
        console2.log("");
        
        console2.log("Minimum Stakes:");
        console2.log("- Liquidity:", staking.MIN_LIQUIDITY_STAKE() / 1e18, "ANDE");
        console2.log("- Governance:", staking.MIN_GOVERNANCE_STAKE() / 1e18, "ANDE");
        console2.log("- Sequencer:", staking.MIN_SEQUENCER_STAKE() / 1e18, "ANDE");
        console2.log("");
        
        uint256 contractBalance = andeToken.balanceOf(STAKING_PROXY_ADDRESS);
        console2.log("Contract ANDE Balance:", contractBalance / 1e18, "ANDE");
        console2.log("");
        
        console2.log("Active Sequencers Count:", staking.getActiveSequencersCount());
        console2.log("==============================================");
    }
}