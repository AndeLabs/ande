// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {DualTrackBurnEngine} from "../src/DualTrackBurnEngine.sol";
import {ANDEToken} from "../src/ANDEToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract DualTrackBurnEngineTest is Test {
    DualTrackBurnEngine public burnEngine;
    ANDEToken public andeToken;

    address public owner = makeAddr("owner");
    address public burner = makeAddr("burner");
    address public otherAccount = makeAddr("otherAccount");

    bytes32 public constant ADMIN_ROLE = bytes32(0);
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    function setUp() public {
        // Deploy ANDEToken
        andeToken = ANDEToken(address(new ERC1967Proxy(address(new ANDEToken()), abi.encodeWithSelector(ANDEToken.initialize.selector, address(this), address(this)))));

        // Deploy DualTrackBurnEngine
        burnEngine = DualTrackBurnEngine(address(new ERC1967Proxy(address(new DualTrackBurnEngine()), abi.encodeWithSelector(DualTrackBurnEngine.initialize.selector, owner, burner, address(andeToken)))));

        // Fund the burn engine
        uint256 initialBurnableAmount = 10_000 * 1e18;
        andeToken.mint(address(burnEngine), initialBurnableAmount);
    }

    // --- Test Group: Deployment ---

    function test_Deployment_SetsCorrectRolesAndToken() public view {
        assertTrue(burnEngine.hasRole(ADMIN_ROLE, owner));
        assertTrue(burnEngine.hasRole(BURNER_ROLE, burner));
        assertEq(address(burnEngine.andeToken()), address(andeToken));
    }

    // --- Test Group: Impulsive Burn ---

    function test_ImpulsiveBurn_BurnerCanBurn() public {
        uint256 burnAmount = 100 * 1e18;
        uint256 initialBalance = andeToken.balanceOf(address(burnEngine));
        uint256 initialTotalSupply = andeToken.totalSupply();

        vm.prank(burner);
        burnEngine.impulsiveBurn(burnAmount);

        uint256 finalBalance = andeToken.balanceOf(address(burnEngine));
        uint256 finalTotalSupply = andeToken.totalSupply();

        assertEq(finalBalance, initialBalance - burnAmount);
        assertEq(finalTotalSupply, initialTotalSupply - burnAmount);
    }

    function test_ImpulsiveBurn_Fail_NonBurnerCannotBurn() public {
        uint256 burnAmount = 100 * 1e18;
        vm.prank(otherAccount);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, otherAccount, BURNER_ROLE));
        burnEngine.impulsiveBurn(burnAmount);
    }

    function test_ImpulsiveBurn_Fail_AmountIsZero() public {
        vm.prank(burner);
        vm.expectRevert(bytes("Burn amount must be positive"));
        burnEngine.impulsiveBurn(0);
    }

    function test_ImpulsiveBurn_Fail_ExceedsBalance() public {
        uint256 balance = andeToken.balanceOf(address(burnEngine));
        uint256 burnAmount = balance + 1;

        vm.prank(burner);
        vm.expectRevert(bytes("Burn amount exceeds balance"));
        burnEngine.impulsiveBurn(burnAmount);
    }

    // --- Test Group: Scheduled Burn ---

    function test_ScheduledBurn_Fail_BeforePeriodPasses() public {
        vm.expectRevert(bytes("Scheduled burn period not yet passed"));
        burnEngine.scheduledBurn();
    }

    function test_ScheduledBurn_CanBurnAfterPeriodPasses() public {
        uint256 schedulePeriod = burnEngine.SCHEDULE_PERIOD();
        vm.warp(block.timestamp + schedulePeriod + 1);

        uint256 initialBalance = andeToken.balanceOf(address(burnEngine));
        uint256 initialTotalSupply = andeToken.totalSupply();
        assertTrue(initialBalance > 0);

        burnEngine.scheduledBurn();

        uint256 finalBalance = andeToken.balanceOf(address(burnEngine));
        uint256 finalTotalSupply = andeToken.totalSupply();

        assertEq(finalBalance, 0, "Engine balance should be zero");
        assertEq(finalTotalSupply, initialTotalSupply - initialBalance, "Total supply should be reduced by entire engine balance");
    }

    function test_ScheduledBurn_ResetsTimestamp() public {
        uint256 schedulePeriod = burnEngine.SCHEDULE_PERIOD();
        uint256 beforeTimestamp = burnEngine.lastScheduledBurnTimestamp();
        
        vm.warp(block.timestamp + schedulePeriod + 1);
        burnEngine.scheduledBurn();

        uint256 afterTimestamp = burnEngine.lastScheduledBurnTimestamp();
        assertTrue(afterTimestamp > beforeTimestamp, "Timestamp should be updated");
    }
}
