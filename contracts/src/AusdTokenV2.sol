// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {XERC20} from "./xERC20/XERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOracle} from "./IOracle.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface IERC20withDecimals is IERC20 {
    function decimals() external view returns (uint8);
}

/**
 * @title AusdTokenV2 (Ande USD v2 - xERC20 Compatible)
 * @author Ande Labs
 * @notice Fully collateralized, cross-chain stablecoin pegged to the US Dollar
 * @dev Combines collateral-backed minting with xERC20 bridge functionality
 *
 * Dual Minting System:
 * 1. Collateral-backed: Users deposit collateral → mint AUSD (native chain)
 * 2. Bridge minting: Authorized bridges mint/burn with rate limits (cross-chain)
 *
 * This allows AUSD to be:
 * - Native on AndeChain (backed by real collateral)
 * - Bridgeable to other chains (via xERC20 standard)
 */
contract AusdTokenV2 is
    XERC20,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    // ==================== ROLES ====================
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant COLLATERAL_MANAGER_ROLE = keccak256("COLLATERAL_MANAGER_ROLE");

    // ==================== STRUCTS ====================
    struct CollateralInfo {
        bool isSupported;
        uint128 overCollateralizationRatio; // In basis points (e.g., 150% = 15000)
        IOracle priceFeed; // Oracle to get the price of the collateral in USD
        uint256 totalDeposited;
    }

    // ==================== STORAGE ====================
    mapping(address => CollateralInfo) public collateralTypes;
    address[] public supportedCollaterals;

    // ==================== EVENTS ====================
    event CollateralAdded(address indexed collateral, uint256 ratio, address priceFeed);
    event CollateralRatioUpdated(address indexed collateral, uint256 newRatio);
    event CollateralMinted(
        address indexed user,
        address indexed collateral,
        uint256 collateralAmount,
        uint256 ausdAmount
    );
    event CollateralBurned(
        address indexed user,
        address indexed collateral,
        uint256 collateralAmount,
        uint256 ausdAmount
    );

    // ==================== ERRORS ====================
    error CollateralNotSupported();
    error InvalidCollateralizationRatio();
    error InvalidPriceFeed();
    error InsufficientCollateral();
    error AmountMustBePositive();
    error OraclePriceInvalid();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the AUSD token with xERC20 and collateral functionality
     * @param defaultAdmin Address for admin roles
     */
    function initialize(address defaultAdmin) public initializer {
        // Initialize XERC20 (includes ERC20, Permit, AccessControl, UUPS)
        super.initialize("Ande USD", "AUSD", defaultAdmin);

        // Initialize additional modules
        __Pausable_init();
        __ReentrancyGuard_init();

        // Grant additional roles
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(COLLATERAL_MANAGER_ROLE, defaultAdmin);
    }

    // ==================== COLLATERAL MANAGEMENT ====================

    /**
     * @notice Adds a new supported collateral type
     * @param _collateral Address of the collateral token
     * @param _ratio Over-collateralization ratio in basis points (e.g., 15000 = 150%)
     * @param _priceFeed Address of the Chainlink price feed oracle
     */
    function addCollateralType(
        address _collateral,
        uint128 _ratio,
        address _priceFeed
    ) external onlyRole(COLLATERAL_MANAGER_ROLE) {
        require(!collateralTypes[_collateral].isSupported, "Collateral already supported");
        if (_ratio < 10000) revert InvalidCollateralizationRatio(); // Must be >= 100%
        if (_priceFeed == address(0)) revert InvalidPriceFeed();

        collateralTypes[_collateral] = CollateralInfo({
            isSupported: true,
            overCollateralizationRatio: _ratio,
            priceFeed: IOracle(_priceFeed),
            totalDeposited: 0
        });
        supportedCollaterals.push(_collateral);

        emit CollateralAdded(_collateral, _ratio, _priceFeed);
    }

    /**
     * @notice Updates the over-collateralization ratio for a collateral type
     * @param _collateral Address of the collateral token
     * @param _newRatio New ratio in basis points
     */
    function updateCollateralRatio(address _collateral, uint128 _newRatio)
        external
        onlyRole(COLLATERAL_MANAGER_ROLE)
    {
        if (!collateralTypes[_collateral].isSupported) revert CollateralNotSupported();
        if (_newRatio < 10000) revert InvalidCollateralizationRatio();

        collateralTypes[_collateral].overCollateralizationRatio = _newRatio;
        emit CollateralRatioUpdated(_collateral, _newRatio);
    }

    // ==================== COLLATERAL-BACKED MINTING ====================

    /**
     * @notice Deposits collateral and mints AUSD based on collateral value
     * @dev This is the native minting mechanism, separate from bridge minting
     * @param _collateral Address of the collateral token to deposit
     * @param _collateralAmount Amount of collateral to deposit
     */
    function depositAndMint(address _collateral, uint256 _collateralAmount)
        external
        whenNotPaused
        nonReentrant
    {
        if (_collateralAmount == 0) revert AmountMustBePositive();
        CollateralInfo storage collateral = collateralTypes[_collateral];
        if (!collateral.isSupported) revert CollateralNotSupported();

        // Get collateral price from oracle
        (, int256 price_signed,,,) = collateral.priceFeed.latestRoundData();
        if (price_signed <= 0) revert OraclePriceInvalid();
        uint256 collateralPrice = uint256(price_signed);
        uint8 oracleDecimals = collateral.priceFeed.decimals();

        // Get collateral token decimals
        uint8 collateralDecimals = IERC20withDecimals(_collateral).decimals();

        // Calculate collateral value in USD (normalized to 18 decimals)
        uint256 scaledPrice = collateralPrice * (10 ** (18 - oracleDecimals));
        uint256 valueInUsd =
            Math.mulDiv(_collateralAmount, scaledPrice, (10 ** collateralDecimals));

        // Calculate AUSD to mint based on over-collateralization ratio
        uint256 amountToMint =
            Math.mulDiv(valueInUsd, 10000, collateral.overCollateralizationRatio);

        // Transfer collateral and mint AUSD
        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _collateralAmount);
        collateral.totalDeposited += _collateralAmount;
        _mint(msg.sender, amountToMint);

        emit CollateralMinted(msg.sender, _collateral, _collateralAmount, amountToMint);
    }

    /**
     * @notice Burns AUSD and withdraws equivalent collateral
     * @dev This is the native burning mechanism, separate from bridge burning
     * @param _collateral Address of the collateral token to withdraw
     * @param _ausdAmount Amount of AUSD to burn
     */
    function burnAndWithdraw(address _collateral, uint256 _ausdAmount)
        external
        whenNotPaused
        nonReentrant
    {
        if (_ausdAmount == 0) revert AmountMustBePositive();
        CollateralInfo storage collateral = collateralTypes[_collateral];
        if (!collateral.isSupported) revert CollateralNotSupported();

        // Get collateral price from oracle
        (, int256 price_signed,,,) = collateral.priceFeed.latestRoundData();
        if (price_signed <= 0) revert OraclePriceInvalid();
        uint256 collateralPrice = uint256(price_signed);
        uint8 oracleDecimals = collateral.priceFeed.decimals();

        // Calculate collateral to withdraw
        uint256 valueInUsd = _ausdAmount;
        uint256 collateralValueInUsd =
            Math.mulDiv(valueInUsd, collateral.overCollateralizationRatio, 10000);
        uint8 collateralDecimals = IERC20withDecimals(_collateral).decimals();
        uint256 scaledPrice = collateralPrice * (10 ** (18 - oracleDecimals));
        uint256 collateralToWithdraw =
            Math.mulDiv(collateralValueInUsd, (10 ** collateralDecimals), scaledPrice);

        if (collateralToWithdraw > collateral.totalDeposited) revert InsufficientCollateral();

        // Burn AUSD and transfer collateral
        _burn(msg.sender, _ausdAmount);
        collateral.totalDeposited -= collateralToWithdraw;
        IERC20(_collateral).safeTransfer(msg.sender, collateralToWithdraw);

        emit CollateralBurned(msg.sender, _collateral, collateralToWithdraw, _ausdAmount);
    }

    // ==================== PAUSABLE ====================

    /**
     * @notice Pauses all token transfers and minting operations
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses token operations
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ==================== OVERRIDES ====================

    /**
     * @dev Override _update to add pause check
     * @dev Note: XERC20 mint/burn functions already have their own access control via rate limits
     */
    function _update(address from, address to, uint256 value)
        internal
        override
        whenNotPaused
    {
        super._update(from, to, value);
    }

    // ==================== VIEW FUNCTIONS ====================

    /**
     * @notice Returns list of all supported collateral tokens
     */
    function getSupportedCollaterals() external view returns (address[] memory) {
        return supportedCollaterals;
    }

    /**
     * @notice Returns collateral information for a specific token
     */
    function getCollateralInfo(address _collateral)
        external
        view
        returns (CollateralInfo memory)
    {
        return collateralTypes[_collateral];
    }
}
