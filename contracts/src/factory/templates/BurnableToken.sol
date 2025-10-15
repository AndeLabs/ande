// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title BurnableToken
 * @dev ERC20 token with enhanced burning capabilities
 * @notice This token allows users to burn tokens with optional rewards
 * @author AndeChain Team
 */
contract BurnableToken is ERC20, Ownable, Pausable {
    uint256 private _totalBurned;
    uint256 private _burnRewardRate; // Basis points (10000 = 100%)
    bool private _burnRewardsEnabled;
    
    mapping(address => uint256) private _userBurned;
    mapping(address => bool) private _authorizedBurners;
    
    event TokensBurned(address indexed burner, uint256 amount, uint256 reward);
    event BurnRewardRateUpdated(uint256 newRate);
    event BurnRewardsStatusChanged(bool enabled);
    event AuthorizedBurnerAdded(address indexed burner);
    event AuthorizedBurnerRemoved(address indexed burner);
    event BurnRewardsClaimed(address indexed claimant, uint256 rewardAmount);

    /**
     * @dev Constructor for BurnableToken
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param initialSupply The initial supply of tokens
     * @param burnRewardRate The burn reward rate in basis points
     * @param owner The owner of the contract
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 burnRewardRate,
        address owner
    ) ERC20(name, symbol) Ownable(owner) {
        require(initialSupply > 0, "BurnableToken: initial supply must be greater than 0");
        require(owner != address(0), "BurnableToken: owner cannot be zero address");
        require(burnRewardRate <= 1000, "BurnableToken: burn reward rate cannot exceed 10%");
        
        _burnRewardRate = burnRewardRate;
        _burnRewardsEnabled = burnRewardRate > 0;
        
        _mint(owner, initialSupply);
    }

    /**
     * @dev Returns the version of this token
     * @return string The version string
     */
    function version() public pure returns (string memory) {
        return "1.0.0";
    }

    /**
     * @dev Returns the token type
     * @return uint8 The token type identifier (2 for Burnable)
     */
    function tokenType() external pure returns (uint8) {
        return 2;
    }

    /**
     * @dev Returns the total amount of burned tokens
     * @return uint256 Total burned amount
     */
    function totalBurned() external view returns (uint256) {
        return _totalBurned;
    }

    /**
     * @dev Returns the burn reward rate
     * @return uint256 Burn reward rate in basis points
     */
    function burnRewardRate() external view returns (uint256) {
        return _burnRewardRate;
    }

    /**
     * @dev Returns whether burn rewards are enabled
     * @return bool Whether burn rewards are enabled
     */
    function burnRewardsEnabled() external view returns (bool) {
        return _burnRewardsEnabled;
    }

    /**
     * @dev Returns the amount burned by a specific user
     * @param user The user address
     * @return uint256 Amount burned by the user
     */
    function userBurned(address user) external view returns (uint256) {
        return _userBurned[user];
    }

    /**
     * @dev Returns whether an address is an authorized burner
     * @param burner The address to check
     * @return bool Whether the address is authorized
     */
    function isAuthorizedBurner(address burner) external view returns (bool) {
        return _authorizedBurners[burner];
    }

    /**
     * @dev Burns tokens from the caller's account
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external whenNotPaused {
        _burnWithReward(_msgSender(), amount);
    }

    /**
     * @dev Burns tokens from a specified account
     * @param account The account to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burnFrom(address account, uint256 amount) external whenNotPaused {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "BurnableToken: burn amount exceeds allowance");
        
        _approve(account, _msgSender(), currentAllowance - amount);
        _burnWithReward(account, amount);
    }

    /**
     * @dev Burns tokens from a specified account (authorized burners only)
     * @param account The account to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function authorizedBurn(address account, uint256 amount) external whenNotPaused {
        require(_authorizedBurners[_msgSender()], "BurnableToken: not authorized burner");
        require(account != address(0), "BurnableToken: cannot burn from zero address");
        
        _burnWithReward(account, amount);
    }

    /**
     * @dev Batch burn tokens from multiple accounts (authorized burners only)
     * @param accounts The accounts to burn tokens from
     * @param amounts The amounts to burn
     */
    function batchAuthorizedBurn(
        address[] calldata accounts,
        uint256[] calldata amounts
    ) external whenNotPaused {
        require(_authorizedBurners[_msgSender()], "BurnableToken: not authorized burner");
        require(accounts.length == amounts.length, "BurnableToken: arrays length mismatch");
        require(accounts.length > 0, "BurnableToken: empty arrays");
        
        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), "BurnableToken: cannot burn from zero address");
            _burnWithReward(accounts[i], amounts[i]);
        }
    }

    /**
     * @dev Sets the burn reward rate
     * @param newRate The new burn reward rate in basis points
     */
    function setBurnRewardRate(uint256 newRate) external onlyOwner {
        require(newRate <= 1000, "BurnableToken: burn reward rate cannot exceed 10%");
        _burnRewardRate = newRate;
        emit BurnRewardRateUpdated(newRate);
    }

    /**
     * @dev Enables or disables burn rewards
     * @param enabled Whether to enable burn rewards
     */
    function setBurnRewardsEnabled(bool enabled) external onlyOwner {
        _burnRewardsEnabled = enabled;
        emit BurnRewardsStatusChanged(enabled);
    }

    /**
     * @dev Adds an authorized burner
     * @param burner The address to authorize
     */
    function addAuthorizedBurner(address burner) external onlyOwner {
        require(burner != address(0), "BurnableToken: burner cannot be zero address");
        _authorizedBurners[burner] = true;
        emit AuthorizedBurnerAdded(burner);
    }

    /**
     * @dev Removes an authorized burner
     * @param burner The address to deauthorize
     */
    function removeAuthorizedBurner(address burner) external onlyOwner {
        _authorizedBurners[burner] = false;
        emit AuthorizedBurnerRemoved(burner);
    }

    /**
     * @dev Claims burn rewards for the caller
     */
    function claimBurnRewards() external whenNotPaused {
        uint256 rewardAmount = _calculateBurnReward(_msgSender());
        require(rewardAmount > 0, "BurnableToken: no rewards to claim");
        
        _userBurned[_msgSender()] = 0;
        _mint(_msgSender(), rewardAmount);
        
        emit BurnRewardsClaimed(_msgSender(), rewardAmount);
    }

    /**
     * @dev Calculates burn rewards for a user
     * @param user The user address
     * @return uint256 The reward amount
     */
    function calculateBurnReward(address user) external view returns (uint256) {
        return _calculateBurnReward(user);
    }

    /**
     * @dev Pauses the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Returns detailed information about the token
     * @return name_ The token name
     * @return symbol_ The token symbol
     * @return decimals_ The token decimals
     * @return totalSupply_ The total supply
     * @return totalBurned_ The total burned amount
     * @return burnRewardRate_ The burn reward rate
     * @return burnRewardsEnabled_ Whether burn rewards are enabled
     * @return paused_ Whether the contract is paused
     * @return version_ The token version
     */
    function getTokenInfo() external view returns (
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        uint256 totalBurned_,
        uint256 burnRewardRate_,
        bool burnRewardsEnabled_,
        bool paused_,
        string memory version_
    ) {
        return (
            name(),
            symbol(),
            decimals(),
            totalSupply(),
            _totalBurned,
            _burnRewardRate,
            _burnRewardsEnabled,
            paused(),
            version()
        );
    }

    /**
     * @dev Internal function to burn tokens with rewards
     * @param account The account to burn from
     * @param amount The amount to burn
     */
    function _burnWithReward(address account, uint256 amount) internal {
        require(amount > 0, "BurnableToken: burn amount must be greater than 0");
        require(balanceOf(account) >= amount, "BurnableToken: insufficient balance");
        
        _burn(account, amount);
        _totalBurned += amount;
        _userBurned[account] += amount;
        
        uint256 reward = 0;
        if (_burnRewardsEnabled && _burnRewardRate > 0) {
            reward = (amount * _burnRewardRate) / 10000;
        }
        
        emit TokensBurned(account, amount, reward);
    }

    /**
     * @dev Internal function to calculate burn rewards
     * @param user The user address
     * @return uint256 The reward amount
     */
    function _calculateBurnReward(address user) internal view returns (uint256) {
        if (!_burnRewardsEnabled || _burnRewardRate == 0) {
            return 0;
        }
        
        return (_userBurned[user] * _burnRewardRate) / 10000;
    }

    /**
     * @dev Hook that is called before any transfer of tokens
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal view whenNotPaused {
        // Hook for future extensions
    }

    /**
     * @dev Emergency function to rescue tokens sent to contract by mistake
     * @param token The token address to rescue
     * @param amount The amount to rescue
     */
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        require(token != address(this), "BurnableToken: cannot rescue own token");
        require(token != address(0), "BurnableToken: cannot rescue zero address");
        
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).transfer(owner(), amount);
        }
    }

    /**
     * @dev Fallback function to receive ETH
     */
    receive() external payable {
        // Allow contract to receive ETH for rescue functionality
    }
}