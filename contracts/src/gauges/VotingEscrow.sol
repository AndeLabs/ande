// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title VotingEscrow
 * @author Curve Finance, with modifications by Ande Labs
 * @notice A contract for locking tokens to gain voting power.
 * @dev This contract is based on the popular ve-model. Users lock a token (ANDE)
 *      for a specified duration and receive a non-transferable token (veANDE)
 *      representing their voting power. The voting power decays linearly over time.
 */
contract VotingEscrow is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeCast for int256;
    using SafeCast for uint256;

    // --- Structs ---

    struct Point {
        int256 bias;
        int128 slope;
        uint256 ts;
        uint256 blk;
    }

    struct LockedBalance {
        int128 amount;
        uint256 end;
    }

    // --- Enums ---

    enum DepositType {
        DEPOSIT_FOR,
        CREATE_LOCK,
        INCREASE_LOCK_AMOUNT,
        INCREASE_UNLOCK_TIME
    }

    // --- Events ---

    event Deposit(
        address indexed provider,
        uint256 value,
        uint256 indexed locktime,
        DepositType indexed deposit_type,
        uint256 ts
    );
    event Withdraw(address indexed provider, uint256 value, uint256 ts);
    event Supply(uint256 prevSupply, uint256 supply);

    // --- Constants ---

    uint256 public constant WEEK = 7 days;
    uint256 public constant MAXTIME = 4 * 365 days; // 4 years
    int128 public constant iMAXTIME = 4 * 365 * 86400;
    uint256 public constant MAX_EPOCH_JUMP = 255; // Maximum epochs to fill in one checkpoint

    // --- State Variables ---

    IERC20 public immutable token; // The token being locked (ANDE)
    
    string public name;
    string public symbol;
    string public version;
    uint8 public decimals;

    // --- History ---
    mapping(uint256 => Point) public point_history; // epoch -> Point
    mapping(address => mapping(uint256 => Point)) public user_point_history; // user -> epoch -> Point
    
    // --- User Data ---
    mapping(address => LockedBalance) public locked;
    
    uint256 public epoch;
    mapping(address => uint256) public user_point_epoch;
    
    uint256 public supply;

    // --- Constructor ---

    constructor(
        address _token_addr,
        string memory _name,
        string memory _symbol,
        string memory _version
    ) {
        require(_token_addr != address(0), "VE: Invalid token address");
        token = IERC20(_token_addr);
        name = _name;
        symbol = _symbol;
        version = _version;
        decimals = 18; // ve-tokens are typically 18 decimals
    }

    // --- External Functions ---

    /**
     * @notice Create a new lock for a user.
     * @param _value Amount of tokens to lock.
     * @param _unlock_time Timestamp when the lock expires. Must be in the future.
     */
    function create_lock(uint256 _value, uint256 _unlock_time) external nonReentrant {
        address _provider = msg.sender;
        LockedBalance memory old_locked = locked[_provider];
        
        require(_value > 0, "VE: Value must be > 0");
        require(old_locked.amount == 0, "VE: Withdraw old tokens first");

        _deposit_for(_provider, _value, _unlock_time, old_locked, DepositType.CREATE_LOCK);
    }

    /**
     * @notice Increase the amount of tokens in an existing lock.
     * @param _value Amount of tokens to add.
     */
    function increase_amount(uint256 _value) external nonReentrant {
        address _provider = msg.sender;
        LockedBalance memory old_locked = locked[_provider];

        require(_value > 0, "VE: Value must be > 0");
        require(old_locked.amount > 0, "VE: No lock found");
        require(old_locked.end > block.timestamp, "VE: Cannot add to expired lock");

        _deposit_for(_provider, _value, 0, old_locked, DepositType.INCREASE_LOCK_AMOUNT);
    }

    /**
     * @notice Extend the duration of an existing lock.
     * @param _unlock_time The new unlock timestamp. Must be greater than the current one.
     */
    function increase_unlock_time(uint256 _unlock_time) external nonReentrant {
        address _provider = msg.sender;
        LockedBalance memory old_locked = locked[_provider];

        require(old_locked.amount > 0, "VE: No lock found");
        require(old_locked.end > block.timestamp, "VE: Lock expired");
        require(_unlock_time > old_locked.end, "VE: Can only increase lock time");

        _deposit_for(_provider, 0, _unlock_time, old_locked, DepositType.INCREASE_UNLOCK_TIME);
    }

    /**
     * @notice Withdraw tokens after a lock has expired.
     */
    function withdraw() external nonReentrant {
        address _provider = msg.sender;
        LockedBalance memory old_locked = locked[_provider];
        
        require(block.timestamp >= old_locked.end, "VE: Lock not yet expired");
        require(old_locked.amount > 0, "VE: Nothing to withdraw");

        uint256 value = uint256(int256(old_locked.amount));

        // Update checkpoint before changing state (Checks-Effects-Interactions pattern)
        _checkpoint(_provider, old_locked, LockedBalance({amount: 0, end: 0}));

        delete locked[_provider];
        
        token.safeTransfer(_provider, value);

        emit Withdraw(_provider, value, block.timestamp);
    }

    // --- View Functions ---

    /**
     * @notice Get the voting power of an address at the current block.
     * @param _owner The address to query.
     * @return The voting power.
     */
    function balanceOf(address _owner) public view returns (uint256) {
        uint256 user_epoch = user_point_epoch[_owner];
        return _balanceOfAt(_owner, user_epoch, block.timestamp);
    }

    /**
     * @notice Get the voting power of an address at a specific timestamp.
     * @param _owner The address to query.
     * @param _t The timestamp to query at.
     * @return The voting power.
     */
    function balanceOfAt(address _owner, uint256 _t) public view returns (uint256) {
        require(_t <= block.timestamp, "VE: Timestamp in future");
        uint256 user_epoch = user_point_epoch[_owner];
        return _balanceOfAt(_owner, user_epoch, _t);
    }

    function _balanceOfAt(address _owner, uint256 _epoch, uint256 _t) internal view returns (uint256) {
        if (_epoch == 0) {
            return 0;
        }

        // Binary search for the epoch
        uint256 min = 1;
        uint256 max = _epoch;
        while (min < max) {
            uint256 mid = (min + max + 1) / 2;
            if (user_point_history[_owner][mid].ts > _t) {
                max = mid - 1;
            } else {
                min = mid;
            }
        }

        Point memory point = user_point_history[_owner][min];

        int256 bias = point.bias;
        int128 slope = point.slope;

        // Calculate the decay and protect against negative values
        int256 decayedBias = bias - (int256(slope) * int256(_t - point.ts));
        if (decayedBias < 0) {
            return 0;
        }

        return decayedBias.toUint256();
    }

    /**
     * @notice Get the total voting power at the current block.
     * @return The total voting power.
     */
    function totalSupply() public view returns (uint256) {
        return totalSupplyAt(block.timestamp);
    }

    /**
     * @notice Get the total voting power at a specific timestamp.
     * @param _t The timestamp to query at.
     * @return The total voting power.
     */
    function totalSupplyAt(uint256 _t) public view returns (uint256) {
        require(_t <= block.timestamp, "VE: Timestamp in future");
        uint256 _epoch = epoch;
        if (_epoch == 0) {
            return 0;
        }

        // Binary search
        uint256 min = 1;
        uint256 max = _epoch;
        while (min < max) {
            uint256 mid = (min + max + 1) / 2;
            if (point_history[mid].ts > _t) {
                max = mid - 1;
            } else {
                min = mid;
            }
        }

        Point memory point = point_history[min];
        int256 bias = point.bias;
        int128 slope = point.slope;

        // Calculate the decay and protect against negative values
        int256 decayedBias = bias - (int256(slope) * int256(_t - point.ts));
        if (decayedBias < 0) {
            return 0;
        }

        return decayedBias.toUint256();
    }

    // --- Internal Functions ---

    /**
     * @dev Checkpoint for a user or global supply.
     * @param _addr Address to checkpoint. Use address(0) for global supply.
     * @param _old_locked Old locked balance.
     * @param _new_locked New locked balance.
     */
    function _checkpoint(
        address _addr,
        LockedBalance memory _old_locked,
        LockedBalance memory _new_locked
    ) internal {
        Point memory u_old;
        Point memory u_new;
        int128 old_slope = 0;
        int128 new_slope = 0;
        
        // Part 1: Update user's history
        uint256 user_epoch = user_point_epoch[_addr];
        if (user_epoch != 0) {
            u_old = user_point_history[_addr][user_epoch];
        }

        if (_old_locked.end > block.timestamp && _old_locked.amount > 0) {
            old_slope = _old_locked.amount / iMAXTIME;
            u_old.bias -= int256(old_slope) * int256(_old_locked.end - block.timestamp);
            u_old.slope -= old_slope;
        }

        if (_new_locked.end > block.timestamp && _new_locked.amount > 0) {
            new_slope = _new_locked.amount / iMAXTIME;
            u_new.bias = int256(new_slope) * int256(_new_locked.end - block.timestamp);
            u_new.slope = new_slope;
        }

        user_point_epoch[_addr] = user_epoch + 1;
        u_new.ts = block.timestamp;
        u_new.blk = block.number;
        user_point_history[_addr][user_epoch + 1] = u_new;

        // Part 2: Update global history
        uint256 g_epoch = epoch;
        if (g_epoch == 0) {
            g_epoch = 1;
            point_history[1] = Point({bias: 0, slope: 0, ts: block.timestamp, blk: block.number});
        }

        uint256 last_g_ts = point_history[g_epoch].ts;
        uint256 time_delta = block.timestamp - last_g_ts;
        uint256 new_g_epoch = g_epoch + time_delta / WEEK;

        if (new_g_epoch > g_epoch) {
            uint256 epoch_jump = new_g_epoch - g_epoch;
            require(epoch_jump <= MAX_EPOCH_JUMP, "VE: Too many epochs to fill");

            Point memory last_g_point = point_history[g_epoch];
            for (uint i = g_epoch; i < new_g_epoch; i++) {
                point_history[i + 1].bias = last_g_point.bias;
                point_history[i + 1].slope = last_g_point.slope;
            }
        }

        epoch = new_g_epoch;

        // Use memory then write once to save gas
        Point memory current_g_point = point_history[new_g_epoch];
        current_g_point.ts = block.timestamp;
        current_g_point.blk = block.number;
        current_g_point.bias = current_g_point.bias - u_old.bias + u_new.bias;
        current_g_point.slope = current_g_point.slope - u_old.slope + u_new.slope;
        point_history[new_g_epoch] = current_g_point;

        // Part 3: Update total supply
        uint256 supply_before = supply;

        // Calculate the change in supply safely
        // old_supply_contribution = old_slope * iMAXTIME
        // new_supply_contribution = new_slope * iMAXTIME
        int256 old_supply_contribution = int256(old_slope) * int256(iMAXTIME);
        int256 new_supply_contribution = int256(new_slope) * int256(iMAXTIME);

        // Calculate net change: new - old
        int256 supply_delta = new_supply_contribution - old_supply_contribution;

        // Apply the change to supply
        if (supply_delta >= 0) {
            supply = supply_before + supply_delta.toUint256();
        } else {
            uint256 decrease = uint256(-supply_delta);
            require(supply_before >= decrease, "VE: Supply underflow");
            supply = supply_before - decrease;
        }

        if (supply_before != supply) {
            emit Supply(supply_before, supply);
        }
    }

    /**
     * @dev Deposit tokens for a user.
     * @param _provider The user address.
     * @param _value The amount to deposit.
     * @param _unlock_time The new unlock time. Can be 0 to keep the existing one.
     * @param _old_locked The user's old locked balance.
     * @param _deposit_type The type of deposit.
     */
    function _deposit_for(
        address _provider,
        uint256 _value,
        uint256 _unlock_time,
        LockedBalance memory _old_locked,
        DepositType _deposit_type
    ) internal {
        LockedBalance memory new_locked = _old_locked;
        uint256 value = _value;

        if (_unlock_time != 0) {
            require(_unlock_time > block.timestamp, "VE: Can only lock until future");
            require(_unlock_time <= block.timestamp + MAXTIME, "VE: Voting lock can be 4 years max");

            uint256 unlock_time = (_unlock_time / WEEK) * WEEK; // Lock times are rounded down to weeks
            new_locked.end = unlock_time;
        }

        new_locked.amount += int128(int256(value));
        require(new_locked.amount > 0, "VE: New lock amount must be > 0");

        // --- Checkpoints ---
        _checkpoint(_provider, _old_locked, new_locked);

        if (value > 0) {
            token.safeTransferFrom(_provider, address(this), value);
        }

        locked[_provider] = new_locked;

        emit Deposit(
            _provider,
            value,
            new_locked.end,
            _deposit_type,
            block.timestamp
        );
    }
}
