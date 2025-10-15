// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AndeLend} from "../../src/lending/AndeLend.sol";
import {AToken} from "../../src/lending/AToken.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockOracle} from "../mocks/MockOracle.sol";

contract AndeLendTest is Test {
    AndeLend public lendingPool;
    AToken public aUSDC;
    AToken public aANDE;
    ERC20Mock public usdc;
    ERC20Mock public ande;
    ERC20Mock public weth;
    MockOracle public oracle;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public liquidator = address(0x4);
    
    uint256 constant INITIAL_BALANCE = 100000e18; // 100k tokens (18 decimals for simplicity)
    uint256 constant INITIAL_ANDE = 100000e18;   // 100k ANDE
    
    event MarketCreated(address indexed token, address indexed aToken, uint256 collateralFactor);
    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 aTokens);
    event Withdraw(address indexed user, address indexed token, uint256 amount, uint256 aTokens);
    event Borrow(address indexed user, address indexed token, uint256 amount);
    event Repay(address indexed user, address indexed token, uint256 amount);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy tokens
        usdc = new ERC20Mock("USD Coin", "USDC");
        ande = new ERC20Mock("ANDE Token", "ANDE");
        weth = new ERC20Mock("Wrapped ETH", "WETH");
        
        // Deploy oracle
        oracle = new MockOracle();
        
        // Set prices (all 1:1 USD for simplicity)
        oracle.setPrice(address(usdc), 1e18); // $1
        oracle.setPrice(address(ande), 1e18); // $1
        oracle.setPrice(address(weth), 1e18); // $1 (normally ~$2000)
        
        // Deploy lending pool
        lendingPool = new AndeLend(address(oracle));
        
        // Deploy aTokens
        aUSDC = new AToken("Ande USDC", "aUSDC", address(usdc), address(lendingPool));
        aANDE = new AToken("Ande ANDE", "aANDE", address(ande), address(lendingPool));
        
        // Create markets
        lendingPool.createMarket(address(usdc), address(aUSDC), 7500); // 75% LTV
        lendingPool.createMarket(address(ande), address(aANDE), 5000); // 50% LTV
        
        // Mint tokens to users
        usdc.mint(alice, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
        ande.mint(alice, INITIAL_ANDE);
        ande.mint(bob, INITIAL_ANDE);
        
        vm.stopPrank();
    }
    
    // ========================================
    // MARKET CREATION TESTS
    // ========================================
    
    function testCreateMarket() public {
        vm.prank(owner);
        
        AToken aWETH = new AToken("Ande WETH", "aWETH", address(weth), address(lendingPool));
        
        vm.expectEmit(true, true, false, true);
        emit MarketCreated(address(weth), address(aWETH), 6000);
        
        vm.prank(owner);
        lendingPool.createMarket(address(weth), address(aWETH), 6000);
        
        (bool isActive, address aToken, , , , , uint256 collateralFactor, , ) = lendingPool.markets(address(weth));
        
        assertTrue(isActive);
        assertEq(aToken, address(aWETH));
        assertEq(collateralFactor, 6000);
    }
    
    function testCannotCreateMarketTwice() public {
        vm.startPrank(owner);
        
        AToken aWETH = new AToken("Ande WETH", "aWETH", address(weth), address(lendingPool));
        lendingPool.createMarket(address(weth), address(aWETH), 6000);
        
        vm.expectRevert(AndeLend.MarketAlreadyExists.selector);
        lendingPool.createMarket(address(weth), address(aWETH), 6000);
        
        vm.stopPrank();
    }
    
    function testOnlyOwnerCanCreateMarket() public {
        AToken aWETH = new AToken("Ande WETH", "aWETH", address(weth), address(lendingPool));
        
        vm.prank(alice);
        vm.expectRevert();
        lendingPool.createMarket(address(weth), address(aWETH), 6000);
    }
    
    // ========================================
    // DEPOSIT TESTS
    // ========================================
    
    function testDeposit() public {
        vm.startPrank(alice);
        
        uint256 depositAmount = 1000e18; // Changed to 18 decimals
        usdc.approve(address(lendingPool), depositAmount);
        
        vm.expectEmit(true, true, false, true);
        emit Deposit(alice, address(usdc), depositAmount, depositAmount);
        
        lendingPool.deposit(address(usdc), depositAmount, true);
        
        // Check user data
        (uint256 principal, , , bool useAsCollateral) = lendingPool.userMarkets(alice, address(usdc));
        assertEq(principal, depositAmount);
        assertTrue(useAsCollateral);
        
        // Check market data
        (, , uint256 totalSupply, , , , , , ) = lendingPool.markets(address(usdc));
        assertEq(totalSupply, depositAmount);
        
        vm.stopPrank();
    }
    
    function testDepositWithoutCollateral() public {
        vm.startPrank(alice);
        
        uint256 depositAmount = 1000e6;
        usdc.approve(address(lendingPool), depositAmount);
        
        lendingPool.deposit(address(usdc), depositAmount, false);
        
        (, , , bool useAsCollateral) = lendingPool.userMarkets(alice, address(usdc));
        assertFalse(useAsCollateral);
        
        vm.stopPrank();
    }
    
    function testCannotDepositZero() public {
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), 1000e6);
        
        vm.expectRevert(AndeLend.InvalidAmount.selector);
        lendingPool.deposit(address(usdc), 0, true);
        
        vm.stopPrank();
    }
    
    function testCannotDepositToInactiveMarket() public {
        vm.startPrank(alice);
        weth.mint(alice, 10e18);
        weth.approve(address(lendingPool), 10e18);
        
        vm.expectRevert(AndeLend.MarketNotActive.selector);
        lendingPool.deposit(address(weth), 10e18, true);
        
        vm.stopPrank();
    }
    
    function testMultipleDeposits() public {
        vm.startPrank(alice);
        
        usdc.approve(address(lendingPool), 3000e6);
        
        lendingPool.deposit(address(usdc), 1000e6, true);
        lendingPool.deposit(address(usdc), 2000e6, true);
        
        (uint256 principal, , , ) = lendingPool.userMarkets(alice, address(usdc));
        assertEq(principal, 3000e6);
        
        vm.stopPrank();
    }
    
    // ========================================
    // WITHDRAW TESTS
    // ========================================
    
    function testWithdraw() public {
        vm.startPrank(alice);
        
        // Deposit first
        uint256 depositAmount = 1000e6;
        usdc.approve(address(lendingPool), depositAmount);
        lendingPool.deposit(address(usdc), depositAmount, false); // Not as collateral
        
        uint256 balanceBefore = usdc.balanceOf(alice);
        
        vm.expectEmit(true, true, false, true);
        emit Withdraw(alice, address(usdc), depositAmount, depositAmount);
        
        lendingPool.withdraw(address(usdc), depositAmount);
        
        uint256 balanceAfter = usdc.balanceOf(alice);
        assertEq(balanceAfter - balanceBefore, depositAmount);
        
        (uint256 principal, , , ) = lendingPool.userMarkets(alice, address(usdc));
        assertEq(principal, 0);
        
        vm.stopPrank();
    }
    
    function testWithdrawAll() public {
        vm.startPrank(alice);
        
        uint256 depositAmount = 1000e6;
        usdc.approve(address(lendingPool), depositAmount);
        lendingPool.deposit(address(usdc), depositAmount, false);
        
        // Withdraw all (amount = 0)
        lendingPool.withdraw(address(usdc), 0);
        
        (uint256 principal, , , ) = lendingPool.userMarkets(alice, address(usdc));
        assertEq(principal, 0);
        
        vm.stopPrank();
    }
    
    function testCannotWithdrawMoreThanDeposited() public {
        vm.startPrank(alice);
        
        usdc.approve(address(lendingPool), 1000e6);
        lendingPool.deposit(address(usdc), 1000e6, false);
        
        vm.expectRevert(AndeLend.InvalidAmount.selector);
        lendingPool.withdraw(address(usdc), 2000e6);
        
        vm.stopPrank();
    }
    
    function testCannotWithdrawIfInsufficientLiquidity() public {
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), 2000e6);
        lendingPool.deposit(address(usdc), 2000e6, true);
        vm.stopPrank();
        
        // Bob borrows most of the liquidity
        vm.startPrank(bob);
        ande.approve(address(lendingPool), 10000e18);
        lendingPool.deposit(address(ande), 10000e18, true);
        lendingPool.borrow(address(usdc), 1500e6);
        vm.stopPrank();
        
        // Alice tries to withdraw more than available
        vm.startPrank(alice);
        vm.expectRevert(AndeLend.InsufficientLiquidity.selector);
        lendingPool.withdraw(address(usdc), 2000e6);
        vm.stopPrank();
    }
    
    // ========================================
    // BORROW TESTS
    // ========================================
    
    function testBorrow() public {
        // Alice deposits USDC as collateral
        vm.startPrank(alice);
        uint256 collateralAmount = 1000e18;
        usdc.approve(address(lendingPool), collateralAmount);
        lendingPool.deposit(address(usdc), collateralAmount, true);
        vm.stopPrank();
        
        // Bob deposits ANDE to provide liquidity
        vm.startPrank(bob);
        uint256 liquidityAmount = 10000e18;
        ande.approve(address(lendingPool), liquidityAmount);
        lendingPool.deposit(address(ande), liquidityAmount, false);
        vm.stopPrank();
        
        // Alice borrows ANDE
        vm.startPrank(alice);
        uint256 borrowAmount = 100e18;
        uint256 balanceBefore = ande.balanceOf(alice);
        
        vm.expectEmit(true, true, false, true);
        emit Borrow(alice, address(ande), borrowAmount);
        
        lendingPool.borrow(address(ande), borrowAmount);
        
        uint256 balanceAfter = ande.balanceOf(alice);
        assertEq(balanceAfter - balanceBefore, borrowAmount);
        
        (, uint256 borrowBalance, , ) = lendingPool.userMarkets(alice, address(ande));
        assertEq(borrowBalance, borrowAmount);
        
        vm.stopPrank();
    }
    
    function testCannotBorrowZero() public {
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), 1000e6);
        lendingPool.deposit(address(usdc), 1000e6, true);
        
        vm.expectRevert(AndeLend.InvalidAmount.selector);
        lendingPool.borrow(address(ande), 0);
        
        vm.stopPrank();
    }
    
    function testCannotBorrowWithoutCollateral() public {
        // Bob provides liquidity
        vm.startPrank(bob);
        ande.approve(address(lendingPool), 10000e18);
        lendingPool.deposit(address(ande), 10000e18, false);
        vm.stopPrank();
        
        // Alice tries to borrow without collateral
        vm.startPrank(alice);
        vm.expectRevert(AndeLend.InsufficientCollateral.selector);
        lendingPool.borrow(address(ande), 100e18);
        vm.stopPrank();
    }
    
    function testCannotBorrowMoreThanAvailable() public {
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), 1000e6);
        lendingPool.deposit(address(usdc), 1000e6, true);
        vm.stopPrank();
        
        // Bob provides small liquidity
        vm.startPrank(bob);
        ande.approve(address(lendingPool), 100e18);
        lendingPool.deposit(address(ande), 100e18, false);
        vm.stopPrank();
        
        // Alice tries to borrow more than available
        vm.startPrank(alice);
        vm.expectRevert(AndeLend.InsufficientLiquidity.selector);
        lendingPool.borrow(address(ande), 200e18);
        vm.stopPrank();
    }
    
    // ========================================
    // REPAY TESTS
    // ========================================
    
    function testRepay() public {
        // Setup: Alice deposits and borrows
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), 1000e18);
        lendingPool.deposit(address(usdc), 1000e18, true);
        vm.stopPrank();
        
        vm.startPrank(bob);
        ande.approve(address(lendingPool), 10000e18);
        lendingPool.deposit(address(ande), 10000e18, false);
        vm.stopPrank();
        
        vm.startPrank(alice);
        uint256 borrowAmount = 100e18;
        lendingPool.borrow(address(ande), borrowAmount);
        
        // Repay
        ande.approve(address(lendingPool), borrowAmount);
        
        vm.expectEmit(true, true, false, true);
        emit Repay(alice, address(ande), borrowAmount);
        
        lendingPool.repay(address(ande), borrowAmount);
        
        (, uint256 borrowBalance, , ) = lendingPool.userMarkets(alice, address(ande));
        assertEq(borrowBalance, 0);
        
        vm.stopPrank();
    }
    
    function testRepayAll() public {
        // Setup
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), 1000e18);
        lendingPool.deposit(address(usdc), 1000e18, true);
        vm.stopPrank();
        
        vm.startPrank(bob);
        ande.approve(address(lendingPool), 10000e18);
        lendingPool.deposit(address(ande), 10000e18, false);
        vm.stopPrank();
        
        vm.startPrank(alice);
        lendingPool.borrow(address(ande), 100e18);
        
        // Repay all (amount = 0)
        ande.approve(address(lendingPool), type(uint256).max);
        lendingPool.repay(address(ande), 0);
        
        (, uint256 borrowBalance, , ) = lendingPool.userMarkets(alice, address(ande));
        assertEq(borrowBalance, 0);
        
        vm.stopPrank();
    }
    
    // ========================================
    // HEALTH FACTOR TESTS
    // ========================================
    
    function testHealthFactorHealthy() public {
        vm.startPrank(alice);
        
        // Deposit 1000 USDC (75% LTV = 750 borrowing power)
        usdc.approve(address(lendingPool), 1000e18);
        lendingPool.deposit(address(usdc), 1000e18, true);
        
        vm.stopPrank();
        
        vm.startPrank(bob);
        ande.approve(address(lendingPool), 10000e18);
        lendingPool.deposit(address(ande), 10000e18, false);
        vm.stopPrank();
        
        // Alice borrows 50 ANDE (well below limit)
        vm.startPrank(alice);
        lendingPool.borrow(address(ande), 50e18);
        
        uint256 healthFactor = lendingPool.getHealthFactor(alice);
        assertTrue(healthFactor >= 1e18); // Should be > 1.0
        
        vm.stopPrank();
    }
    
    function testHealthFactorMax() public {
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), 1000e6);
        lendingPool.deposit(address(usdc), 1000e6, true);
        
        // No borrows = infinite health factor
        uint256 healthFactor = lendingPool.getHealthFactor(alice);
        assertEq(healthFactor, type(uint256).max);
        
        vm.stopPrank();
    }
    
    // ========================================
    // VIEW FUNCTION TESTS
    // ========================================
    
    function testGetUserCollateralValue() public {
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), 1000e6);
        lendingPool.deposit(address(usdc), 1000e6, true);
        
        uint256 collateralValue = lendingPool.getUserCollateralValue(alice);
        assertTrue(collateralValue > 0);
        
        vm.stopPrank();
    }
    
    function testGetUserBorrowValue() public {
        // Setup
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), 1000e18);
        lendingPool.deposit(address(usdc), 1000e18, true);
        vm.stopPrank();
        
        vm.startPrank(bob);
        ande.approve(address(lendingPool), 10000e18);
        lendingPool.deposit(address(ande), 10000e18, false);
        vm.stopPrank();
        
        vm.startPrank(alice);
        lendingPool.borrow(address(ande), 100e18);
        
        uint256 borrowValue = lendingPool.getUserBorrowValue(alice);
        assertTrue(borrowValue > 0);
        
        vm.stopPrank();
    }
    
    function testGetBorrowAPR() public {
        uint256 borrowAPR = lendingPool.getBorrowAPR(address(usdc));
        assertEq(borrowAPR, 200); // Base rate: 2%
    }
    
    function testGetSupplyAPR() public {
        uint256 supplyAPR = lendingPool.getSupplyAPR(address(usdc));
        assertEq(supplyAPR, 0); // No borrows yet
    }
    
    // ========================================
    // INTEGRATION TESTS
    // ========================================
    
    function testFullCycle() public {
        // 1. Alice deposits USDC
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), 1000e18);
        lendingPool.deposit(address(usdc), 1000e18, true);
        vm.stopPrank();
        
        // 2. Bob deposits ANDE (liquidity)
        vm.startPrank(bob);
        ande.approve(address(lendingPool), 10000e18);
        lendingPool.deposit(address(ande), 10000e18, false);
        vm.stopPrank();
        
        // 3. Alice borrows ANDE
        vm.startPrank(alice);
        lendingPool.borrow(address(ande), 100e18);
        
        // 4. Check health factor
        uint256 hf1 = lendingPool.getHealthFactor(alice);
        assertTrue(hf1 >= 1e18);
        
        // 5. Alice repays
        ande.approve(address(lendingPool), 100e18);
        lendingPool.repay(address(ande), 100e18);
        
        // 6. Alice withdraws
        lendingPool.withdraw(address(usdc), 1000e18);
        
        // 7. Check final state
        (uint256 principal, uint256 borrowBalance, , ) = lendingPool.userMarkets(alice, address(usdc));
        assertEq(principal, 0);
        assertEq(borrowBalance, 0);
        
        vm.stopPrank();
    }
}
