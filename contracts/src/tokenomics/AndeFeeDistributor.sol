// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title AndeFeeDistributor
 * @author Ande Labs
 * @notice Distribuye todas las fees del network entre sequencers, stakers, protocol y Pachamama Fund
 * @dev Sistema de distribución completo de fees (no solo MEV)
 *
 * DISTRIBUCIÓN DE FEES:
 * - 40% → Sequencer operator
 * - 30% → Stakers (delegators)
 * - 20% → Protocol treasury
 * - 10% → Pachamama Fund
 */
contract AndeFeeDistributor is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant FEE_COLLECTOR_ROLE = keccak256("FEE_COLLECTOR_ROLE");

    struct FeeDistributionConfig {
        uint256 sequencerShare;
        uint256 stakersShare;
        uint256 protocolShare;
        uint256 pachamamaShare;
    }

    struct EpochStats {
        uint256 totalFeesCollected;
        uint256 sequencerFees;
        uint256 stakersFees;
        uint256 protocolFees;
        uint256 pachamamaFees;
        uint256 startTime;
        uint256 endTime;
    }

    IERC20 public andeToken;
    address public sequencerRegistry;
    address public stakingContract;
    address public protocolTreasury;
    address public pachamamaFund;

    FeeDistributionConfig public distributionConfig;

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant EPOCH_DURATION = 7 days;

    uint256 public currentEpoch;
    mapping(uint256 => EpochStats) public epochStats;

    uint256 public totalFeesCollected;
    uint256 public totalSequencerFees;
    uint256 public totalStakersFees;
    uint256 public totalProtocolFees;
    uint256 public totalPachamamaFees;

    event FeesCollected(address indexed from, uint256 amount, uint256 epoch);
    event FeesDistributed(
        uint256 indexed epoch,
        uint256 sequencerFees,
        uint256 stakersFees,
        uint256 protocolFees,
        uint256 pachamamaFees
    );
    event DistributionConfigUpdated(
        uint256 sequencerShare,
        uint256 stakersShare,
        uint256 protocolShare,
        uint256 pachamamaShare
    );
    event EpochEnded(uint256 indexed epoch, uint256 totalFees);
    event ContractAddressUpdated(string indexed contractType, address newAddress);

    error InvalidDistributionShares();
    error ZeroAddress();
    error InsufficientBalance();
    error EpochNotEnded();
    error InvalidAmount();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _andeToken,
        address _sequencerRegistry,
        address _stakingContract,
        address _protocolTreasury,
        address _pachamamaFund,
        address defaultAdmin
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        if (
            _andeToken == address(0) || _sequencerRegistry == address(0)
                || _stakingContract == address(0) || _protocolTreasury == address(0)
                || _pachamamaFund == address(0)
        ) revert ZeroAddress();

        andeToken = IERC20(_andeToken);
        sequencerRegistry = _sequencerRegistry;
        stakingContract = _stakingContract;
        protocolTreasury = _protocolTreasury;
        pachamamaFund = _pachamamaFund;

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(FEE_COLLECTOR_ROLE, defaultAdmin);

        distributionConfig = FeeDistributionConfig({
            sequencerShare: 4000,
            stakersShare: 3000,
            protocolShare: 2000,
            pachamamaShare: 1000
        });

        epochStats[currentEpoch].startTime = block.timestamp;
    }

    function collectFees(uint256 amount) external onlyRole(FEE_COLLECTOR_ROLE) whenNotPaused {
        if (amount == 0) revert InvalidAmount();

        andeToken.safeTransferFrom(msg.sender, address(this), amount);

        EpochStats storage stats = epochStats[currentEpoch];
        stats.totalFeesCollected += amount;
        totalFeesCollected += amount;

        emit FeesCollected(msg.sender, amount, currentEpoch);
    }

    function distributeFees() external nonReentrant whenNotPaused {
        EpochStats storage stats = epochStats[currentEpoch];

        if (stats.totalFeesCollected == 0) revert InsufficientBalance();

        uint256 totalFees = stats.totalFeesCollected;

        uint256 sequencerFees = (totalFees * distributionConfig.sequencerShare) / BASIS_POINTS;
        uint256 stakersFees = (totalFees * distributionConfig.stakersShare) / BASIS_POINTS;
        uint256 protocolFees = (totalFees * distributionConfig.protocolShare) / BASIS_POINTS;
        uint256 pachamamaFees = (totalFees * distributionConfig.pachamamaShare) / BASIS_POINTS;

        stats.sequencerFees = sequencerFees;
        stats.stakersFees = stakersFees;
        stats.protocolFees = protocolFees;
        stats.pachamamaFees = pachamamaFees;

        totalSequencerFees += sequencerFees;
        totalStakersFees += stakersFees;
        totalProtocolFees += protocolFees;
        totalPachamamaFees += pachamamaFees;

        if (sequencerFees > 0) {
            andeToken.safeTransfer(sequencerRegistry, sequencerFees);
        }
        if (stakersFees > 0) {
            andeToken.safeTransfer(stakingContract, stakersFees);
        }
        if (protocolFees > 0) {
            andeToken.safeTransfer(protocolTreasury, protocolFees);
        }
        if (pachamamaFees > 0) {
            andeToken.safeTransfer(pachamamaFund, pachamamaFees);
        }

        emit FeesDistributed(currentEpoch, sequencerFees, stakersFees, protocolFees, pachamamaFees);
    }

    function endEpoch() external onlyRole(DEFAULT_ADMIN_ROLE) {
        EpochStats storage stats = epochStats[currentEpoch];

        if (block.timestamp < stats.startTime + EPOCH_DURATION) revert EpochNotEnded();

        stats.endTime = block.timestamp;

        emit EpochEnded(currentEpoch, stats.totalFeesCollected);

        currentEpoch++;
        epochStats[currentEpoch].startTime = block.timestamp;
    }

    function updateDistributionConfig(
        uint256 sequencerShare,
        uint256 stakersShare,
        uint256 protocolShare,
        uint256 pachamamaShare
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (sequencerShare + stakersShare + protocolShare + pachamamaShare != BASIS_POINTS) {
            revert InvalidDistributionShares();
        }

        distributionConfig = FeeDistributionConfig({
            sequencerShare: sequencerShare,
            stakersShare: stakersShare,
            protocolShare: protocolShare,
            pachamamaShare: pachamamaShare
        });

        emit DistributionConfigUpdated(sequencerShare, stakersShare, protocolShare, pachamamaShare);
    }

    function updateSequencerRegistry(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newAddress == address(0)) revert ZeroAddress();
        sequencerRegistry = newAddress;
        emit ContractAddressUpdated("sequencerRegistry", newAddress);
    }

    function updateStakingContract(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newAddress == address(0)) revert ZeroAddress();
        stakingContract = newAddress;
        emit ContractAddressUpdated("stakingContract", newAddress);
    }

    function updateProtocolTreasury(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newAddress == address(0)) revert ZeroAddress();
        protocolTreasury = newAddress;
        emit ContractAddressUpdated("protocolTreasury", newAddress);
    }

    function updatePachamamaFund(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newAddress == address(0)) revert ZeroAddress();
        pachamamaFund = newAddress;
        emit ContractAddressUpdated("pachamamaFund", newAddress);
    }

    function getEpochStats(uint256 epoch) external view returns (EpochStats memory) {
        return epochStats[epoch];
    }

    function getCurrentEpochStats() external view returns (EpochStats memory) {
        return epochStats[currentEpoch];
    }

    function getTotalStats()
        external
        view
        returns (
            uint256 _totalFeesCollected,
            uint256 _totalSequencerFees,
            uint256 _totalStakersFees,
            uint256 _totalProtocolFees,
            uint256 _totalPachamamaFees
        )
    {
        return (
            totalFeesCollected,
            totalSequencerFees,
            totalStakersFees,
            totalProtocolFees,
            totalPachamamaFees
        );
    }

    function getDistributionConfig() external view returns (FeeDistributionConfig memory) {
        return distributionConfig;
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
