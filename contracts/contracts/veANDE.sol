// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract VeANDE is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    struct LockedBalance {
        uint256 amount;
        uint256 end;
    }

    error InvalidAndeTokenAddress();
    error AmountNotPositive();
    error UnlockTimeNotInFuture();
    error CannotShortenLockTime();
    error LockDurationExceedsMax();
    error NoLockFound();
    error LockNotExpired();

    IERC20 public andeToken;
    mapping(address => LockedBalance) public lockedBalances;

    uint256 public constant MAX_LOCK_TIME = 4 * 365 days;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address andeTokenAddress) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        if (andeTokenAddress == address(0)) revert InvalidAndeTokenAddress();
        andeToken = IERC20(andeTokenAddress);
    }

    function createLock(uint256 amount, uint256 unlockTime) external {
        LockedBalance storage userLock = lockedBalances[msg.sender];

        if (userLock.amount == 0) {
            if (amount == 0) revert AmountNotPositive();
        }

        if (unlockTime <= block.timestamp) revert UnlockTimeNotInFuture();

        if (userLock.amount > 0) {
            if (unlockTime < userLock.end) revert CannotShortenLockTime();
        }

        uint256 lockDuration = unlockTime - block.timestamp;
        if (lockDuration > MAX_LOCK_TIME) revert LockDurationExceedsMax();

        if (amount > 0) {
            andeToken.safeTransferFrom(msg.sender, address(this), amount);
        }

        userLock.amount += amount;
        userLock.end = unlockTime;
    }

    function withdraw() external {
        LockedBalance storage userLock = lockedBalances[msg.sender];
        if (userLock.amount == 0) revert NoLockFound();
        if (block.timestamp < userLock.end) revert LockNotExpired();

        uint256 amount = userLock.amount;
        delete lockedBalances[msg.sender];

        andeToken.safeTransfer(msg.sender, amount);
    }

    function balanceOf(address owner) public view returns (uint256) {
        LockedBalance storage userLock = lockedBalances[owner];
        if (userLock.amount == 0 || block.timestamp >= userLock.end) {
            return 0;
        }
        uint256 timeRemaining = userLock.end - block.timestamp;
        return userLock.amount * timeRemaining / MAX_LOCK_TIME;
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
