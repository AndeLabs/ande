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
 * @title AndeVesting
 * @author Ande Labs
 * @notice Sistema de vesting para distribución de tokens ANDE según tokenomics
 * @dev Maneja vesting de equipo, inversores, comunidad y sequencers
 *
 * DISTRIBUCIÓN TOTAL: 1,000,000,000 ANDE (1 Billion)
 * - 35% Comunidad y Ecosistema (350M)
 * - 25% Equipo y Fundadores (250M)
 * - 20% Sequencers & Validadores (200M)
 * - 15% Inversores (150M)
 * - 5% Liquidez & Market Making (50M)
 */
contract AndeVesting is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant VESTING_MANAGER_ROLE = keccak256("VESTING_MANAGER_ROLE");

    enum AllocationCategory {
        COMMUNITY,
        TEAM,
        SEQUENCERS,
        SEED_INVESTORS,
        PRIVATE_INVESTORS,
        PUBLIC_INVESTORS,
        LIQUIDITY
    }

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        AllocationCategory category;
        bool revoked;
    }

    IERC20 public andeToken;
    uint256 public tgeTimestamp;

    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 1e18;

    uint256 public constant COMMUNITY_ALLOCATION = 350_000_000 * 1e18;
    uint256 public constant TEAM_ALLOCATION = 250_000_000 * 1e18;
    uint256 public constant SEQUENCERS_ALLOCATION = 200_000_000 * 1e18;
    uint256 public constant SEED_ALLOCATION = 50_000_000 * 1e18;
    uint256 public constant PRIVATE_ALLOCATION = 50_000_000 * 1e18;
    uint256 public constant PUBLIC_ALLOCATION = 50_000_000 * 1e18;
    uint256 public constant LIQUIDITY_ALLOCATION = 50_000_000 * 1e18;

    uint256 public constant TEAM_CLIFF = 365 days;
    uint256 public constant TEAM_VESTING = 1095 days;

    uint256 public constant SEED_CLIFF = 365 days;
    uint256 public constant SEED_VESTING = 730 days;

    uint256 public constant PRIVATE_CLIFF = 180 days;
    uint256 public constant PRIVATE_VESTING = 548 days;

    uint256 public constant PUBLIC_CLIFF = 90 days;
    uint256 public constant PUBLIC_VESTING = 365 days;

    mapping(address => VestingSchedule[]) public vestingSchedules;
    mapping(AllocationCategory => uint256) public allocatedAmounts;
    mapping(AllocationCategory => uint256) public claimedAmounts;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 scheduleId,
        uint256 amount,
        AllocationCategory category
    );
    event TokensClaimed(address indexed beneficiary, uint256 scheduleId, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 scheduleId);
    event TGESet(uint256 timestamp);

    error TGEAlreadySet();
    error TGENotSet();
    error AllocationExceeded();
    error NoVestingSchedule();
    error NothingToClaim();
    error VestingAlreadyRevoked();
    error InvalidSchedule();
    error InvalidCategory();

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
        _grantRole(VESTING_MANAGER_ROLE, defaultAdmin);
    }

    function setTGE(uint256 timestamp) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tgeTimestamp != 0) revert TGEAlreadySet();
        tgeTimestamp = timestamp;
        emit TGESet(timestamp);
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        AllocationCategory category
    ) external onlyRole(VESTING_MANAGER_ROLE) returns (uint256) {
        return _createVestingSchedule(beneficiary, amount, category);
    }

    function createBatchVestingSchedules(
        address[] calldata beneficiaries,
        uint256[] calldata amounts,
        AllocationCategory category
    ) external onlyRole(VESTING_MANAGER_ROLE) {
        require(beneficiaries.length == amounts.length, "Length mismatch");

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            _createVestingSchedule(beneficiaries[i], amounts[i], category);
        }
    }

    function _createVestingSchedule(
        address beneficiary,
        uint256 amount,
        AllocationCategory category
    ) internal returns (uint256) {
        if (tgeTimestamp == 0) revert TGENotSet();

        uint256 maxAllocation = _getMaxAllocation(category);
        if (allocatedAmounts[category] + amount > maxAllocation) revert AllocationExceeded();

        (uint256 cliffDuration, uint256 vestingDuration) = _getVestingParams(category);

        VestingSchedule memory schedule = VestingSchedule({
            totalAmount: amount,
            claimedAmount: 0,
            startTime: tgeTimestamp,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            category: category,
            revoked: false
        });

        vestingSchedules[beneficiary].push(schedule);
        allocatedAmounts[category] += amount;

        uint256 scheduleId = vestingSchedules[beneficiary].length - 1;

        emit VestingScheduleCreated(beneficiary, scheduleId, amount, category);

        return scheduleId;
    }

    function claim(uint256 scheduleId) external nonReentrant whenNotPaused {
        VestingSchedule[] storage schedules = vestingSchedules[msg.sender];
        if (scheduleId >= schedules.length) revert NoVestingSchedule();

        VestingSchedule storage schedule = schedules[scheduleId];
        if (schedule.revoked) revert VestingAlreadyRevoked();

        uint256 claimable = _calculateClaimable(schedule);
        if (claimable == 0) revert NothingToClaim();

        schedule.claimedAmount += claimable;
        claimedAmounts[schedule.category] += claimable;

        andeToken.safeTransfer(msg.sender, claimable);

        emit TokensClaimed(msg.sender, scheduleId, claimable);
    }

    function claimAll() external nonReentrant whenNotPaused {
        VestingSchedule[] storage schedules = vestingSchedules[msg.sender];
        if (schedules.length == 0) revert NoVestingSchedule();

        uint256 totalClaimable = 0;

        for (uint256 i = 0; i < schedules.length; i++) {
            VestingSchedule storage schedule = schedules[i];
            if (!schedule.revoked) {
                uint256 claimable = _calculateClaimable(schedule);
                if (claimable > 0) {
                    schedule.claimedAmount += claimable;
                    claimedAmounts[schedule.category] += claimable;
                    totalClaimable += claimable;

                    emit TokensClaimed(msg.sender, i, claimable);
                }
            }
        }

        if (totalClaimable == 0) revert NothingToClaim();

        andeToken.safeTransfer(msg.sender, totalClaimable);
    }

    function revokeVestingSchedule(address beneficiary, uint256 scheduleId)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        VestingSchedule[] storage schedules = vestingSchedules[beneficiary];
        if (scheduleId >= schedules.length) revert NoVestingSchedule();

        VestingSchedule storage schedule = schedules[scheduleId];
        if (schedule.revoked) revert VestingAlreadyRevoked();

        uint256 claimable = _calculateClaimable(schedule);
        if (claimable > 0) {
            schedule.claimedAmount += claimable;
            claimedAmounts[schedule.category] += claimable;
            andeToken.safeTransfer(beneficiary, claimable);
        }

        schedule.revoked = true;

        emit VestingRevoked(beneficiary, scheduleId);
    }

    function _calculateClaimable(VestingSchedule storage schedule)
        internal
        view
        returns (uint256)
    {
        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - schedule.startTime;

        if (elapsedTime >= schedule.vestingDuration) {
            return schedule.totalAmount - schedule.claimedAmount;
        }

        uint256 vestedAmount = (schedule.totalAmount * elapsedTime) / schedule.vestingDuration;
        return vestedAmount - schedule.claimedAmount;
    }

    function _getVestingParams(AllocationCategory category)
        internal
        pure
        returns (uint256 cliffDuration, uint256 vestingDuration)
    {
        if (category == AllocationCategory.TEAM) {
            return (TEAM_CLIFF, TEAM_VESTING);
        } else if (category == AllocationCategory.SEED_INVESTORS) {
            return (SEED_CLIFF, SEED_VESTING);
        } else if (category == AllocationCategory.PRIVATE_INVESTORS) {
            return (PRIVATE_CLIFF, PRIVATE_VESTING);
        } else if (category == AllocationCategory.PUBLIC_INVESTORS) {
            return (PUBLIC_CLIFF, PUBLIC_VESTING);
        } else if (category == AllocationCategory.COMMUNITY) {
            return (0, 1460 days);
        } else if (category == AllocationCategory.SEQUENCERS) {
            return (0, 1095 days);
        } else if (category == AllocationCategory.LIQUIDITY) {
            return (0, 0);
        }
        revert InvalidCategory();
    }

    function _getMaxAllocation(AllocationCategory category) internal pure returns (uint256) {
        if (category == AllocationCategory.COMMUNITY) return COMMUNITY_ALLOCATION;
        if (category == AllocationCategory.TEAM) return TEAM_ALLOCATION;
        if (category == AllocationCategory.SEQUENCERS) return SEQUENCERS_ALLOCATION;
        if (category == AllocationCategory.SEED_INVESTORS) return SEED_ALLOCATION;
        if (category == AllocationCategory.PRIVATE_INVESTORS) return PRIVATE_ALLOCATION;
        if (category == AllocationCategory.PUBLIC_INVESTORS) return PUBLIC_ALLOCATION;
        if (category == AllocationCategory.LIQUIDITY) return LIQUIDITY_ALLOCATION;
        revert InvalidCategory();
    }

    function getClaimableAmount(address beneficiary, uint256 scheduleId)
        external
        view
        returns (uint256)
    {
        VestingSchedule[] storage schedules = vestingSchedules[beneficiary];
        if (scheduleId >= schedules.length) return 0;

        VestingSchedule storage schedule = schedules[scheduleId];
        if (schedule.revoked) return 0;

        return _calculateClaimable(schedule);
    }

    function getAllClaimableAmount(address beneficiary) external view returns (uint256) {
        VestingSchedule[] storage schedules = vestingSchedules[beneficiary];
        uint256 totalClaimable = 0;

        for (uint256 i = 0; i < schedules.length; i++) {
            if (!schedules[i].revoked) {
                totalClaimable += _calculateClaimable(schedules[i]);
            }
        }

        return totalClaimable;
    }

    function getVestingScheduleCount(address beneficiary) external view returns (uint256) {
        return vestingSchedules[beneficiary].length;
    }

    function getVestingSchedule(address beneficiary, uint256 scheduleId)
        external
        view
        returns (VestingSchedule memory)
    {
        return vestingSchedules[beneficiary][scheduleId];
    }

    function getAllocationStatus(AllocationCategory category)
        external
        view
        returns (uint256 maxAllocation, uint256 allocated, uint256 claimed, uint256 available)
    {
        maxAllocation = _getMaxAllocation(category);
        allocated = allocatedAmounts[category];
        claimed = claimedAmounts[category];
        available = maxAllocation - allocated;
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
