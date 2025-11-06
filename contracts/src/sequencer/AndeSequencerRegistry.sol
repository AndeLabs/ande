// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title AndeSequencerRegistry
 * @author Ande Labs
 * @notice Sistema de registro y gestión de sequencers con descentralización progresiva
 * @dev Implementa las 4 fases del plan de transición de sequencers
 *
 * FASES:
 * 1. Genesis Sequencer (Mes 0-6) - 1 sequencer centralizado (Foundation)
 * 2. Dual Sequencer (Mes 6-12) - 2 sequencers con rotación
 * 3. Multi-Sequencer Set (Mes 12-24) - 5-7 sequencers
 * 4. Fully Decentralized (Mes 24+) - 20+ sequencers
 */
contract AndeSequencerRegistry is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SEQUENCER_MANAGER_ROLE = keccak256("SEQUENCER_MANAGER_ROLE");

    enum Phase {
        GENESIS,
        DUAL,
        MULTI,
        DECENTRALIZED
    }

    struct SequencerInfo {
        address sequencer;
        uint256 stakedAmount;
        uint256 registeredAt;
        uint256 lastBlockProduced;
        uint256 totalBlocksProduced;
        uint256 uptime;
        bool isActive;
        bool isPermanent;
        string endpoint;
    }

    struct EpochInfo {
        uint256 startTime;
        uint256 endTime;
        address[] activeSequencers;
        mapping(address => uint256) blocksProduced;
        mapping(address => uint256) rewards;
    }

    Phase public currentPhase;
    uint256 public genesisTimestamp;

    uint256 public constant MIN_STAKE_GENESIS = 0;
    uint256 public constant MIN_STAKE_DUAL = 50_000 * 1e18;
    uint256 public constant MIN_STAKE_MULTI = 100_000 * 1e18;
    uint256 public constant MIN_STAKE_DECENTRALIZED = 100_000 * 1e18;

    uint256 public constant PHASE_1_DURATION = 180 days;
    uint256 public constant PHASE_2_DURATION = 180 days;
    uint256 public constant PHASE_3_DURATION = 365 days;

    uint256 public constant MIN_UPTIME_PERCENTAGE = 9900;
    uint256 public constant BASIS_POINTS = 10000;

    uint256 public constant EPOCH_DURATION = 90 days;

    mapping(address => SequencerInfo) public sequencers;
    address[] public sequencerList;
    address[] public activeSequencers;

    uint256 public currentEpoch;
    mapping(uint256 => EpochInfo) public epochs;

    uint256 public maxSequencersPhase2 = 2;
    uint256 public maxSequencersPhase3 = 7;
    uint256 public maxSequencersPhase4 = 100;

    uint256 public currentLeaderIndex;
    uint256 public blocksPerRotation = 100;

    event PhaseTransitioned(Phase oldPhase, Phase newPhase, uint256 timestamp);
    event SequencerRegistered(address indexed sequencer, uint256 stakedAmount, bool isPermanent);
    event SequencerRemoved(address indexed sequencer, string reason);
    event SequencerSlashed(address indexed sequencer, uint256 amount, string reason);
    event EpochStarted(uint256 indexed epoch, uint256 startTime, address[] sequencers);
    event EpochEnded(uint256 indexed epoch, uint256 endTime);
    event LeaderRotated(address indexed oldLeader, address indexed newLeader, uint256 blockNumber);
    event BlockProduced(address indexed sequencer, uint256 blockNumber, uint256 timestamp);

    error InvalidPhase();
    error InsufficientStake();
    error SequencerAlreadyRegistered();
    error SequencerNotFound();
    error MaxSequencersReached();
    error BelowMinUptime();
    error NotActiveSequencer();
    error CannotRemovePermanentSequencer();
    error EpochNotEnded();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address foundation) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(SEQUENCER_MANAGER_ROLE, defaultAdmin);

        genesisTimestamp = block.timestamp;
        currentPhase = Phase.GENESIS;
        
        // Initialize state variables (required for proxy pattern)
        blocksPerRotation = 100;
        currentLeaderIndex = 0;
        currentEpoch = 1;
        maxSequencersPhase2 = 2;
        maxSequencersPhase3 = 7;
        maxSequencersPhase4 = 100;

        _registerGenesisSequencer(foundation);

        _startEpoch();
    }

    function _registerGenesisSequencer(address foundation) internal {
        SequencerInfo storage seq = sequencers[foundation];
        seq.sequencer = foundation;
        seq.stakedAmount = 0;
        seq.registeredAt = block.timestamp;
        seq.isActive = true;
        seq.isPermanent = true;
        seq.endpoint = "";

        sequencerList.push(foundation);
        activeSequencers.push(foundation);

        emit SequencerRegistered(foundation, 0, true);
    }

    function registerSequencer(address sequencer, uint256 stakedAmount, string calldata endpoint)
        external
        onlyRole(SEQUENCER_MANAGER_ROLE)
        whenNotPaused
    {
        if (sequencers[sequencer].sequencer != address(0)) revert SequencerAlreadyRegistered();

        uint256 minStake = _getMinStakeForPhase();
        if (stakedAmount < minStake) revert InsufficientStake();

        uint256 maxSequencers = _getMaxSequencersForPhase();
        if (activeSequencers.length >= maxSequencers) revert MaxSequencersReached();

        SequencerInfo storage seq = sequencers[sequencer];
        seq.sequencer = sequencer;
        seq.stakedAmount = stakedAmount;
        seq.registeredAt = block.timestamp;
        seq.isActive = true;
        seq.isPermanent = false;
        seq.endpoint = endpoint;

        sequencerList.push(sequencer);
        activeSequencers.push(sequencer);

        emit SequencerRegistered(sequencer, stakedAmount, false);
    }

    function removeSequencer(address sequencer, string calldata reason)
        external
        onlyRole(SEQUENCER_MANAGER_ROLE)
    {
        _removeSequencer(sequencer, reason);
    }

    function slashSequencer(address sequencer, uint256 amount, string calldata reason)
        external
        onlyRole(SEQUENCER_MANAGER_ROLE)
    {
        SequencerInfo storage seq = sequencers[sequencer];
        if (seq.sequencer == address(0)) revert SequencerNotFound();
        if (!seq.isActive) revert NotActiveSequencer();

        seq.stakedAmount -= amount;

        emit SequencerSlashed(sequencer, amount, reason);

        uint256 minStake = _getMinStakeForPhase();
        if (seq.stakedAmount < minStake && !seq.isPermanent) {
            _removeSequencer(sequencer, "Insufficient stake after slashing");
        }
    }

    function _removeSequencer(address sequencer, string memory reason) internal {
        SequencerInfo storage seq = sequencers[sequencer];
        if (seq.sequencer == address(0)) revert SequencerNotFound();
        if (seq.isPermanent) revert CannotRemovePermanentSequencer();

        seq.isActive = false;

        for (uint256 i = 0; i < activeSequencers.length; i++) {
            if (activeSequencers[i] == sequencer) {
                activeSequencers[i] = activeSequencers[activeSequencers.length - 1];
                activeSequencers.pop();
                break;
            }
        }

        emit SequencerRemoved(sequencer, reason);
    }

    function recordBlockProduced(address sequencer) external onlyRole(SEQUENCER_MANAGER_ROLE) whenNotPaused {
        SequencerInfo storage seq = sequencers[sequencer];
        if (seq.sequencer == address(0)) revert SequencerNotFound();
        if (!seq.isActive) revert NotActiveSequencer();

        seq.lastBlockProduced = block.timestamp;
        seq.totalBlocksProduced++;

        EpochInfo storage epoch = epochs[currentEpoch];
        epoch.blocksProduced[sequencer]++;

        emit BlockProduced(sequencer, block.number, block.timestamp);

        if (seq.totalBlocksProduced % blocksPerRotation == 0) {
            _rotateLeader();
        }
    }

    function _rotateLeader() internal {
        if (activeSequencers.length == 0) return;

        address oldLeader = activeSequencers[currentLeaderIndex];
        currentLeaderIndex = (currentLeaderIndex + 1) % activeSequencers.length;
        address newLeader = activeSequencers[currentLeaderIndex];

        emit LeaderRotated(oldLeader, newLeader, block.number);
    }

    function getCurrentLeader() external view returns (address) {
        if (activeSequencers.length == 0) return address(0);
        return activeSequencers[currentLeaderIndex];
    }

    function transitionPhase() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 timeElapsed = block.timestamp - genesisTimestamp;

        Phase newPhase = currentPhase;

        if (currentPhase == Phase.GENESIS && timeElapsed >= PHASE_1_DURATION) {
            newPhase = Phase.DUAL;
        } else if (currentPhase == Phase.DUAL && timeElapsed >= PHASE_1_DURATION + PHASE_2_DURATION)
        {
            newPhase = Phase.MULTI;
        } else if (
            currentPhase == Phase.MULTI
                && timeElapsed >= PHASE_1_DURATION + PHASE_2_DURATION + PHASE_3_DURATION
        ) {
            newPhase = Phase.DECENTRALIZED;
        } else {
            revert InvalidPhase();
        }

        Phase oldPhase = currentPhase;
        currentPhase = newPhase;

        emit PhaseTransitioned(oldPhase, newPhase, block.timestamp);
    }

    function startNewEpoch() external onlyRole(SEQUENCER_MANAGER_ROLE) {
        EpochInfo storage oldEpoch = epochs[currentEpoch];
        if (block.timestamp < oldEpoch.startTime + EPOCH_DURATION) revert EpochNotEnded();

        oldEpoch.endTime = block.timestamp;
        emit EpochEnded(currentEpoch, block.timestamp);

        currentEpoch++;
        _startEpoch();
    }

    function _startEpoch() internal {
        EpochInfo storage epoch = epochs[currentEpoch];
        epoch.startTime = block.timestamp;
        epoch.activeSequencers = activeSequencers;

        emit EpochStarted(currentEpoch, block.timestamp, activeSequencers);
    }

    function updateSequencerUptime(address sequencer, uint256 uptimePercentage)
        external
        onlyRole(SEQUENCER_MANAGER_ROLE)
    {
        SequencerInfo storage seq = sequencers[sequencer];
        if (seq.sequencer == address(0)) revert SequencerNotFound();

        seq.uptime = uptimePercentage;

        if (uptimePercentage < MIN_UPTIME_PERCENTAGE && !seq.isPermanent) {
            _removeSequencer(sequencer, "Below minimum uptime");
        }
    }

    function _getMinStakeForPhase() internal view returns (uint256) {
        if (currentPhase == Phase.GENESIS) return MIN_STAKE_GENESIS;
        if (currentPhase == Phase.DUAL) return MIN_STAKE_DUAL;
        if (currentPhase == Phase.MULTI) return MIN_STAKE_MULTI;
        return MIN_STAKE_DECENTRALIZED;
    }

    function _getMaxSequencersForPhase() internal view returns (uint256) {
        if (currentPhase == Phase.GENESIS) return 1;
        if (currentPhase == Phase.DUAL) return maxSequencersPhase2;
        if (currentPhase == Phase.MULTI) return maxSequencersPhase3;
        return maxSequencersPhase4;
    }

    function getSequencerInfo(address sequencer) external view returns (SequencerInfo memory) {
        return sequencers[sequencer];
    }

    function getActiveSequencers() external view returns (address[] memory) {
        return activeSequencers;
    }

    function getActiveSequencersCount() external view returns (uint256) {
        return activeSequencers.length;
    }

    function getEpochInfo(uint256 epoch)
        external
        view
        returns (uint256 startTime, uint256 endTime, address[] memory sequencersList)
    {
        EpochInfo storage epochInfo = epochs[epoch];
        return (epochInfo.startTime, epochInfo.endTime, epochInfo.activeSequencers);
    }

    function getSequencerBlocksInEpoch(uint256 epoch, address sequencer)
        external
        view
        returns (uint256)
    {
        return epochs[epoch].blocksProduced[sequencer];
    }

    function getPhaseRequirements()
        external
        view
        returns (uint256 minStake, uint256 maxSequencers, uint256 minUptime)
    {
        minStake = _getMinStakeForPhase();
        maxSequencers = _getMaxSequencersForPhase();
        minUptime = MIN_UPTIME_PERCENTAGE;
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
