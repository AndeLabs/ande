// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {AndeNativeStaking} from "../../../src/staking/AndeNativeStaking.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";

/**
 * @title StakingHandler
 * @notice Handler contract para invariant testing de AndeNativeStaking
 * @dev Simula comportamiento aleatorio de usuarios para encontrar edge cases
 */
contract StakingHandler is Test {
    AndeNativeStaking public staking;
    MockERC20 public andeToken;
    
    address[] public actors;
    address internal currentActor;
    
    mapping(bytes32 => uint256) public calls;
    
    uint256 public ghost_totalStaked;
    uint256 public ghost_totalLiquidityStaked;
    uint256 public ghost_totalGovernanceStaked;
    uint256 public ghost_totalSequencerStaked;
    uint256 public ghost_zeroAddressCalls;
    
    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }
    
    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }
    
    constructor(AndeNativeStaking _staking, MockERC20 _andeToken) {
        staking = _staking;
        andeToken = _andeToken;
        
        for (uint256 i = 0; i < 10; i++) {
            address actor = address(uint160(uint256(keccak256(abi.encodePacked("actor", i)))));
            actors.push(actor);
            andeToken.mint(actor, 10_000_000 * 1e18);
            vm.prank(actor);
            andeToken.approve(address(staking), type(uint256).max);
        }
    }
    
    function stakeLiquidity(uint256 actorSeed, uint256 amount) 
        external 
        useActor(actorSeed)
        countCall("stakeLiquidity")
    {
        amount = bound(amount, staking.MIN_LIQUIDITY_STAKE(), 1_000_000 * 1e18);
        
        try staking.stakeLiquidity(amount) {
            ghost_totalStaked += amount;
            ghost_totalLiquidityStaked += amount;
        } catch {
            // Expected reverts are ok
        }
    }
    
    function stakeGovernance(uint256 actorSeed, uint256 amount, uint8 lockPeriodSeed) 
        external 
        useActor(actorSeed)
        countCall("stakeGovernance")
    {
        amount = bound(amount, staking.MIN_GOVERNANCE_STAKE(), 1_000_000 * 1e18);
        
        AndeNativeStaking.LockPeriod lockPeriod = AndeNativeStaking.LockPeriod(
            bound(lockPeriodSeed, 1, 4)
        );
        
        try staking.stakeGovernance(amount, lockPeriod) {
            ghost_totalStaked += amount;
            ghost_totalGovernanceStaked += amount;
        } catch {
            // Expected reverts are ok
        }
    }
    
    function stakeSequencer(uint256 actorSeed, uint256 amount) 
        external 
        useActor(actorSeed)
        countCall("stakeSequencer")
    {
        amount = bound(amount, staking.MIN_SEQUENCER_STAKE(), 5_000_000 * 1e18);
        
        try staking.stakeSequencer(amount) {
            ghost_totalStaked += amount;
            ghost_totalSequencerStaked += amount;
        } catch {
            // Expected reverts are ok
        }
    }
    
    function unstake(uint256 actorSeed) 
        external 
        useActor(actorSeed)
        countCall("unstake")
    {
        AndeNativeStaking.StakeInfo memory stake = staking.getStakeInfo(currentActor);
        
        if (stake.amount == 0) return;
        
        if (stake.lockUntil > block.timestamp) {
            vm.warp(stake.lockUntil + 1);
        }
        
        try staking.unstake() {
            ghost_totalStaked -= stake.amount;
            
            if (stake.level == AndeNativeStaking.StakingLevel.LIQUIDITY) {
                ghost_totalLiquidityStaked -= stake.amount;
            } else if (stake.level == AndeNativeStaking.StakingLevel.GOVERNANCE) {
                ghost_totalGovernanceStaked -= stake.amount;
            } else if (stake.level == AndeNativeStaking.StakingLevel.SEQUENCER) {
                ghost_totalSequencerStaked -= stake.amount;
            }
        } catch {
            // Expected reverts are ok
        }
    }
    
    function claimRewards(uint256 actorSeed) 
        external 
        useActor(actorSeed)
        countCall("claimRewards")
    {
        try staking.claimRewards() {
            // Success
        } catch {
            // Expected reverts are ok
        }
    }
    
    function extendLock(uint256 actorSeed, uint8 newLockPeriodSeed) 
        external 
        useActor(actorSeed)
        countCall("extendLock")
    {
        AndeNativeStaking.LockPeriod newLockPeriod = AndeNativeStaking.LockPeriod(
            bound(newLockPeriodSeed, 1, 4)
        );
        
        try staking.extendLock(newLockPeriod) {
            // Success
        } catch {
            // Expected reverts are ok
        }
    }
    
    function warpTime(uint256 seconds_) external countCall("warpTime") {
        seconds_ = bound(seconds_, 1, 365 days);
        vm.warp(block.timestamp + seconds_);
    }
    
    function rollBlocks(uint256 blocks_) external countCall("rollBlocks") {
        blocks_ = bound(blocks_, 1, 10000);
        vm.roll(block.number + blocks_);
    }
    
    function callSummary() external view {
        console.log("Call Summary:");
        console.log("-------------------");
        console.log("stakeLiquidity:    ", calls["stakeLiquidity"]);
        console.log("stakeGovernance:   ", calls["stakeGovernance"]);
        console.log("stakeSequencer:    ", calls["stakeSequencer"]);
        console.log("unstake:           ", calls["unstake"]);
        console.log("claimRewards:      ", calls["claimRewards"]);
        console.log("extendLock:        ", calls["extendLock"]);
        console.log("warpTime:          ", calls["warpTime"]);
        console.log("rollBlocks:        ", calls["rollBlocks"]);
        console.log("-------------------");
        console.log("Ghost Variables:");
        console.log("ghost_totalStaked:           ", ghost_totalStaked);
        console.log("ghost_totalLiquidityStaked:  ", ghost_totalLiquidityStaked);
        console.log("ghost_totalGovernanceStaked: ", ghost_totalGovernanceStaked);
        console.log("ghost_totalSequencerStaked:  ", ghost_totalSequencerStaked);
    }
    
    function getActors() external view returns (address[] memory) {
        return actors;
    }
    
    function forEachActor(function(address) external func) external {
        for (uint256 i = 0; i < actors.length; i++) {
            func(actors[i]);
        }
    }
}
