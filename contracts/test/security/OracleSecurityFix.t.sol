// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../../src/lending/AndeLend.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/mocks/MockPriceOracle.sol";

/**
 * @title OracleSecurityFix Test
 * @notice Tests oracle validation in AndeLend
 * @dev Ensures protocol requires valid oracle (no fallback)
 */
contract OracleSecurityFixTest is Test {
    AndeLend lending;
    MockERC20 usdc;
    MockERC20 weth;
    MockPriceOracle oracle;
    
    address alice = address(0x1);
    address bob = address(0x2);
    
    function setUp() public {
        oracle = new MockPriceOracle();
        lending = new AndeLend(address(oracle));
        
        usdc = new MockERC20("USDC", "USDC", 6);
        weth = new MockERC20("WETH", "WETH", 18);
        
        // Set oracle prices
        oracle.setPrice(address(usdc), 1e18); // $1
        oracle.setPrice(address(weth), 2000e18); // $2000
        
        // Create markets
        address aUSDC = address(new MockERC20("aUSDC", "aUSDC", 6));
        address aWETH = address(new MockERC20("aWETH", "aWETH", 18));
        
        lending.createMarket(address(usdc), aUSDC, 7500); // 75% LTV
        lending.createMarket(address(weth), aWETH, 7500);
        
        // Mint tokens
        usdc.mint(alice, 10000e6);
        weth.mint(bob, 10 ether);
    }
    
    function testOracle_RequiresValidOracle() public {
        // Deploy lending WITHOUT oracle
        AndeLend lendingNoOracle = new AndeLend(address(0));
        
        // Create market
        address aUSDC = address(new MockERC20("aUSDC", "aUSDC", 6));
        lendingNoOracle.createMarket(address(usdc), aUSDC, 7500);
        
        // Try to deposit (should revert without oracle)
        vm.startPrank(alice);
        usdc.approve(address(lendingNoOracle), 1000e6);
        
        // This should revert with InvalidMarket (no fallback pricing)
        vm.expectRevert(AndeLend.InvalidMarket.selector);
        lendingNoOracle.deposit(address(usdc), 1000e6, true);
        
        vm.stopPrank();
    }
    
    function testOracle_RejectsZeroPrice() public {
        // Set zero price
        oracle.setPrice(address(usdc), 0);
        
        vm.startPrank(alice);
        usdc.approve(address(lending), 1000e6);
        
        // Should revert with InvalidMarket (zero price not allowed)
        vm.expectRevert(AndeLend.InvalidMarket.selector);
        lending.deposit(address(usdc), 1000e6, true);
        
        vm.stopPrank();
    }
    
    function testOracle_WorksWithValidPrice() public {
        // Should work with valid oracle and price
        vm.startPrank(alice);
        usdc.approve(address(lending), 1000e6);
        
        // This should succeed
        lending.deposit(address(usdc), 1000e6, true);
        
        vm.stopPrank();
        
        // Verify deposit worked
        uint256 collateralValue = lending.getUserCollateralValue(alice);
        assertGt(collateralValue, 0, "Collateral should be recorded");
    }
    
    function testOracle_BorrowRequiresValidPrice() public {
        // Deposit collateral
        vm.startPrank(alice);
        usdc.approve(address(lending), 10000e6);
        lending.deposit(address(usdc), 10000e6, true);
        vm.stopPrank();
        
        // Set oracle price to zero
        oracle.setPrice(address(weth), 0);
        
        // Supply WETH for borrowing
        vm.startPrank(bob);
        weth.approve(address(lending), 10 ether);
        lending.deposit(address(weth), 10 ether, false);
        vm.stopPrank();
        
        // Try to borrow with zero price
        vm.startPrank(alice);
        
        // Should revert (can't borrow asset with zero price)
        vm.expectRevert();
        lending.borrow(address(weth), 1 ether);
        
        vm.stopPrank();
    }
    
    function testOracle_LiquidationRequiresValidPrice() public {
        // Setup: Alice deposits USDC, borrows WETH
        vm.startPrank(alice);
        usdc.approve(address(lending), 10000e6);
        lending.deposit(address(usdc), 10000e6, true);
        vm.stopPrank();
        
        vm.startPrank(bob);
        weth.approve(address(lending), 10 ether);
        lending.deposit(address(weth), 10 ether, false);
        vm.stopPrank();
        
        vm.startPrank(alice);
        lending.borrow(address(weth), 2 ether);
        vm.stopPrank();
        
        // Crash USDC price to make Alice liquidatable
        oracle.setPrice(address(usdc), 0.1e18); // $0.10
        
        // Set WETH price to zero to test rejection
        oracle.setPrice(address(weth), 0);
        
        // Liquidation should fail (can't liquidate with zero price)
        vm.startPrank(bob);
        weth.approve(address(lending), 2 ether);
        
        vm.expectRevert();
        lending.liquidate(alice, address(weth), address(usdc), 1 ether);
        
        vm.stopPrank();
    }
}
