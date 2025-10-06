// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {VeANDE} from "../../src/VeANDE.sol";
import {ANDEToken} from "../../src/ANDEToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VeANDETest is Test {
    VeANDE public veANDE;
    ANDEToken public andeToken;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    uint256 public constant FOUR_YEARS = 4 * 365 days;
    uint256 public constant LOCK_AMOUNT = 1000 * 1e18;

    function setUp() public {
        andeToken = ANDEToken(address(new ERC1967Proxy(address(new ANDEToken()), abi.encodeWithSelector(ANDEToken.initialize.selector, owner, owner))));
        veANDE = VeANDE(address(new ERC1967Proxy(address(new VeANDE()), abi.encodeWithSelector(VeANDE.initialize.selector, owner, address(andeToken)))));

        vm.prank(owner);
        andeToken.mint(user, LOCK_AMOUNT * 2);
    }

    modifier givenUserHasLock(uint256 amount, uint256 duration) {
        uint256 unlockTime = block.timestamp + duration;
        vm.startPrank(user);
        andeToken.approve(address(veANDE), amount);
        veANDE.createLock(amount, unlockTime);
        vm.stopPrank();
        _;
    }

    function test_Locking_CanCreateLock() public {
        uint256 unlockTime = block.timestamp + 365 days;
        vm.startPrank(user);
        andeToken.approve(address(veANDE), LOCK_AMOUNT);
        veANDE.createLock(LOCK_AMOUNT, unlockTime);
        vm.stopPrank();

        (uint256 amount, uint256 end) = veANDE.lockedBalances(user);
        assertEq(amount, LOCK_AMOUNT);
        assertEq(end, unlockTime);
    }

    function test_Withdraw_CanWithdrawAfterExpiry() public givenUserHasLock(LOCK_AMOUNT, 365 days) {
        ( , uint256 unlockTime) = veANDE.lockedBalances(user);
        uint256 initialBalance = andeToken.balanceOf(user);

        vm.warp(unlockTime);

        vm.prank(user);
        veANDE.withdraw();

        assertEq(andeToken.balanceOf(user), initialBalance + LOCK_AMOUNT);
    }

    function test_Fail_CannotWithdrawBeforeExpiry() public givenUserHasLock(LOCK_AMOUNT, 365 days) {
        vm.prank(user);
        vm.expectRevert(VeANDE.LockNotExpired.selector);
        veANDE.withdraw();
    }

    function test_VotingPower_DecaysLinearly() public {
        uint256 unlockTime = block.timestamp + FOUR_YEARS;
        vm.startPrank(user);
        andeToken.approve(address(veANDE), LOCK_AMOUNT);
        veANDE.createLock(LOCK_AMOUNT, unlockTime);
        vm.stopPrank();

        uint256 power_t0 = veANDE.balanceOf(user);
        assertApproxEqAbs(power_t0, LOCK_AMOUNT, 1e18);

        vm.warp(block.timestamp + FOUR_YEARS / 2);
        uint256 power_t2 = veANDE.balanceOf(user);
        assertApproxEqAbs(power_t2, LOCK_AMOUNT / 2, 1e18);

        vm.warp(unlockTime);
        uint256 power_t4 = veANDE.balanceOf(user);
        assertEq(power_t4, 0);
    }
}
