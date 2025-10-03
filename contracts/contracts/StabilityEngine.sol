// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AbobToken} from "./AbobToken.sol";
import {IOracle} from "./IOracle.sol";

contract StabilityEngine is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using SafeERC20 for AbobToken;

    struct CollateralRatio {
        uint8 ausd;
        uint8 ande;
    }

    AbobToken public abobToken;
    IERC20 public ausdToken;
    IERC20 public andeToken;
    IOracle public andeOracle;
    CollateralRatio public ratio;
    bytes32 public constant ANDE_USD_PAIR_ID = keccak256(abi.encodePacked("ANDE/USD"));

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

        ratio = CollateralRatio({ausd: 80, ande: 20});
    }

    function mint(uint256 abobAmount) external nonReentrant {
        require(abobAmount > 0, "Amount must be positive");
        uint256 requiredAusd = (abobAmount * ratio.ausd) / 100;
        uint256 requiredAndeValue = (abobAmount * ratio.ande) / 100;
        
        // --- ORACLE CALL UPDATED ---
        (, int256 price_signed, , , ) = andeOracle.latestRoundData();
        require(price_signed > 0, "Invalid ANDE price");
        uint256 andePrice = uint256(price_signed);

        uint256 requiredAnde = (requiredAndeValue * (10**18)) / andePrice;

        ausdToken.safeTransferFrom(msg.sender, address(this), requiredAusd);
        andeToken.safeTransferFrom(msg.sender, address(this), requiredAnde);

        abobToken.mint(msg.sender, abobAmount);
        emit AbobMinted(msg.sender, abobAmount, requiredAusd, requiredAnde);
    }

    function burn(uint256 abobAmount) external nonReentrant {
        require(abobAmount > 0, "Amount must be positive");
        abobToken.burnFrom(msg.sender, abobAmount);
        uint256 ausdToReturn = (abobAmount * ratio.ausd) / 100;
        uint256 andeValueToReturn = (abobAmount * ratio.ande) / 100;

        // --- ORACLE CALL UPDATED ---
        (, int256 price_signed, , , ) = andeOracle.latestRoundData();
        require(price_signed > 0, "Invalid ANDE price");
        uint256 andePrice = uint256(price_signed);

        uint256 andeToReturn = (andeValueToReturn * (10**18)) / andePrice;

        ausdToken.safeTransfer(msg.sender, ausdToReturn);
        andeToken.safeTransfer(msg.sender, andeToReturn);
        emit AbobBurned(msg.sender, abobAmount, ausdToReturn, andeToReturn);
    }

    function setRatio(uint8 newAusdRatio, uint8 newAndeRatio) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newAusdRatio + newAndeRatio == 100, "Ratios must sum to 100");
        ratio = CollateralRatio({ausd: newAusdRatio, ande: newAndeRatio});
        emit RatioUpdated(newAusdRatio, newAndeRatio);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}