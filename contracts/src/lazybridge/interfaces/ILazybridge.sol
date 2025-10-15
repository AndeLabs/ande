// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title ILazybridge
 * @notice Main interface for ZK-powered instant bridging via Celestia
 * @dev Combines ZK proofs + Celestia DA + IBC for <5 second bridges
 */
interface ILazybridge {
    /**
     * @notice Bridge lock event structure
     */
    struct BridgeLock {
        address token;           // Token being bridged
        uint256 amount;          // Amount locked
        address sender;          // Original sender
        uint256 sourceChainId;   // Source chain ID
        uint256 destChainId;     // Destination chain ID
        address recipient;       // Recipient on dest chain
        uint256 nonce;           // Unique nonce
        uint64 timestamp;        // Lock timestamp
    }

    /**
     * @notice ZK proof data structure
     */
    struct ZKProof {
        bytes proof;             // Compressed Groth16 proof
        uint256[] publicSignals; // Public inputs
        uint64 celestiaHeight;   // Height where proof was posted
        bytes32 dataRoot;        // Celestia data root
    }

    // ========================================
    // EVENTS
    // ========================================

    event TokensLocked(
        address indexed token,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 destChainId,
        uint256 nonce
    );

    event TokensUnlocked(
        address indexed token,
        address indexed recipient,
        uint256 amount,
        uint256 sourceChainId,
        uint256 nonce
    );

    event ProofSubmitted(
        uint256 indexed nonce,
        uint64 celestiaHeight,
        bytes32 proofHash
    );

    event BridgeCompleted(
        uint256 indexed nonce,
        address indexed recipient,
        uint256 amount,
        uint256 totalTime
    );

    // ========================================
    // CORE FUNCTIONS
    // ========================================

    /**
     * @notice Lock tokens on source chain to initiate bridge
     * @param token Token address to bridge
     * @param amount Amount to lock
     * @param destChainId Destination chain ID
     * @param recipient Recipient address on destination chain
     * @return nonce Unique nonce for this bridge operation
     */
    function lock(
        address token,
        uint256 amount,
        uint256 destChainId,
        address recipient
    ) external returns (uint256 nonce);

    /**
     * @notice Relay a ZK proof to complete bridge on destination chain
     * @param lockData Original lock data
     * @param zkProof ZK proof of the lock
     * @param ibcPacket IBC packet from Celestia
     * @param daProof Data availability proof
     */
    function relay(
        BridgeLock calldata lockData,
        ZKProof calldata zkProof,
        bytes calldata ibcPacket,
        bytes calldata daProof
    ) external;

    /**
     * @notice Emergency unlock if bridge fails
     * @param nonce Lock nonce
     */
    function emergencyUnlock(uint256 nonce) external;

    // ========================================
    // VIEW FUNCTIONS
    // ========================================

    /**
     * @notice Get bridge lock details
     * @param nonce Lock nonce
     * @return lock Bridge lock data
     */
    function getLock(uint256 nonce) external view returns (BridgeLock memory lock);

    /**
     * @notice Check if a lock has been completed
     * @param nonce Lock nonce
     * @return completed True if bridge completed
     */
    function isCompleted(uint256 nonce) external view returns (bool completed);

    /**
     * @notice Get the current bridge nonce
     * @return nonce Current nonce
     */
    function getCurrentNonce() external view returns (uint256 nonce);

    /**
     * @notice Check if a token is supported for bridging
     * @param token Token address
     * @return supported True if token is supported
     */
    function isSupportedToken(address token) external view returns (bool supported);
}
