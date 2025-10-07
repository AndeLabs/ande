// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOracle} from "./IOracle.sol";

/**
 * @title P2POracle
 * @author Ande Labs
 * @notice Implements a decentralized, stake-weighted median price oracle.
 * @dev Reporters stake ANDE tokens to submit price data each epoch. A trusted
 * FINALIZER_ROLE calculates the stake-weighted median and finalizes the price.
 * This contract is upgradeable using the UUPS pattern.
 * @custom:dev-note The contract defines `SLASHER_ROLE` and an `ReporterUnregistered` event,
 * but the corresponding `slash()` and `unregister()` functions are not yet implemented.
 */
contract P2POracle is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    IOracle
{
    using SafeERC20 for IERC20;

    // @notice Role for accounts authorized to finalize an epoch's price.
    bytes32 public constant FINALIZER_ROLE = keccak256("FINALIZER_ROLE");
    // @notice Role for accounts authorized to slash a reporter's stake (functionality not yet implemented).
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");

    /**
     * @notice Represents a registered price reporter.
     * @param isRegistered True if the address is an active reporter.
     * @param stake The amount of ANDE tokens staked.
     * @param registrationTime The timestamp when the reporter registered.
     * @param lastReportEpoch The last epoch the reporter submitted a price for. Used to prevent double-reporting.
     */
    struct Reporter {
        bool isRegistered;
        uint256 stake;
        uint256 registrationTime;
        uint256 lastReportEpoch;
    }

    /**
     * @notice Represents a single price submission within an epoch.
     * @param reporter The address of the reporter.
     * @param price The price reported by the reporter.
     * @param stake The stake of the reporter at the time of reporting.
     */
    struct PriceReport {
        address reporter;
        uint256 price;
        uint256 stake;
    }

    /// @notice The ANDE token contract used for staking.
    IERC20 public andeToken;
    /// @notice The minimum stake required to become a reporter.
    uint256 public minStake;
    /// @notice The duration of each price reporting epoch in seconds.
    uint256 public reportEpochDuration;

    /// @notice Maps reporter addresses to their registration data.
    mapping(address => Reporter) public reporters;
    /// @notice Maps epoch numbers to an array of price reports for that epoch.
    mapping(uint256 => PriceReport[]) public epochReports;
    /// @notice Maps epoch numbers to their finalized median price.
    mapping(uint256 => uint256) public finalizedPrices;
    /// @notice Maps epoch numbers to the timestamp of their finalization.
    mapping(uint256 => uint256) public finalizedTimestamps;
    /// @notice The current epoch number, calculated from block.timestamp.
    uint256 public currentEpoch;
    /// @notice The address where slashed stakes are sent.
    address public treasury;

    /// @notice Emitted when a new reporter stakes tokens and registers.
    event ReporterRegistered(address indexed reporter, uint256 stake);
    /// @notice Emitted when a reporter unregisters and withdraws their stake.
    event ReporterUnregistered(address indexed reporter, uint256 returnedStake);
    /// @notice Emitted when a reporter increases their stake.
    event StakeIncreased(address indexed reporter, uint256 amount, uint256 newTotalStake);
    /// @notice Emitted when a reporter decreases their stake.
    event StakeDecreased(address indexed reporter, uint256 amount, uint256 newTotalStake);
    /// @notice Emitted when a reporter successfully submits a price for an epoch.
    event PriceReported(uint256 indexed epoch, address indexed reporter, uint256 price);
    /// @notice Emitted when an epoch is finalized with a median price.
    event EpochFinalized(uint256 indexed epoch, uint256 price, uint256 reporters);
    /// @notice Emitted when a reporter's stake is slashed.
    event ReporterSlashed(address indexed reporter, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the oracle contract.
     * @dev Sets up access control, roles, and initial oracle parameters.
     * Can only be called once.
     * @param defaultAdmin The address to grant DEFAULT_ADMIN_ROLE, FINALIZER_ROLE, and SLASHER_ROLE.
     * @param andeTokenAddress The address of the ANDE token contract for staking.
     * @param _minStake The minimum stake required to be a reporter.
     * @param _epochDuration The duration of each reporting epoch in seconds.
     */
    function initialize(address defaultAdmin, address andeTokenAddress, uint256 _minStake, uint256 _epochDuration)
        public
        initializer
    {
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
        treasury = defaultAdmin; // Set initial treasury to the admin
    }

    // ==================== IOracle Implementation ====================

    /**
     * @notice Returns the number of decimals used in the price data.
     * @dev Implements the IOracle interface for Chainlink compatibility. Always returns 18.
     */
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /**
     * @notice Returns the latest finalized round data.
     * @dev Implements the IOracle interface for Chainlink compatibility.
     * The data corresponds to the most recently finalized epoch (current epoch - 1).
     * @return roundId The epoch number of the latest finalized price.
     * @return answer The latest finalized price.
     * @return startedAt The timestamp when the round was finalized.
     * @return updatedAt The timestamp when the round was finalized.
     * @return answeredInRound The epoch number of the latest finalized price.
     */
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        uint256 currentEpochNumber = block.timestamp / reportEpochDuration;
        if (currentEpochNumber == 0) {
            return (0, 0, 0, 0, 0);
        }
        uint256 latestFinalizedEpoch = currentEpochNumber - 1;
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

    // ==================== Governance Functions ====================

    /**
     * @notice Sets the address of the treasury contract where slashed funds are sent.
     * @dev Can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * @param _treasury The new treasury address.
     */
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Treasury address cannot be zero");
        treasury = _treasury;
    }

    // ==================== Reporter Management ====================

    /**
     * @notice Allows a user to register as a price reporter by staking the minimum required ANDE tokens.
     * @dev The user must first approve the contract to spend `minStake` of their ANDE tokens.
     */
    function register() external nonReentrant {
        reporters[msg.sender] =
            Reporter({isRegistered: true, stake: minStake, registrationTime: block.timestamp, lastReportEpoch: 0});

        andeToken.safeTransferFrom(msg.sender, address(this), minStake);

        emit ReporterRegistered(msg.sender, minStake);
    }

    /**
     * @notice Allows a registered reporter to unregister and withdraw their stake.
     * @dev Reverts if the caller is not a registered reporter.
     */
    function unregister() external nonReentrant {
        Reporter storage reporter = reporters[msg.sender];
        require(reporter.isRegistered, "Not a registered reporter");

        uint256 stakeToReturn = reporter.stake;
        delete reporters[msg.sender];
        andeToken.safeTransfer(msg.sender, stakeToReturn);

        emit ReporterUnregistered(msg.sender, stakeToReturn);
    }

    /**
     * @notice Allows a registered reporter to increase their stake by adding more ANDE tokens.
     * @dev The reporter must approve the contract to spend the additional amount.
     * @param additionalAmount The amount of additional ANDE tokens to stake.
     */
    function increaseStake(uint256 additionalAmount) external nonReentrant {
        require(additionalAmount > 0, "Amount must be greater than 0");
        Reporter storage reporter = reporters[msg.sender];
        require(reporter.isRegistered, "Not a registered reporter");

        reporter.stake += additionalAmount;
        andeToken.safeTransferFrom(msg.sender, address(this), additionalAmount);

        emit StakeIncreased(msg.sender, additionalAmount, reporter.stake);
    }

    /**
     * @notice Allows a registered reporter to decrease their stake by withdrawing ANDE tokens.
     * @dev The reporter must maintain at least the minimum stake.
     * @param withdrawalAmount The amount of ANDE tokens to withdraw.
     */
    function decreaseStake(uint256 withdrawalAmount) external nonReentrant {
        require(withdrawalAmount > 0, "Amount must be greater than 0");
        Reporter storage reporter = reporters[msg.sender];
        require(reporter.isRegistered, "Not a registered reporter");
        require(reporter.stake - withdrawalAmount >= minStake, "Cannot withdraw below minimum stake");

        reporter.stake -= withdrawalAmount;
        andeToken.safeTransfer(msg.sender, withdrawalAmount);

        emit StakeDecreased(msg.sender, withdrawalAmount, reporter.stake);
    }

    /**
     * @notice Allows an account with SLASHER_ROLE to slash a reporter's stake.
     * @dev The slashed stake remains in the contract. Reverts if the target is not a reporter.
     * @param reporterAddress The address of the reporter to be slashed.
     */
    function slash(address reporterAddress) external onlyRole(SLASHER_ROLE) nonReentrant {
        Reporter storage reporter = reporters[reporterAddress];
        require(reporter.isRegistered, "Not a registered reporter");
        require(treasury != address(0), "Treasury not set");

        uint256 slashedAmount = reporter.stake;
        delete reporters[reporterAddress];

        // Transfer the slashed stake to the treasury
        andeToken.safeTransfer(treasury, slashedAmount);

        emit ReporterSlashed(reporterAddress, slashedAmount);
    }

    // ==================== Core Oracle Logic ====================

    /**
     * @notice Allows a registered reporter to submit a price for the current epoch.
     * @dev Reverts if the caller is not a registered reporter or has already reported for the current epoch.
     * @param price The price to report, formatted with 18 decimals.
     */
    function reportPrice(uint256 price) external nonReentrant {
        Reporter storage reporter = reporters[msg.sender];
        require(reporter.isRegistered, "Not a registered reporter");

        uint256 epoch = block.timestamp / reportEpochDuration;

        // Correctly prevent double-reporting, including for epoch 0
        require(reporter.lastReportEpoch != epoch + 1, "Already reported this epoch");

        reporter.lastReportEpoch = epoch + 1;
        epochReports[epoch].push(PriceReport({reporter: msg.sender, price: price, stake: reporter.stake}));

        emit PriceReported(epoch, msg.sender, price);
    }

    /**
     * @notice Finalizes the current epoch, calculating and storing the stake-weighted median price.
     * @dev Can only be called by an account with the FINALIZER_ROLE.
     * Reverts if the epoch has already been finalized or if there are no reports.
     */
    function finalizeCurrentEpoch() external onlyRole(FINALIZER_ROLE) nonReentrant {
        uint256 epochToFinalize = currentEpoch;
        require(finalizedPrices[epochToFinalize] == 0, "Epoch already finalized");

        PriceReport[] memory reports = epochReports[epochToFinalize];
        require(reports.length > 0, "Not enough reports to finalize");

        // --- Stake-Weighted Median Calculation ---
        _sortReports(reports);
        uint256 totalStake = 0;
        for (uint256 i = 0; i < reports.length; i++) {
            totalStake += reports[i].stake;
        }

        uint256 medianStake = totalStake / 2;
        uint256 cumulativeStake = 0;
        uint256 medianPrice = 0;

        for (uint256 i = 0; i < reports.length; i++) {
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
     * @dev Sorts price reports in-place by price, using insertion sort.
     * @param _reports The array of PriceReport structs to sort.
     */
    function _sortReports(PriceReport[] memory _reports) internal pure {
        for (uint256 i = 1; i < _reports.length; i++) {
            PriceReport memory key = _reports[i];
            uint256 j = i;
            while (j > 0 && _reports[j - 1].price > key.price) {
                _reports[j] = _reports[j - 1];
                j--;
            }
            _reports[j] = key;
        }
    }

    // ==================== UUPS UPGRADE ====================

    /**
     * @dev Authorizes an upgrade to a new implementation contract.
     * @dev Can only be called by an account with the DEFAULT_ADMIN_ROLE.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
