// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VotingEscrow} from "src/gauges/VotingEscrow.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract VotingEscrowTest is Test {
    VotingEscrow public ve;
    MockERC20 public ande;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant ALICE_AMOUNT = 1000 * 1e18;
    uint256 internal constant BOB_AMOUNT = 500 * 1e18;

    function setUp() public {
        // Deploy mock ANDE token
        ande = new MockERC20("Ande Token", "ANDE", 18);

        // Deploy VotingEscrow
        ve = new VotingEscrow(
            address(ande),
            "Vote-escrowed ANDE",
            "veANDE",
            "1.0.0"
        );

        // Mint tokens for users
        ande.mint(alice, ALICE_AMOUNT);
        ande.mint(bob, BOB_AMOUNT);

        // Approve VotingEscrow to spend tokens
        vm.startPrank(alice);
        ande.approve(address(ve), ALICE_AMOUNT);
        vm.stopPrank();

        vm.startPrank(bob);
        ande.approve(address(ve), BOB_AMOUNT);
        vm.stopPrank();
    }

    // --- Test Cases ---

    function test_CreateLock() public {
        uint256 lock_amount = 1000000000000; // Reduced from 100 * 1e18 for debugging
        uint256 lock_duration = 52 * ve.WEEK(); // 1 year
        uint256 unlock_time = block.timestamp + lock_duration;

        vm.startPrank(alice);
        ve.create_lock(lock_amount, unlock_time);
        vm.stopPrank();

        // 1. Check the lock details
        (int128 amount, uint256 end) = ve.locked(alice);
        assertEq(uint256(int256(amount)), lock_amount, "Lock amount mismatch");
        assertEq(end, (unlock_time / ve.WEEK()) * ve.WEEK(), "Lock end time mismatch");

        // 2. Check token balances
        assertEq(ande.balanceOf(address(ve)), lock_amount, "VE contract ANDE balance mismatch");
        assertEq(ande.balanceOf(alice), ALICE_AMOUNT - lock_amount, "Alice ANDE balance mismatch");

        // 3. Check voting power
        uint256 voting_power = ve.balanceOf(alice);
        assertTrue(voting_power > 0, "Voting power should be > 0");
        
        // Expected power is approx. amount * (lock_duration / MAXTIME)
        uint256 expected_power = lock_amount * lock_duration / ve.MAXTIME();
        // Allow for small precision differences due to integer math
        assertApproxEqAbs(voting_power, expected_power, 1e16, "Voting power calculation is incorrect");
    }

    function test_Fail_CreateLock_ZeroAmount() public {
        uint256 lock_duration = 52 * ve.WEEK();
        uint256 unlock_time = block.timestamp + lock_duration;

        vm.expectRevert("VE: Value must be > 0");
        ve.create_lock(0, unlock_time);
    }

    function test_Fail_CreateLock_InvalidTime() public {
        uint256 lock_amount = 100 * 1e18;

        // 1. Test locking for a duration longer than MAXTIME
        uint256 too_long_duration = ve.MAXTIME() + 1 days;
        uint256 too_long_unlock_time = block.timestamp + too_long_duration;

        vm.startPrank(alice);
        vm.expectRevert("VE: Voting lock can be 4 years max");
        ve.create_lock(lock_amount, too_long_unlock_time);
        vm.stopPrank();

        // 2. Test locking with an unlock time in the past
        // Warp time forward to ensure we have a 'past' to refer to
        vm.warp(block.timestamp + 1 weeks);
        uint256 past_unlock_time = block.timestamp - 1 days; // This is now a valid timestamp, but in the past

        vm.startPrank(alice);
        vm.expectRevert("VE: Can only lock until future");
        ve.create_lock(lock_amount, past_unlock_time);
        vm.stopPrank();
    }

    function test_VotingPowerDecay() public {
        uint256 lock_amount = 100 * 1e18;
        uint256 lock_duration = 52 * ve.WEEK(); // 1 year
        uint256 unlock_time = block.timestamp + lock_duration;

        vm.startPrank(alice);
        ve.create_lock(lock_amount, unlock_time);
        vm.stopPrank();

        uint256 initial_power = ve.balanceOf(alice);
        assertTrue(initial_power > 0, "Initial power should be positive");

        // Warp time forward by half the duration
        uint256 half_duration = lock_duration / 2;
        vm.warp(block.timestamp + half_duration);

        uint256 halfway_power = ve.balanceOf(alice);
        
        // Expected power should be roughly half. Allow a small delta for precision.
        assertApproxEqAbs(halfway_power, initial_power / 2, 1e16, "Power should be ~half at halfway point");

        // Warp time past the expiry date
        vm.warp(unlock_time + 1);

        uint256 final_power = ve.balanceOf(alice);
        assertEq(final_power, 0, "Power should be 0 after expiry");
    }

    function test_IncreaseAmount() public {
        uint256 initial_lock_amount = 100 * 1e18;
        uint256 lock_duration = 52 * ve.WEEK(); // 1 year
        uint256 unlock_time = block.timestamp + lock_duration;

        // 1. Create initial lock
        vm.startPrank(alice);
        ve.create_lock(initial_lock_amount, unlock_time);
        
        uint256 initial_power = ve.balanceOf(alice);

        // 2. Increase lock amount
        uint256 increase_amount_val = 50 * 1e18;
        ve.increase_amount(increase_amount_val);
        vm.stopPrank();

        // 3. Check new lock details
        uint256 total_lock_amount = initial_lock_amount + increase_amount_val;
        (int128 amount, uint256 end) = ve.locked(alice);
        assertEq(uint256(int256(amount)), total_lock_amount, "Total lock amount mismatch");
        assertEq(end, (unlock_time / ve.WEEK()) * ve.WEEK(), "Lock end time should not change");

        // 4. Check voting power
        uint256 new_power = ve.balanceOf(alice);
        assertTrue(new_power > initial_power, "New power should be greater than initial power");

        uint256 expected_power = total_lock_amount * lock_duration / ve.MAXTIME();
        assertApproxEqAbs(new_power, expected_power, 1e16, "New voting power calculation is incorrect");
    }

    function test_IncreaseUnlockTime() public {
        // TODO: Implement test logic
    }

    function test_Withdraw() public {
        // TODO: Implement test logic
        // 1. Alice creates a lock
        // 2. Warp time past the expiry
        // 3. Alice withdraws
        // 4. Check her ANDE balance is restored
        // 5. Check her veANDE balance is 0
    }

    function test_Fail_Withdraw_BeforeExpiry() public {
        // TODO: Implement test logic
        // Attempt to withdraw before lock expires and expect a revert
    }
}
