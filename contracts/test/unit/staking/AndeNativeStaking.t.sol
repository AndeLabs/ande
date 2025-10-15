// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {AndeNativeStaking} from "../../../src/staking/AndeNativeStaking.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";

contract AndeNativeStakingTest is Test {
    AndeNativeStaking public staking;
    MockERC20 public andeToken;

    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);

    uint256 public constant INITIAL_BALANCE = 1_000_000 * 1e18;

    function setUp() public {
        vm.startPrank(owner);

        andeToken = new MockERC20("ANDE Token", "ANDE", 18);
        andeToken.mint(owner, INITIAL_BALANCE);
        andeToken.mint(alice, INITIAL_BALANCE);
        andeToken.mint(bob, INITIAL_BALANCE);
        andeToken.mint(charlie, INITIAL_BALANCE);

        AndeNativeStaking implementation = new AndeNativeStaking();
        bytes memory initData =
            abi.encodeWithSelector(AndeNativeStaking.initialize.selector, address(andeToken), owner);

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        staking = AndeNativeStaking(address(proxy));

        vm.stopPrank();
    }

    function testInitialization() public view {
        assertEq(address(staking.andeToken()), address(andeToken));
        assertTrue(staking.hasRole(staking.DEFAULT_ADMIN_ROLE(), owner));
    }

    function testLiquidityStaking() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.startPrank(alice);
        andeToken.approve(address(staking), stakeAmount);
        staking.stakeLiquidity(stakeAmount);
        vm.stopPrank();

        AndeNativeStaking.StakeInfo memory stake = staking.getStakeInfo(alice);

        assertEq(stake.amount, stakeAmount);
        assertEq(uint256(stake.level), uint256(AndeNativeStaking.StakingLevel.LIQUIDITY));
        assertEq(uint256(stake.lockPeriod), uint256(AndeNativeStaking.LockPeriod.NONE));
    }

    function testGovernanceStaking() public {
        uint256 stakeAmount = 10_000 * 1e18;

        vm.startPrank(alice);
        andeToken.approve(address(staking), stakeAmount);
        staking.stakeGovernance(stakeAmount, AndeNativeStaking.LockPeriod.SIX_MONTHS);
        vm.stopPrank();

        AndeNativeStaking.StakeInfo memory stake = staking.getStakeInfo(alice);

        assertEq(stake.amount, stakeAmount);
        assertEq(uint256(stake.level), uint256(AndeNativeStaking.StakingLevel.GOVERNANCE));
        assertEq(uint256(stake.lockPeriod), uint256(AndeNativeStaking.LockPeriod.SIX_MONTHS));
        assertGt(stake.votingPower, stakeAmount);
    }

    function testSequencerStaking() public {
        uint256 stakeAmount = 100_000 * 1e18;

        vm.startPrank(alice);
        andeToken.approve(address(staking), stakeAmount);
        staking.stakeSequencer(stakeAmount);
        vm.stopPrank();

        AndeNativeStaking.StakeInfo memory stake = staking.getStakeInfo(alice);

        assertEq(stake.amount, stakeAmount);
        assertEq(uint256(stake.level), uint256(AndeNativeStaking.StakingLevel.SEQUENCER));
        assertTrue(stake.isSequencer);
    }

    function test_RevertWhen_InsufficientStakeAmount() public {
        uint256 stakeAmount = 50 * 1e18;

        vm.startPrank(alice);
        andeToken.approve(address(staking), stakeAmount);
        vm.expectRevert(AndeNativeStaking.InsufficientStakeAmount.selector);
        staking.stakeLiquidity(stakeAmount);
        vm.stopPrank();
    }

    function testUnstakeLiquidity() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.startPrank(alice);
        andeToken.approve(address(staking), stakeAmount);
        staking.stakeLiquidity(stakeAmount);

        uint256 balanceBefore = andeToken.balanceOf(alice);

        staking.unstake();

        uint256 balanceAfter = andeToken.balanceOf(alice);

        assertEq(balanceAfter, balanceBefore + stakeAmount);
        vm.stopPrank();
    }

    function testUnstakeGovernanceBeforeLockExpires() public {
        uint256 stakeAmount = 10_000 * 1e18;

        vm.startPrank(alice);
        andeToken.approve(address(staking), stakeAmount);
        staking.stakeGovernance(stakeAmount, AndeNativeStaking.LockPeriod.THREE_MONTHS);

        vm.expectRevert(AndeNativeStaking.StakeStillLocked.selector);
        staking.unstake();
        vm.stopPrank();
    }

    function testUnstakeGovernanceAfterLockExpires() public {
        uint256 stakeAmount = 10_000 * 1e18;

        vm.startPrank(alice);
        andeToken.approve(address(staking), stakeAmount);
        staking.stakeGovernance(stakeAmount, AndeNativeStaking.LockPeriod.THREE_MONTHS);

        vm.warp(block.timestamp + 91 days);

        uint256 balanceBefore = andeToken.balanceOf(alice);
        staking.unstake();
        uint256 balanceAfter = andeToken.balanceOf(alice);

        assertEq(balanceAfter, balanceBefore + stakeAmount);
        vm.stopPrank();
    }

    function testRewardDistribution() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 1000 * 1e18;

        vm.startPrank(alice);
        andeToken.approve(address(staking), stakeAmount);
        staking.stakeLiquidity(stakeAmount);
        vm.stopPrank();

        vm.startPrank(bob);
        andeToken.approve(address(staking), stakeAmount);
        staking.stakeLiquidity(stakeAmount);
        vm.stopPrank();

        vm.startPrank(owner);
        andeToken.approve(address(staking), rewardAmount);
        staking.distributeRewards(rewardAmount);
        vm.stopPrank();

        uint256 aliceReward = staking.getPendingRewards(alice);
        uint256 bobReward = staking.getPendingRewards(bob);

        assertGt(aliceReward, 0);
        assertGt(bobReward, 0);
        assertEq(aliceReward, bobReward);
    }

    function testExtendLock() public {
        uint256 stakeAmount = 10_000 * 1e18;

        vm.startPrank(alice);
        andeToken.approve(address(staking), stakeAmount);
        staking.stakeGovernance(stakeAmount, AndeNativeStaking.LockPeriod.THREE_MONTHS);

        AndeNativeStaking.StakeInfo memory stakeBefore = staking.getStakeInfo(alice);
        uint256 votingPowerBefore = stakeBefore.votingPower;

        staking.extendLock(AndeNativeStaking.LockPeriod.TWELVE_MONTHS);

        AndeNativeStaking.StakeInfo memory stakeAfter = staking.getStakeInfo(alice);
        uint256 votingPowerAfter = stakeAfter.votingPower;

        assertGt(votingPowerAfter, votingPowerBefore);
        assertEq(uint256(stakeAfter.lockPeriod), uint256(AndeNativeStaking.LockPeriod.TWELVE_MONTHS));
        vm.stopPrank();
    }

    function test_RevertWhen_ExtendLockToShorterPeriod() public {
        uint256 stakeAmount = 10_000 * 1e18;

        vm.startPrank(alice);
        andeToken.approve(address(staking), stakeAmount);
        staking.stakeGovernance(stakeAmount, AndeNativeStaking.LockPeriod.TWELVE_MONTHS);

        vm.expectRevert(AndeNativeStaking.CannotReduceLockPeriod.selector);
        staking.extendLock(AndeNativeStaking.LockPeriod.SIX_MONTHS);
        vm.stopPrank();
    }

    function testGetSequencers() public {
        uint256 stakeAmount = 100_000 * 1e18;

        vm.startPrank(alice);
        andeToken.approve(address(staking), stakeAmount);
        staking.stakeSequencer(stakeAmount);
        vm.stopPrank();

        vm.startPrank(owner);
        staking.registerSequencer(alice);
        vm.stopPrank();

        address[] memory sequencers = staking.getSequencers();
        assertEq(sequencers.length, 1);
        assertEq(sequencers[0], alice);
    }

    function testPauseUnpause() public {
        vm.startPrank(owner);
        staking.pause();
        assertTrue(staking.paused());

        staking.unpause();
        assertFalse(staking.paused());
        vm.stopPrank();
    }

    function test_RevertWhen_StakeWhenPaused() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.prank(owner);
        staking.pause();

        vm.startPrank(alice);
        andeToken.approve(address(staking), stakeAmount);
        vm.expectRevert();
        staking.stakeLiquidity(stakeAmount);
        vm.stopPrank();
    }

    function testVotingPowerCalculation() public {
        uint256 stakeAmount = 10_000 * 1e18;

        vm.startPrank(alice);
        andeToken.approve(address(staking), stakeAmount * 4);

        staking.stakeGovernance(stakeAmount, AndeNativeStaking.LockPeriod.THREE_MONTHS);
        uint256 votingPower3M = staking.getStakeInfo(alice).votingPower;

        vm.warp(block.timestamp + 91 days);
        staking.unstake();

        staking.stakeGovernance(stakeAmount, AndeNativeStaking.LockPeriod.TWENTY_FOUR_MONTHS);
        uint256 votingPower24M = staking.getStakeInfo(alice).votingPower;

        assertGt(votingPower24M, votingPower3M);
        vm.stopPrank();
    }
}
