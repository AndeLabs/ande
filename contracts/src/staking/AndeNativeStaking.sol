// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
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

    error InsufficientStakeAmount();
    error StakeStillLocked();
    error NoStakeFound();
    error InvalidLockPeriod();
    error NotSequencer();
    error SequencerStakeRequired();
    error InvalidStakingLevel();
    error CannotReduceLockPeriod();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _andeToken, address defaultAdmin) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        andeToken = IERC20(_andeToken);

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(REWARD_DISTRIBUTOR_ROLE, defaultAdmin);
        _grantRole(SEQUENCER_MANAGER_ROLE, defaultAdmin);

        rewardPools[StakingLevel.SEQUENCER].lastUpdateTime = block.timestamp;
        rewardPools[StakingLevel.GOVERNANCE].lastUpdateTime = block.timestamp;
        rewardPools[StakingLevel.LIQUIDITY].lastUpdateTime = block.timestamp;
    }

    function stakeLiquidity(uint256 amount) external whenNotPaused nonReentrant {
        if (amount < MIN_LIQUIDITY_STAKE) revert InsufficientStakeAmount();

        _updateRewardPool(StakingLevel.LIQUIDITY);
        _stake(msg.sender, amount, StakingLevel.LIQUIDITY, LockPeriod.NONE);
    }

    function stakeGovernance(uint256 amount, LockPeriod lockPeriod)
        external
        whenNotPaused
        nonReentrant
    {
        if (amount < MIN_GOVERNANCE_STAKE) revert InsufficientStakeAmount();
        if (lockPeriod == LockPeriod.NONE) revert InvalidLockPeriod();

        _updateRewardPool(StakingLevel.GOVERNANCE);
        _stake(msg.sender, amount, StakingLevel.GOVERNANCE, lockPeriod);
    }

    function stakeSequencer(uint256 amount) external whenNotPaused nonReentrant {
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
        stake.rewardDebt = (stake.amount * rewardPools[level].rewardPerShare) / 1e18;

        totalStaked[level] += amount;
        if (level == StakingLevel.GOVERNANCE) {
            totalVotingPower += votingPower;
        }

        emit Staked(user, amount, level, lockPeriod, votingPower);
    }

    function unstake() external nonReentrant {
        StakeInfo storage stake = stakes[msg.sender];
        if (stake.amount == 0) revert NoStakeFound();
        if (block.timestamp < stake.lockUntil) revert StakeStillLocked();

        _updateRewardPool(stake.level);
        uint256 reward = _claimRewards(msg.sender);

        uint256 amount = stake.amount;
        StakingLevel level = stake.level;

        totalStaked[level] -= amount;
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

    function claimRewards() external nonReentrant {
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
            stake.rewardDebt = (stake.amount * pool.rewardPerShare) / 1e18;
        }

        return pending;
    }

    function distributeRewards(uint256 totalAmount) external onlyRole(REWARD_DISTRIBUTOR_ROLE) {
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
