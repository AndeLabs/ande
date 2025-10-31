// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AndePerpetuals} from "../../src/perpetuals/AndePerpetuals.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockOracle} from "../mocks/MockOracle.sol";

contract AndePerpetualsTest is Test {
    AndePerpetuals public perpetuals;
    ERC20Mock public usdc;
    ERC20Mock public wbtc;
    ERC20Mock public weth;
    MockOracle public oracle;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public insuranceFund = address(0x4);
    address public feeRecipient = address(0x5);
    
    uint256 constant INITIAL_BALANCE = 100000e6; // 100k USDC
    uint256 constant BTC_PRICE = 50000e18; // $50,000
    uint256 constant ETH_PRICE = 3000e18;  // $3,000
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy tokens
        usdc = new ERC20Mock("USD Coin", "USDC");
        wbtc = new ERC20Mock("Wrapped BTC", "WBTC");
        weth = new ERC20Mock("Wrapped ETH", "WETH");
        
        // Deploy oracle
        oracle = new MockOracle();
        oracle.setPrice(address(wbtc), BTC_PRICE);
        oracle.setPrice(address(weth), ETH_PRICE);
        
        // Deploy perpetuals
        perpetuals = new AndePerpetuals(
            address(usdc),
            address(oracle),
            insuranceFund,
            feeRecipient
        );
        
        // Add markets
        perpetuals.addMarket(address(wbtc), 10000000e18); // $10M max OI
        perpetuals.addMarket(address(weth), 5000000e18);  // $5M max OI
        
        // Mint USDC to users
        usdc.mint(alice, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
        
        // Add liquidity to perpetuals contract (insurance fund)
        usdc.mint(address(perpetuals), 1000000e6); // $1M liquidity
        
        vm.stopPrank();
    }
    
    // ========================================
    // OPEN POSITION TESTS
    // ========================================
    
    function testOpenLongPosition() public {
        console.log("=== TEST OPEN LONG POSITION ===");
        
        vm.startPrank(alice);
        
        uint256 collateral = 1000e6; // $1,000 USDC
        uint256 leverage = 10;        // 10x leverage
        
        usdc.approve(address(perpetuals), collateral);
        
        perpetuals.openPosition(
            address(wbtc),
            AndePerpetuals.PositionSide.LONG,
            collateral,
            leverage,
            0, // No take profit
            0  // No stop loss
        );
        
        console.log("Alice opened LONG position");
        console.log("Collateral: $1,000");
        console.log("Leverage: 10x");
        console.log("Position size: $10,000");
        console.log("Entry price: $50,000");
        
        // Check position
        AndePerpetuals.Position memory position = perpetuals.getPosition(alice, address(wbtc));
        
        assertTrue(position.isOpen);
        assertEq(uint(position.side), uint(AndePerpetuals.PositionSide.LONG));
        assertEq(position.size, 10000e6); // $10,000
        assertEq(position.leverage, 10);
        assertEq(position.entryPrice, BTC_PRICE);
        
        vm.stopPrank();
    }
    
    function testOpenShortPosition() public {
        vm.startPrank(alice);
        
        uint256 collateral = 2000e6;
        uint256 leverage = 5;
        
        usdc.approve(address(perpetuals), collateral);
        
        perpetuals.openPosition(
            address(weth),
            AndePerpetuals.PositionSide.SHORT,
            collateral,
            leverage,
            0,
            0
        );
        
        AndePerpetuals.Position memory position = perpetuals.getPosition(alice, address(weth));
        
        assertTrue(position.isOpen);
        assertEq(uint(position.side), uint(AndePerpetuals.PositionSide.SHORT));
        assertEq(position.size, 10000e6); // $10,000 (2000 * 5)
        
        vm.stopPrank();
    }
    
    function testCannotOpenWithInvalidLeverage() public {
        vm.startPrank(alice);
        usdc.approve(address(perpetuals), 1000e6);
        
        // Too low (< 2x)
        vm.expectRevert(AndePerpetuals.InvalidLeverage.selector);
        perpetuals.openPosition(
            address(wbtc),
            AndePerpetuals.PositionSide.LONG,
            1000e6,
            1, // Invalid
            0,
            0
        );
        
        // Too high (> 50x)
        vm.expectRevert(AndePerpetuals.InvalidLeverage.selector);
        perpetuals.openPosition(
            address(wbtc),
            AndePerpetuals.PositionSide.LONG,
            1000e6,
            51, // Invalid
            0,
            0
        );
        
        vm.stopPrank();
    }
    
    function testCannotOpenTwoPositionsInSameMarket() public {
        vm.startPrank(alice);
        usdc.approve(address(perpetuals), 2000e6);
        
        // Open first position
        perpetuals.openPosition(
            address(wbtc),
            AndePerpetuals.PositionSide.LONG,
            1000e6,
            10,
            0,
            0
        );
        
        // Try to open second (should fail)
        vm.expectRevert(AndePerpetuals.PositionAlreadyOpen.selector);
        perpetuals.openPosition(
            address(wbtc),
            AndePerpetuals.PositionSide.SHORT,
            1000e6,
            10,
            0,
            0
        );
        
        vm.stopPrank();
    }
    
    // ========================================
    // CLOSE POSITION TESTS
    // ========================================
    
    function testCloseProfitablePosition() public {
        console.log("\n=== TEST CLOSE PROFITABLE POSITION ===");
        
        vm.startPrank(alice);
        
        // Open long position
        uint256 collateral = 1000e6;
        usdc.approve(address(perpetuals), collateral);
        
        perpetuals.openPosition(
            address(wbtc),
            AndePerpetuals.PositionSide.LONG,
            collateral,
            10,
            0,
            0
        );
        
        console.log("Opened LONG at $50,000");
        
        vm.stopPrank();
        
        // Price goes up 10%
        vm.prank(owner);
        oracle.setPrice(address(wbtc), 55000e18); // $55,000
        console.log("BTC price moved to $55,000 (+10%)");
        
        // Check PnL
        (int256 pnl,) = perpetuals.getPositionPnL(alice, address(wbtc));
        console.log("Current PnL:", uint256(pnl));
        console.log("Expected: ~$1,000 (10% of $10,000 position)");
        
        // Close position
        uint256 balanceBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        perpetuals.closePosition(address(wbtc));
        uint256 balanceAfter = usdc.balanceOf(alice);
        
        console.log("Position closed");
        console.log("Profit withdrawn:", balanceAfter - balanceBefore);
        
        // Should have profit (minus fees)
        assertTrue(balanceAfter > balanceBefore);
    }
    
    function testCloseLossPosition() public {
        vm.startPrank(alice);
        
        // Open long position
        usdc.approve(address(perpetuals), 1000e6);
        perpetuals.openPosition(
            address(wbtc),
            AndePerpetuals.PositionSide.LONG,
            1000e6,
            10,
            0,
            0
        );
        
        vm.stopPrank();
        
        // Price goes down 5%
        vm.prank(owner);
        oracle.setPrice(address(wbtc), 47500e18); // $47,500
        
        // Check PnL (should be negative)
        (int256 pnl,) = perpetuals.getPositionPnL(alice, address(wbtc));
        assertTrue(pnl < 0);
        
        // Close position
        vm.prank(alice);
        perpetuals.closePosition(address(wbtc));
        
        // Position should be closed
        AndePerpetuals.Position memory position = perpetuals.getPosition(alice, address(wbtc));
        assertFalse(position.isOpen);
    }
    
    // ========================================
    // PNL CALCULATION TESTS
    // ========================================
    
    function testPnLCalculationLong() public {
        vm.startPrank(alice);
        
        usdc.approve(address(perpetuals), 1000e6);
        perpetuals.openPosition(
            address(wbtc),
            AndePerpetuals.PositionSide.LONG,
            1000e6,
            10, // 10x = $10,000 position
            0,
            0
        );
        
        vm.stopPrank();
        
        // Price +20%
        vm.prank(owner);
        oracle.setPrice(address(wbtc), 60000e18);
        
        (int256 pnl,) = perpetuals.getPositionPnL(alice, address(wbtc));
        
        // Expected: 20% of $10,000 = $2,000
        assertEq(pnl, 2000e6);
    }
    
    function testPnLCalculationShort() public {
        vm.startPrank(alice);
        
        usdc.approve(address(perpetuals), 1000e6);
        perpetuals.openPosition(
            address(wbtc),
            AndePerpetuals.PositionSide.SHORT,
            1000e6,
            10,
            0,
            0
        );
        
        vm.stopPrank();
        
        // Price -10% (good for shorts)
        vm.prank(owner);
        oracle.setPrice(address(wbtc), 45000e18);
        
        (int256 pnl,) = perpetuals.getPositionPnL(alice, address(wbtc));
        
        // Expected: 10% of $10,000 = $1,000
        assertEq(pnl, 1000e6);
    }
    
    // ========================================
    // LIQUIDATION TESTS
    // ========================================
    
    function testLiquidation() public {
        console.log("\n=== TEST LIQUIDATION ===");
        
        vm.startPrank(alice);
        
        // Open highly leveraged long
        usdc.approve(address(perpetuals), 1000e6);
        perpetuals.openPosition(
            address(wbtc),
            AndePerpetuals.PositionSide.LONG,
            1000e6,
            20, // 20x leverage = $20,000 position
            0,
            0
        );
        
        console.log("Alice opened 20x LONG");
        console.log("Entry: $50,000");
        
        vm.stopPrank();
        
        // Price drops 6% (enough to liquidate)
        vm.prank(owner);
        oracle.setPrice(address(wbtc), 47000e18);
        console.log("Price dropped to $47,000 (-6%)");
        
        // Bob liquidates
        uint256 balanceBefore = usdc.balanceOf(bob);
        vm.prank(bob);
        perpetuals.liquidate(alice, address(wbtc));
        uint256 balanceAfter = usdc.balanceOf(bob);
        
        console.log("Bob liquidated Alice's position");
        console.log("Bob earned:", balanceAfter - balanceBefore);
        
        // Bob should earn liquidation fee
        assertTrue(balanceAfter > balanceBefore);
        
        // Alice's position should be closed
        AndePerpetuals.Position memory position = perpetuals.getPosition(alice, address(wbtc));
        assertFalse(position.isOpen);
    }
    
    // ========================================
    // FUNDING RATE TESTS
    // ========================================
    
    function testFundingRateUpdate() public {
        // Open more longs than shorts
        vm.startPrank(alice);
        usdc.approve(address(perpetuals), 5000e6);
        perpetuals.openPosition(
            address(wbtc),
            AndePerpetuals.PositionSide.LONG,
            5000e6,
            10,
            0,
            0
        );
        vm.stopPrank();
        
        vm.startPrank(bob);
        usdc.approve(address(perpetuals), 1000e6);
        perpetuals.openPosition(
            address(wbtc),
            AndePerpetuals.PositionSide.SHORT,
            1000e6,
            10,
            0,
            0
        );
        vm.stopPrank();
        
        // Move time forward 1 hour
        vm.warp(block.timestamp + 1 hours);
        
        // Trigger funding update by calling getPositionPnL (which calls _updateFundingRate internally)
        // Or close one of the positions to trigger update
        vm.startPrank(bob);
        perpetuals.closePosition(address(wbtc));
        vm.stopPrank();
        
        // Check that funding was updated
        (, , , , uint256 fundingRate, , ,) = perpetuals.markets(address(wbtc));
        console.log("Funding rate:", fundingRate);
        
        // Since more longs, funding should be positive
        assertTrue(fundingRate > 0);
    }
    
    // ========================================
    // VIEW FUNCTION TESTS
    // ========================================
    
    function testGetLiquidationPrice() public {
        vm.startPrank(alice);
        
        usdc.approve(address(perpetuals), 1000e6);
        perpetuals.openPosition(
            address(wbtc),
            AndePerpetuals.PositionSide.LONG,
            1000e6,
            10,
            0,
            0
        );
        
        uint256 liquidationPrice = perpetuals.getLiquidationPrice(alice, address(wbtc));
        
        console.log("Entry price:", BTC_PRICE);
        console.log("Liquidation price:", liquidationPrice);
        
        // Liquidation price should be below entry for longs
        assertTrue(liquidationPrice < BTC_PRICE);
        
        vm.stopPrank();
    }
}
