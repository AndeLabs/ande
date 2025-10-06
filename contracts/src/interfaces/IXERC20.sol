// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IXERC20
 * @author Ande Labs (adapted from ERC-7281 standard)
 * @notice Interface for xERC20 tokens - sovereign cross-chain tokens
 * @dev Extends ERC20 with bridge-controlled minting/burning with rate limits
 */
interface IXERC20 {
    // ==================== STRUCTS ====================

    /**
     * @notice Bridge configuration containing minting and burning parameters
     */
    struct Bridge {
        BridgeParameters minterParams;
        BridgeParameters burnerParams;
    }

    /**
     * @notice Rate limiting parameters for bridge operations
     * @param timestamp Last update timestamp for the limit calculation
     * @param ratePerSecond Rate at which the limit replenishes (per second)
     * @param maxLimit Maximum limit that can be accumulated
     * @param currentLimit Current available limit
     */
    struct BridgeParameters {
        uint256 timestamp;
        uint256 ratePerSecond;
        uint256 maxLimit;
        uint256 currentLimit;
    }

    // ==================== EVENTS ====================

    /**
     * @notice Emitted when the lockbox contract is set
     * @param lockbox Address of the lockbox contract
     */
    event LockboxSet(address indexed lockbox);

    /**
     * @notice Emitted when bridge limits are updated
     * @param mintingLimit New minting limit for the bridge
     * @param burningLimit New burning limit for the bridge
     * @param bridge Address of the bridge
     */
    event BridgeLimitsSet(
        uint256 mintingLimit,
        uint256 burningLimit,
        address indexed bridge
    );

    // ==================== ERRORS ====================

    /**
     * @notice Error when attempting operation that exceeds current limits
     */
    error IXERC20_NotHighEnoughLimits();

    /**
     * @notice Error when caller is not the authorized factory
     */
    error IXERC20_NotFactory();

    /**
     * @notice Error when a zero value is provided where it's invalid
     */
    error IXERC20_INVALID_0_VALUE();

    // ==================== FUNCTIONS ====================

    /**
     * @notice Sets the lockbox contract address
     * @dev Only callable by owner
     * @param lockbox Address of the lockbox contract
     */
    function setLockbox(address lockbox) external;

    /**
     * @notice Updates the limits of a bridge
     * @dev Only callable by owner
     * @param bridge Address of the bridge
     * @param mintingLimit Minting limit to set (tokens per duration)
     * @param burningLimit Burning limit to set (tokens per duration)
     */
    function setLimits(
        address bridge,
        uint256 mintingLimit,
        uint256 burningLimit
    ) external;

    /**
     * @notice Returns the maximum minting limit for a bridge
     * @param minter Address of the bridge/minter
     * @return limit Maximum minting limit
     */
    function mintingMaxLimitOf(address minter) external view returns (uint256 limit);

    /**
     * @notice Returns the maximum burning limit for a bridge
     * @param bridge Address of the bridge
     * @return limit Maximum burning limit
     */
    function burningMaxLimitOf(address bridge) external view returns (uint256 limit);

    /**
     * @notice Returns the current available minting limit for a bridge
     * @param minter Address of the bridge/minter
     * @return limit Current available minting limit
     */
    function mintingCurrentLimitOf(address minter) external view returns (uint256 limit);

    /**
     * @notice Returns the current available burning limit for a bridge
     * @param bridge Address of the bridge
     * @return limit Current available burning limit
     */
    function burningCurrentLimitOf(address bridge) external view returns (uint256 limit);

    /**
     * @notice Mints tokens to a user
     * @dev Only callable by authorized bridges within their limits
     * @param user Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address user, uint256 amount) external;

    /**
     * @notice Burns tokens from a user
     * @dev Only callable by authorized bridges within their limits
     * @param user Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(address user, uint256 amount) external;
}
