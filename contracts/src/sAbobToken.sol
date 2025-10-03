// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ERC4626Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {AccessControlUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title sAbobToken (Staked ABOB)
 * @notice An ERC-4626 vault for earning yield on ABOB tokens.
 * @dev Yield is generated from real protocol revenue (trading fees, lending interest, etc.)
 *      and deposited into the vault by authorized contracts, increasing the value of sABOB shares.
 */
contract sAbobToken is
    Initializable,
    ERC4626Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    // ==================== ROLES ====================
    bytes32 public constant YIELD_DEPOSITOR_ROLE = keccak256("YIELD_DEPOSITOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address abobTokenAddress
    ) public initializer {
        __ERC20_init("Staked ABOB", "sABOB");
        __ERC4626_init(IERC20(abobTokenAddress));
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
    }

    // ==================== YIELD DEPOSIT ====================

    function depositYield(uint256 amount)
        external
        onlyRole(YIELD_DEPOSITOR_ROLE)
    {
        require(amount > 0, "Yield amount must be positive");
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
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
}