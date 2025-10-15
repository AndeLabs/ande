// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../../../src/lazybridge/interfaces/ICelestiaLightClient.sol";

/**
 * @title MockCelestiaLightClient
 * @notice Mock Celestia IBC light client for testing
 * @dev Simulates Celestia block production and data availability
 */
contract MockCelestiaLightClient is ICelestiaLightClient {
    // ========================================
    // STATE VARIABLES
    // ========================================

    /// @notice Current Celestia height (simulated)
    uint64 private _currentHeight;

    /// @notice Mapping of height to data root
    mapping(uint64 => bytes32) private _dataRoots;

    /// @notice Whether to accept all DA proofs
    bool public acceptAllProofs = true;

    /// @notice Mapping of proof hash to validity
    mapping(bytes32 => bool) public proofValidity;

    /// @notice Mapping of IBC packet hash to validity
    mapping(bytes32 => bool) public ibcPacketValidity;

    /// @notice Block time (seconds) - Celestia ~12s
    uint64 public constant BLOCK_TIME = 12;

    /// @notice Last block timestamp
    uint256 private _lastBlockTimestamp;

    // ========================================
    // EVENTS
    // ========================================

    event HeightAdvanced(uint64 indexed newHeight, bytes32 dataRoot);
    event DataRootSet(uint64 indexed height, bytes32 dataRoot);
    event DAProofVerified(uint64 indexed height, bytes32 dataRoot, bool valid);
    event IBCPacketVerified(bytes32 indexed packetHash, bool valid);

    // ========================================
    // CONSTRUCTOR
    // ========================================

    constructor() {
        _currentHeight = 1;
        _lastBlockTimestamp = block.timestamp;
    }

    // ========================================
    // ADMIN FUNCTIONS
    // ========================================

    /**
     * @notice Advance Celestia height (simulate block production)
     * @param dataRoot Data root for new height
     */
    function advanceHeight(bytes32 dataRoot) external {
        _currentHeight++;
        _dataRoots[_currentHeight] = dataRoot;
        _lastBlockTimestamp = block.timestamp;

        emit HeightAdvanced(_currentHeight, dataRoot);
    }

    /**
     * @notice Advance multiple heights at once
     * @param count Number of heights to advance
     */
    function advanceHeights(uint64 count) external {
        for (uint64 i = 0; i < count; i++) {
            _currentHeight++;
            bytes32 dataRoot = keccak256(abi.encodePacked(_currentHeight, block.timestamp));
            _dataRoots[_currentHeight] = dataRoot;
        }
        _lastBlockTimestamp = block.timestamp;

        emit HeightAdvanced(_currentHeight, _dataRoots[_currentHeight]);
    }

    /**
     * @notice Set data root for a specific height
     * @param height Block height
     * @param dataRoot Data root
     */
    function setDataRoot(uint64 height, bytes32 dataRoot) external {
        _dataRoots[height] = dataRoot;
        if (height > _currentHeight) {
            _currentHeight = height;
        }

        emit DataRootSet(height, dataRoot);
    }

    /**
     * @notice Set whether to accept all proofs
     * @param accept True to accept all
     */
    function setAcceptAllProofs(bool accept) external {
        acceptAllProofs = accept;
    }

    /**
     * @notice Set validity for a specific DA proof
     * @param height Block height
     * @param dataRoot Data root
     * @param proof Proof bytes
     * @param valid Whether proof is valid
     */
    function setDAProofValidity(
        uint64 height,
        bytes32 dataRoot,
        bytes calldata proof,
        bool valid
    ) external {
        bytes32 proofHash = keccak256(abi.encodePacked(height, dataRoot, proof));
        proofValidity[proofHash] = valid;
    }

    /**
     * @notice Set validity for an IBC packet
     * @param packet IBC packet bytes
     * @param valid Whether packet is valid
     */
    function setIBCPacketValidity(bytes calldata packet, bool valid) external {
        bytes32 packetHash = keccak256(packet);
        ibcPacketValidity[packetHash] = valid;
    }

    // ========================================
    // ICELESTIALIGHTCLIENT IMPLEMENTATION
    // ========================================

    /// @inheritdoc ICelestiaLightClient
    function verifyDataAvailability(
        uint64 height,
        bytes32 dataRoot,
        bytes calldata proof
    ) external returns (bool valid) {
        // Check if height exists
        require(height <= _currentHeight, "Height not yet produced");

        // Check data root matches
        bytes32 storedRoot = _dataRoots[height];
        if (storedRoot != bytes32(0)) {
            require(storedRoot == dataRoot, "Data root mismatch");
        }

        // If accept all mode, return true
        if (acceptAllProofs) {
            emit DAProofVerified(height, dataRoot, true);
            return true;
        }

        // Check specific proof validity
        bytes32 proofHash = keccak256(abi.encodePacked(height, dataRoot, proof));
        valid = proofValidity[proofHash];

        emit DAProofVerified(height, dataRoot, valid);

        return valid;
    }

    /// @inheritdoc ICelestiaLightClient
    function verifyIBCPacket(
        bytes calldata packet,
        bytes calldata proof
    ) external returns (bool valid) {
        bytes32 packetHash = keccak256(packet);

        // If accept all mode, return true
        if (acceptAllProofs) {
            emit IBCPacketVerified(packetHash, true);
            return true;
        }

        // Check specific packet validity
        valid = ibcPacketValidity[packetHash];

        emit IBCPacketVerified(packetHash, valid);

        return valid;
    }

    /// @inheritdoc ICelestiaLightClient
    function getLatestHeight() external view returns (uint64 height) {
        return _currentHeight;
    }

    /// @inheritdoc ICelestiaLightClient
    function getDataRoot(uint64 height) external view returns (bytes32 dataRoot) {
        require(height <= _currentHeight, "Height not yet produced");
        return _dataRoots[height];
    }

    /// @inheritdoc ICelestiaLightClient
    function verifyHeader(
        bytes calldata header,
        bytes calldata validatorSetProof
    ) external returns (bool valid) {
        // Simplified mock - just check header is not empty
        if (header.length > 0) {
            // Extract height from header (simplified)
            uint64 height = _currentHeight + 1;
            _currentHeight = height;

            // Generate mock data root
            bytes32 dataRoot = keccak256(abi.encodePacked(header, validatorSetProof));
            _dataRoots[height] = dataRoot;

            return true;
        }

        return false;
    }

    // ========================================
    // HELPER FUNCTIONS
    // ========================================

    /**
     * @notice Simulate time passing (advance block time)
     * @param duration Duration in seconds to advance
     */
    function advanceTime(uint256 duration) external {
        _lastBlockTimestamp += duration;
    }

    /**
     * @notice Get mock data root for testing
     * @param height Block height
     * @return dataRoot Generated data root
     */
    function getMockDataRoot(uint64 height) external pure returns (bytes32 dataRoot) {
        return keccak256(abi.encodePacked("celestia_block_", height));
    }

    /**
     * @notice Create a mock IBC packet for testing
     * @param sourceChain Source chain ID
     * @param destChain Dest chain ID
     * @param data Packet data
     * @return packet IBC packet bytes
     */
    function createMockIBCPacket(
        uint256 sourceChain,
        uint256 destChain,
        bytes calldata data
    ) external view returns (bytes memory packet) {
        return abi.encodePacked(
            sourceChain,
            destChain,
            data,
            block.timestamp
        );
    }

    /**
     * @notice Get timestamp of last block
     * @return timestamp Last block timestamp
     */
    function getLastBlockTimestamp() external view returns (uint256 timestamp) {
        return _lastBlockTimestamp;
    }

    /**
     * @notice Estimate time for confirmations
     * @param confirmations Number of confirmations
     * @return duration Estimated seconds
     */
    function estimateConfirmationTime(uint64 confirmations) external pure returns (uint256 duration) {
        return uint256(confirmations) * BLOCK_TIME;
    }
}
