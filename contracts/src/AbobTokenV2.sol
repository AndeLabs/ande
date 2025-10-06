// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {XERC20} from "./xERC20/XERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOracle} from "./IOracle.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title AbobTokenV2 (Andean Boliviano v2 - xERC20 Compatible)
 * @author Ande Labs
 * @notice Hybrid algorithmic stablecoin pegged to Bolivian Boliviano with xERC20 support
 * @dev Combines dual-collateral backing (AUSD + ANDE) with cross-chain bridging
 *
 * Dual Minting System:
 * 1. Collateral-backed: Users deposit AUSD + ANDE → mint ABOB (native chain)
 * 2. Bridge minting: Authorized bridges mint/burn with rate limits (cross-chain)
 *
 * Collateral Model:
 * - Dynamic ratio between stable collateral (AUSD) and volatile collateral (ANDE)
 * - Governed collateralization ratio adjustable by DAO
 * - Oracle-based pricing for accurate collateral valuation
 */
contract AbobTokenV2 is XERC20, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    // ==================== ROLES ====================
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    // ==================== STATE VARIABLES ====================
    IERC20 public ausdToken;
    IERC20 public andeToken;
    IOracle public andePriceFeed;
    IOracle public abobPriceFeed;

    /// @notice Ratio of stable collateral (AUSD) in basis points (e.g., 7000 = 70% AUSD, 30% ANDE)
    uint256 public collateralRatio;
    uint256 public constant BASIS_POINTS = 10000;

    // ==================== EVENTS ====================
    event CollateralMinted(
        address indexed user,
        uint256 abobAmount,
        uint256 ausdAmount,
        uint256 andeAmount
    );
    event CollateralRedeemed(
        address indexed user,
        uint256 abobAmount,
        uint256 ausdAmount,
        uint256 andeAmount
    );
    event CollateralRatioUpdated(uint256 newRatio);
    event PriceFeedsUpdated(address newAndeFeed, address newAbobFeed);
    event CollateralTokensUpdated(address newAusdToken, address newAndeToken);

    // ==================== ERRORS ====================
    error InvalidRatio();
    error InvalidAddress();
    error InvalidAmount();
    error OraclePriceInvalid();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the ABOB token with xERC20 and collateral functionality
     * @param defaultAdmin Address for admin roles
     * @param _ausdToken Address of AUSD token (stable collateral)
     * @param _andeToken Address of ANDE token (volatile collateral)
     * @param _andePriceFeed Address of ANDE/USD price oracle
     * @param _abobPriceFeed Address of ABOB/USD price oracle
     * @param _initialRatio Initial collateral ratio in basis points
     */
    function initialize(
        address defaultAdmin,
        address _ausdToken,
        address _andeToken,
        address _andePriceFeed,
        address _abobPriceFeed,
        uint256 _initialRatio
    ) public initializer {
        // Initialize XERC20 (includes ERC20, Permit, AccessControl, UUPS)
        super.initialize("Andean Boliviano", "ABOB", defaultAdmin);

        // Initialize additional modules
        __Pausable_init();
        __ReentrancyGuard_init();

        // Grant additional roles
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(GOVERNANCE_ROLE, defaultAdmin);

        // Set collateral tokens and oracles
        if (_ausdToken == address(0) || _andeToken == address(0)) revert InvalidAddress();
        if (_andePriceFeed == address(0) || _abobPriceFeed == address(0)) {
            revert InvalidAddress();
        }
        if (_initialRatio > BASIS_POINTS) revert InvalidRatio();

        ausdToken = IERC20(_ausdToken);
        andeToken = IERC20(_andeToken);
        andePriceFeed = IOracle(_andePriceFeed);
        abobPriceFeed = IOracle(_abobPriceFeed);
        collateralRatio = _initialRatio;
    }

    // ==================== COLLATERAL-BACKED MINTING ====================

    /**
     * @notice Mints ABOB by depositing AUSD and ANDE as collateral
     * @dev Calculates required collateral based on dynamic ratio and oracle prices
     * @param _abobAmountToMint Amount of ABOB to mint
     */
    function mintWithCollateral(uint256 _abobAmountToMint)
        external
        whenNotPaused
        nonReentrant
    {
        if (_abobAmountToMint == 0) revert InvalidAmount();

        // Get oracle prices
        (, int256 andePriceSigned,,,) = andePriceFeed.latestRoundData();
        (, int256 abobPriceSigned,,,) = abobPriceFeed.latestRoundData();
        if (andePriceSigned <= 0 || abobPriceSigned <= 0) revert OraclePriceInvalid();

        uint256 andePrice = uint256(andePriceSigned);
        uint256 abobPrice = uint256(abobPriceSigned);

        // Calculate total collateral value needed in USD (18 decimals)
        uint256 totalCollateralValueInUSD =
            Math.mulDiv(_abobAmountToMint, abobPrice, 1e18);

        // Calculate AUSD portion (stable collateral)
        uint256 requiredAusdAmount =
            Math.mulDiv(totalCollateralValueInUSD, collateralRatio, BASIS_POINTS);

        // Calculate ANDE portion (volatile collateral)
        uint256 requiredAndeValueInUSD = totalCollateralValueInUSD - requiredAusdAmount;
        uint256 requiredAndeAmount = Math.mulDiv(requiredAndeValueInUSD, 1e18, andePrice);

        // Transfer collateral from user
        ausdToken.safeTransferFrom(msg.sender, address(this), requiredAusdAmount);
        andeToken.safeTransferFrom(msg.sender, address(this), requiredAndeAmount);

        // Mint ABOB
        _mint(msg.sender, _abobAmountToMint);

        emit CollateralMinted(
            msg.sender, _abobAmountToMint, requiredAusdAmount, requiredAndeAmount
        );
    }

    /**
     * @notice Burns ABOB and redeems collateral (AUSD + ANDE)
     * @dev Returns collateral based on current ratio and oracle prices
     * @param _abobAmountToBurn Amount of ABOB to burn
     */
    function redeemCollateral(uint256 _abobAmountToBurn)
        external
        whenNotPaused
        nonReentrant
    {
        if (_abobAmountToBurn == 0) revert InvalidAmount();

        // Burn ABOB first
        _burn(msg.sender, _abobAmountToBurn);

        // Get oracle prices
        (, int256 andePriceSigned,,,) = andePriceFeed.latestRoundData();
        (, int256 abobPriceSigned,,,) = abobPriceFeed.latestRoundData();
        if (andePriceSigned <= 0 || abobPriceSigned <= 0) revert OraclePriceInvalid();

        uint256 andePrice = uint256(andePriceSigned);
        uint256 abobPrice = uint256(abobPriceSigned);

        // Calculate total collateral value to return in USD
        uint256 totalCollateralValueInUSD =
            Math.mulDiv(_abobAmountToBurn, abobPrice, 1e18);

        // Calculate AUSD to return
        uint256 ausdAmountToReturn =
            Math.mulDiv(totalCollateralValueInUSD, collateralRatio, BASIS_POINTS);

        // Calculate ANDE to return
        uint256 andeValueToReturnInUSD = totalCollateralValueInUSD - ausdAmountToReturn;
        uint256 andeAmountToReturn = Math.mulDiv(andeValueToReturnInUSD, 1e18, andePrice);

        // Transfer collateral back to user
        ausdToken.safeTransfer(msg.sender, ausdAmountToReturn);
        andeToken.safeTransfer(msg.sender, andeAmountToReturn);

        emit CollateralRedeemed(
            msg.sender, _abobAmountToBurn, ausdAmountToReturn, andeAmountToReturn
        );
    }

    // ==================== GOVERNANCE FUNCTIONS ====================

    /**
     * @notice Updates the collateral ratio (AUSD vs ANDE)
     * @dev Only callable by governance
     * @param _newRatio New ratio in basis points (e.g., 7000 = 70% AUSD, 30% ANDE)
     */
    function setCollateralRatio(uint256 _newRatio) external onlyRole(GOVERNANCE_ROLE) {
        if (_newRatio > BASIS_POINTS) revert InvalidRatio();
        collateralRatio = _newRatio;
        emit CollateralRatioUpdated(_newRatio);
    }

    /**
     * @notice Updates the price feed oracles
     * @dev Only callable by governance
     * @param _newAndeFeed New ANDE price feed address
     * @param _newAbobFeed New ABOB price feed address
     */
    function setPriceFeeds(address _newAndeFeed, address _newAbobFeed)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        if (_newAndeFeed == address(0) || _newAbobFeed == address(0)) {
            revert InvalidAddress();
        }
        andePriceFeed = IOracle(_newAndeFeed);
        abobPriceFeed = IOracle(_newAbobFeed);
        emit PriceFeedsUpdated(_newAndeFeed, _newAbobFeed);
    }

    /**
     * @notice Updates the collateral token addresses
     * @dev Only callable by governance
     * @param _newAusdToken New AUSD token address
     * @param _newAndeToken New ANDE token address
     */
    function setCollateralTokens(address _newAusdToken, address _newAndeToken)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        if (_newAusdToken == address(0) || _newAndeToken == address(0)) {
            revert InvalidAddress();
        }
        ausdToken = IERC20(_newAusdToken);
        andeToken = IERC20(_newAndeToken);
        emit CollateralTokensUpdated(_newAusdToken, _newAndeToken);
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
     * @notice Calculates required collateral for minting ABOB
     * @param _abobAmount Amount of ABOB to mint
     * @return ausdRequired AUSD collateral required
     * @return andeRequired ANDE collateral required
     */
    function calculateMintCollateral(uint256 _abobAmount)
        external
        view
        returns (uint256 ausdRequired, uint256 andeRequired)
    {
        (, int256 andePriceSigned,,,) = andePriceFeed.latestRoundData();
        (, int256 abobPriceSigned,,,) = abobPriceFeed.latestRoundData();

        if (andePriceSigned <= 0 || abobPriceSigned <= 0) {
            return (0, 0);
        }

        uint256 andePrice = uint256(andePriceSigned);
        uint256 abobPrice = uint256(abobPriceSigned);

        uint256 totalValueUSD = Math.mulDiv(_abobAmount, abobPrice, 1e18);
        ausdRequired = Math.mulDiv(totalValueUSD, collateralRatio, BASIS_POINTS);
        uint256 andeValueUSD = totalValueUSD - ausdRequired;
        andeRequired = Math.mulDiv(andeValueUSD, 1e18, andePrice);
    }

    /**
     * @notice Calculates collateral returned when redeeming ABOB
     * @param _abobAmount Amount of ABOB to redeem
     * @return ausdReturned AUSD collateral returned
     * @return andeReturned ANDE collateral returned
     */
    function calculateRedeemCollateral(uint256 _abobAmount)
        external
        view
        returns (uint256 ausdReturned, uint256 andeReturned)
    {
        (, int256 andePriceSigned,,,) = andePriceFeed.latestRoundData();
        (, int256 abobPriceSigned,,,) = abobPriceFeed.latestRoundData();

        if (andePriceSigned <= 0 || abobPriceSigned <= 0) {
            return (0, 0);
        }

        uint256 andePrice = uint256(andePriceSigned);
        uint256 abobPrice = uint256(abobPriceSigned);

        uint256 totalValueUSD = Math.mulDiv(_abobAmount, abobPrice, 1e18);
        ausdReturned = Math.mulDiv(totalValueUSD, collateralRatio, BASIS_POINTS);
        uint256 andeValueUSD = totalValueUSD - ausdReturned;
        andeReturned = Math.mulDiv(andeValueUSD, 1e18, andePrice);
    }
}
