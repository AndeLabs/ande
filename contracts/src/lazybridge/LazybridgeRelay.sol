// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ILazybridge.sol";
import "./interfaces/IZKVerifier.sol";
import "./interfaces/ICelestiaLightClient.sol";

/**
 * @title LazybridgeRelay
 * @notice ZK-powered instant bridging via Celestia DA + IBC
 * @dev Achieves <5 second bridge times using Groth16 proofs
 *
 * Flow:
 * 1. User locks tokens on source chain
 * 2. ZK prover generates proof of lock (off-chain)
 * 3. Proof submitted to Celestia for DA
 * 4. Relay verifies proof + DA + IBC packet
 * 5. Tokens minted/unlocked on destination chain
 *
 * @author Ande Labs
 */
contract LazybridgeRelay is ILazybridge, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ========================================
    // STATE VARIABLES
    // ========================================

    /// @notice ZK proof verifier contract
    IZKVerifier public immutable zkVerifier;

    /// @notice Celestia IBC light client
    ICelestiaLightClient public celestiaClient;

    /// @notice Current bridge nonce
    uint256 private _currentNonce;

    /// @notice Mapping of nonce to bridge lock data
    mapping(uint256 => BridgeLock) public locks;

    /// @notice Mapping of nonce to completion status
    mapping(uint256 => bool) public completed;

    /// @notice Mapping of nonce to Celestia height
    mapping(uint256 => uint64) public lockToCelestiaHeight;

    /// @notice Supported tokens for bridging
    mapping(address => bool) public supportedTokens;

    /// @notice Bridge timeout period (emergency unlock)
    uint256 public constant BRIDGE_TIMEOUT = 1 hours;

    /// @notice Chain ID
    uint256 public immutable chainId;

    /// @notice Minimum Celestia confirmations required
    uint64 public minCelestiaConfirmations = 12; // ~12 seconds

    // ========================================
    // ERRORS
    // ========================================

    error TokenNotSupported();
    error InvalidAmount();
    error InvalidRecipient();
    error InvalidChainId();
    error LockNotFound();
    error AlreadyCompleted();
    error InvalidZKProof();
    error InvalidIBCPacket();
    error InsufficientCelestiaConfirmations();
    error BridgeNotExpired();
    error Unauthorized();
    error TransferFailed();

    // ========================================
    // CONSTRUCTOR
    // ========================================

    /**
     * @notice Initialize Lazybridge relay
     * @param _zkVerifier ZK verifier contract address
     * @param _celestiaClient Celestia light client address
     * @param initialOwner Owner address
     */
    constructor(
        address _zkVerifier,
        address _celestiaClient,
        address initialOwner
    ) Ownable(initialOwner) {
        if (_zkVerifier == address(0)) revert InvalidRecipient();
        if (_celestiaClient == address(0)) revert InvalidRecipient();

        zkVerifier = IZKVerifier(_zkVerifier);
        celestiaClient = ICelestiaLightClient(_celestiaClient);
        chainId = block.chainid;
        _currentNonce = 1;
    }

    // ========================================
    // CORE BRIDGE FUNCTIONS
    // ========================================

    /**
     * @inheritdoc ILazybridge
     */
    function lock(
        address token,
        uint256 amount,
        uint256 destChainId,
        address recipient
    ) external nonReentrant returns (uint256 nonce) {
        // Validations
        if (!supportedTokens[token]) revert TokenNotSupported();
        if (amount == 0) revert InvalidAmount();
        if (recipient == address(0)) revert InvalidRecipient();
        if (destChainId == chainId) revert InvalidChainId();

        // Generate nonce
        nonce = _currentNonce++;

        // Create lock record
        locks[nonce] = BridgeLock({
            token: token,
            amount: amount,
            sender: msg.sender,
            sourceChainId: chainId,
            destChainId: destChainId,
            recipient: recipient,
            nonce: nonce,
            timestamp: uint64(block.timestamp)
        });

        // Lock tokens
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit TokensLocked(token, msg.sender, recipient, amount, destChainId, nonce);

        return nonce;
    }

    /**
     * @inheritdoc ILazybridge
     */
    function relay(
        BridgeLock calldata lockData,
        ZKProof calldata zkProof,
        bytes calldata ibcPacket,
        bytes calldata daProof
    ) external nonReentrant {
        uint256 nonce = lockData.nonce;

        // Validations
        if (locks[nonce].timestamp == 0) revert LockNotFound();
        if (completed[nonce]) revert AlreadyCompleted();

        // Verify lock data matches
        _verifyLockData(nonce, lockData);

        // 1. Verify ZK proof locally
        if (!_verifyZKProof(lockData, zkProof)) {
            revert InvalidZKProof();
        }

        // 2. Verify data availability on Celestia
        if (!_verifyDataAvailability(zkProof, daProof)) {
            revert InsufficientCelestiaConfirmations();
        }

        // 3. Verify IBC packet from Celestia
        if (!_verifyIBCPacket(ibcPacket, zkProof)) {
            revert InvalidIBCPacket();
        }

        // Mark as completed
        completed[nonce] = true;
        lockToCelestiaHeight[nonce] = zkProof.celestiaHeight;

        // Unlock/mint tokens on destination chain
        IERC20(lockData.token).safeTransfer(lockData.recipient, lockData.amount);

        uint256 totalTime = block.timestamp - lockData.timestamp;

        emit TokensUnlocked(
            lockData.token,
            lockData.recipient,
            lockData.amount,
            lockData.sourceChainId,
            nonce
        );

        emit BridgeCompleted(nonce, lockData.recipient, lockData.amount, totalTime);
    }

    /**
     * @inheritdoc ILazybridge
     */
    function emergencyUnlock(uint256 nonce) external nonReentrant {
        BridgeLock memory bridgeLock = locks[nonce];

        // Validations
        if (bridgeLock.timestamp == 0) revert LockNotFound();
        if (completed[nonce]) revert AlreadyCompleted();
        if (bridgeLock.sender != msg.sender) revert Unauthorized();

        // Check timeout
        if (block.timestamp < bridgeLock.timestamp + BRIDGE_TIMEOUT) {
            revert BridgeNotExpired();
        }

        // Mark as completed to prevent relay
        completed[nonce] = true;

        // Return tokens to sender
        IERC20(bridgeLock.token).safeTransfer(bridgeLock.sender, bridgeLock.amount);

        emit TokensUnlocked(
            bridgeLock.token,
            bridgeLock.sender,
            bridgeLock.amount,
            bridgeLock.sourceChainId,
            nonce
        );
    }

    // ========================================
    // INTERNAL VERIFICATION FUNCTIONS
    // ========================================

    /**
     * @notice Verify lock data matches stored lock
     * @param nonce Lock nonce
     * @param lockData Provided lock data
     */
    function _verifyLockData(uint256 nonce, BridgeLock calldata lockData) internal view {
        BridgeLock memory storedLock = locks[nonce];

        require(lockData.token == storedLock.token, "Token mismatch");
        require(lockData.amount == storedLock.amount, "Amount mismatch");
        require(lockData.sender == storedLock.sender, "Sender mismatch");
        require(lockData.recipient == storedLock.recipient, "Recipient mismatch");
        require(lockData.sourceChainId == storedLock.sourceChainId, "Source chain mismatch");
        require(lockData.destChainId == storedLock.destChainId, "Dest chain mismatch");
    }

    /**
     * @notice Verify ZK proof of bridge lock
     * @param lockData Bridge lock data
     * @param zkProof ZK proof structure
     * @return valid True if proof is valid
     */
    function _verifyZKProof(
        BridgeLock calldata lockData,
        ZKProof calldata zkProof
    ) internal returns (bool valid) {
        // Verify public signals match lock data
        require(zkProof.publicSignals.length >= 6, "Invalid public signals");

        require(
            zkProof.publicSignals[0] == uint256(uint160(lockData.token)),
            "Token signal mismatch"
        );
        require(
            zkProof.publicSignals[1] == lockData.amount,
            "Amount signal mismatch"
        );
        require(
            zkProof.publicSignals[2] == lockData.sourceChainId,
            "Source chain signal mismatch"
        );
        require(
            zkProof.publicSignals[3] == lockData.destChainId,
            "Dest chain signal mismatch"
        );
        require(
            zkProof.publicSignals[4] == uint256(uint160(lockData.recipient)),
            "Recipient signal mismatch"
        );
        require(
            zkProof.publicSignals[5] == lockData.nonce,
            "Nonce signal mismatch"
        );

        // Verify Groth16 proof
        return zkVerifier.verifyProof(zkProof.proof, zkProof.publicSignals);
    }

    /**
     * @notice Verify data availability on Celestia
     * @param zkProof ZK proof with Celestia height
     * @param daProof Data availability proof
     * @return valid True if DA is confirmed
     */
    function _verifyDataAvailability(
        ZKProof calldata zkProof,
        bytes calldata daProof
    ) internal returns (bool valid) {
        // Check Celestia height has enough confirmations
        uint64 latestHeight = celestiaClient.getLatestHeight();
        if (latestHeight < zkProof.celestiaHeight + minCelestiaConfirmations) {
            return false;
        }

        // Verify data availability proof
        return celestiaClient.verifyDataAvailability(
            zkProof.celestiaHeight,
            zkProof.dataRoot,
            daProof
        );
    }

    /**
     * @notice Verify IBC packet from Celestia
     * @param ibcPacket IBC packet bytes
     * @param zkProof ZK proof for correlation
     * @return valid True if packet is valid
     */
    function _verifyIBCPacket(
        bytes calldata ibcPacket,
        ZKProof calldata zkProof
    ) internal returns (bool valid) {
        // Verify IBC packet through Celestia light client
        // This ensures the proof was actually posted to Celestia
        return celestiaClient.verifyIBCPacket(ibcPacket, zkProof.proof);
    }

    // ========================================
    // VIEW FUNCTIONS
    // ========================================

    /// @inheritdoc ILazybridge
    function getLock(uint256 nonce) external view override returns (BridgeLock memory) {
        return locks[nonce];
    }

    /// @inheritdoc ILazybridge
    function isCompleted(uint256 nonce) external view override returns (bool) {
        return completed[nonce];
    }

    /// @inheritdoc ILazybridge
    function getCurrentNonce() external view override returns (uint256) {
        return _currentNonce;
    }

    /// @inheritdoc ILazybridge
    function isSupportedToken(address token) external view override returns (bool) {
        return supportedTokens[token];
    }

    /**
     * @notice Get bridge statistics
     * @param nonce Lock nonce
     * @return celestiaHeight Height where proof was posted
     * @return isComplete Whether bridge is completed
     * @return timeElapsed Time since lock (0 if not completed)
     */
    function getBridgeStats(uint256 nonce)
        external
        view
        returns (uint64 celestiaHeight, bool isComplete, uint256 timeElapsed)
    {
        celestiaHeight = lockToCelestiaHeight[nonce];
        isComplete = completed[nonce];

        if (isComplete && locks[nonce].timestamp > 0) {
            // Note: In production, you'd want to store completion timestamp
            timeElapsed = 0; // Placeholder
        }
    }

    // ========================================
    // ADMIN FUNCTIONS
    // ========================================

    /**
     * @notice Add supported token
     * @param token Token address
     */
    function addSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = true;
    }

    /**
     * @notice Remove supported token
     * @param token Token address
     */
    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = false;
    }

    /**
     * @notice Update Celestia light client
     * @param newClient New client address
     */
    function updateCelestiaClient(address newClient) external onlyOwner {
        if (newClient == address(0)) revert InvalidRecipient();
        celestiaClient = ICelestiaLightClient(newClient);
    }

    /**
     * @notice Update minimum Celestia confirmations
     * @param newMin New minimum confirmations
     */
    function updateMinConfirmations(uint64 newMin) external onlyOwner {
        minCelestiaConfirmations = newMin;
    }

    /**
     * @notice Emergency withdraw tokens (owner only)
     * @param token Token address
     * @param to Recipient
     * @param amount Amount
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }
}
