// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOracle} from "./IOracle.sol";

/**
 * @title AbobToken
 * @author Ande Labs
 * @notice Stablecoin híbrida algorítmica para el ecosistema AndeChain, vinculada a monedas locales (ej. Boliviano).
 * @dev Utiliza un sistema de colateral dual (AUSD y ANDE) con un ratio dinámico.
 */
contract AbobToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    // --- Roles ---
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // --- State Variables ---
    IERC20 public ausdToken;
    IERC20 public andeToken;
    IOracle public andePriceFeed;
    IOracle public abobPriceFeed;
    uint256 public collateralRatio;
    uint256 public constant BASIS_POINTS = 10000;

    // --- Eventos ---
    event Minted(address indexed user, uint256 abobAmount, uint256 ausdAmount, uint256 andeAmount);
    event Redeemed(address indexed user, uint256 abobAmount, uint256 ausdAmount, uint256 andeAmount);
    event CollateralRatioUpdated(uint256 newRatio);
    event PriceFeedsUpdated(address newAndeFeed, address newAbobFeed);
    event CollateralTokensUpdated(address newAusdToken, address newAndeToken);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address pauser,
        address governance,
        address _ausdToken,
        address _andeToken,
        address _andePriceFeed,
        address _abobPriceFeed,
        uint256 _initialRatio
    ) public initializer {
        __ERC20_init("Andean Boliviano", "ABOB");
        __ERC20Burnable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(GOVERNANCE_ROLE, governance);

        ausdToken = IERC20(_ausdToken);
        andeToken = IERC20(_andeToken);
        andePriceFeed = IOracle(_andePriceFeed);
        abobPriceFeed = IOracle(_abobPriceFeed);
        collateralRatio = _initialRatio;
    }

    // --- Lógica de Acuñación (Mint) --- 
    function mint(uint256 _abobAmountToMint) external whenNotPaused nonReentrant {
        require(_abobAmountToMint > 0, "Amount must be positive");

        (, int256 andePriceSigned, , , ) = andePriceFeed.latestRoundData();
        (, int256 abobPriceSigned, , , ) = abobPriceFeed.latestRoundData();
        require(andePriceSigned > 0 && abobPriceSigned > 0, "Invalid oracle price");

        uint256 andePrice = uint256(andePriceSigned);
        uint256 abobPrice = uint256(abobPriceSigned);

        uint256 totalCollateralValueInUSD = (_abobAmountToMint * abobPrice) / 1e18;
        uint256 requiredAusdAmount = (totalCollateralValueInUSD * collateralRatio) / BASIS_POINTS;
        uint256 requiredAndeValueInUSD = totalCollateralValueInUSD - requiredAusdAmount;
        uint256 requiredAndeAmount = (requiredAndeValueInUSD * 1e18) / andePrice;

        ausdToken.safeTransferFrom(msg.sender, address(this), requiredAusdAmount);
        andeToken.safeTransferFrom(msg.sender, address(this), requiredAndeAmount);

        _mint(msg.sender, _abobAmountToMint);

        emit Minted(msg.sender, _abobAmountToMint, requiredAusdAmount, requiredAndeAmount);
    }

    // --- Lógica de Redención (Redeem) ---
    function redeem(uint256 _abobAmountToBurn) external whenNotPaused nonReentrant {
        require(_abobAmountToBurn > 0, "Amount must be positive");

        _burn(msg.sender, _abobAmountToBurn);

        (, int256 andePriceSigned, , , ) = andePriceFeed.latestRoundData();
        (, int256 abobPriceSigned, , , ) = abobPriceFeed.latestRoundData();
        require(andePriceSigned > 0 && abobPriceSigned > 0, "Invalid oracle price");

        uint256 andePrice = uint256(andePriceSigned);
        uint256 abobPrice = uint256(abobPriceSigned);

        uint256 totalCollateralValueInUSD = (_abobAmountToBurn * abobPrice) / 1e18;
        uint256 ausdAmountToReturn = (totalCollateralValueInUSD * collateralRatio) / BASIS_POINTS;
        uint256 andeValueToReturnInUSD = totalCollateralValueInUSD - ausdAmountToReturn;
        uint256 andeAmountToReturn = (andeValueToReturnInUSD * 1e18) / andePrice;

        ausdToken.safeTransfer(msg.sender, ausdAmountToReturn);
        andeToken.safeTransfer(msg.sender, andeAmountToReturn);

        emit Redeemed(msg.sender, _abobAmountToBurn, ausdAmountToReturn, andeAmountToReturn);
    }

    // --- Funciones de Gobernanza ---
    function setCollateralRatio(uint256 _newRatio) external onlyRole(GOVERNANCE_ROLE) {
        require(_newRatio <= BASIS_POINTS, "Ratio cannot exceed 100%");
        collateralRatio = _newRatio;
        emit CollateralRatioUpdated(_newRatio);
    }

    function setPriceFeeds(address _newAndeFeed, address _newAbobFeed) external onlyRole(GOVERNANCE_ROLE) {
        require(_newAndeFeed != address(0) && _newAbobFeed != address(0), "Invalid feed address");
        andePriceFeed = IOracle(_newAndeFeed);
        abobPriceFeed = IOracle(_newAbobFeed);
        emit PriceFeedsUpdated(_newAndeFeed, _newAbobFeed);
    }

    function setCollateralTokens(address _newAusdToken, address _newAndeToken) external onlyRole(GOVERNANCE_ROLE) {
        require(_newAusdToken != address(0) && _newAndeToken != address(0), "Invalid token address");
        ausdToken = IERC20(_newAusdToken);
        andeToken = IERC20(_newAndeToken);
        emit CollateralTokensUpdated(_newAusdToken, _newAndeToken);
    }

    // --- Funciones de Pausa ---
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // --- Hook Interno y Actualización ---
    function _update(address from, address to, uint256 value) internal override(ERC20Upgradeable, PausableUpgradeable) {
        super._update(from, to, value);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
