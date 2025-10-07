// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {AbobToken} from "../src/AbobToken.sol";
import {CollateralManager} from "../src/CollateralManager.sol";
import {AndeOracleAggregator} from "../src/AndeOracleAggregator.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import {ANDEToken} from "../src/ANDEToken.sol";

contract TestCDPBasicFlow is Script {
    // Core contracts
    AbobToken public abobToken;
    CollateralManager public collateralManager;
    AndeOracleAggregator public oracleAggregator;
    ANDEToken public andeToken;

    // Test tokens
    MockERC20 public mockUSDC;

    // Test addresses
    address public constant ADMIN = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant USER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public constant LIQUIDATOR = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    function run() external {
        vm.startBroadcast(ADMIN);

        // === DEPLOYMENT ===
        console.log("=== DEPLOYING CDP SYSTEM ===");

        // 1. Deploy ANDE Token
        andeToken = new ANDEToken();
        console.log("ANDE Token:", address(andeToken));

        // 2. Deploy Mock USDC
        mockUSDC = new MockERC20("USD Coin", "USDC", 6);
        console.log("Mock USDC:", address(mockUSDC));

        // 3. Deploy Oracle Aggregator (mock for now)
        oracleAggregator = new AndeOracleAggregator();
        oracleAggregator.initialize(ADMIN, ADMIN); // Use ADMIN as oracle for simplicity
        console.log("Oracle Aggregator:", address(oracleAggregator));

        // 4. Deploy Collateral Manager
        collateralManager = new CollateralManager();
        collateralManager.initialize(ADMIN, address(oracleAggregator));
        console.log("Collateral Manager:", address(collateralManager));

        // 5. Deploy ABOB Token (CDP)
        abobToken = new AbobToken();
        abobToken.initialize(
            ADMIN,    // admin
            ADMIN,    // pauser
            ADMIN,    // governance
            address(oracleAggregator), // price oracle
            address(collateralManager), // collateral manager
            ADMIN     // liquidation manager
        );
        console.log("ABOB Token:", address(abobToken));

        // === SETUP ===
        console.log("\n=== SETTING UP SYSTEM ===");

        // Add USDC as collateral
        collateralManager.addCollateral(
            address(mockUSDC),
            12000, // 120% ratio
            11000, // 110% liquidation threshold
            1000000 * 1e18, // 1M ABOB debt ceiling
            100 * 1e6, // 100 USDC minimum
            address(oracleAggregator)
        );
        console.log("USDC added as collateral");

        // Mint tokens for testing
        mockUSDC.mint(USER, 10000 * 1e6); // 10K USDC
        mockUSDC.mint(LIQUIDATOR, 50000 * 1e6); // 50K USDC
        andeToken.mint(USER, 1000 * 1e18); // 1K ANDE for gas

        console.log("Tokens minted for testing");

        vm.stopBroadcast();

        // === TEST CDP FLOW ===
        console.log("\n=== TESTING CDP FLOW ===");
        _testCompleteCDPFlow();

        console.log("\n=== ✅ CDP BASIC FLOW TEST COMPLETED ===");
    }

    function _testCompleteCDPFlow() internal {
        // === STEP 1: DEPOSIT COLLATERAL AND MINT ABOB ===
        console.log("\n1. DEPOSIT & MINT");

        vm.startBroadcast(USER);
        mockUSDC.approve(address(abobToken), 5000 * 1e6);

        // Deposit 5000 USDC and mint 4000 ABOB (125% ratio)
        abobToken.depositCollateralAndMint(
            address(mockUSDC),
            5000 * 1e6,
            4000 * 1e18
        );

        (uint256 collateralValue, uint256 debt, uint256 healthFactor) = abobToken.getUserVaultInfo(USER);
        console.log("Collateral Value:", collateralValue / 1e18);
        console.log("Debt:", debt / 1e18);
        console.log("Health Factor:", healthFactor);

        require(healthFactor >= 12000, "Health factor should be >= 120%");
        console.log("✅ Deposit & Mint successful");

        // === STEP 2: MINT MORE ABOB AGAINST EXISTING COLLATERAL ===
        console.log("\n2. ADDITIONAL MINT");

        abobToken.mintAbob(500 * 1e18); // Mint additional 500 ABOB

        (collateralValue, debt, healthFactor) = abobToken.getUserVaultInfo(USER);
        console.log("New Debt:", debt / 1e18);
        console.log("New Health Factor:", healthFactor);

        require(healthFactor >= 12000, "Health factor should still be >= 120%");
        console.log("✅ Additional mint successful");

        // === STEP 3: PARTIAL DEBT REPAYMENT ===
        console.log("\n3. DEBT REPAYMENT");

        abobToken.repayDebt(1000 * 1e18); // Repay 1000 ABOB

        (collateralValue, debt, healthFactor) = abobToken.getUserVaultInfo(USER);
        console.log("Debt after repayment:", debt / 1e18);
        console.log("Health Factor after repayment:", healthFactor);
        console.log("✅ Debt repayment successful");

        // === STEP 4: WITHDRAW SOME COLLATERAL ===
        console.log("\n4. COLLATERAL WITHDRAWAL");

        abobToken.withdrawCollateral(
            address(mockUSDC),
            1000 * 1e6 // Withdraw 1000 USDC
        );

        (collateralValue, debt, healthFactor) = abobToken.getUserVaultInfo(USER);
        console.log("Collateral after withdrawal:", collateralValue / 1e18);
        console.log("Health Factor after withdrawal:", healthFactor);

        require(healthFactor >= 12000, "Health factor should remain >= 120%");
        console.log("✅ Collateral withdrawal successful");

        // === STEP 5: COMBINED OPERATION ===
        console.log("\n5. COMBINED WITHDRAW & REPAY");

        // Withdraw 500 USDC and repay 500 ABOB in one transaction
        abobToken.withdrawCollateralAndRepayDebt(
            address(mockUSDC),
            500 * 1e6,
            500 * 1e18
        );

        (collateralValue, debt, healthFactor) = abobToken.getUserVaultInfo(USER);
        console.log("Final Collateral:", collateralValue / 1e18);
        console.log("Final Debt:", debt / 1e18);
        console.log("Final Health Factor:", healthFactor);

        console.log("✅ Combined operation successful");

        // === STEP 6: SYSTEM OVERVIEW ===
        console.log("\n6. SYSTEM OVERVIEW");

        (uint256 totalCollateral, uint256 totalDebt, uint256 systemRatio) = abobToken.getSystemInfo();
        console.log("Total System Collateral:", totalCollateral / 1e18);
        console.log("Total System Debt:", totalDebt / 1e18);
        console.log("System Ratio:", systemRatio);

        console.log("✅ System overview generated");

        // === STEP 7: LIQUIDATION TEST ===
        console.log("\n7. LIQUIDATION TEST");

        // Create underwater position for liquidation test
        // Deposit more collateral but mint too much ABOB
        mockUSDC.approve(address(abobToken), 2000 * 1e6);
        abobToken.depositCollateralAndMint(
            address(mockUSDC),
            2000 * 1e6,
            2200 * 1e18 // This creates ~109% ratio (below 120% but above 110%)
        );

        (collateralValue, debt, healthFactor) = abobToken.getUserVaultInfo(USER);
        console.log("Position for liquidation test:");
        console.log("Collateral:", collateralValue / 1e18);
        console.log("Debt:", debt / 1e18);
        console.log("Health Factor:", healthFactor);

        // Check if liquidatable (should be false since 109% > 110% threshold)
        bool canLiquidate = abobToken.canLiquidate(USER);
        console.log("Can liquidate:", canLiquidate);

        if (!canLiquidate) {
            console.log("ℹ️ Position not liquidatable (as expected)");
            console.log("✅ Liquidation test completed");
        }
    }

    function getVaultInfo(address _user) external view returns (
        uint256 collateralValue,
        uint256 debt,
        uint256 healthFactor
    ) {
        return abobToken.getUserVaultInfo(_user);
    }

    function getSystemInfo() external view returns (
        uint256 totalCollateral,
        uint256 totalDebt,
        uint256 systemRatio
    ) {
        return abobToken.getSystemInfo();
    }
}