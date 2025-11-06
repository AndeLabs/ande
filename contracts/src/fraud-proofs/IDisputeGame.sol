// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IDisputeGame
 * @notice Interface for all dispute game implementations
 * @dev All dispute games must implement this interface to work with the factory
 */
interface IDisputeGame {
    /**
     * @notice Represents the status of the dispute game
     */
    enum GameStatus {
        IN_PROGRESS,     // Game is still being played
        CHALLENGER_WINS, // Challenger successfully disputed the claim
        DEFENDER_WINS    // Defender successfully defended the claim
    }

    /**
     * @notice Emitted when the game status changes
     */
    event GameStatusChanged(GameStatus indexed newStatus, address indexed resolver);

    /**
     * @notice Emitted when a move is made in the game
     */
    event Move(uint256 indexed claimIndex, address indexed claimant, bytes32 claim);

    /**
     * @notice Returns the current status of the game
     */
    function status() external view returns (GameStatus);

    /**
     * @notice Returns the root claim being disputed
     */
    function rootClaim() external view returns (bytes32);

    /**
     * @notice Returns the address of the creator of this game
     */
    function creator() external view returns (address);

    /**
     * @notice Returns the timestamp when the game was created
     */
    function createdAt() external view returns (uint256);

    /**
     * @notice Returns the timestamp when the game resolved (0 if not resolved)
     */
    function resolvedAt() external view returns (uint256);

    /**
     * @notice Resolves the game and determines the winner
     * @dev Can only be called once per game
     */
    function resolve() external;

    /**
     * @notice Returns extra data for the game (implementation specific)
     */
    function extraData() external view returns (bytes memory);

    /**
     * @notice Returns the game type identifier
     */
    function gameType() external pure returns (uint8);
}
