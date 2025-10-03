// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOracle} from "./IOracle.sol";

interface IERC20withDecimals is IERC20 {
    function decimals() external view returns (uint8);
}

/**
 * @title AusdToken (Ande USD)
 * @notice A fully collateralized, decentralized stablecoin pegged to the US Dollar.
 * @dev This contract functions as a vault where users can deposit approved collateral
 *      (like USDC, USDT) to mint AUSD at a specific over-collateralization ratio.
 *      It is upgradeable using the UUPS pattern.
 */
contract AusdToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    // ==================== ROLES ====================
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); // For internal minting logic
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

    // Precision for price calculations (1e8)
    uint256 private constant PRICE_PRECISION = 1e8;

    // ==================== EVENTS ====================
    event CollateralAdded(address indexed collateral, uint256 ratio, address priceFeed);
    event CollateralRatioUpdated(address indexed collateral, uint256 newRatio);
    event Minted(address indexed user, address indexed collateral, uint256 collateralAmount, uint256 ausdAmount);
    event Burned(address indexed user, address indexed collateral, uint256 collateralAmount, uint256 ausdAmount);

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

    function initialize(address defaultAdmin) public initializer {
        __ERC20_init("Ande USD", "AUSD");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(COLLATERAL_MANAGER_ROLE, defaultAdmin);
    }

    // ==================== COLLATERAL MANAGEMENT (Admin) ====================

    function addCollateralType(address _collateral, uint128 _ratio, address _priceFeed)
        external
        onlyRole(COLLATERAL_MANAGER_ROLE)
    {
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

    function updateCollateralRatio(address _collateral, uint128 _newRatio)
        external
        onlyRole(COLLATERAL_MANAGER_ROLE)
    {
        if (!collateralTypes[_collateral].isSupported) revert CollateralNotSupported();
        if (_newRatio < 10000) revert InvalidCollateralizationRatio();

        collateralTypes[_collateral].overCollateralizationRatio = _newRatio;
        emit CollateralRatioUpdated(_collateral, _newRatio);
    }

    // ==================== CORE LOGIC: MINT & BURN ====================

    function depositAndMint(address _collateral, uint256 _collateralAmount)
        external
        whenNotPaused
        nonReentrant
    {
        if (_collateralAmount == 0) revert AmountMustBePositive();
        CollateralInfo storage collateral = collateralTypes[_collateral];
        if (!collateral.isSupported) revert CollateralNotSupported();

        // --- Lógica de Oráculo Corregida ---
        // 1. Obtener precio y decimales del oráculo
        (, int256 price_signed, , , ) = collateral.priceFeed.latestRoundData();
        if (price_signed <= 0) revert OraclePriceInvalid();
        uint256 collateralPrice = uint256(price_signed);
        uint8 oracleDecimals = collateral.priceFeed.decimals();

        // 2. Obtener decimales del token de colateral
        uint8 collateralDecimals = IERC20withDecimals(_collateral).decimals();

        // 3. Calcular el valor del colateral en USD, normalizado a 18 decimales (como AUSD)
        // Formula: (collateralAmount * price) / 10^oracleDecimals
        // Para evitar pérdida de precisión, escalamos el precio a 18 decimales antes de dividir
        uint256 scaledPrice = collateralPrice * (10**(18 - oracleDecimals));
        uint256 valueInUsd = (_collateralAmount * scaledPrice) / (10**collateralDecimals);

        // 4. Calcular la cantidad de AUSD a acuñar
        uint256 amountToMint = (valueInUsd * 10000) / collateral.overCollateralizationRatio;

        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _collateralAmount);
        collateral.totalDeposited += _collateralAmount;
        _mint(msg.sender, amountToMint);

        emit Minted(msg.sender, _collateral, _collateralAmount, amountToMint);
    }

    function burnAndWithdraw(address _collateral, uint256 _ausdAmount)
        external
        whenNotPaused
        nonReentrant
    {
        if (_ausdAmount == 0) revert AmountMustBePositive();
        CollateralInfo storage collateral = collateralTypes[_collateral];
        if (!collateral.isSupported) revert CollateralNotSupported();

        // --- Lógica de Oráculo Corregida ---
        (, int256 price_signed, , , ) = collateral.priceFeed.latestRoundData();
        if (price_signed <= 0) revert OraclePriceInvalid();
        uint256 collateralPrice = uint256(price_signed);
        uint8 oracleDecimals = collateral.priceFeed.decimals();

        // 2. Calcular el valor del AUSD a quemar en USD (es 1:1, pero normalizado)
        uint256 valueInUsd = _ausdAmount;

        // 3. Calcular la cantidad de colateral a retirar, APLICANDO EL RATIO
        uint256 collateralValueInUsd = (valueInUsd * collateral.overCollateralizationRatio) / 10000;
        uint8 collateralDecimals = IERC20withDecimals(_collateral).decimals();
        uint256 scaledPrice = collateralPrice * (10**(18 - oracleDecimals));
        uint256 collateralToWithdraw = (collateralValueInUsd * (10**collateralDecimals)) / scaledPrice;

        if (collateralToWithdraw > collateral.totalDeposited) revert InsufficientCollateral();

        _burn(msg.sender, _ausdAmount);
        collateral.totalDeposited -= collateralToWithdraw;
        IERC20(_collateral).safeTransfer(msg.sender, collateralToWithdraw);

        emit Burned(msg.sender, _collateral, collateralToWithdraw, _ausdAmount);
    }


    // ==================== PAUSABLE OVERRIDES ====================

    function _update(address from, address to, uint256 value)
        internal
        override
        whenNotPaused
    {
        super._update(from, to, value);
    }

    // ==================== UUPS UPGRADE ====================

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    // ==================== VIEW FUNCTIONS ====================

    function getSupportedCollaterals() external view returns (address[] memory) {
        return supportedCollaterals;
    }
}