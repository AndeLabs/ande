// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {LiquidityGaugeV1} from "src/gauges/LiquidityGaugeV1.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract LiquidityGaugeV1Test is Test {
    LiquidityGaugeV1 public gauge;
    MockERC20 public lpToken;
    MockERC20 public ande;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal minter = makeAddr("minter");

    function setUp() public {
        // Deploy mock tokens
        lpToken = new MockERC20("LP Token", "LP", 18);
        ande = new MockERC20("Ande Token", "ANDE", 18);

        // Deploy Gauge, now with reward token in constructor
        gauge = new LiquidityGaugeV1(address(lpToken), minter, address(ande));

        // Mint LP tokens to users
        lpToken.mint(alice, 1000 * 1e18);
        lpToken.mint(bob, 1000 * 1e18);

        // Approve Gauge to spend LP tokens
        vm.startPrank(alice);
        lpToken.approve(address(gauge), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        lpToken.approve(address(gauge), type(uint256).max);
        vm.stopPrank();
    }

    // --- Test Cases ---

    function test_DepositWithdraw() public {
        uint256 deposit_amount = 100 * 1e18;
        uint256 initial_alice_balance = lpToken.balanceOf(alice);

        // 1. Alice deposits
        vm.startPrank(alice);
        gauge.deposit(deposit_amount);
        vm.stopPrank();

        // 2. Check balances after deposit
        assertEq(
            lpToken.balanceOf(alice), initial_alice_balance - deposit_amount, "Alice LP balance incorrect after deposit"
        );
        assertEq(lpToken.balanceOf(address(gauge)), deposit_amount, "Gauge LP balance incorrect after deposit");
        assertEq(gauge.balanceOf(alice), deposit_amount, "Alice gauge share balance incorrect after deposit");

        // 3. Alice withdraws
        vm.startPrank(alice);
        gauge.withdraw(deposit_amount);
        vm.stopPrank();

        // 4. Check balances after withdrawal
        assertEq(lpToken.balanceOf(alice), initial_alice_balance, "Alice LP balance not restored");
        assertEq(lpToken.balanceOf(address(gauge)), 0, "Gauge LP balance should be 0");
        assertEq(gauge.balanceOf(alice), 0, "Alice gauge share balance should be 0");
    }

    function test_EarnedRewards() public {
        uint256 reward_amount = 1000 * 1e18;
        uint256 deposit_amount = 100 * 1e18;

        // 1. Minter sends rewards to the gauge contract and notifies it
        ande.mint(minter, reward_amount);
        vm.startPrank(minter);
        ande.transfer(address(gauge), reward_amount);
        gauge.notifyRewardAmount(reward_amount);
        vm.stopPrank();

        // 2. Alice deposits LP tokens
        vm.startPrank(alice);
        gauge.deposit(deposit_amount);
        vm.stopPrank();

        // 3. Warp time forward by exactly one week from the last update
        uint256 last_update = gauge.last_update_time();
        vm.warp(last_update + 7 days);

        uint256 earned = gauge.earned(alice);

        // Since she is the only depositor, she should get all the rewards.
        // Allow a small delta for single-second timestamp variations.
        assertApproxEqAbs(earned, reward_amount, 1e18, "Earned amount is incorrect");
    }

    function test_ClaimRewards() public {
        uint256 reward_amount = 1000 * 1e18;
        uint256 deposit_amount = 100 * 1e18;

        // 1. Minter notifies reward amount
        ande.mint(minter, reward_amount);
        vm.startPrank(minter);
        ande.transfer(address(gauge), reward_amount);
        gauge.notifyRewardAmount(reward_amount);
        vm.stopPrank();

        // 2. Alice deposits
        vm.startPrank(alice);
        gauge.deposit(deposit_amount);
        vm.stopPrank();

        // 3. Warp time forward
        uint256 last_update = gauge.last_update_time();
        vm.warp(last_update + 7 days);

        uint256 earned = gauge.earned(alice);
        assertTrue(earned > 0, "Should have earned rewards before claiming");

        uint256 initial_ande_balance = ande.balanceOf(alice);

        // 4. Alice claims rewards
        vm.startPrank(alice);
        gauge.claim_rewards();
        vm.stopPrank();

        // 5. Check balances
        uint256 final_ande_balance = ande.balanceOf(alice);
        assertApproxEqAbs(
            final_ande_balance, initial_ande_balance + earned, 1, "Alice did not receive correct reward amount"
        );

        uint256 remaining_earned = gauge.earned(alice);
        assertEq(remaining_earned, 0, "Earned amount should be 0 after claiming");
    }
}
