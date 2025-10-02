// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract veANDE is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    struct LockedBalance {
        uint256 amount;
        uint256 end;
    }

    IERC20 public andeToken;
    mapping(address => LockedBalance) public locked_balances;

    uint256 public constant MAX_LOCK_TIME = 4 * 365 days;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address andeTokenAddress) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        require(andeTokenAddress != address(0), "ANDE token address cannot be zero");
        andeToken = IERC20(andeTokenAddress);
    }

    function create_lock(uint256 _amount, uint256 _unlock_time) external {
        LockedBalance storage user_lock = locked_balances[msg.sender];

        if (user_lock.amount == 0) {
            require(_amount > 0, "Amount must be positive for new locks");
        }

        require(_unlock_time > block.timestamp, "Unlock time must be in the future");

        if (user_lock.amount > 0) {
            require(_unlock_time >= user_lock.end, "Cannot shorten lock time");
        }

        uint256 lock_duration = _unlock_time - block.timestamp;
        require(lock_duration <= MAX_LOCK_TIME, "Lock duration cannot exceed 4 years");

        if (_amount > 0) {
            andeToken.safeTransferFrom(msg.sender, address(this), _amount);
        }

        user_lock.amount += _amount;
        user_lock.end = _unlock_time;
    }

    function withdraw() external {
        LockedBalance storage user_lock = locked_balances[msg.sender];
        require(user_lock.amount > 0, "No lock found");
        require(block.timestamp >= user_lock.end, "Lock has not expired");

        uint256 amount = user_lock.amount;
        delete locked_balances[msg.sender];

        andeToken.safeTransfer(msg.sender, amount);
    }

    function balanceOf(address _owner) public view returns (uint256) {
        LockedBalance storage user_lock = locked_balances[_owner];
        if (user_lock.amount == 0 || block.timestamp >= user_lock.end) {
            return 0;
        }
        uint256 time_remaining = user_lock.end - block.timestamp;
        return user_lock.amount * time_remaining / MAX_LOCK_TIME;
    }

    // The following functions are required by UUPSUpgradeable.
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {}
}
