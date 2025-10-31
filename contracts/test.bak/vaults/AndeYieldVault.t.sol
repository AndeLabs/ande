// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AndeYieldVault} from "../../src/vaults/yield/AndeYieldVault.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AndeYieldVaultTest is Test {
    AndeYieldVault public vault;
    ERC20Mock public lpToken;
    ERC20Mock public rewardToken;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public treasury = address(0x4);
    address public router = address(0x5);
    address public gauge = address(0);  // No gauge for now
    
    uint256 constant INITIAL_LP = 100000e18;
    
    event Harvest(uint256 rewards, uint256 compounded, uint256 fee);
    event PerformanceFeeUpdated(uint256 newFee);
    event WithdrawalFeeUpdated(uint256 newFee);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy tokens
        lpToken = new ERC20Mock("LP Token", "LP");
        rewardToken = new ERC20Mock("ANDE Token", "ANDE");
        
        // Deploy vault
        vault = new AndeYieldVault(
            address(lpToken),
            address(rewardToken),
            router,
            gauge,
            treasury,
            "Ande LP Vault",
            "aLP"
        );
        
        // Mint LP tokens to users
        lpToken.mint(alice, INITIAL_LP);
        lpToken.mint(bob, INITIAL_LP);
        
        vm.stopPrank();
    }
    
    // ========================================
    // DEPOSIT TESTS
    // ========================================
    
    function testDeposit() public {
        vm.startPrank(alice);
        
        uint256 depositAmount = 1000e18;
        lpToken.approve(address(vault), depositAmount);
        
        uint256 shares = vault.deposit(depositAmount, alice);
        
        assertEq(shares, depositAmount); // 1:1 initially
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), depositAmount);
        
        vm.stopPrank();
    }
    
    function testDepositMultipleUsers() public {
        // Alice deposits
        vm.startPrank(alice);
        lpToken.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();
        
        // Bob deposits
        vm.startPrank(bob);
        lpToken.approve(address(vault), 2000e18);
        vault.deposit(2000e18, bob);
        vm.stopPrank();
        
        assertEq(vault.totalAssets(), 3000e18);
        assertEq(vault.balanceOf(alice), 1000e18);
        assertEq(vault.balanceOf(bob), 2000e18);
    }
    
    function testCannotDepositZero() public {
        vm.startPrank(alice);
        lpToken.approve(address(vault), 1000e18);
        
        vm.expectRevert(AndeYieldVault.ZeroAmount.selector);
        vault.deposit(0, alice);
        
        vm.stopPrank();
    }
    
    function testCannotDepositWhenPaused() public {
        vm.prank(owner);
        vault.pause();
        
        vm.startPrank(alice);
        lpToken.approve(address(vault), 1000e18);
        
        vm.expectRevert(AndeYieldVault.VaultPaused.selector);
        vault.deposit(1000e18, alice);
        
        vm.stopPrank();
    }
    
    // ========================================
    // WITHDRAW TESTS
    // ========================================
    
    function testWithdraw() public {
        // Deposit first
        vm.startPrank(alice);
        lpToken.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        
        uint256 balanceBefore = lpToken.balanceOf(alice);
        
        // Withdraw (with fee)
        uint256 shares = vault.withdraw(1000e18, alice, alice);
        
        uint256 balanceAfter = lpToken.balanceOf(alice);
        
        // Should receive slightly less due to withdrawal fee (0.1%)
        uint256 expectedAmount = 1000e18 - (1000e18 * 10) / 10000; // 0.1% fee
        assertEq(balanceAfter - balanceBefore, expectedAmount);
        
        vm.stopPrank();
    }
    
    function testCannotWithdrawZero() public {
        vm.startPrank(alice);
        lpToken.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        
        vm.expectRevert(AndeYieldVault.ZeroAmount.selector);
        vault.withdraw(0, alice, alice);
        
        vm.stopPrank();
    }
    
    function testWithdrawalFee() public {
        vm.startPrank(alice);
        lpToken.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        
        uint256 treasuryBefore = lpToken.balanceOf(treasury);
        
        vault.withdraw(1000e18, alice, alice);
        
        uint256 treasuryAfter = lpToken.balanceOf(treasury);
        uint256 feeCollected = treasuryAfter - treasuryBefore;
        
        // Fee should be 0.1% of 1000 = 1
        assertEq(feeCollected, 1e18);
        
        vm.stopPrank();
    }
    
    // ========================================
    // SHARE CALCULATION TESTS
    // ========================================
    
    function testPreviewDeposit() public {
        uint256 assets = 1000e18;
        uint256 shares = vault.previewDeposit(assets);
        
        assertEq(shares, assets); // 1:1 initially
    }
    
    function testPreviewWithdraw() public {
        vm.startPrank(alice);
        lpToken.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();
        
        uint256 shares = vault.previewWithdraw(1000e18);
        assertTrue(shares > 0);
    }
    
    function testMint() public {
        vm.startPrank(alice);
        
        uint256 shares = 1000e18;
        lpToken.approve(address(vault), shares);
        
        uint256 assets = vault.mint(shares, alice);
        
        assertEq(assets, shares); // 1:1 initially
        assertEq(vault.balanceOf(alice), shares);
        
        vm.stopPrank();
    }
    
    function testRedeem() public {
        vm.startPrank(alice);
        
        lpToken.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        
        uint256 shares = vault.balanceOf(alice);
        uint256 assets = vault.redeem(shares, alice, alice);
        
        assertTrue(assets > 0);
        assertEq(vault.balanceOf(alice), 0);
        
        vm.stopPrank();
    }
    
    // ========================================
    // ADMIN TESTS
    // ========================================
    
    function testSetPerformanceFee() public {
        vm.prank(owner);
        
        vm.expectEmit(false, false, false, true);
        emit PerformanceFeeUpdated(1500);
        
        vault.setPerformanceFee(1500); // 15%
        
        assertEq(vault.performanceFee(), 1500);
    }
    
    function testCannotSetPerformanceFeeAboveMax() public {
        vm.prank(owner);
        
        vm.expectRevert(AndeYieldVault.InvalidFee.selector);
        vault.setPerformanceFee(2500); // 25% > max 20%
    }
    
    function testOnlyOwnerCanSetPerformanceFee() public {
        vm.prank(alice);
        
        vm.expectRevert();
        vault.setPerformanceFee(1500);
    }
    
    function testSetWithdrawalFee() public {
        vm.prank(owner);
        
        vm.expectEmit(false, false, false, true);
        emit WithdrawalFeeUpdated(50);
        
        vault.setWithdrawalFee(50); // 0.5%
        
        assertEq(vault.withdrawalFee(), 50);
    }
    
    function testCannotSetWithdrawalFeeAboveMax() public {
        vm.prank(owner);
        
        vm.expectRevert(AndeYieldVault.InvalidFee.selector);
        vault.setWithdrawalFee(150); // 1.5% > max 1%
    }
    
    function testSetTreasury() public {
        address newTreasury = address(0x999);
        
        vm.prank(owner);
        vault.setTreasury(newTreasury);
        
        assertEq(vault.treasury(), newTreasury);
    }
    
    function testCannotSetZeroTreasury() public {
        vm.prank(owner);
        
        vm.expectRevert(AndeYieldVault.InvalidAddress.selector);
        vault.setTreasury(address(0));
    }
    
    function testPause() public {
        vm.prank(owner);
        vault.pause();
        
        assertTrue(vault.paused());
    }
    
    function testUnpause() public {
        vm.startPrank(owner);
        vault.pause();
        vault.unpause();
        vm.stopPrank();
        
        assertFalse(vault.paused());
    }
    
    function testOnlyOwnerCanPause() public {
        vm.prank(alice);
        
        vm.expectRevert();
        vault.pause();
    }
    
    // ========================================
    // VIEW FUNCTION TESTS
    // ========================================
    
    function testTotalAssets() public {
        vm.startPrank(alice);
        lpToken.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();
        
        assertEq(vault.totalAssets(), 1000e18);
    }
    
    function testTotalSupply() public {
        vm.startPrank(alice);
        lpToken.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();
        
        assertEq(vault.totalSupply(), 1000e18);
    }
    
    function testAsset() public {
        assertEq(vault.asset(), address(lpToken));
    }
    
    function testPendingRewards() public {
        // No gauge, so should be 0
        assertEq(vault.pendingRewards(), 0);
    }
    
    function testGetAPY() public {
        // No harvest yet, should be 0
        assertEq(vault.getAPY(), 0);
    }
    
    // ========================================
    // ERC4626 COMPLIANCE TESTS
    // ========================================
    
    function testMaxDeposit() public {
        uint256 maxDeposit = vault.maxDeposit(alice);
        assertEq(maxDeposit, type(uint256).max);
    }
    
    function testMaxMint() public {
        uint256 maxMint = vault.maxMint(alice);
        assertEq(maxMint, type(uint256).max);
    }
    
    function testMaxWithdraw() public {
        vm.startPrank(alice);
        lpToken.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        
        uint256 maxWithdraw = vault.maxWithdraw(alice);
        assertTrue(maxWithdraw > 0);
        
        vm.stopPrank();
    }
    
    function testMaxRedeem() public {
        vm.startPrank(alice);
        lpToken.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        
        uint256 maxRedeem = vault.maxRedeem(alice);
        assertEq(maxRedeem, vault.balanceOf(alice));
        
        vm.stopPrank();
    }
    
    function testConvertToShares() public {
        uint256 assets = 1000e18;
        uint256 shares = vault.convertToShares(assets);
        assertEq(shares, assets); // 1:1 initially
    }
    
    function testConvertToAssets() public {
        uint256 shares = 1000e18;
        uint256 assets = vault.convertToAssets(shares);
        assertEq(assets, shares); // 1:1 initially
    }
    
    // ========================================
    // INTEGRATION TESTS
    // ========================================
    
    function testMultipleUsersDepositWithdraw() public {
        // Alice deposits
        vm.startPrank(alice);
        lpToken.approve(address(vault), 1000e18);
        uint256 aliceShares = vault.deposit(1000e18, alice);
        vm.stopPrank();
        
        // Bob deposits
        vm.startPrank(bob);
        lpToken.approve(address(vault), 2000e18);
        uint256 bobShares = vault.deposit(2000e18, bob);
        vm.stopPrank();
        
        assertEq(vault.totalAssets(), 3000e18);
        
        // Alice withdraws
        vm.startPrank(alice);
        vault.redeem(aliceShares, alice, alice);
        vm.stopPrank();
        
        // Bob should still have shares
        assertEq(vault.balanceOf(bob), bobShares);
        assertTrue(vault.totalAssets() < 3000e18);
    }
    
    function testDepositAfterYield() public {
        // Alice deposits
        vm.startPrank(alice);
        lpToken.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();
        
        // Simulate yield by sending LP tokens directly
        lpToken.mint(address(vault), 100e18);
        
        // Bob deposits same amount but gets fewer shares
        vm.startPrank(bob);
        lpToken.approve(address(vault), 1000e18);
        uint256 bobShares = vault.deposit(1000e18, bob);
        vm.stopPrank();
        
        // Bob should get fewer shares due to appreciated value
        assertTrue(bobShares < 1000e18);
    }
    
    function testFullCycleWithFees() public {
        // 1. Deposit
        vm.startPrank(alice);
        lpToken.approve(address(vault), 1000e18);
        uint256 shares = vault.deposit(1000e18, alice);
        vm.stopPrank();
        
        // 2. Simulate some time passing and yield
        vm.warp(block.timestamp + 7 days);
        lpToken.mint(address(vault), 100e18); // 10% yield
        
        // 3. Withdraw
        vm.startPrank(alice);
        uint256 balanceBefore = lpToken.balanceOf(alice);
        vault.redeem(shares, alice, alice);
        uint256 balanceAfter = lpToken.balanceOf(alice);
        
        // Should have gained yield minus withdrawal fee
        uint256 gained = balanceAfter - balanceBefore;
        assertTrue(gained > 1000e18); // More than initial due to yield
        assertTrue(gained < 1100e18); // Less than total due to fee
        
        vm.stopPrank();
    }
}
