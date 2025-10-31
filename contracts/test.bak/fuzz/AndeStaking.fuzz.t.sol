// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {AndeNativeStaking} from "../../src/staking/AndeNativeStaking.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title AndeStakingFuzzTest
 * @notice Fuzz testing para funciones específicas de AndeNativeStaking
 * @dev Tests paramétricos que prueban rangos completos de inputs
 */
contract AndeStakingFuzzTest is Test {
    AndeNativeStaking public staking;
    MockERC20 public andeToken;
    
    address public owner = address(0x1);
    address public treasury = address(0x999);
    address public alice = address(0x2);
    address public bob = address(0x3);
    
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;
    
    function setUp() public {
        vm.startPrank(owner);
        
        andeToken = new MockERC20("ANDE Token", "ANDE", 18);
        
        AndeNativeStaking implementation = new AndeNativeStaking();
        bytes memory initData = abi.encodeWithSelector(
            AndeNativeStaking.initialize.selector,
            address(andeToken),
            owner,
            treasury
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        staking = AndeNativeStaking(address(proxy));
        
        andeToken.mint(alice, MAX_SUPPLY / 2);
        andeToken.mint(bob, MAX_SUPPLY / 2);
        
        vm.stopPrank();
        
        vm.prank(alice);
        andeToken.approve(address(staking), type(uint256).max);
        
        vm.prank(bob);
        andeToken.approve(address(staking), type(uint256).max);
    }
    
    function testFuzz_stakeLiquidity(uint256 amount) public {
        amount = bound(amount, staking.MIN_LIQUIDITY_STAKE(), 10_000_000 * 1e18);
        
        uint256 balanceBefore = andeToken.balanceOf(alice);
        
        vm.prank(alice);
        staking.stakeLiquidity(amount);
        
        uint256 balanceAfter = andeToken.balanceOf(alice);
        AndeNativeStaking.StakeInfo memory stake = staking.getStakeInfo(alice);
        
        assertEq(balanceBefore - balanceAfter, amount, "Balance change mismatch");
        assertEq(stake.amount, amount, "Stake amount mismatch");
        assertEq(uint8(stake.level), uint8(AndeNativeStaking.StakingLevel.LIQUIDITY), "Level mismatch");
    }
    
    function testFuzz_stakeGovernance(uint256 amount, uint8 lockPeriodSeed) public {
        amount = bound(amount, staking.MIN_GOVERNANCE_STAKE(), 10_000_000 * 1e18);
        AndeNativeStaking.LockPeriod lockPeriod = AndeNativeStaking.LockPeriod(
            bound(lockPeriodSeed, 1, 4)
        );
        
        vm.prank(alice);
        staking.stakeGovernance(amount, lockPeriod);
        
        AndeNativeStaking.StakeInfo memory stake = staking.getStakeInfo(alice);
        
        assertEq(stake.amount, amount);
        assertEq(uint8(stake.level), uint8(AndeNativeStaking.StakingLevel.GOVERNANCE));
        assertGt(stake.votingPower, amount, "Voting power should exceed base amount");
        assertGt(stake.lockUntil, block.timestamp, "Lock should be in future");
    }
    
    function testFuzz_multipleStakesAccumulate(
        uint256 amount1,
        uint256 amount2,
        uint8 lockSeed
    ) public {
        amount1 = bound(amount1, staking.MIN_GOVERNANCE_STAKE(), 5_000_000 * 1e18);
        amount2 = bound(amount2, staking.MIN_GOVERNANCE_STAKE(), 5_000_000 * 1e18);
        
        AndeNativeStaking.LockPeriod lockPeriod = AndeNativeStaking.LockPeriod(
            bound(lockSeed, 1, 4)
        );
        
        vm.startPrank(alice);
        staking.stakeGovernance(amount1, lockPeriod);
        
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        
        staking.stakeGovernance(amount2, lockPeriod);
        vm.stopPrank();
        
        AndeNativeStaking.StakeInfo memory stake = staking.getStakeInfo(alice);
        
        assertEq(stake.amount, amount1 + amount2, "Stakes should accumulate");
    }
    
    function testFuzz_circuitBreakerMaxStake(uint256 amount) public {
        amount = bound(amount, 10_000_001 * 1e18, 100_000_000 * 1e18);
        
        vm.prank(alice);
        vm.expectRevert(AndeNativeStaking.ExceedsMaxPerTx.selector);
        staking.stakeLiquidity(amount);
    }
    
    function testFuzz_circuitBreakerDailyLimit(uint256[] memory amounts) public {
        vm.assume(amounts.length > 0 && amounts.length <= 10);
        
        uint256 totalToWithdraw = 0;
        
        for (uint256 i = 0; i < amounts.length; i++) {
            amounts[i] = bound(amounts[i], staking.MIN_LIQUIDITY_STAKE(), 500_000 * 1e18);
            totalToWithdraw += amounts[i];
        }
        
        for (uint256 i = 0; i < amounts.length; i++) {
            address user = address(uint160(i + 100));
            andeToken.mint(user, amounts[i]);
            
            vm.startPrank(user);
            andeToken.approve(address(staking), amounts[i]);
            staking.stakeLiquidity(amounts[i]);
            vm.stopPrank();
        }
        
        vm.warp(block.timestamp + 1);
        
        uint256 dailyLimit = 1_000_000 * 1e18;
        uint256 withdrawn = 0;
        
        for (uint256 i = 0; i < amounts.length; i++) {
            address user = address(uint160(i + 100));
            
            if (withdrawn + amounts[i] > dailyLimit) {
                vm.prank(user);
                vm.expectRevert(AndeNativeStaking.ExceedsDailyLimit.selector);
                staking.unstake();
                break;
            }
            
            vm.prank(user);
            staking.unstake();
            withdrawn += amounts[i];
        }
    }
    
    function testFuzz_slashingReducesStake(uint256 amount) public {
        amount = bound(amount, staking.MIN_SEQUENCER_STAKE(), 10_000_000 * 1e18);
        
        vm.prank(alice);
        staking.stakeSequencer(amount);
        
        vm.prank(owner);
        staking.registerSequencer(alice);
        
        uint256 expectedSlash = (amount * 500) / 10000;
        uint256 expectedRemaining = amount - expectedSlash;
        
        vm.prank(owner);
        staking.slashSequencer(alice, "Test slash");
        
        AndeNativeStaking.StakeInfo memory stake = staking.getStakeInfo(alice);
        
        assertEq(stake.amount, expectedRemaining, "Slash amount mismatch");
        assertEq(andeToken.balanceOf(treasury), expectedSlash, "Treasury balance mismatch");
    }
    
    function testFuzz_slashingMaxTimes(uint256 amount) public {
        amount = bound(amount, staking.MIN_SEQUENCER_STAKE(), 10_000_000 * 1e18);
        
        vm.prank(alice);
        staking.stakeSequencer(amount);
        
        vm.prank(owner);
        staking.registerSequencer(alice);
        
        vm.startPrank(owner);
        staking.slashSequencer(alice, "Slash 1");
        staking.slashSequencer(alice, "Slash 2");
        staking.slashSequencer(alice, "Slash 3");
        vm.stopPrank();
        
        assertFalse(staking.isActiveSequencer(alice), "Should be removed after 3 slashes");
        
        vm.prank(owner);
        vm.expectRevert(AndeNativeStaking.NotSequencer.selector);
        staking.slashSequencer(alice, "Slash 4");
    }
    
    function testFuzz_votingPowerFlashLoanProtection(
        uint256 amount,
        uint8 lockSeed,
        uint256 blocksToWait,
        uint256 timeToWait
    ) public {
        amount = bound(amount, staking.MIN_GOVERNANCE_STAKE(), 10_000_000 * 1e18);
        blocksToWait = bound(blocksToWait, 0, 10);
        timeToWait = bound(timeToWait, 0, 2 hours);
        
        AndeNativeStaking.LockPeriod lockPeriod = AndeNativeStaking.LockPeriod(
            bound(lockSeed, 1, 4)
        );
        
        vm.prank(alice);
        staking.stakeGovernance(amount, lockPeriod);
        
        vm.roll(block.number + blocksToWait);
        vm.warp(block.timestamp + timeToWait);
        
        uint256 votingPower = staking.getVotingPowerWithFlashLoanProtection(alice);
        
        if (blocksToWait < 2 || timeToWait < 1 hours) {
            assertEq(votingPower, 0, "Should have no voting power yet");
        } else {
            assertGt(votingPower, 0, "Should have voting power after delay");
        }
    }
    
    function testFuzz_extendLockIncreasesVotingPower(
        uint256 amount,
        uint8 initialLockSeed,
        uint8 newLockSeed
    ) public {
        amount = bound(amount, staking.MIN_GOVERNANCE_STAKE(), 10_000_000 * 1e18);
        
        uint8 initialLock = uint8(bound(initialLockSeed, 1, 3));
        uint8 newLock = uint8(bound(newLockSeed, uint256(initialLock) + 1, 4));
        
        vm.prank(alice);
        staking.stakeGovernance(amount, AndeNativeStaking.LockPeriod(initialLock));
        
        AndeNativeStaking.StakeInfo memory stakeBefore = staking.getStakeInfo(alice);
        
        vm.prank(alice);
        staking.extendLock(AndeNativeStaking.LockPeriod(newLock));
        
        AndeNativeStaking.StakeInfo memory stakeAfter = staking.getStakeInfo(alice);
        
        assertGt(stakeAfter.votingPower, stakeBefore.votingPower, "Voting power should increase");
        assertGt(stakeAfter.lockUntil, stakeBefore.lockUntil, "Lock period should extend");
    }
    
    function testFuzz_rewardDistributionSplits(uint256 totalReward) public {
        totalReward = bound(totalReward, 1000 * 1e18, 10_000_000 * 1e18);
        
        vm.prank(alice);
        staking.stakeLiquidity(1_000_000 * 1e18);
        
        vm.prank(bob);
        staking.stakeGovernance(1_000_000 * 1e18, AndeNativeStaking.LockPeriod.TWELVE_MONTHS);
        
        address carol = address(0x4);
        andeToken.mint(carol, 5_000_000 * 1e18);
        vm.startPrank(carol);
        andeToken.approve(address(staking), type(uint256).max);
        staking.stakeSequencer(5_000_000 * 1e18);
        vm.stopPrank();
        
        andeToken.mint(owner, totalReward);
        
        vm.startPrank(owner);
        andeToken.approve(address(staking), totalReward);
        staking.distributeRewards(totalReward);
        vm.stopPrank();
        
        uint256 expectedSequencer = (totalReward * 4000) / 10000;
        uint256 expectedGovernance = (totalReward * 3000) / 10000;
        uint256 expectedLiquidity = (totalReward * 3000) / 10000;
        
        (uint256 liquidityRewards, , ) = staking.rewardPools(AndeNativeStaking.StakingLevel.LIQUIDITY);
        (uint256 governanceRewards, , ) = staking.rewardPools(AndeNativeStaking.StakingLevel.GOVERNANCE);
        (uint256 sequencerRewards, , ) = staking.rewardPools(AndeNativeStaking.StakingLevel.SEQUENCER);
        
        assertEq(liquidityRewards, expectedLiquidity, "Liquidity rewards mismatch");
        assertEq(governanceRewards, expectedGovernance, "Governance rewards mismatch");
        assertEq(sequencerRewards, expectedSequencer, "Sequencer rewards mismatch");
    }
}
