// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IXERC20Lockbox
 * @author Ande Labs (adapted from ERC-7281 standard)
 * @notice Interface for xERC20 Lockbox - wraps existing ERC20 tokens into xERC20
 * @dev Provides 1:1 conversion between ERC20 and xERC20 tokens
 */
interface IXERC20Lockbox {
    // ==================== EVENTS ====================

    /**
     * @notice Emitted when tokens are deposited and xERC20 minted
     * @param sender Address that deposited tokens
     * @param amount Amount of tokens deposited
     */
    event Deposit(address indexed sender, uint256 amount);

    /**
     * @notice Emitted when xERC20 is burned and tokens withdrawn
     * @param sender Address that withdrew tokens
     * @param amount Amount of tokens withdrawn
     */
    event Withdraw(address indexed sender, uint256 amount);

    // ==================== ERRORS ====================

    /**
     * @notice Error when attempting to deposit/withdraw zero amount
     */
    error IXERC20Lockbox_Invalid_Amount();

    /**
     * @notice Error when withdrawal fails
     */
    error IXERC20Lockbox_Withdrawal_Failed();

    // ==================== FUNCTIONS ====================

    /**
     * @notice Deposits ERC20 tokens and mints equivalent xERC20 tokens
     * @dev Transfers ERC20 from sender to lockbox, mints xERC20 to sender
     * @param amount Amount of tokens to deposit
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Burns xERC20 tokens and withdraws equivalent ERC20 tokens
     * @dev Burns xERC20 from sender, transfers ERC20 to sender
     * @param amount Amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice Deposits ERC20 tokens and mints xERC20 to a specified address
     * @dev Transfers ERC20 from sender to lockbox, mints xERC20 to recipient
     * @param to Address to receive the minted xERC20 tokens
     * @param amount Amount of tokens to deposit
     */
    function depositTo(address to, uint256 amount) external;

    /**
     * @notice Burns xERC20 tokens and withdraws ERC20 to a specified address
     * @dev Burns xERC20 from sender, transfers ERC20 to recipient
     * @param to Address to receive the withdrawn ERC20 tokens
     * @param amount Amount of tokens to withdraw
     */
    function withdrawTo(address to, uint256 amount) external;

    // ==================== VIEW FUNCTIONS ====================

    /**
     * @notice Returns the address of the underlying ERC20 token
     * @return Address of the ERC20 token
     */
    function ERC20() external view returns (address);

    /**
     * @notice Returns the address of the xERC20 token
     * @return Address of the xERC20 token
     */
    function XERC20() external view returns (address);
}
