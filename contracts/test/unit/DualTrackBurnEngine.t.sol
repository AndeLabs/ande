// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {DualTrackBurnEngine} from "../../src/DualTrackBurnEngine.sol";
import {ANDEToken} from "../../src/ANDEToken.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract DualTrackBurnEngineTest is Test {
    DualTrackBurnEngine public burnEngine;
    ANDEToken public andeToken;

    address public owner = makeAddr("owner");
    address public burner = makeAddr("burner");
    address public otherAccount = makeAddr("otherAccount");

    bytes32 public constant ADMIN_ROLE = bytes32(0);
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    function setUp() public {
        andeToken = ANDEToken(address(new ERC1967Proxy(address(new ANDEToken()), abi.encodeWithSelector(ANDEToken.initialize.selector, address(this), address(this)))));
        burnEngine = DualTrackBurnEngine(address(new ERC1967Proxy(address(new DualTrackBurnEngine()), abi.encodeWithSelector(DualTrackBurnEngine.initialize.selector, owner, burner, address(andeToken)))));

        uint256 initialBurnableAmount = 10_000 * 1e18;
        andeToken.mint(address(burnEngine), initialBurnableAmount);
    }

    function test_Deployment_SetsCorrectRolesAndToken() public view {
        assertTrue(burnEngine.hasRole(ADMIN_ROLE, owner));
        assertTrue(burnEngine.hasRole(BURNER_ROLE, burner));
        assertEq(address(burnEngine.andeToken()), address(andeToken));
    }

    function test_ImpulsiveBurn_BurnerCanBurn() public {
        uint256 burnAmount = 100 * 1e18;
        uint256 initialBalance = andeToken.balanceOf(address(burnEngine));
        uint256 initialTotalSupply = andeToken.totalSupply();

        vm.prank(burner);
        burnEngine.impulsiveBurn(burnAmount);

        assertEq(andeToken.balanceOf(address(burnEngine)), initialBalance - burnAmount);
        assertEq(andeToken.totalSupply(), initialTotalSupply - burnAmount);
    }

    function test_ScheduledBurn_CanBurnAfterPeriodPasses() public {
        uint256 schedulePeriod = burnEngine.SCHEDULE_PERIOD();
        vm.warp(block.timestamp + schedulePeriod + 1);

        uint256 initialBalance = andeToken.balanceOf(address(burnEngine));
        assertTrue(initialBalance > 0);

        burnEngine.scheduledBurn();

        assertEq(andeToken.balanceOf(address(burnEngine)), 0);
    }
}
