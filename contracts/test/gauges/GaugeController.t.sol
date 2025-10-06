// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VotingEscrow} from "src/gauges/VotingEscrow.sol";
import {GaugeController} from "src/gauges/GaugeController.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract GaugeControllerTest is Test {
    VotingEscrow public ve;
    GaugeController public gc;
    MockERC20 public ande;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal gauge1 = makeAddr("gauge1");
    address internal gauge2 = makeAddr("gauge2");

    function setUp() public {
        // Deploy mock ANDE token
        ande = new MockERC20("Ande Token", "ANDE", 18);

        // Deploy VotingEscrow
        ve = new VotingEscrow(address(ande), "veANDE", "veANDE", "1.0");

        // Deploy GaugeController
        gc = new GaugeController(address(ande), address(ve));

        // Mint tokens for users
        ande.mint(alice, 1000 * 1e18);
        ande.mint(bob, 1000 * 1e18);

        // Alice approves VE and creates a lock to get voting power
        vm.startPrank(alice);
        ande.approve(address(ve), 1000 * 1e18);
        uint256 lock_end = block.timestamp + 52 * 7 * 86400; // 1 year
        ve.create_lock(100 * 1e18, lock_end);
        vm.stopPrank();

        // Add a gauge type and gauges to the controller
        gc.add_gauge_type("Liquidity Pools");
        gc.add_gauge(gauge1, 0, 0);
        gc.add_gauge(gauge2, 0, 0);
    }

    // --- Test Cases ---

    function test_Vote() public {
        uint256 weight = 5000; // 50%

        vm.startPrank(alice);
        gc.vote(gauge1, weight);
        vm.stopPrank();

        assertEq(gc.user_vote_weight(alice, gauge1), weight, "Vote weight for gauge1 mismatch");
        assertEq(gc.user_total_weight(alice), weight, "Total user weight mismatch");
    }

    function test_Fail_Vote_NoPower() public {
        // Bob has ANDE but no veANDE (no lock)
        vm.startPrank(bob);
        vm.expectRevert("GC: You have no voting power");
        gc.vote(gauge1, 5000);
        vm.stopPrank();
    }

    function test_Fail_Vote_Over100Percent() public {
        vm.startPrank(alice);
        
        // 1. Alice votes 8000 for gauge1 (should succeed)
        gc.vote(gauge1, 8000);
        
        // 2. Alice tries to vote 3000 for gauge2 (total 11000, should fail)
        vm.expectRevert("GC: Total weight exceeds 10000");
        gc.vote(gauge2, 3000);

        vm.stopPrank();
    }

    function test_GaugeWeight_AfterVote() public {
        // 1. Alice votes for gauge1
        vm.startPrank(alice);
        gc.vote(gauge1, 10000); // 100% vote
        vm.stopPrank();

        // 2. Check that gauge_relative_weight for gauge1 is > 0
        uint256 weight = gc.gauge_relative_weight(gauge1);
        assertTrue(weight > 0, "Gauge weight should be greater than 0 after vote");
    }
}
