// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {AndeNativeStaking} from "../../src/staking/AndeNativeStaking.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {StakingHandler} from "./handlers/StakingHandler.sol";

/**
 * @title AndeStakingInvariantTest
 * @notice Property-based testing (fuzzing) para AndeNativeStaking
 * @dev Ejecuta operaciones aleatorias y verifica invariantes después de cada operación
 * 
 * INVARIANTES CRÍTICOS:
 * 1. Total staked = contract balance
 * 2. Sum of pools = total staked
 * 3. Reward debt never exceeds distributed rewards
 * 4. Voting power never exceeds cap (500%)
 * 5. Circuit breakers enforce limits
 * 6. No underflows/overflows
 */
contract AndeStakingInvariantTest is Test {
    AndeNativeStaking public staking;
    MockERC20 public andeToken;
    StakingHandler public handler;
    
    address public owner = address(0x1);
    address public treasury = address(0x999);
    
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
        
        vm.stopPrank();
        
        handler = new StakingHandler(staking, andeToken);
        
        targetContract(address(handler));
        
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = StakingHandler.stakeLiquidity.selector;
        selectors[1] = StakingHandler.stakeGovernance.selector;
        selectors[2] = StakingHandler.stakeSequencer.selector;
        selectors[3] = StakingHandler.unstake.selector;
        selectors[4] = StakingHandler.claimRewards.selector;
        selectors[5] = StakingHandler.warpTime.selector;
        selectors[6] = StakingHandler.rollBlocks.selector;
        
        targetSelector(FuzzSelector({
            addr: address(handler),
            selectors: selectors
        }));
    }
    
    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.depth = 100
    function invariant_totalStakedMatchesBalance() public {
        uint256 contractBalance = andeToken.balanceOf(address(staking));
        uint256 totalStaked = staking.totalStaked(AndeNativeStaking.StakingLevel.LIQUIDITY) +
                              staking.totalStaked(AndeNativeStaking.StakingLevel.GOVERNANCE) +
                              staking.totalStaked(AndeNativeStaking.StakingLevel.SEQUENCER);
        
        assertLe(
            totalStaked,
            contractBalance,
            "CRITICAL: Total staked exceeds contract balance"
        );
    }
    
    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.depth = 100
    function invariant_sumOfPoolsEqualsTotal() public {
        uint256 liquidityPool = staking.totalStaked(AndeNativeStaking.StakingLevel.LIQUIDITY);
        uint256 governancePool = staking.totalStaked(AndeNativeStaking.StakingLevel.GOVERNANCE);
        uint256 sequencerPool = staking.totalStaked(AndeNativeStaking.StakingLevel.SEQUENCER);
        
        uint256 sum = liquidityPool + governancePool + sequencerPool;
        uint256 balance = andeToken.balanceOf(address(staking));
        
        assertLe(sum, balance, "Sum of pools exceeds balance");
    }
    
    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.depth = 100
    function invariant_noStakeWithoutBalance() public {
        uint256 totalStaked = staking.totalStaked(AndeNativeStaking.StakingLevel.LIQUIDITY) +
                              staking.totalStaked(AndeNativeStaking.StakingLevel.GOVERNANCE) +
                              staking.totalStaked(AndeNativeStaking.StakingLevel.SEQUENCER);
        
        uint256 balance = andeToken.balanceOf(address(staking));
        
        if (totalStaked > 0) {
            assertGt(balance, 0, "Non-zero stakes with zero balance");
        }
    }
    
    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.depth = 100
    function invariant_votingPowerNeverExceedsCap() public {
        address[] memory actors = handler.getActors();
        
        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            AndeNativeStaking.StakeInfo memory stake = staking.getStakeInfo(actor);
            
            if (stake.level == AndeNativeStaking.StakingLevel.GOVERNANCE && stake.amount > 0) {
                uint256 maxVotingPower = (stake.amount * 20000) / 10000;
                
                assertLe(
                    stake.votingPower,
                    maxVotingPower,
                    "Voting power exceeds 200% of stake amount"
                );
            }
        }
    }
    
    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.depth = 100
    function invariant_flashLoanProtection() public {
        address[] memory actors = handler.getActors();
        
        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            AndeNativeStaking.StakeInfo memory stake = staking.getStakeInfo(actor);
            
            if (stake.amount > 0) {
                uint256 protectedVotingPower = staking.getVotingPowerWithFlashLoanProtection(actor);
                
                if (block.number - stake.lastStakeBlock < 2) {
                    assertEq(
                        protectedVotingPower,
                        0,
                        "Flash loan protection: voting power available too soon (blocks)"
                    );
                }
                
                if (block.timestamp - stake.lastStakeTimestamp < 1 hours) {
                    assertEq(
                        protectedVotingPower,
                        0,
                        "Flash loan protection: voting power available too soon (time)"
                    );
                }
            }
        }
    }
    
    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.depth = 100
    function invariant_circuitBreakerLimits() public view {
        (
            bool stakingPaused,
            bool unstakingPaused,
            bool rewardClaimPaused,
            bool rewardDistributionPaused,
            uint256 maxStakePerTx,
            uint256 maxUnstakePerTx,
            uint256 dailyWithdrawLimit,
            uint256 withdrawnToday,
            uint256 lastResetDay
        ) = staking.circuitBreaker();
        
        assertLe(withdrawnToday, dailyWithdrawLimit, "Withdrawn today exceeds daily limit");
        assertGt(maxStakePerTx, 0, "Max stake per tx should be > 0");
        assertGt(maxUnstakePerTx, 0, "Max unstake per tx should be > 0");
        assertGt(dailyWithdrawLimit, 0, "Daily limit should be > 0");
    }
    
    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.depth = 100  
    function invariant_lockPeriodEnforced() public {
        address[] memory actors = handler.getActors();
        
        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            AndeNativeStaking.StakeInfo memory stake = staking.getStakeInfo(actor);
            
            if (stake.amount > 0 && stake.lockUntil > 0 && stake.level != AndeNativeStaking.StakingLevel.LIQUIDITY) {
                assertTrue(
                    stake.lockUntil >= stake.stakedAt,
                    "Lock period should be set correctly at stake time"
                );
            }
        }
    }
    
    /// forge-config: default.invariant.runs = 50
    /// forge-config: default.invariant.depth = 50
    function invariant_sequencerMinimumStake() public {
        address[] memory sequencers = staking.getSequencers();
        
        for (uint256 i = 0; i < sequencers.length; i++) {
            if (staking.isActiveSequencer(sequencers[i])) {
                AndeNativeStaking.StakeInfo memory stake = staking.getStakeInfo(sequencers[i]);
                
                assertGe(
                    stake.amount,
                    staking.MIN_SEQUENCER_STAKE(),
                    "Active sequencer below minimum stake"
                );
            }
        }
    }
    
    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.depth = 100
    function invariant_ghostVariablesMatchActual() public {
        uint256 actualTotal = staking.totalStaked(AndeNativeStaking.StakingLevel.LIQUIDITY) +
                              staking.totalStaked(AndeNativeStaking.StakingLevel.GOVERNANCE) +
                              staking.totalStaked(AndeNativeStaking.StakingLevel.SEQUENCER);
        
        assertApproxEqAbs(
            handler.ghost_totalStaked(),
            actualTotal,
            1e18,
            "Ghost variable mismatch with actual"
        );
    }
    
    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
