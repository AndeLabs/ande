// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title LiquidityGaugeV1
 * @author Ande Labs
 * @notice A contract for staking LP tokens and receiving reward tokens.
 * @dev LPs deposit their LP tokens here. The gauge receives rewards from a minter
 *      and distributes them to the stakers based on the gauge's weight from the
 *      GaugeController.
 */
contract LiquidityGaugeV1 is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- Constants ---

    uint256 public constant WEEK = 7 days;

    // --- State Variables ---

    IERC20 public immutable lp_token; // The token being staked (e.g., a Uniswap LP token)
    address public minter; // Address of the ANDE minter contract
    IERC20 public reward_token; // The reward token (ANDE)

    mapping(address => uint256) public rewards;
    mapping(address => uint256) public user_reward_per_token_paid;

    uint256 public reward_rate;
    uint256 public last_update_time;
    uint256 public reward_per_token_stored;

    // --- Constructor ---

    constructor(address _lp_addr, address _minter, address _reward_token) ERC20("Ande Liquidity Gauge", "aLG") {
        lp_token = IERC20(_lp_addr);
        minter = _minter;
        reward_token = IERC20(_reward_token);
    }

    // --- Modifiers ---

    modifier update_reward(address _user) {
        reward_per_token_stored = reward_per_token();
        last_update_time = block.timestamp;

        if (_user != address(0)) {
            rewards[_user] = earned(_user);
            user_reward_per_token_paid[_user] = reward_per_token_stored;
        }
        _;
    }

    // --- External Functions: User Interactions ---

    /**
     * @notice Deposit LP tokens to stake in the gauge.
     * @param _value The amount of LP tokens to deposit.
     */
    function deposit(uint256 _value) external nonReentrant update_reward(msg.sender) returns (bool) {
        require(_value > 0, "LG: Cannot deposit 0");

        // Transfer LP tokens from user
        lp_token.safeTransferFrom(msg.sender, address(this), _value);

        // Mint gauge share tokens to the user
        _mint(msg.sender, _value);

        return true;
    }

    /**
     * @notice Withdraw LP tokens from the gauge.
     * @param _value The amount of LP tokens to withdraw.
     */
    function withdraw(uint256 _value) external nonReentrant update_reward(msg.sender) returns (bool) {
        require(_value > 0, "LG: Cannot withdraw 0");

        // Burn user's gauge share tokens
        _burn(msg.sender, _value);

        // Transfer LP tokens back to user
        lp_token.safeTransfer(msg.sender, _value);

        return true;
    }

    /**
     * @notice Claim available reward tokens.
     */
    function claim_rewards() external nonReentrant update_reward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            reward_token.safeTransfer(msg.sender, reward);
        }
    }

    // --- External Functions: Minter/Admin Interactions ---

    /**
     * @notice Called by the minter to notify the gauge of a new reward amount.
     * @param _amount The amount of reward tokens for the next period.
     */
    function notifyRewardAmount(uint256 _amount) external update_reward(address(0)) {
        require(msg.sender == minter, "LG: Only minter can notify");

        if (block.timestamp >= last_update_time + WEEK) {
            reward_rate = _amount / WEEK;
        } else {
            uint256 remaining_time = last_update_time + WEEK - block.timestamp;
            uint256 leftover_rewards = remaining_time * reward_rate;
            reward_rate = (_amount + leftover_rewards) / WEEK;
        }

        last_update_time = block.timestamp;
    }

    // --- View Functions ---

    function reward_per_token() public view returns (uint256) {
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            return reward_per_token_stored;
        }
        return reward_per_token_stored + ((block.timestamp - last_update_time) * reward_rate * 1e18) / _totalSupply;
    }

    /**
     * @notice Calculate the amount of rewards earned by a user.
     * @param _user The address of the user.
     * @return The amount of rewards earned.
     */
    function earned(address _user) public view returns (uint256) {
        return (balanceOf(_user) * (reward_per_token() - user_reward_per_token_paid[_user])) / 1e18 + rewards[_user];
    }
}
