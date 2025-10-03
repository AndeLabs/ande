// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AbobToken} from "./AbobToken.sol";
import {IOracle} from "./IOracle.sol";

/**
 * @title StabilityEngine
 * @notice Mints and burns ABOB by managing a hybrid collateral of AUSD and ANDE.
 * @dev This is the core of the Frax-style hybrid model for ABOB.
 */
contract StabilityEngine is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using SafeERC20 for AbobToken;

    // ==================== STRUCTS ====================
    struct CollateralRatio {
        uint8 ausd;  // Percentage of collateral in AUSD (e.g., 80 for 80%)
        uint8 ande;  // Percentage of collateral in ANDE (e.g., 20 for 20%)
    }

    // ==================== STORAGE ====================
    AbobToken public abobToken;
    IERC20 public ausdToken;
    IERC20 public andeToken;
    IOracle public andeOracle;

    bytes32 public constant ANDE_USD_PAIR_ID = keccak256(abi.encodePacked("ANDE/USD"));

    CollateralRatio public ratio;

    // ==================== EVENTS ====================
    event RatioUpdated(uint8 newAusdRatio, uint8 newAndeRatio);
    event AbobMinted(address indexed user, uint256 abobAmount, uint256 ausdAmount, uint256 andeAmount);
    event AbobBurned(address indexed user, uint256 abobAmount, uint256 ausdAmount, uint256 andeAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address _abobToken,
        address _ausdToken,
        address _andeToken,
        address _andeOracle
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        abobToken = AbobToken(_abobToken);
        ausdToken = IERC20(_ausdToken);
        andeToken = IERC20(_andeToken);
        andeOracle = IOracle(_andeOracle);

        // Initial ratio: 80% AUSD, 20% ANDE
        ratio = CollateralRatio({ausd: 80, ande: 20});
    }

    // ==================== CORE LOGIC ====================

    function mint(uint256 abobAmount) external nonReentrant {
        require(abobAmount > 0, "Amount must be positive");

        // 1. Calculate required collateral based on ratio
        uint256 requiredAusd = (abobAmount * ratio.ausd) / 100;
        uint256 requiredAndeValue = (abobAmount * ratio.ande) / 100;

        // 2. Get ANDE price from our P2P Oracle
        uint256 andePrice = andeOracle.getPrice(ANDE_USD_PAIR_ID); // Assumes price is in USD with 18 decimals
        require(andePrice > 0, "Invalid ANDE price");

        // 3. Calculate required ANDE tokens
        uint256 requiredAnde = (requiredAndeValue * (10**18)) / andePrice;

        // 4. Pull collateral from user
        ausdToken.safeTransferFrom(msg.sender, address(this), requiredAusd);
        andeToken.safeTransferFrom(msg.sender, address(this), requiredAnde);

        // 5. Mint ABOB to user
        abobToken.mint(msg.sender, abobAmount);

        emit AbobMinted(msg.sender, abobAmount, requiredAusd, requiredAnde);
    }

    function burn(uint256 abobAmount) external nonReentrant {
        require(abobAmount > 0, "Amount must be positive");

        // 1. Burn user's ABOB
        abobToken.burnFrom(msg.sender, abobAmount);

        // 2. Calculate collateral to return based on ratio
        uint256 ausdToReturn = (abobAmount * ratio.ausd) / 100;
        uint256 andeValueToReturn = (abobAmount * ratio.ande) / 100;

        // 3. Get ANDE price
        uint256 andePrice = andeOracle.getPrice(ANDE_USD_PAIR_ID);
        require(andePrice > 0, "Invalid ANDE price");

        // 4. Calculate ANDE tokens to return
        uint256 andeToReturn = (andeValueToReturn * (10**18)) / andePrice;

        // 5. Push collateral to user
        ausdToken.safeTransfer(msg.sender, ausdToReturn);
        andeToken.safeTransfer(msg.sender, andeToReturn);

        emit AbobBurned(msg.sender, abobAmount, ausdToReturn, andeToReturn);
    }

    // ==================== ADMIN FUNCTIONS ====================

    function setRatio(uint8 newAusdRatio, uint8 newAndeRatio) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newAusdRatio + newAndeRatio == 100, "Ratios must sum to 100");
        ratio = CollateralRatio({ausd: newAusdRatio, ande: newAndeRatio});
        emit RatioUpdated(newAusdRatio, newAndeRatio);
    }

    // ==================== UUPS UPGRADE ====================

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
