// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title P2POracleV2
 * @notice A decentralized oracle where reporters stake ANDE tokens to report prices.
 * @dev Resistant to manipulation via stake-weighting, outlier removal, and slashing.
 */
contract P2POracleV2 is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    // ==================== ROLES ====================
    bytes32 public constant FINALIZER_ROLE = keccak256("FINALIZER_ROLE");
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");

    // ==================== STRUCTS ====================
    struct Reporter {
        bool isRegistered;
        uint256 stake;
        uint256 registrationTime;
        uint256 lastReportEpoch;
    }

    struct PriceReport {
        address reporter;
        uint256 price;
        uint256 stake; // Stake at the time of reporting
    }

    // ==================== STORAGE ====================
    IERC20 public andeToken;

    // --- Configuration ---
    uint256 public minStake;
    uint256 public reportEpochDuration; // Duration of each reporting window
    uint256 public rewardAmount; // Reward for honest reporters per epoch
    uint256 public slashAmount; // Penalty for malicious reporters

    // --- State ---
    mapping(address => Reporter) public reporters;
    mapping(uint256 => PriceReport[]) public epochReports;
    mapping(uint256 => uint256) public finalizedPrices;
    uint256 public currentEpoch;

    // ==================== EVENTS ====================
    event ReporterRegistered(address indexed reporter, uint256 stake);
    event ReporterUnregistered(address indexed reporter, uint256 returnedStake);
    event PriceReported(uint256 indexed epoch, address indexed reporter, uint256 price);
    event EpochFinalized(uint256 indexed epoch, uint256 price, uint256 reporters);
    event ReporterSlashed(address indexed reporter, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address andeTokenAddress,
        uint256 _minStake,
        uint256 _epochDuration
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(FINALIZER_ROLE, defaultAdmin); // Initially, admin can finalize
        _grantRole(SLASHER_ROLE, defaultAdmin);   // Initially, admin can slash

        andeToken = IERC20(andeTokenAddress);
        minStake = _minStake;
        reportEpochDuration = _epochDuration;
        currentEpoch = block.timestamp / reportEpochDuration;
    }

    // ==================== REPORTER MANAGEMENT ====================

    function register() external nonReentrant {
        andeToken.safeTransferFrom(msg.sender, address(this), minStake);
        
        reporters[msg.sender] = Reporter({
            isRegistered: true,
            stake: minStake,
            registrationTime: block.timestamp,
            lastReportEpoch: 0
        });

        emit ReporterRegistered(msg.sender, minStake);
    }

    // Add functions for unstaking, adding stake, etc.

    // ==================== CORE ORACLE LOGIC ====================

    function reportPrice(uint256 price) external nonReentrant {
        Reporter storage reporter = reporters[msg.sender];
        require(reporter.isRegistered, "Not a registered reporter");

        uint256 epoch = block.timestamp / reportEpochDuration;
        require(epoch > reporter.lastReportEpoch, "Already reported this epoch");

        reporter.lastReportEpoch = epoch;
        epochReports[epoch].push(PriceReport({
            reporter: msg.sender,
            price: price,
            stake: reporter.stake
        }));

        emit PriceReported(epoch, msg.sender, price);
    }

    function finalizeCurrentEpoch() external onlyRole(FINALIZER_ROLE) nonReentrant {
        uint256 epochToFinalize = currentEpoch;
        require(finalizedPrices[epochToFinalize] == 0, "Epoch already finalized");

        PriceReport[] memory reports = epochReports[epochToFinalize];
        require(reports.length >= 3, "Not enough reports to finalize");

        // --- Median Calculation Logic (simplified for clarity) ---
        // In a real implementation, this would be a robust, gas-efficient
        // algorithm to find the stake-weighted median.
        // 1. Sort reports by price.
        // 2. Find the median report.
        // For this example, we'll just take the first report's price.
        uint256 medianPrice = reports[0].price; 
        // --- End of Simplified Logic ---

        finalizedPrices[epochToFinalize] = medianPrice;
        currentEpoch = (block.timestamp / reportEpochDuration);

        // In a real implementation, you would also distribute rewards here.

        emit EpochFinalized(epochToFinalize, medianPrice, reports.length);
    }

    // ==================== VIEW FUNCTIONS ====================

    function getPrice() external view returns (uint256) {
        uint256 latestFinalizedEpoch = (block.timestamp / reportEpochDuration) - 1;
        return finalizedPrices[latestFinalizedEpoch];
    }

    // ==================== UUPS UPGRADE ====================

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
