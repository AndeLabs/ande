// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {VeANDE} from "../src/VeANDE.sol";
import {ANDEToken} from "../src/ANDEToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VeANDETest is Test {
    VeANDE public veANDE;
    ANDEToken public andeToken;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    uint256 public constant FOUR_YEARS = 4 * 365 days;
    uint256 public constant LOCK_AMOUNT = 1000 * 1e18;

    function setUp() public {
        // Deploy ANDEToken
        andeToken = ANDEToken(address(new ERC1967Proxy(address(new ANDEToken()), abi.encodeWithSelector(ANDEToken.initialize.selector, owner, owner))));

        // Deploy VeANDE
        veANDE = VeANDE(address(new ERC1967Proxy(address(new VeANDE()), abi.encodeWithSelector(VeANDE.initialize.selector, owner, address(andeToken)))));

        // Fund user
        vm.prank(owner);
        andeToken.mint(user, LOCK_AMOUNT * 2);
    }

    // --- Modifier para crear un lock inicial ---
    modifier givenUserHasLock(uint256 amount, uint256 duration) {
        uint256 unlockTime = block.timestamp + duration;
        vm.startPrank(user);
        andeToken.approve(address(veANDE), amount);
        veANDE.createLock(amount, unlockTime);
        vm.stopPrank();
        _;
    }

    // --- Test Group: Locking ---

    function test_Locking_CanCreateLock() public {
        uint256 unlockTime = block.timestamp + 365 days;
        
        vm.startPrank(user);
        andeToken.approve(address(veANDE), LOCK_AMOUNT);
        veANDE.createLock(LOCK_AMOUNT, unlockTime);
        vm.stopPrank();

        (uint256 amount, uint256 end) = veANDE.lockedBalances(user);
        assertEq(amount, LOCK_AMOUNT);
        assertEq(end, unlockTime);
        assertEq(andeToken.balanceOf(address(veANDE)), LOCK_AMOUNT);
    }

    function test_Locking_CanIncreaseAmount() public givenUserHasLock(LOCK_AMOUNT, 365 days) {
        uint256 additionalAmount = 500 * 1e18;
        
        vm.startPrank(user);
        andeToken.approve(address(veANDE), additionalAmount);
        // Llamar a createLock con 0 en tiempo para solo aumentar el monto
        ( , uint256 unlockEnd) = veANDE.lockedBalances(user);
        veANDE.createLock(additionalAmount, unlockEnd);
        vm.stopPrank();

        (uint256 amount, ) = veANDE.lockedBalances(user);
        assertEq(amount, LOCK_AMOUNT + additionalAmount);
    }

    function test_Locking_CanExtendLockTime() public givenUserHasLock(LOCK_AMOUNT, 365 days) {
        ( , uint256 initialUnlockTime) = veANDE.lockedBalances(user);
        uint256 extendedUnlockTime = initialUnlockTime + 365 days;

        vm.prank(user);
        veANDE.createLock(0, extendedUnlockTime);

        ( , uint256 end) = veANDE.lockedBalances(user);
        assertEq(end, extendedUnlockTime);
    }

    function test_Fail_CannotShortenLockTime() public givenUserHasLock(LOCK_AMOUNT, 730 days) {
        ( , uint256 initialUnlockTime) = veANDE.lockedBalances(user);
        uint256 shorterUnlockTime = initialUnlockTime - 365 days;

        vm.prank(user);
        vm.expectRevert(VeANDE.CannotShortenLockTime.selector);
        veANDE.createLock(0, shorterUnlockTime);
    }

    function test_Fail_CannotLockForMoreThanMax() public {
        uint256 invalidUnlockTime = block.timestamp + FOUR_YEARS + 1 days;
        vm.prank(user);
        andeToken.approve(address(veANDE), LOCK_AMOUNT);
        vm.expectRevert(VeANDE.LockDurationExceedsMax.selector);
        veANDE.createLock(LOCK_AMOUNT, invalidUnlockTime);
    }

    // --- Test Group: Withdrawing ---

    function test_Withdraw_CanWithdrawAfterExpiry() public givenUserHasLock(LOCK_AMOUNT, 365 days) {
        ( , uint256 unlockTime) = veANDE.lockedBalances(user);
        uint256 initialBalance = andeToken.balanceOf(user);

        vm.warp(unlockTime); // Viaje en el tiempo!

        vm.prank(user);
        veANDE.withdraw();

        assertEq(andeToken.balanceOf(user), initialBalance + LOCK_AMOUNT);
        assertEq(andeToken.balanceOf(address(veANDE)), 0);
    }

    function test_Fail_CannotWithdrawBeforeExpiry() public givenUserHasLock(LOCK_AMOUNT, 365 days) {
        vm.prank(user);
        vm.expectRevert(VeANDE.LockNotExpired.selector);
        veANDE.withdraw();
    }

    // --- Test Group: Voting Power ---

    function test_VotingPower_DecaysLinearly() public {
        uint256 unlockTime = block.timestamp + FOUR_YEARS;
        vm.startPrank(user);
        andeToken.approve(address(veANDE), LOCK_AMOUNT);
        veANDE.createLock(LOCK_AMOUNT, unlockTime);
        vm.stopPrank();

        // At T=0, power should be close to max
        uint256 power_t0 = veANDE.balanceOf(user);
        assertApproxEqAbs(power_t0, LOCK_AMOUNT, 1e18, "Power at T=0 is not max");

        // At T=2 years (halfway), power should be ~50%
        vm.warp(block.timestamp + FOUR_YEARS / 2);
        uint256 power_t2 = veANDE.balanceOf(user);
        assertApproxEqAbs(power_t2, LOCK_AMOUNT / 2, 1e18, "Power at T=2 is not 50%");

        // At T=4 years (expiry), power should be 0
        vm.warp(unlockTime);
        uint256 power_t4 = veANDE.balanceOf(user);
        assertEq(power_t4, 0, "Power at T=4 is not 0");
    }
}
