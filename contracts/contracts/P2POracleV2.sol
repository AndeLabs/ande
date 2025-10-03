// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOracle} from "./IOracle.sol";

/**
 * @title P2POracleV2
 * @dev Production-ready implementation of a stake-weighted median oracle.
 */
contract P2POracleV2 is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    IOracle
{
    using SafeERC20 for IERC20;

    bytes32 public constant FINALIZER_ROLE = keccak256("FINALIZER_ROLE");
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");

    struct Reporter {
        bool isRegistered;
        uint256 stake;
        uint256 registrationTime;
        uint256 lastReportEpoch;
    }

    struct PriceReport {
        address reporter;
        uint256 price;
        uint256 stake;
    }

    IERC20 public andeToken;
    uint256 public minStake;
    uint256 public reportEpochDuration;

    mapping(address => Reporter) public reporters;
    mapping(uint256 => PriceReport[]) public epochReports;
    mapping(uint256 => uint256) public finalizedPrices;
    mapping(uint256 => uint256) public finalizedTimestamps;
    uint256 public currentEpoch;

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
        _grantRole(FINALIZER_ROLE, defaultAdmin);
        _grantRole(SLASHER_ROLE, defaultAdmin);

        andeToken = IERC20(andeTokenAddress);
        minStake = _minStake;
        reportEpochDuration = _epochDuration;
        currentEpoch = block.timestamp / reportEpochDuration;
    }

    // ==================== IOracle Implementation ====================

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        uint256 latestFinalizedEpoch = (block.timestamp / reportEpochDuration) - 1;
        uint256 price = finalizedPrices[latestFinalizedEpoch];
        uint256 timestamp = finalizedTimestamps[latestFinalizedEpoch];
        
        return (
            uint80(latestFinalizedEpoch),
            int256(price),
            timestamp, // Simplification: using update time as start time
            timestamp,
            uint80(latestFinalizedEpoch)
        );
    }

    // ==================== Reporter Management ====================

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

    // ==================== Core Oracle Logic ====================

    function reportPrice(uint256 price) external nonReentrant {
        Reporter storage reporter = reporters[msg.sender];
        require(reporter.isRegistered, "Not a registered reporter");

        uint256 epoch = block.timestamp / reportEpochDuration;
        require(epoch >= reporter.lastReportEpoch, "Invalid epoch");
        if (epoch == reporter.lastReportEpoch && reporter.lastReportEpoch != 0) {
             revert("Already reported this epoch");
        }

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
        require(reports.length > 0, "Not enough reports to finalize");

        // --- Stake-Weighted Median Calculation ---
        _sortReports(reports);
        uint256 totalStake = 0;
        for (uint i = 0; i < reports.length; i++) {
            totalStake += reports[i].stake;
        }

        uint256 medianStake = totalStake / 2;
        uint256 cumulativeStake = 0;
        uint256 medianPrice = 0;

        for (uint i = 0; i < reports.length; i++) {
            cumulativeStake += reports[i].stake;
            if (cumulativeStake >= medianStake) {
                medianPrice = reports[i].price;
                break;
            }
        }
        // --- End of Calculation ---

        finalizedPrices[epochToFinalize] = medianPrice;
        finalizedTimestamps[epochToFinalize] = block.timestamp;
        currentEpoch = (block.timestamp / reportEpochDuration);

        emit EpochFinalized(epochToFinalize, medianPrice, reports.length);
    }

    // ==================== Internal Helpers ====================

    /**
     * @dev Sorts price reports in-place using insertion sort.
     */
    function _sortReports(PriceReport[] memory _reports) internal pure {
        for (uint i = 1; i < _reports.length; i++) {
            PriceReport memory key = _reports[i];
            int j = int(i) - 1;
            while (j >= 0 && _reports[uint(j)].price > key.price) {
                _reports[uint(j) + 1] = _reports[uint(j)];
                j--;
            }
            _reports[uint(j) + 1] = key;
        }
    }

    // ==================== UUPS UPGRADE ====================

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
