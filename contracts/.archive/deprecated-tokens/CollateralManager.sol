// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title CollateralManager
 * @author Ande Labs
 * @notice Gestiona el registro y parámetros de riesgo de los colaterales en el ecosistema ABOB
 * @dev Controlado por gobernanza para añadir/modificar tipos de colateral y sus parámetros
 */
contract CollateralManager is Initializable, OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    // ==================== STRUCTS ====================
    struct CollateralInfo {
        bool isSupported;
        uint256 overCollateralizationRatio; // Ratio required for minting (e.g., 15000 = 150%)
        uint256 liquidationThreshold;     // Ratio at which vault can be liquidated (e.g., 12500 = 125%)
        uint256 debtCeiling;              // Maximum debt that can be minted against this collateral
        uint256 minCollateralAmount;      // Minimum amount to deposit
        address priceOracle;              // Specific oracle for this collateral (if different from default)
        uint256 protocolFee;              // Fee for using this collateral (in basis points)
        uint256 lastUpdateTime;
    }

    struct CollateralStats {
        uint256 totalDeposited;
        uint256 totalBorrowed;
        uint256 totalLiquidated;
        address[] users;
    }

    // ==================== CONSTANTS ====================
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant DEFAULT_OVERCOLLATERALIZATION_RATIO = 15000; // 150%
    uint256 public constant DEFAULT_LIQUIDATION_THRESHOLD = 12500;     // 125%
    uint256 public constant DEFAULT_PROTOCOL_FEE = 50;                  // 0.5%
    uint256 public constant MAX_PROTOCOL_FEE = 500;                     // 5%
    uint256 public constant MIN_COLLATERAL_RATIO = 11000;               // 110%

    // ==================== STORAGE ====================
    mapping(address => CollateralInfo) public collateralInfos;
    mapping(address => CollateralStats) public collateralStats;
    address[] public supportedCollaterals;

    address public defaultPriceOracle;

    // ==================== EVENTS ====================
    event CollateralAdded(
        address indexed token,
        uint256 overCollateralizationRatio,
        uint256 liquidationThreshold,
        uint256 debtCeiling,
        address oracle
    );
    event CollateralUpdated(
        address indexed token,
        uint256 overCollateralizationRatio,
        uint256 liquidationThreshold,
        uint256 debtCeiling
    );
    event CollateralRemoved(address indexed token);
    event CollateralDeactivated(address indexed token);
    event CollateralReactivated(address indexed token);
    event ProtocolFeeUpdated(address indexed token, uint256 newFee);
    event DebtCeilingUpdated(address indexed token, uint256 newCeiling);
    event DefaultPriceOracleUpdated(address newOracle);

    // ==================== ERRORS ====================
    error InvalidCollateralRatio();
    error InvalidThreshold();
    error InvalidFee();
    error InvalidAddress();
    error CollateralNotSupported();
    error CollateralAlreadySupported();
    error InsufficientDebtCeiling();
    error BelowMinimumCollateralRatio();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address _defaultPriceOracle) public initializer {
        __Ownable_init(defaultAdmin);
        __UUPSUpgradeable_init();
        __Pausable_init();

        defaultPriceOracle = _defaultPriceOracle;
    }

    // ==================== GOVERNANCE FUNCTIONS ====================

    /**
     * @notice Add a new collateral type
     * @param token The token address
     * @param overCollateralizationRatio Ratio required for minting (basis points)
     * @param liquidationThreshold Liquidation threshold (basis points)
     * @param debtCeiling Maximum debt allowed
     * @param minCollateralAmount Minimum deposit amount
     * @param oracle Specific oracle (optional, uses default if address(0))
     */
    function addCollateral(
        address token,
        uint256 overCollateralizationRatio,
        uint256 liquidationThreshold,
        uint256 debtCeiling,
        uint256 minCollateralAmount,
        address oracle
    ) external onlyOwner whenNotPaused {
        if (token == address(0)) revert InvalidAddress();
        if (collateralInfos[token].isSupported) revert CollateralAlreadySupported();
        if (overCollateralizationRatio < MIN_COLLATERAL_RATIO || overCollateralizationRatio > 50000) {
            revert InvalidCollateralRatio();
        }
        if (liquidationThreshold < MIN_COLLATERAL_RATIO || liquidationThreshold >= overCollateralizationRatio) {
            revert InvalidThreshold();
        }

        collateralInfos[token] = CollateralInfo({
            isSupported: true,
            overCollateralizationRatio: overCollateralizationRatio,
            liquidationThreshold: liquidationThreshold,
            debtCeiling: debtCeiling,
            minCollateralAmount: minCollateralAmount,
            priceOracle: oracle == address(0) ? defaultPriceOracle : oracle,
            protocolFee: DEFAULT_PROTOCOL_FEE,
            lastUpdateTime: block.timestamp
        });

        supportedCollaterals.push(token);

        emit CollateralAdded(token, overCollateralizationRatio, liquidationThreshold, debtCeiling, oracle);
    }

    /**
     * @notice Update collateral parameters
     * @param token The token address
     * @param overCollateralizationRatio New ratio for minting
     * @param liquidationThreshold New liquidation threshold
     * @param debtCeiling New debt ceiling
     */
    function updateCollateral(
        address token,
        uint256 overCollateralizationRatio,
        uint256 liquidationThreshold,
        uint256 debtCeiling
    ) external onlyOwner whenNotPaused {
        if (!collateralInfos[token].isSupported) revert CollateralNotSupported();
        if (overCollateralizationRatio < MIN_COLLATERAL_RATIO || overCollateralizationRatio > 50000) {
            revert InvalidCollateralRatio();
        }
        if (liquidationThreshold < MIN_COLLATERAL_RATIO || liquidationThreshold >= overCollateralizationRatio) {
            revert InvalidThreshold();
        }

        CollateralInfo storage info = collateralInfos[token];
        info.overCollateralizationRatio = overCollateralizationRatio;
        info.liquidationThreshold = liquidationThreshold;
        info.debtCeiling = debtCeiling;
        info.lastUpdateTime = block.timestamp;

        emit CollateralUpdated(token, overCollateralizationRatio, liquidationThreshold, debtCeiling);
    }

    /**
     * @notice Deactivate a collateral type (temporarily)
     * @param token The token address
     */
    function deactivateCollateral(address token) external onlyOwner {
        if (!collateralInfos[token].isSupported) revert CollateralNotSupported();
        collateralInfos[token].isSupported = false;
        emit CollateralDeactivated(token);
    }

    /**
     * @notice Reactivate a previously deactivated collateral
     * @param token The token address
     */
    function reactivateCollateral(address token) external onlyOwner {
        if (collateralInfos[token].isSupported) revert CollateralNotSupported();
        collateralInfos[token].isSupported = true;
        emit CollateralReactivated(token);
    }

    /**
     * @notice Remove a collateral type permanently
     * @param token The token address
     */
    function removeCollateral(address token) external onlyOwner {
        if (!collateralInfos[token].isSupported) revert CollateralNotSupported();

        // Check if any users have deposits
        if (collateralStats[token].totalDeposited > 0) {
            revert InsufficientDebtCeiling(); // Cannot remove with active deposits
        }

        delete collateralInfos[token];
        delete collateralStats[token];

        // Remove from supported list
        for (uint i = 0; i < supportedCollaterals.length; i++) {
            if (supportedCollaterals[i] == token) {
                supportedCollaterals[i] = supportedCollaterals[supportedCollaterals.length - 1];
                supportedCollaterals.pop();
                break;
            }
        }

        emit CollateralRemoved(token);
    }

    /**
     * @notice Set protocol fee for a collateral
     * @param token The token address
     * @param fee New fee in basis points
     */
    function setProtocolFee(address token, uint256 fee) external onlyOwner {
        if (!collateralInfos[token].isSupported) revert CollateralNotSupported();
        if (fee > MAX_PROTOCOL_FEE) revert InvalidFee();

        collateralInfos[token].protocolFee = fee;
        emit ProtocolFeeUpdated(token, fee);
    }

    /**
     * @notice Update debt ceiling for a collateral
     * @param token The token address
     * @param newCeiling New debt ceiling
     */
    function updateDebtCeiling(address token, uint256 newCeiling) external onlyOwner {
        if (!collateralInfos[token].isSupported) revert CollateralNotSupported();
        if (newCeiling < collateralStats[token].totalBorrowed) revert InsufficientDebtCeiling();

        collateralInfos[token].debtCeiling = newCeiling;
        emit DebtCeilingUpdated(token, newCeiling);
    }

    /**
     * @notice Set default price oracle
     * @param oracle New default oracle address
     */
    function setDefaultPriceOracle(address oracle) external onlyOwner {
        if (oracle == address(0)) revert InvalidAddress();
        defaultPriceOracle = oracle;
        emit DefaultPriceOracleUpdated(oracle);
    }

    // ==================== VIEW FUNCTIONS ====================

    /**
     * @notice Get collateral information for a token
     * @param token The token address
     * @return isSupported Whether the token is supported
     * @return overCollateralizationRatio Required ratio for minting
     * @return liquidationThreshold Liquidation threshold
     * @return debtCeiling Maximum debt allowed
     */
    function getCollateralInfo(address token) external view returns (
        bool isSupported,
        uint256 overCollateralizationRatio,
        uint256 liquidationThreshold,
        uint256 debtCeiling
    ) {
        CollateralInfo storage info = collateralInfos[token];
        return (
            info.isSupported,
            info.overCollateralizationRatio,
            info.liquidationThreshold,
            info.debtCeiling
        );
    }

    /**
     * @notice Get extended collateral information
     * @param token The token address
     * @return info Complete CollateralInfo struct
     */
    function getExtendedCollateralInfo(address token) external view returns (CollateralInfo memory info) {
        return collateralInfos[token];
    }

    /**
     * @notice Get statistics for a collateral
     * @param token The token address
     * @return totalDeposited Total amount deposited
     * @return totalBorrowed Total amount borrowed
     * @return totalLiquidated Total amount liquidated
     * @return users Array of users who have used this collateral
     */
    function getCollateralStats(address token) external view returns (
        uint256 totalDeposited,
        uint256 totalBorrowed,
        uint256 totalLiquidated,
        address[] memory users
    ) {
        CollateralStats storage stats = collateralStats[token];
        return (stats.totalDeposited, stats.totalBorrowed, stats.totalLiquidated, stats.users);
    }

    /**
     * @notice Get all supported collaterals
     * @return tokens Array of supported token addresses
     */
    function getSupportedCollaterals() external view returns (address[] memory tokens) {
        return supportedCollaterals;
    }

    /**
     * @notice Get the price oracle for a specific collateral
     * @param token The token address
     * @return oracle The oracle address
     */
    function getPriceOracle(address token) external view returns (address oracle) {
        return collateralInfos[token].priceOracle;
    }

    /**
     * @notice Calculate protocol fee for an operation
     * @param token The collateral token
     * @param amount The operation amount
     * @return fee The calculated fee
     */
    function calculateProtocolFee(address token, uint256 amount) external view returns (uint256 fee) {
        CollateralInfo storage info = collateralInfos[token];
        return Math.mulDiv(amount, info.protocolFee, BASIS_POINTS);
    }

    /**
     * @notice Check if a token can be used as collateral
     * @param token The token address
     * @return canUse Whether the token can be used
     * @return reason Reason if cannot be used
     */
    function canUseCollateral(address token) external view returns (bool canUse, string memory reason) {
        CollateralInfo storage info = collateralInfos[token];

        if (!info.isSupported) {
            return (false, "Collateral not supported");
        }

        if (paused()) {
            return (false, "Contract paused");
        }

        return (true, "");
    }

    // ==================== INTERNAL FUNCTIONS ====================
    // Note: These functions would be called by the AbobToken contract
    // to update statistics. They're included here for completeness.

    /**
     * @notice Update deposited amount for a collateral (called by AbobToken)
     * @param token The collateral token
     * @param user The user address
     * @param amount The amount deposited
     */
    function updateDeposit(address token, address user, uint256 amount) external {
        // This should be restricted to authorized contracts
        // Implementation would update collateralStats
    }

    /**
     * @notice Update borrowed amount for a collateral (called by AbobToken)
     * @param token The collateral token
     * @param amount The amount borrowed
     */
    function updateBorrowed(address token, uint256 amount) external {
        // This should be restricted to authorized contracts
        // Implementation would update collateralStats
    }

    // ==================== EMERGENCY FUNCTIONS ====================

    /**
     * @notice Emergency pause of all collateral operations
     */
    function emergencyPause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Check if contract is in emergency state
     * @return isEmergency True if paused
     */
    function isEmergencyState() external view returns (bool isEmergency) {
        return paused();
    }

    // ==================== UPGRADE ====================

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}