// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract DualTrackBurnEngine is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // Se añade un límite máximo para la quema impulsiva para prevenir errores o manipulaciones
    uint256 public constant MAX_IMPULSIVE_BURN_AMOUNT = 1_000_000 * 1e18; // 1 millón de tokens

    IERC20 public andeToken;
    uint256 public lastScheduledBurnTimestamp;

    uint256 public constant SCHEDULE_PERIOD = 90 days;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address burner, address andeTokenAddress) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(BURNER_ROLE, burner);

        require(andeTokenAddress != address(0), "ANDE token address cannot be zero");
        andeToken = IERC20(andeTokenAddress);
        lastScheduledBurnTimestamp = block.timestamp;
    }

    function impulsiveBurn(uint256 amount) public onlyRole(BURNER_ROLE) nonReentrant {
        uint256 currentBalance = andeToken.balanceOf(address(this));
        require(amount > 0, "Burn amount must be positive");
        require(amount <= MAX_IMPULSIVE_BURN_AMOUNT, "Exceeds max burn per tx");
        require(amount <= currentBalance, "Burn amount exceeds balance");
        
        ERC20BurnableUpgradeable(address(andeToken)).burn(amount);
    }

    function scheduledBurn() public nonReentrant {
        require(block.timestamp >= lastScheduledBurnTimestamp + SCHEDULE_PERIOD, "Scheduled burn period not yet passed");
        uint256 currentBalance = andeToken.balanceOf(address(this));
        require(currentBalance > 0, "No tokens to burn");

        lastScheduledBurnTimestamp = block.timestamp;
        ERC20BurnableUpgradeable(address(andeToken)).burn(currentBalance);
    }

    // The following functions are required by UUPSUpgradeable.
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        view
        override
    {
        newImplementation;
    }
}
