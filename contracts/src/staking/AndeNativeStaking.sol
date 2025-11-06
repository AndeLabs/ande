// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title AndeNativeStaking
 * @author Ande Labs
 * @notice Sistema de staking nativo de ANDE con tres niveles
 * @dev Implementa staking directo de ANDE token con funcionalidades específicas para el rollup soberano
 *
 * TRES NIVELES DE STAKING:
 * 1. Sequencer Staking - Validadores que operan el sequencer (stake mínimo: 100,000 ANDE)
 * 2. Governance Staking - Lock periods para voting power (3, 6, 12, 24 meses)
 * 3. Liquidity Staking - Sin lock period, menor APY
 */
contract AndeNativeStaking is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant REWARD_DISTRIBUTOR_ROLE = keccak256("REWARD_DISTRIBUTOR_ROLE");
    bytes32 public constant SEQUENCER_MANAGER_ROLE = keccak256("SEQUENCER_MANAGER_ROLE");

    enum StakingLevel {
        LIQUIDITY,
        GOVERNANCE,
        SEQUENCER
    }

    enum LockPeriod {
        NONE,
        THREE_MONTHS,
        SIX_MONTHS,
        TWELVE_MONTHS,
        TWENTY_FOUR_MONTHS
    }

    struct StakeInfo {
        uint256 amount;
        StakingLevel level;
        LockPeriod lockPeriod;
        uint256 lockUntil;
        uint256 votingPower;
        uint256 rewardDebt;
        uint256 stakedAt;
        bool isSequencer;
        uint256 lastStakeBlock;
        uint256 lastStakeTimestamp;
    }
    
    struct CircuitBreaker {
        bool stakingPaused;
        bool unstakingPaused;
        bool rewardClaimPaused;
        bool rewardDistributionPaused;
        uint256 maxStakePerTx;
        uint256 maxUnstakePerTx;
        uint256 dailyWithdrawLimit;
        uint256 withdrawnToday;
        uint256 lastResetDay;
    }
    
    struct SequencerPerformance {
        uint256 totalBlocks;
        uint256 missedBlocks;
        uint256 lastActivityBlock;
        bool isActive;
        uint256 slashCount;
    }

    struct RewardPool {
        uint256 totalRewards;
        uint256 rewardPerShare;
        uint256 lastUpdateTime;
    }

    IERC20 public andeToken;

    uint256 public constant MIN_SEQUENCER_STAKE = 100_000 * 1e18;
    uint256 public constant MIN_GOVERNANCE_STAKE = 1_000 * 1e18;
    uint256 public constant MIN_LIQUIDITY_STAKE = 100 * 1e18;

    uint256 public constant SEQUENCER_SHARE = 4000;
    uint256 public constant GOVERNANCE_SHARE = 3000;
    uint256 public constant LIQUIDITY_SHARE = 3000;
    uint256 public constant BASIS_POINTS = 10000;

    uint256 public constant LOCK_3_MONTHS = 90 days;
    uint256 public constant LOCK_6_MONTHS = 180 days;
    uint256 public constant LOCK_12_MONTHS = 365 days;
    uint256 public constant LOCK_24_MONTHS = 730 days;

    uint256 public constant MULTIPLIER_3_MONTHS = 10500;
    uint256 public constant MULTIPLIER_6_MONTHS = 12000;
    uint256 public constant MULTIPLIER_12_MONTHS = 15000;
    uint256 public constant MULTIPLIER_24_MONTHS = 20000;

    mapping(address => StakeInfo) public stakes;
    mapping(StakingLevel => RewardPool) public rewardPools;
    mapping(StakingLevel => uint256) public totalStaked;

    uint256 public totalVotingPower;
    address[] public sequencers;
    mapping(address => bool) public isActiveSequencer;
    
    CircuitBreaker public circuitBreaker;
    mapping(address => SequencerPerformance) public sequencerPerformance;
    address public treasury;
    
    uint256 public constant MIN_VOTING_POWER_BLOCKS = 2;
    uint256 public constant MIN_VOTING_POWER_TIME = 1 hours;
    uint256 public constant MAX_SLASHES = 3;
    uint256 public constant SLASH_PERCENTAGE = 500;
    uint256 public totalRewardDebt;

    event Staked(
        address indexed user,
        uint256 amount,
        StakingLevel level,
        LockPeriod lockPeriod,
        uint256 votingPower
    );
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsDistributed(StakingLevel level, uint256 amount);
    event SequencerRegistered(address indexed sequencer);
    event SequencerRemoved(address indexed sequencer);
    event LockExtended(address indexed user, LockPeriod newLockPeriod, uint256 newLockUntil);
    event SequencerSlashed(address indexed sequencer, uint256 amount, string reason);
    event CircuitBreakerTriggered(string breakerType, bool enabled);
    event DailyLimitUpdated(uint256 newLimit);
    event InvariantCheckFailed(string invariantType, uint256 expected, uint256 actual);

    error InsufficientStakeAmount();
    error StakeStillLocked();
    error NoStakeFound();
    error InvalidLockPeriod();
    error NotSequencer();
    error SequencerStakeRequired();
    error InvalidStakingLevel();
    error CannotReduceLockPeriod();
    error InvariantViolation(string reason);
    error StakingPaused();
    error UnstakingPaused();
    error RewardClaimPaused();
    error RewardDistributionPaused();
    error ExceedsMaxPerTx();
    error ExceedsDailyLimit();
    error MaxSlashesReached();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _andeToken, address defaultAdmin, address _treasury) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        andeToken = IERC20(_andeToken);
        treasury = _treasury;

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(REWARD_DISTRIBUTOR_ROLE, defaultAdmin);
        _grantRole(SEQUENCER_MANAGER_ROLE, defaultAdmin);

        rewardPools[StakingLevel.SEQUENCER].lastUpdateTime = block.timestamp;
        rewardPools[StakingLevel.GOVERNANCE].lastUpdateTime = block.timestamp;
        rewardPools[StakingLevel.LIQUIDITY].lastUpdateTime = block.timestamp;
        
        circuitBreaker.dailyWithdrawLimit = 1_000_000 * 1e18;
        circuitBreaker.maxStakePerTx = 10_000_000 * 1e18;
        circuitBreaker.maxUnstakePerTx = 1_000_000 * 1e18;
        circuitBreaker.lastResetDay = block.timestamp / 1 days;
    }

    modifier checkInvariants() {
        _;
        _verifyInvariants();
    }
    
    modifier whenStakingEnabled() {
        if (circuitBreaker.stakingPaused || paused()) revert StakingPaused();
        _;
    }
    
    modifier whenUnstakingEnabled() {
        if (circuitBreaker.unstakingPaused || paused()) revert UnstakingPaused();
        _;
    }
    
    modifier whenRewardClaimEnabled() {
        if (circuitBreaker.rewardClaimPaused) revert RewardClaimPaused();
        _;
    }
    
    modifier whenRewardDistributionEnabled() {
        if (circuitBreaker.rewardDistributionPaused) revert RewardDistributionPaused();
        _;
    }
    
    modifier checkDailyLimit(uint256 amount) {
        _resetDailyLimitIfNeeded();
        if (circuitBreaker.withdrawnToday + amount > circuitBreaker.dailyWithdrawLimit) {
            revert ExceedsDailyLimit();
        }
        circuitBreaker.withdrawnToday += amount;
        _;
    }
    
    modifier checkMaxPerTx(uint256 amount, bool isStake) {
        if (isStake && amount > circuitBreaker.maxStakePerTx) revert ExceedsMaxPerTx();
        if (!isStake && amount > circuitBreaker.maxUnstakePerTx) revert ExceedsMaxPerTx();
        _;
    }

    function stakeLiquidity(uint256 amount) 
        external 
        whenStakingEnabled 
        nonReentrant 
        checkMaxPerTx(amount, true)
        checkInvariants
    {
        if (amount < MIN_LIQUIDITY_STAKE) revert InsufficientStakeAmount();

        _updateRewardPool(StakingLevel.LIQUIDITY);
        _stake(msg.sender, amount, StakingLevel.LIQUIDITY, LockPeriod.NONE);
    }

    function stakeGovernance(uint256 amount, LockPeriod lockPeriod)
        external
        whenStakingEnabled
        nonReentrant
        checkMaxPerTx(amount, true)
        checkInvariants
    {
        if (amount < MIN_GOVERNANCE_STAKE) revert InsufficientStakeAmount();
        if (lockPeriod == LockPeriod.NONE) revert InvalidLockPeriod();

        _updateRewardPool(StakingLevel.GOVERNANCE);
        _stake(msg.sender, amount, StakingLevel.GOVERNANCE, lockPeriod);
    }

    function stakeSequencer(uint256 amount) 
        external 
        whenStakingEnabled 
        nonReentrant 
        checkMaxPerTx(amount, true)
        checkInvariants
    {
        if (amount < MIN_SEQUENCER_STAKE) revert InsufficientStakeAmount();

        _updateRewardPool(StakingLevel.SEQUENCER);
        _stake(msg.sender, amount, StakingLevel.SEQUENCER, LockPeriod.TWELVE_MONTHS);

        stakes[msg.sender].isSequencer = true;
    }

    function _stake(
        address user,
        uint256 amount,
        StakingLevel level,
        LockPeriod lockPeriod
    ) internal {
        StakeInfo storage stake = stakes[user];

        if (stake.amount > 0) {
            _claimRewards(user);
        }

        andeToken.safeTransferFrom(user, address(this), amount);

        uint256 lockDuration = _getLockDuration(lockPeriod);
        uint256 votingPower = _calculateVotingPower(amount, lockPeriod);

        stake.amount += amount;
        stake.level = level;
        stake.lockPeriod = lockPeriod;
        stake.lockUntil = block.timestamp + lockDuration;
        stake.votingPower += votingPower;
        stake.stakedAt = block.timestamp;
        stake.lastStakeBlock = block.number;
        stake.lastStakeTimestamp = block.timestamp;
        
        uint256 newRewardDebt = (stake.amount * rewardPools[level].rewardPerShare) / 1e18;
        totalRewardDebt = totalRewardDebt - stake.rewardDebt + newRewardDebt;
        stake.rewardDebt = newRewardDebt;

        totalStaked[level] += amount;
        if (level == StakingLevel.GOVERNANCE) {
            totalVotingPower += votingPower;
        }

        emit Staked(user, amount, level, lockPeriod, votingPower);
    }

    function unstake() 
        external 
        whenUnstakingEnabled 
        nonReentrant 
        checkMaxPerTx(stakes[msg.sender].amount, false)
        checkDailyLimit(stakes[msg.sender].amount)
        checkInvariants
    {
        StakeInfo storage stake = stakes[msg.sender];
        if (stake.amount == 0) revert NoStakeFound();
        if (block.timestamp < stake.lockUntil) revert StakeStillLocked();

        _updateRewardPool(stake.level);
        uint256 reward = _claimRewards(msg.sender);

        uint256 amount = stake.amount;
        StakingLevel level = stake.level;
        uint256 rewardDebt = stake.rewardDebt;

        totalStaked[level] -= amount;
        totalRewardDebt -= rewardDebt;
        
        if (level == StakingLevel.GOVERNANCE) {
            totalVotingPower -= stake.votingPower;
        }

        if (stake.isSequencer) {
            _removeSequencer(msg.sender);
        }

        delete stakes[msg.sender];

        andeToken.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount, reward);
    }

    function claimRewards() 
        external 
        whenRewardClaimEnabled 
        nonReentrant 
    {
        StakeInfo storage stake = stakes[msg.sender];
        if (stake.amount == 0) revert NoStakeFound();

        _updateRewardPool(stake.level);
        uint256 reward = _claimRewards(msg.sender);

        emit RewardsClaimed(msg.sender, reward);
    }

    function _claimRewards(address user) internal returns (uint256) {
        StakeInfo storage stake = stakes[user];
        RewardPool storage pool = rewardPools[stake.level];

        uint256 pending = (stake.amount * pool.rewardPerShare) / 1e18 - stake.rewardDebt;

        if (pending > 0) {
            andeToken.safeTransfer(user, pending);
            uint256 oldRewardDebt = stake.rewardDebt;
            uint256 newRewardDebt = (stake.amount * pool.rewardPerShare) / 1e18;
            stake.rewardDebt = newRewardDebt;
            totalRewardDebt = totalRewardDebt - oldRewardDebt + newRewardDebt;
        }

        return pending;
    }

    function distributeRewards(uint256 totalAmount) 
        external 
        onlyRole(REWARD_DISTRIBUTOR_ROLE) 
        whenRewardDistributionEnabled
        checkInvariants
    {
        uint256 sequencerAmount = (totalAmount * SEQUENCER_SHARE) / BASIS_POINTS;
        uint256 governanceAmount = (totalAmount * GOVERNANCE_SHARE) / BASIS_POINTS;
        uint256 liquidityAmount = (totalAmount * LIQUIDITY_SHARE) / BASIS_POINTS;

        andeToken.safeTransferFrom(msg.sender, address(this), totalAmount);

        if (totalStaked[StakingLevel.SEQUENCER] > 0) {
            _distributeToPool(StakingLevel.SEQUENCER, sequencerAmount);
        }
        if (totalStaked[StakingLevel.GOVERNANCE] > 0) {
            _distributeToPool(StakingLevel.GOVERNANCE, governanceAmount);
        }
        if (totalStaked[StakingLevel.LIQUIDITY] > 0) {
            _distributeToPool(StakingLevel.LIQUIDITY, liquidityAmount);
        }
    }

    function _distributeToPool(StakingLevel level, uint256 amount) internal {
        _updateRewardPool(level);
        RewardPool storage pool = rewardPools[level];

        pool.totalRewards += amount;
        pool.rewardPerShare += (amount * 1e18) / totalStaked[level];

        emit RewardsDistributed(level, amount);
    }

    function _updateRewardPool(StakingLevel level) internal {
        rewardPools[level].lastUpdateTime = block.timestamp;
    }

    function registerSequencer(address sequencer) external onlyRole(SEQUENCER_MANAGER_ROLE) {
        StakeInfo storage stake = stakes[sequencer];
        if (stake.amount < MIN_SEQUENCER_STAKE) revert SequencerStakeRequired();
        if (!stake.isSequencer) revert NotSequencer();

        if (!isActiveSequencer[sequencer]) {
            sequencers.push(sequencer);
            isActiveSequencer[sequencer] = true;
            emit SequencerRegistered(sequencer);
        }
    }

    function _removeSequencer(address sequencer) internal {
        if (isActiveSequencer[sequencer]) {
            isActiveSequencer[sequencer] = false;
            emit SequencerRemoved(sequencer);
        }
    }

    function extendLock(LockPeriod newLockPeriod) external {
        StakeInfo storage stake = stakes[msg.sender];
        if (stake.amount == 0) revert NoStakeFound();
        if (uint256(newLockPeriod) <= uint256(stake.lockPeriod)) revert CannotReduceLockPeriod();

        uint256 lockDuration = _getLockDuration(newLockPeriod);
        uint256 oldVotingPower = stake.votingPower;
        uint256 newVotingPower = _calculateVotingPower(stake.amount, newLockPeriod);

        stake.lockPeriod = newLockPeriod;
        stake.lockUntil = block.timestamp + lockDuration;
        stake.votingPower = newVotingPower;

        if (stake.level == StakingLevel.GOVERNANCE) {
            totalVotingPower = totalVotingPower - oldVotingPower + newVotingPower;
        }

        emit LockExtended(msg.sender, newLockPeriod, stake.lockUntil);
    }

    function _calculateVotingPower(uint256 amount, LockPeriod lockPeriod)
        internal
        pure
        returns (uint256)
    {
        uint256 multiplier = _getLockMultiplier(lockPeriod);
        return (amount * multiplier) / BASIS_POINTS;
    }

    function _getLockMultiplier(LockPeriod lockPeriod) internal pure returns (uint256) {
        if (lockPeriod == LockPeriod.THREE_MONTHS) return MULTIPLIER_3_MONTHS;
        if (lockPeriod == LockPeriod.SIX_MONTHS) return MULTIPLIER_6_MONTHS;
        if (lockPeriod == LockPeriod.TWELVE_MONTHS) return MULTIPLIER_12_MONTHS;
        if (lockPeriod == LockPeriod.TWENTY_FOUR_MONTHS) return MULTIPLIER_24_MONTHS;
        return BASIS_POINTS;
    }

    function _getLockDuration(LockPeriod lockPeriod) internal pure returns (uint256) {
        if (lockPeriod == LockPeriod.THREE_MONTHS) return LOCK_3_MONTHS;
        if (lockPeriod == LockPeriod.SIX_MONTHS) return LOCK_6_MONTHS;
        if (lockPeriod == LockPeriod.TWELVE_MONTHS) return LOCK_12_MONTHS;
        if (lockPeriod == LockPeriod.TWENTY_FOUR_MONTHS) return LOCK_24_MONTHS;
        return 0;
    }

    function getStakeInfo(address user) external view returns (StakeInfo memory) {
        return stakes[user];
    }

    function getPendingRewards(address user) external view returns (uint256) {
        StakeInfo storage stake = stakes[user];
        if (stake.amount == 0) return 0;

        RewardPool storage pool = rewardPools[stake.level];
        return (stake.amount * pool.rewardPerShare) / 1e18 - stake.rewardDebt;
    }

    function getSequencers() external view returns (address[] memory) {
        return sequencers;
    }

    function getActiveSequencersCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < sequencers.length; i++) {
            if (isActiveSequencer[sequencers[i]]) {
                count++;
            }
        }
        return count;
    }

    function getVotingPowerWithFlashLoanProtection(address user) 
        external 
        view 
        returns (uint256) 
    {
        StakeInfo memory stake = stakes[user];
        
        if (block.number - stake.lastStakeBlock < MIN_VOTING_POWER_BLOCKS) {
            return 0;
        }
        
        if (block.timestamp - stake.lastStakeTimestamp < MIN_VOTING_POWER_TIME) {
            return 0;
        }
        
        return stake.votingPower;
    }
    
    function _verifyInvariants() internal view {
        uint256 contractBalance = andeToken.balanceOf(address(this));
        uint256 calculatedTotal = totalStaked[StakingLevel.LIQUIDITY] +
                                  totalStaked[StakingLevel.GOVERNANCE] +
                                  totalStaked[StakingLevel.SEQUENCER];
        
        if (calculatedTotal > contractBalance) {
            revert InvariantViolation("Total staked exceeds contract balance");
        }
        
        if (totalStaked[StakingLevel.GOVERNANCE] > 0 || 
            totalStaked[StakingLevel.LIQUIDITY] > 0 || 
            totalStaked[StakingLevel.SEQUENCER] > 0) {
            if (contractBalance == 0) {
                revert InvariantViolation("Non-zero stakes with zero balance");
            }
        }
    }
    
    function _resetDailyLimitIfNeeded() internal {
        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay > circuitBreaker.lastResetDay) {
            circuitBreaker.withdrawnToday = 0;
            circuitBreaker.lastResetDay = currentDay;
        }
    }
    
    function slashSequencer(address sequencer, string memory reason)
        external
        onlyRole(SEQUENCER_MANAGER_ROLE)
    {
        if (!isActiveSequencer[sequencer]) revert NotSequencer();
        
        StakeInfo storage stake = stakes[sequencer];
        if (!stake.isSequencer) revert NotSequencer();
        
        if (sequencerPerformance[sequencer].slashCount >= MAX_SLASHES) {
            revert MaxSlashesReached();
        }
        
        uint256 slashAmount = (stake.amount * SLASH_PERCENTAGE) / BASIS_POINTS;
        
        stake.amount -= slashAmount;
        totalStaked[stake.level] -= slashAmount;
        
        if (stake.level == StakingLevel.GOVERNANCE) {
            uint256 lostVotingPower = (stake.votingPower * SLASH_PERCENTAGE) / BASIS_POINTS;
            stake.votingPower -= lostVotingPower;
            totalVotingPower -= lostVotingPower;
        }
        
        andeToken.safeTransfer(treasury, slashAmount);
        
        sequencerPerformance[sequencer].slashCount++;
        
        emit SequencerSlashed(sequencer, slashAmount, reason);
        
        if (sequencerPerformance[sequencer].slashCount >= MAX_SLASHES) {
            _removeSequencer(sequencer);
        }
    }
    
    function emergencyPauseStaking() external onlyRole(PAUSER_ROLE) {
        circuitBreaker.stakingPaused = true;
        emit CircuitBreakerTriggered("staking", true);
    }
    
    function emergencyResumeStaking() external onlyRole(PAUSER_ROLE) {
        circuitBreaker.stakingPaused = false;
        emit CircuitBreakerTriggered("staking", false);
    }
    
    function emergencyPauseUnstaking() external onlyRole(PAUSER_ROLE) {
        circuitBreaker.unstakingPaused = true;
        emit CircuitBreakerTriggered("unstaking", true);
    }
    
    function emergencyResumeUnstaking() external onlyRole(PAUSER_ROLE) {
        circuitBreaker.unstakingPaused = false;
        emit CircuitBreakerTriggered("unstaking", false);
    }
    
    function emergencyPauseRewardClaim() external onlyRole(PAUSER_ROLE) {
        circuitBreaker.rewardClaimPaused = true;
        emit CircuitBreakerTriggered("rewardClaim", true);
    }
    
    function emergencyResumeRewardClaim() external onlyRole(PAUSER_ROLE) {
        circuitBreaker.rewardClaimPaused = false;
        emit CircuitBreakerTriggered("rewardClaim", false);
    }
    
    function emergencyPauseRewardDistribution() external onlyRole(PAUSER_ROLE) {
        circuitBreaker.rewardDistributionPaused = true;
        emit CircuitBreakerTriggered("rewardDistribution", true);
    }
    
    function emergencyResumeRewardDistribution() external onlyRole(PAUSER_ROLE) {
        circuitBreaker.rewardDistributionPaused = false;
        emit CircuitBreakerTriggered("rewardDistribution", false);
    }
    
    function setDailyWithdrawLimit(uint256 newLimit) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        circuitBreaker.dailyWithdrawLimit = newLimit;
        emit DailyLimitUpdated(newLimit);
    }
    
    function setMaxStakePerTx(uint256 newMax) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        circuitBreaker.maxStakePerTx = newMax;
    }
    
    function setMaxUnstakePerTx(uint256 newMax) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        circuitBreaker.maxUnstakePerTx = newMax;
    }
    
    function setTreasury(address newTreasury) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        treasury = newTreasury;
    }
    
    function recordSequencerActivity(address sequencer) 
        external 
        onlyRole(SEQUENCER_MANAGER_ROLE) 
    {
        sequencerPerformance[sequencer].totalBlocks++;
        sequencerPerformance[sequencer].lastActivityBlock = block.number;
        sequencerPerformance[sequencer].isActive = true;
    }
    
    function recordSequencerMiss(address sequencer) 
        external 
        onlyRole(SEQUENCER_MANAGER_ROLE) 
    {
        sequencerPerformance[sequencer].missedBlocks++;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
