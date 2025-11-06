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
 * @notice Distributes all network fees among sequencers, stakers, protocol, and community treasury
 * @dev Complete fee distribution system (not just MEV)
 *
 * FEE DISTRIBUTION:
 * - 40% → Sequencer operator
 * - 30% → Stakers (delegators)
 * - 20% → Protocol treasury
 * - 10% → Community Treasury
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
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    struct FeeDistributionConfig {
        uint256 sequencerShare;
        uint256 stakersShare;
        uint256 protocolShare;
        uint256 communityTreasuryShare;
    }

    struct EpochStats {
        uint256 totalFeesCollected;
        uint256 sequencerFees;
        uint256 stakersFees;
        uint256 protocolFees;
        uint256 communityTreasuryFees;
        uint256 startTime;
        uint256 endTime;
    }

    IERC20 public andeToken;
    address public sequencerRegistry;
    address public stakingContract;
    address public protocolTreasury;
    address public communityTreasury;

    FeeDistributionConfig public distributionConfig;

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant EPOCH_DURATION = 7 days;

    uint256 public currentEpoch;
    mapping(uint256 => EpochStats) public epochStats;

    uint256 public totalFeesCollected;
    uint256 public totalSequencerFees;
    uint256 public totalStakersFees;
    uint256 public totalProtocolFees;
    uint256 public totalCommunityTreasuryFees;

    event FeesCollected(address indexed from, uint256 amount, uint256 epoch);
    event FeesDistributed(
        uint256 indexed epoch,
        uint256 sequencerFees,
        uint256 stakersFees,
        uint256 protocolFees,
        uint256 communityTreasuryFees
    );
    event DistributionConfigUpdated(
        uint256 sequencerShare,
        uint256 stakersShare,
        uint256 protocolShare,
        uint256 communityTreasuryShare
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
        address _communityTreasury,
        address defaultAdmin
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        if (
            _andeToken == address(0) || _sequencerRegistry == address(0)
                || _stakingContract == address(0) || _protocolTreasury == address(0)
                || _communityTreasury == address(0)
        ) revert ZeroAddress();

        andeToken = IERC20(_andeToken);
        sequencerRegistry = _sequencerRegistry;
        stakingContract = _stakingContract;
        protocolTreasury = _protocolTreasury;
        communityTreasury = _communityTreasury;

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(FEE_COLLECTOR_ROLE, defaultAdmin);

        distributionConfig = FeeDistributionConfig({
            sequencerShare: 4000,
            stakersShare: 3000,
            protocolShare: 2000,
            communityTreasuryShare: 1000
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
        uint256 communityTreasuryFees = (totalFees * distributionConfig.communityTreasuryShare) / BASIS_POINTS;

        stats.sequencerFees = sequencerFees;
        stats.stakersFees = stakersFees;
        stats.protocolFees = protocolFees;
        stats.communityTreasuryFees = communityTreasuryFees;

        totalSequencerFees += sequencerFees;
        totalStakersFees += stakersFees;
        totalProtocolFees += protocolFees;
        totalCommunityTreasuryFees += communityTreasuryFees;

        if (sequencerFees > 0) {
            andeToken.safeTransfer(sequencerRegistry, sequencerFees);
        }
        if (stakersFees > 0) {
            andeToken.safeTransfer(stakingContract, stakersFees);
        }
        if (protocolFees > 0) {
            andeToken.safeTransfer(protocolTreasury, protocolFees);
        }
        if (communityTreasuryFees > 0) {
            andeToken.safeTransfer(communityTreasury, communityTreasuryFees);
        }

        emit FeesDistributed(currentEpoch, sequencerFees, stakersFees, protocolFees, communityTreasuryFees);
    }

    function endEpoch() external onlyRole(DEFAULT_ADMIN_ROLE) {
        EpochStats storage stats = epochStats[currentEpoch];

        if (block.timestamp < stats.startTime + EPOCH_DURATION) revert EpochNotEnded();

        stats.endTime = block.timestamp;

        emit EpochEnded(currentEpoch, stats.totalFeesCollected);

        currentEpoch++;
        epochStats[currentEpoch].startTime = block.timestamp;
    }

    /**
     * @notice Actualiza configuración de distribución (Governor o Admin)
     * @dev Permite a governance ajustar la distribución de fees
     */
    function updateDistributionConfig(
        uint256 sequencerShare,
        uint256 stakersShare,
        uint256 protocolShare,
        uint256 communityTreasuryShare
    ) external {
        if (!hasRole(GOVERNOR_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, GOVERNOR_ROLE);
        }
        if (sequencerShare + stakersShare + protocolShare + communityTreasuryShare != BASIS_POINTS) {
            revert InvalidDistributionShares();
        }

        distributionConfig = FeeDistributionConfig({
            sequencerShare: sequencerShare,
            stakersShare: stakersShare,
            protocolShare: protocolShare,
            communityTreasuryShare: communityTreasuryShare
        });

        emit DistributionConfigUpdated(sequencerShare, stakersShare, protocolShare, communityTreasuryShare);
    }

    /**
     * @notice Actualiza sequencer registry (Governor o Admin)
     */
    function updateSequencerRegistry(address newAddress) external {
        if (!hasRole(GOVERNOR_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, GOVERNOR_ROLE);
        }
        if (newAddress == address(0)) revert ZeroAddress();
        sequencerRegistry = newAddress;
        emit ContractAddressUpdated("sequencerRegistry", newAddress);
    }

    function updateStakingContract(address newAddress) external {
        if (!hasRole(GOVERNOR_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, GOVERNOR_ROLE);
        }
        if (newAddress == address(0)) revert ZeroAddress();
        stakingContract = newAddress;
        emit ContractAddressUpdated("stakingContract", newAddress);
    }

    function updateProtocolTreasury(address newAddress) external {
        if (!hasRole(GOVERNOR_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, GOVERNOR_ROLE);
        }
        if (newAddress == address(0)) revert ZeroAddress();
        protocolTreasury = newAddress;
        emit ContractAddressUpdated("protocolTreasury", newAddress);
    }

    function updateCommunityTreasury(address newAddress) external {
        if (!hasRole(GOVERNOR_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, GOVERNOR_ROLE);
        }
        if (newAddress == address(0)) revert ZeroAddress();
        communityTreasury = newAddress;
        emit ContractAddressUpdated("communityTreasury", newAddress);
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
            uint256 _totalCommunityTreasuryFees
        )
    {
        return (
            totalFeesCollected,
            totalSequencerFees,
            totalStakersFees,
            totalProtocolFees,
            totalCommunityTreasuryFees
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
