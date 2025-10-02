// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title veANDE (Vote-Escrowed ANDE)
 * @notice This contract handles the locking of ANDE tokens for a specified duration
 *         in exchange for voting power (veANDE). The voting power decays linearly
 *         over time. This is based on the model pioneered by Curve Finance.
 */
contract veANDE is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20 for ERC20Upgradeable;

    // --- Structs ---

    struct LockedBalance {
        uint256 amount; // Amount of ANDE locked
        uint256 unlockTime; // Timestamp when the lock expires
    }

    // --- State Variables ---

    ERC20Upgradeable public andeToken; // The ANDE token contract

    mapping(address => LockedBalance) public lockedBalances;

    // --- Constants ---

    uint256 public constant MAX_LOCK_TIME = 4 * 365 days; // 4 years
    uint256 public constant WEEK = 7 days;

    // --- Events ---

    event LockCreated(address indexed user, uint256 amount, uint256 unlockTime);
    event Withdrawn(address indexed user, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // --- Initializer ---

    function initialize(address _andeTokenAddress, address _defaultAdmin) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);

        andeToken = ERC20Upgradeable(_andeTokenAddress);
    }

    // --- Public Functions ---

    /**
     * @notice Create a new lock or increase an existing lock's amount/duration.
     * @param _amount The amount of ANDE to lock.
     * @param _unlockTime The new unlock time. Must be in the future and up to MAX_LOCK_TIME.
     */
    function createLock(uint256 _amount, uint256 _unlockTime) external {
        LockedBalance storage userLock = lockedBalances[msg.sender];
        require(userLock.amount == 0, "veANDE: Withdraw old lock first");

        require(_amount > 0, "veANDE: Cannot lock 0 tokens");

        uint256 roundedUnlockTime = (_unlockTime / WEEK) * WEEK;
        require(roundedUnlockTime > block.timestamp, "veANDE: Unlock time must be in the future");
        require(roundedUnlockTime <= block.timestamp + MAX_LOCK_TIME, "veANDE: Lock duration cannot exceed max lock time");

        // Update state before transfer to prevent re-entrancy issues (Checks-Effects-Interactions pattern)
        userLock.amount = _amount;
        userLock.unlockTime = roundedUnlockTime;

        // Transfer ANDE tokens from the user to this contract
        andeToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit LockCreated(msg.sender, _amount, roundedUnlockTime);
    }

    /**
     * @notice Withdraw locked ANDE tokens after the lock has expired.
     */
    function withdraw() external {
        // TODO: Implement withdrawal logic
        // 1. Check that the lock has expired (block.timestamp >= unlockTime)
        // 2. Get the locked amount
        // 3. Delete the user's lock
        // 4. Transfer the ANDE back to the user
        // 5. Emit Withdrawn event
    }

    // --- UUPS Upgrade Function ---
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {}

    // --- View Functions ---

    /**
     * @notice Calculate the current voting power (veANDE balance) of a user.
     *         The power decays linearly from the moment of locking until the unlock time.
     * @param _user The address of the user.
     * @return The user's current voting power.
     */
    function balanceOf(address _user) public view returns (uint256) {
        LockedBalance memory userLock = lockedBalances[_user];

        if (userLock.unlockTime <= block.timestamp || userLock.amount == 0) {
            return 0;
        }

        uint256 timeRemaining = userLock.unlockTime - block.timestamp;
        
        // Voting power decays linearly over time
        return (userLock.amount * timeRemaining) / MAX_LOCK_TIME;
    }
}