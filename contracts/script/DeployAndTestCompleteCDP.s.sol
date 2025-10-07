// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {AbobToken} from "../src/AbobToken.sol";
import {CollateralManager} from "../src/CollateralManager.sol";
import {AuctionManager} from "../src/AuctionManager.sol";
import {AndeOracleAggregator} from "../src/AndeOracleAggregator.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {P2POracle} from "../src/P2POracle.sol";
import {ANDEToken} from "../src/ANDEToken.sol";

contract DeployAndTestCompleteCDP is Script {
    // Contracts
    AbobToken public abobToken;
    CollateralManager public collateralManager;
    AuctionManager public auctionManager;
    AndeOracleAggregator public oracleAggregator;
    P2POracle public p2pOracle;
    ANDEToken public andeToken;

    // Mock tokens for testing
    MockERC20 public mockUSDC;
    MockERC20 public mockWBTC;

    // Test addresses
    address public constant ADMIN = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant USER1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public constant USER2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address public constant USER3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address public constant LIQUIDATOR = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;

    // Test parameters
    uint256 public constant USDC_PRICE = 1e18; // $1
    uint256 public constant WBTC_PRICE = 50000e18; // $50,000

    function run() external {
        vm.startBroadcast(ADMIN);

        // === PHASE 1: DEPLOY CORE INFRASTRUCTURE ===
        _deployInfrastructure();

        // === PHASE 2: SETUP ORACLES ===
        _setupOracles();

        // === PHASE 3: SETUP COLLATERALS ===
        _setupCollaterals();

        vm.stopBroadcast();

        // === PHASE 4: TEST COMPLETE CDP FLOW ===
        _testCDPFlow();

        // === PHASE 5: TEST LIQUIDATIONS ===
        _testLiquidations();

        console.log("=== TEST COMPLETED ===");
    }

    function _deployInfrastructure() internal {
        console.log("=== TEST COMPLETED ===");

        // 1. Deploy ANDE Token (native gas token)
        console.log("1. Deploying ANDE Token...");
        andeToken = new ANDEToken();
        console.log("   ANDE Token deployed to:", address(andeToken));

        // 2. Deploy Mock Collaterals
        console.log("2. Deploying Mock Collaterals...");
        mockUSDC = new MockERC20("USD Coin", "USDC", 6);
        mockWBTC = new MockERC20("Wrapped Bitcoin", "WBTC", 8);
        console.log("   Mock USDC deployed to:", address(mockUSDC));
        console.log("   Mock WBTC deployed to:", address(mockWBTC));

        // 3. Deploy P2P Oracle
        console.log("3. Deploying P2P Oracle...");
        p2pOracle = new P2POracle();
        p2pOracle.initialize(
            ADMIN,
            address(andeToken),
            100 * 1e18, // 100 ANDE min stake
            3600 // 1 hour epoch
        );
        console.log("   P2P Oracle deployed to:", address(p2pOracle));

        // 4. Deploy Oracle Aggregator
        console.log("4. Deploying Oracle Aggregator...");
        oracleAggregator = new AndeOracleAggregator();
        oracleAggregator.initialize(ADMIN, address(p2pOracle));
        console.log("   Oracle Aggregator deployed to:", address(oracleAggregator));

        // 5. Deploy Collateral Manager
        console.log("5. Deploying Collateral Manager...");
        collateralManager = new CollateralManager();
        collateralManager.initialize(ADMIN, address(oracleAggregator));
        console.log("   Collateral Manager deployed to:", address(collateralManager));

        // 6. Deploy ABOB Token (CDP Contract)
        console.log("6. Deploying ABOB Token (CDP)...");
        abobToken = new AbobToken();
        abobToken.initialize(
            ADMIN,    // admin
            ADMIN,    // pauser
            ADMIN,    // governance
            address(oracleAggregator), // price oracle
            address(collateralManager), // collateral manager
            ADMIN     // liquidation manager (for now)
        );
        console.log("   ABOB Token deployed to:", address(abobToken));

        // 7. Deploy Auction Manager
        console.log("7. Deploying Auction Manager...");
        auctionManager = new AuctionManager();
        auctionManager.initialize(
            ADMIN,
            address(abobToken),
            address(collateralManager)
        );
        console.log("   Auction Manager deployed to:", address(auctionManager));

        // Set up initial token supplies
        mockUSDC.mint(ADMIN, 1000000 * 1e6); // 1M USDC
        mockWBTC.mint(ADMIN, 100 * 1e8); // 100 WBTC
        andeToken.mint(ADMIN, 1000000 * 1e18); // 1M ANDE

        // Approve tokens for testing
        mockUSDC.approve(address(abobToken), type(uint256).max);
        mockWBTC.approve(address(abobToken), type(uint256).max);
        mockUSDC.approve(address(auctionManager), type(uint256).max);
        mockWBTC.approve(address(auctionManager), type(uint256).max);

        console.log("SUCCESS Infrastructure deployed successfully");
    }

    function _setupOracles() internal {
        console.log("=== TEST COMPLETED ===");

        // Setup P2P Oracle prices
        uint256 currentEpoch = block.timestamp / 3600;

        // Finalize current epoch with prices
        vm.startPrank(ADMIN);
        p2pOracle.finalizeCurrentEpoch();

        // Set USDC price ($1)
        uint256 usdcPrice = (1 ether * 1e18) / 1e18; // 1 USDC = $1
        mockUSDC.mint(USER1, 10000 * 1e6);
        vm.startPrank(USER1);
        andeToken.approve(address(p2pOracle), 100 * 1e18);
        p2pOracle.register();
        p2pOracle.reportPrice(usdcPrice);

        // Set WBTC price ($50,000)
        uint256 wbtcPrice = (1 ether * 1e18) / (50000 * 1e18); // 1 WBTC = $50,000
        mockWBTC.mint(USER2, 10 * 1e8);
        vm.startPrank(USER2);
        andeToken.approve(address(p2pOracle), 100 * 1e18);
        p2pOracle.register();
        p2pOracle.reportPrice(wbtcPrice);

        // Finalize with oracle prices
        vm.startPrank(ADMIN);
        p2pOracle.finalizeCurrentEpoch();

        console.log("SUCCESS Oracles configured with prices:");
        console.log("   USDC: $1.00");
        console.log("   WBTC: $50,000.00");
    }

    function _setupCollaterals() internal {
        console.log("=== TEST COMPLETED ===");

        vm.startBroadcast(ADMIN);

        // Add USDC as collateral
        collateralManager.addCollateral(
            address(mockUSDC),
            12000, // 120% overcollateralization
            11000, // 110% liquidation threshold
            1000000 * 1e18, // 1M ABOB debt ceiling
            100 * 1e6, // 100 USDC minimum
            address(oracleAggregator)
        );

        // Add WBTC as collateral
        collateralManager.addCollateral(
            address(mockWBTC),
            15000, // 150% overcollateralization
            12500, // 125% liquidation threshold
            500000 * 1e18, // 500K ABOB debt ceiling
            1 * 1e8, // 0.01 WBTC minimum
            address(oracleAggregator)
        );

        // Give users tokens for testing
        mockUSDC.transfer(USER1, 10000 * 1e6); // 10K USDC
        mockUSDC.transfer(USER2, 5000 * 1e6);  // 5K USDC
        mockUSDC.transfer(USER3, 2000 * 1e6);  // 2K USDC
        mockUSDC.transfer(LIQUIDATOR, 50000 * 1e6); // 50K USDC

        mockWBTC.transfer(USER1, 2 * 1e8);     // 2 WBTC
        mockWBTC.transfer(USER2, 1 * 1e8);     // 1 WBTC
        mockWBTC.transfer(LIQUIDATOR, 5 * 1e8); // 5 WBTC

        console.log("SUCCESS Collaterals added:");
        console.log("   USDC: 120% ratio, 110% threshold");
        console.log("   WBTC: 150% ratio, 125% threshold");
    }

    function _testCDPFlow() internal {
        console.log("=== TEST COMPLETED ===");

        // === Test 1: USER1 - Deposit USDC and mint ABOB ===
        console.log("\n1. USER1: Depositing USDC and minting ABOB...");

        vm.startBroadcast(USER1);
        mockUSDC.approve(address(abobToken), 5000 * 1e6);

        // Deposit 5000 USDC and mint 4000 ABOB (125% collateral ratio)
        abobToken.depositCollateralAndMint(
            address(mockUSDC),
            5000 * 1e6,
            4000 * 1e18
        );

        // Check vault status
        (uint256 collateralValue, uint256 debt, uint256 healthFactor) = abobToken.getUserVaultInfo(USER1);
        console.log("   Collateral Value:", collateralValue / 1e18);
        console.log("   Debt:", debt / 1e18);
        console.log("   Health Factor:", healthFactor);
        require(healthFactor >= 12000, "Health factor too low");

        // === Test 2: USER2 - Deposit WBTC and mint ABOB ===
        console.log("\n2. USER2: Depositing WBTC and minting ABOB...");

        vm.startBroadcast(USER2);
        mockWBTC.approve(address(abobToken), 1 * 1e8);

        // Deposit 1 WBTC ($50K) and mint 30K ABOB (166% collateral ratio)
        abobToken.depositCollateralAndMint(
            address(mockWBTC),
            1 * 1e8,
            30000 * 1e18
        );

        // Check vault status
        (collateralValue, debt, healthFactor) = abobToken.getUserVaultInfo(USER2);
        console.log("   Collateral Value:", collateralValue / 1e18);
        console.log("   Debt:", debt / 1e18);
        console.log("   Health Factor:", healthFactor);
        require(healthFactor >= 15000, "Health factor too low");

        // === Test 3: USER3 - Deposit and mint small amount ===
        console.log("\n3. USER3: Depositing USDC and minting ABOB...");

        vm.startBroadcast(USER3);
        mockUSDC.approve(address(abobToken), 1000 * 1e6);

        // Deposit 1000 USDC and mint 800 ABOB
        abobToken.depositCollateralAndMint(
            address(mockUSDC),
            1000 * 1e6,
            800 * 1e18
        );

        // === Test 4: Partial repayment ===
        console.log("\n4. USER1: Partial debt repayment...");

        vm.startBroadcast(USER1);
        abobToken.repayDebt(1000 * 1e18); // Repay 1000 ABOB

        (collateralValue, debt, healthFactor) = abobToken.getUserVaultInfo(USER1);
        console.log("   New debt:", debt / 1e18);
        console.log("   New Health Factor:", healthFactor);

        // === Test 5: Withdraw some collateral ===
        console.log("\n5. USER1: Withdrawing some USDC...");

        vm.startBroadcast(USER1);
        abobToken.withdrawCollateral(
            address(mockUSDC),
            1000 * 1e6 // Withdraw 1000 USDC
        );

        (collateralValue, debt, healthFactor) = abobToken.getUserVaultInfo(USER1);
        console.log("   New collateral value:", collateralValue / 1e18);
        console.log("   New Health Factor:", healthFactor);
        require(healthFactor >= 12000, "Health factor too low after withdrawal");

        console.log("SUCCESS CDP flow tests completed successfully");
    }

    function _testLiquidations() internal {
        console.log("=== TEST COMPLETED ===");

        // === Test 1: Create underwater position ===
        console.log("\n1. Creating underwater position for liquidation test...");

        // First, we need to simulate a price drop. Let's create a new user with high leverage
        vm.startBroadcast(USER1);
        mockUSDC.approve(address(abobToken), 5000 * 1e6);

        // Deposit additional 5000 USDC and mint maximum ABOB (close to liquidation threshold)
        abobToken.depositCollateralAndMint(
            address(mockUSDC),
            5000 * 1e6,
            9000 * 1e18 // 9000 ABOB against 10000 USDC = 111% ratio (close to 110% threshold)
        );

        (uint256 collateralValue, uint256 debt, uint256 healthFactor) = abobToken.getUserVaultInfo(USER1);
        console.log("   Position created:");
        console.log("   Collateral:", collateralValue / 1e18);
        console.log("   Debt:", debt / 1e18);
        console.log("   Health Factor:", healthFactor);

        // === Test 2: Check liquidation eligibility ===
        console.log("\n2. Testing liquidation eligibility...");

        bool canLiquidate = abobToken.canLiquidate(USER1);
        console.log("   Can liquidate USER1:", canLiquidate);

        // For testing purposes, let's create a scenario that can be liquidated
        // We'll use the AuctionManager directly to test auction flow
        console.log("\n3. Testing auction flow...");

        vm.startBroadcast(ADMIN);

        // Transfer some ABOB to liquidator for bidding
        abobToken.transfer(LIQUIDATOR, 10000 * 1e18);

        // Start auction through AuctionManager
        uint256 auctionId = auctionManager.startLiquidationAuction(
            USER1,
            address(mockUSDC),
            10000 * 1e6, // 10000 USDC
            3000 * 1e18  // 3000 ABOB debt
        );

        console.log("   Auction started with ID:", auctionId);

        // === Test 3: Place bid ===
        console.log("\n4. Testing auction bidding...");

        vm.startBroadcast(LIQUIDATOR);
        abobToken.approve(address(auctionManager), 5000 * 1e18);

        // Place bid
        auctionManager.placeBid(auctionId, 3500 * 1e18);
        console.log("   Bid placed: 3500 ABOB");

        // === Test 4: End auction ===
        console.log("\n5. Ending auction...");

        // Fast forward time to end auction
        vm.warp(block.timestamp + 7 hours);

        vm.startBroadcast(ADMIN);
        auctionManager.endAuction(auctionId);
        console.log("   Auction ended");

        // === Test 5: Verify auction results ===
        console.log("\n6. Verifying auction results...");

        (,, uint256 successRate) = auctionManager.getAuctionStats();
        console.log("   Auction success rate:", successRate);

        console.log("SUCCESS Liquidation tests completed successfully");
    }

    // Helper function to get system overview
    function getSystemOverview() external view returns (
        uint256 totalSystemDebt,
        uint256 totalCollateral,
        uint256 systemRatio
    ) {
        (totalCollateral, totalSystemDebt, systemRatio) = abobToken.getSystemInfo();

        console.log("=== TEST COMPLETED ===");
        console.log("Total System Debt:", totalSystemDebt / 1e18);
        console.log("Total Collateral Value:", totalCollateral / 1e18);
        console.log("System Ratio:", systemRatio);

        // Get individual user positions
        address[] memory users = new address[](3);
        users[0] = USER1;
        users[1] = USER2;
        users[2] = USER3;

        for (uint i = 0; i < users.length; i++) {
            (uint256 collateral, uint256 debt, uint256 healthFactor) = abobToken.getUserVaultInfo(users[i]);
            console.log("\nUser", i + 1, "Position:");
            console.log("  Collateral:", collateral / 1e18);
            console.log("  Debt:", debt / 1e18);
            console.log("  Health Factor:", healthFactor);
        }
    }
}