// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/mev/MEVDistributor.sol";
import "../src/mev/MEVAuctionManager.sol";
import "../src/ANDEToken.sol";
import "../src/gauges/VotingEscrow.sol";

/**
 * @title DeployMEVSystem
 * @notice Deployment script for MEV Redistribution System
 * @dev Deploys MEVDistributor and MEVAuctionManager contracts
 */
contract DeployMEVSystem is Script {
    // ========================================
    // CONFIGURATION
    // ========================================
    
    // Deployment addresses (will be set from environment)
    address private ANDE_TOKEN_ADDRESS;
    address private VOTING_ESCROW_ADDRESS;
    address private TREASURY_ADDRESS;
    address private PROTOCOL_FEE_COLLECTOR;
    address private SEQUENCER_ADDRESS;
    
    // MEV System parameters
    uint256 private constant MINIMUM_BID = 0.1 ether;      // 0.1 ANDE
    uint256 private constant REGISTRATION_DEPOSIT = 1 ether; // 1 ANDE
    
    // ========================================
    // DEPLOYMENT STATE
    // ========================================
    
    MEVDistributor public mevDistributor;
    MEVAuctionManager public mevAuctionManager;
    
    // ========================================
    // MAIN DEPLOYMENT FUNCTION
    // ========================================
    
    function run() external {
        // Load configuration from environment
        _loadConfiguration();
        
        // Validate configuration
        _validateConfiguration();
        
        // Start deployment
        vm.startBroadcast();
        
        // Deploy MEV Distributor
        _deployMEVDistributor();
        
        // Deploy MEV Auction Manager
        _deployMEVAuctionManager();
        
        // Post-deployment setup
        _postDeploymentSetup();
        
        vm.stopBroadcast();
        
        // Log deployment results
        _logDeploymentResults();
    }
    
    // ========================================
    // CONFIGURATION
    // ========================================
    
    function _loadConfiguration() internal {
        // Load from environment variables or use defaults
        ANDE_TOKEN_ADDRESS = vm.envOr("ANDE_TOKEN_ADDRESS", address(0));
        VOTING_ESCROW_ADDRESS = vm.envOr("VOTING_ESCROW_ADDRESS", address(0));
        TREASURY_ADDRESS = vm.envOr("TREASURY_ADDRESS", address(0));
        PROTOCOL_FEE_COLLECTOR = vm.envOr("PROTOCOL_FEE_COLLECTOR", address(0));
        SEQUENCER_ADDRESS = vm.envOr("SEQUENCER_ADDRESS", address(0));
        
        // If addresses are not provided, use deployer as default for testing
        address deployer = msg.sender;
        
        if (ANDE_TOKEN_ADDRESS == address(0)) {
            console.log("Warning: ANDE_TOKEN_ADDRESS not provided, using deployer for testing");
            ANDE_TOKEN_ADDRESS = deployer;
        }
        
        if (VOTING_ESCROW_ADDRESS == address(0)) {
            console.log("Warning: VOTING_ESCROW_ADDRESS not provided, using deployer for testing");
            VOTING_ESCROW_ADDRESS = deployer;
        }
        
        if (TREASURY_ADDRESS == address(0)) {
            console.log("Warning: TREASURY_ADDRESS not provided, using deployer for testing");
            TREASURY_ADDRESS = deployer;
        }
        
        if (PROTOCOL_FEE_COLLECTOR == address(0)) {
            console.log("Warning: PROTOCOL_FEE_COLLECTOR_ADDRESS not provided, using deployer for testing");
            PROTOCOL_FEE_COLLECTOR = deployer;
        }
        
        if (SEQUENCER_ADDRESS == address(0)) {
            console.log("Warning: SEQUENCER_ADDRESS not provided, using deployer for testing");
            SEQUENCER_ADDRESS = deployer;
        }
    }
    
    function _validateConfiguration() internal view {
        require(ANDE_TOKEN_ADDRESS != address(0), "ANDE_TOKEN_ADDRESS required");
        require(VOTING_ESCROW_ADDRESS != address(0), "VOTING_ESCROW_ADDRESS required");
        require(TREASURY_ADDRESS != address(0), "TREASURY_ADDRESS required");
        require(PROTOCOL_FEE_COLLECTOR != address(0), "PROTOCOL_FEE_COLLECTOR_ADDRESS required");
        require(SEQUENCER_ADDRESS != address(0), "SEQUENCER_ADDRESS required");
        
        console.log("Configuration validated");
    }
    
    // ========================================
    // DEPLOYMENT FUNCTIONS
    // ========================================
    
    function _deployMEVDistributor() internal {
        console.log("Deploying MEVDistributor...");
        
        mevDistributor = new MEVDistributor(
            VOTING_ESCROW_ADDRESS,
            ANDE_TOKEN_ADDRESS,
            TREASURY_ADDRESS,
            PROTOCOL_FEE_COLLECTOR,
            SEQUENCER_ADDRESS
        );
        
        console.log("MEVDistributor deployed at:", address(mevDistributor));
    }
    
    function _deployMEVAuctionManager() internal {
        console.log("Deploying MEVAuctionManager...");
        
        mevAuctionManager = new MEVAuctionManager(
            ANDE_TOKEN_ADDRESS,
            SEQUENCER_ADDRESS,
            MINIMUM_BID,
            REGISTRATION_DEPOSIT
        );
        
        console.log("MEVAuctionManager deployed at:", address(mevAuctionManager));
    }
    
    // ========================================
    // POST-DEPLOYMENT SETUP
    // ========================================
    
    function _postDeploymentSetup() internal {
        console.log("Setting up post-deployment configuration...");
        
        // Approve MEV Distributor to spend ANDE tokens (for sequencer)
        // This would typically be done by the sequencer after deployment
        console.log("Note: Sequencer should approve MEVDistributor to spend ANDE tokens");
        
        // Set up initial epoch info
        (uint256 currentEpoch, uint256 startTime, uint256 endTime, uint256 timeRemaining) = 
            mevDistributor.getCurrentEpochInfo();
        
        console.log("Current epoch info:");
        console.log("   Epoch:", currentEpoch);
        console.log("   Start time:", startTime);
        console.log("   End time:", endTime);
        console.log("   Time remaining:", timeRemaining);
        
        console.log("Post-deployment setup completed");
    }
    
    // ========================================
    // LOGGING
    // ========================================
    
    function _logDeploymentResults() internal {
        console.log("\nMEV System Deployment Complete!");
        console.log("Contract Addresses:");
        console.log("   MEVDistributor:    ", address(mevDistributor));
        console.log("   MEVAuctionManager: ", address(mevAuctionManager));
        console.log("");
        console.log("Configuration:");
        console.log("   ANDE Token:         ", ANDE_TOKEN_ADDRESS);
        console.log("   Voting Escrow:      ", VOTING_ESCROW_ADDRESS);
        console.log("   Treasury:           ", TREASURY_ADDRESS);
        console.log("   Protocol Fee Coll.: ", PROTOCOL_FEE_COLLECTOR);
        console.log("   Sequencer:          ", SEQUENCER_ADDRESS);
        console.log("");
        console.log("MEV Parameters:");
        console.log("   Minimum Bid:        ", MINIMUM_BID);
        console.log("   Registration Dep.:  ", REGISTRATION_DEPOSIT);
        console.log("");
        console.log("Distribution Splits:");
        console.log("   veANDE Stakers:     80%");
        console.log("   Protocol Fee:       15%");
        console.log("   Treasury:           5%");
        console.log("");
        console.log("Verification:");
        console.log("   Verify on explorer:  https://explorer.andechain.io/address/", address(mevDistributor));
        console.log("   Verify on explorer:  https://explorer.andechain.io/address/", address(mevAuctionManager));
    }
    
    // ========================================
    // UTILITY FUNCTIONS
    // ========================================
    
    /**
     * @notice Get deployment summary
     * @return distributor Address of MEVDistributor
     * @return auctionManager Address of MEVAuctionManager
     */
    function getDeploymentAddresses() external view returns (address distributor, address auctionManager) {
        return (address(mevDistributor), address(mevAuctionManager));
    }
    
    /**
     * @notice Verify deployment was successful
     * @return success Whether deployment was successful
     */
    function verifyDeployment() external view returns (bool success) {
        return address(mevDistributor) != address(0) && address(mevAuctionManager) != address(0);
    }
}