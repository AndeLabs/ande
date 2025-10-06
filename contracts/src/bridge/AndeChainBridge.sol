// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IXERC20} from "../interfaces/IXERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IBlobstream} from "./IBlobstream.sol";

/**
 * @title AndeChainBridge
 * @author Ande Labs
 * @notice Reference implementation for bridging xERC20 tokens with Celestia DA
 * @dev This contract demonstrates how to integrate AndeChain xERC20 tokens with a bridge
 *
 * Key Features:
 * - Burn tokens on source chain
 * - Mint tokens on destination chain with proof verification
 * - Rate limiting through xERC20 standard
 * - Support for multiple tokens
 * - Emergency pause mechanism
 *
 * Architecture:
 * 1. User calls bridgeTokens() → burns tokens, emits event
 * 2. Relayer picks up event from source chain
 * 3. Relayer queries Celestia for Merkle proof
 * 4. Relayer calls receiveTokens() on destination with proof
 * 5. Tokens minted to recipient on destination chain
 */
contract AndeChainBridge is ReentrancyGuard, Ownable, Pausable {
    // ==================== STATE VARIABLES ====================

    /// @notice Mapping of supported xERC20 tokens
    mapping(address => bool) public supportedTokens;

    /// @notice Mapping of destination chain IDs to their bridge addresses
    mapping(uint256 => address) public destinationBridges;

    /// @notice Mapping to prevent replay attacks: txHash => processed
    mapping(bytes32 => bool) public processedTransactions;

    /// @notice Nonce for bridge transactions (unique identifier)
    uint256 public nonce;

    /// @notice Minimum confirmations required before bridging
    uint256 public minConfirmations;

    /// @notice Address of Celestia Blobstream verifier contract
    address public blobstreamVerifier;

    /// @notice Force inclusion period (time after which users can force transactions)
    uint256 public forceInclusionPeriod;

    // ==================== EVENTS ====================

    /**
     * @notice Emitted when tokens are bridged to destination chain
     * @param token Token address
     * @param sender Address that initiated bridge
     * @param recipient Recipient on destination chain
     * @param amount Amount bridged
     * @param destinationChain Destination chain ID
     * @param nonce Unique transaction nonce
     */
    event TokensBridged(
        address indexed token,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 destinationChain,
        uint256 nonce
    );

    /**
     * @notice Emitted when tokens are received from source chain
     * @param token Token address
     * @param recipient Recipient address
     * @param amount Amount received
     * @param sourceChain Source chain ID
     * @param sourceTxHash Transaction hash from source chain
     */
    event TokensReceived(
        address indexed token,
        address indexed recipient,
        uint256 amount,
        uint256 sourceChain,
        bytes32 indexed sourceTxHash
    );

    /**
     * @notice Emitted when a token is added to supported list
     */
    event TokenAdded(address indexed token);

    /**
     * @notice Emitted when a token is removed from supported list
     */
    event TokenRemoved(address indexed token);

    /**
     * @notice Emitted when destination bridge is configured
     */
    event DestinationBridgeSet(uint256 indexed chainId, address bridge);

    // ==================== STRUCTS =====================

    struct BridgeTransaction {
        address token;
        address recipient;
        uint256 amount;
        uint256 sourceChain;
        bytes32 sourceTxHash;
        uint256 blockTimestamp; // Timestamp of inclusion in DA layer
    }

    // ==================== ERRORS ====================

    error TokenNotSupported();
    error InvalidAmount();
    error InvalidRecipient();
    error DestinationChainNotConfigured();
    error ProofVerificationFailed();
    error TransactionAlreadyProcessed();
    error InvalidBlobstreamVerifier();
    error InsufficientConfirmations();
    error ForcePeriodNotElapsed();

    // ==================== CONSTRUCTOR ====================

    /**
     * @notice Initializes the bridge contract
     * @param initialOwner Owner address (should be multi-sig)
     * @param _blobstreamVerifier Celestia Blobstream verifier address
     * @param _minConfirmations Minimum confirmations required
     * @param _forceInclusionPeriod Time window for forced transactions
     */
    constructor(
        address initialOwner,
        address _blobstreamVerifier,
        uint256 _minConfirmations,
        uint256 _forceInclusionPeriod
    ) Ownable(initialOwner) {
        if (_blobstreamVerifier == address(0)) revert InvalidBlobstreamVerifier();

        blobstreamVerifier = _blobstreamVerifier;
        minConfirmations = _minConfirmations;
        forceInclusionPeriod = _forceInclusionPeriod;
    }

    // ==================== EXTERNAL FUNCTIONS ====================

    /**
     * @notice Bridge tokens to destination chain
     * @dev Burns tokens on current chain and emits event for relayer
     * @param token xERC20 token address to bridge
     * @param recipient Recipient address on destination chain
     * @param amount Amount to bridge
     * @param destinationChain Destination chain ID (1 = Ethereum, 137 = Polygon, etc.)
     */
    function bridgeTokens(address token, address recipient, uint256 amount, uint256 destinationChain)
        external
        nonReentrant
        whenNotPaused
    {
        // Validation
        if (!supportedTokens[token]) revert TokenNotSupported();
        if (amount == 0) revert InvalidAmount();
        if (recipient == address(0)) revert InvalidRecipient();
        if (destinationBridges[destinationChain] == address(0)) {
            revert DestinationChainNotConfigured();
        }

        // Burn tokens using xERC20 interface
        // This will check rate limits and revert if exceeded
        IXERC20(token).burn(msg.sender, amount);

        // Emit event for relayer to pick up
        emit TokensBridged(token, msg.sender, recipient, amount, destinationChain, nonce++);
    }

    /**
     * @notice Receive and mint bridged tokens from source chain
     * @dev Only callable by owner (relayer) with valid proof
     * @param token Token address on this chain
     * @param recipient Recipient address
     * @param amount Amount to mint
     * @param sourceChain Source chain ID
     * @param sourceTxHash Transaction hash from source chain
     * @param proof Merkle proof from Celestia Blobstream
     */
    function receiveTokens(
        address token,
        address recipient,
        uint256 amount,
        uint256 sourceChain,
        bytes32 sourceTxHash,
        bytes calldata proof
    ) external nonReentrant whenNotPaused onlyOwner {
        // Validation
        if (!supportedTokens[token]) revert TokenNotSupported();
        if (processedTransactions[sourceTxHash]) {
            revert TransactionAlreadyProcessed();
        }

        // Verify proof from Celestia DA layer
        if (!_verifyBlobstreamProof(sourceTxHash, sourceChain, proof)) {
            revert ProofVerificationFailed();
        }

        // Mark transaction as processed to prevent replay
        processedTransactions[sourceTxHash] = true;

        // Mint tokens using xERC20 interface
        // This will check rate limits and revert if exceeded
        IXERC20(token).mint(recipient, amount);

        emit TokensReceived(token, recipient, amount, sourceChain, sourceTxHash);
    }

    /**
     * @notice Allows a user to force a transaction if the relayer has not processed it
     * @dev Requires a valid proof and that the forceInclusionPeriod has passed
     * @param txData The full transaction data struct
     * @param proof Merkle proof from Celestia Blobstream
     */
    function forceTransaction(BridgeTransaction calldata txData, bytes calldata proof)
        external
        nonReentrant
        whenNotPaused
    {
        // 1. Check if already processed
        if (processedTransactions[txData.sourceTxHash]) {
            revert TransactionAlreadyProcessed();
        }

        // 2. Verify the proof from Celestia
        if (!_verifyBlobstreamProof(txData.sourceTxHash, txData.sourceChain, proof)) {
            revert ProofVerificationFailed();
        }

        // 3. Check if the force inclusion period has passed
        if (block.timestamp < txData.blockTimestamp + forceInclusionPeriod) {
            revert ForcePeriodNotElapsed();
        }

        // 4. Mark as processed to prevent replay
        processedTransactions[txData.sourceTxHash] = true;

        // 5. Mint the tokens to the recipient
        IXERC20(txData.token).mint(txData.recipient, txData.amount);

        emit TokensReceived(txData.token, txData.recipient, txData.amount, txData.sourceChain, txData.sourceTxHash);
    }

    // ==================== ADMIN FUNCTIONS ====================

    /**
     * @notice Add a supported xERC20 token
     * @param token Token address to add
     */
    function addSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = true;
        emit TokenAdded(token);
    }

    /**
     * @notice Remove a supported token
     * @param token Token address to remove
     */
    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = false;
        emit TokenRemoved(token);
    }

    /**
     * @notice Configure destination bridge address for a chain
     * @param chainId Destination chain ID
     * @param bridge Bridge address on destination chain
     */
    function setDestinationBridge(uint256 chainId, address bridge) external onlyOwner {
        destinationBridges[chainId] = bridge;
        emit DestinationBridgeSet(chainId, bridge);
    }

    /**
     * @notice Update Blobstream verifier address
     * @param newVerifier New verifier address
     */
    function setBlobstreamVerifier(address newVerifier) external onlyOwner {
        if (newVerifier == address(0)) revert InvalidBlobstreamVerifier();
        blobstreamVerifier = newVerifier;
    }

    /**
     * @notice Update minimum confirmations
     * @param newMinConfirmations New minimum confirmations
     */
    function setMinConfirmations(uint256 newMinConfirmations) external onlyOwner {
        minConfirmations = newMinConfirmations;
    }

    /**
     * @notice Update the force inclusion period
     * @param _forceInclusionPeriod New force inclusion period in seconds
     */
    function setForceInclusionPeriod(uint256 _forceInclusionPeriod) external onlyOwner {
        forceInclusionPeriod = _forceInclusionPeriod;
    }

    /**
     * @notice Pause bridge operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause bridge operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ==================== INTERNAL FUNCTIONS ====================

    /**
     * @notice Verify Merkle proof from Celestia Blobstream
     * @dev This is a simplified version - actual implementation should use Blobstream contract
     * @param txHash Transaction hash to verify
     * @param sourceChain Source chain ID
     * @param proof Merkle proof bytes
     * @return bool True if proof is valid
     */
    function _verifyBlobstreamProof(bytes32 txHash, uint256 sourceChain, bytes calldata proof)
        internal
        view
        returns (bool)
    {
        // Call the actual Blobstream contract to verify the proof.
        // This ensures the transaction is valid and included in the DA layer.
        return IBlobstream(blobstreamVerifier).verifyAttestation(txHash, sourceChain, proof, minConfirmations);
    }

    // ==================== VIEW FUNCTIONS ====================

    /**
     * @notice Check if a token is supported
     * @param token Token address to check
     * @return bool True if supported
     */
    function isTokenSupported(address token) external view returns (bool) {
        return supportedTokens[token];
    }

    /**
     * @notice Get destination bridge for a chain
     * @param chainId Chain ID to query
     * @return address Bridge address on destination chain
     */
    function getDestinationBridge(uint256 chainId) external view returns (address) {
        return destinationBridges[chainId];
    }

    /**
     * @notice Check if a transaction has been processed
     * @param txHash Transaction hash to check
     * @return bool True if processed
     */
    function isTransactionProcessed(bytes32 txHash) external view returns (bool) {
        return processedTransactions[txHash];
    }
}
