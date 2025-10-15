// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../../../src/lazybridge/interfaces/IZKVerifier.sol";

/**
 * @title MockZKVerifier
 * @notice Mock ZK verifier for testing
 * @dev Allows configuring proof validation results for testing scenarios
 */
contract MockZKVerifier is IZKVerifier {
    // ========================================
    // STATE VARIABLES
    // ========================================

    /// @notice Whether to accept all proofs (for happy path testing)
    bool public acceptAllProofs = true;

    /// @notice Mapping of proof hash to validity
    mapping(bytes32 => bool) public proofValidity;

    /// @notice Expected number of public inputs
    uint256 public constant PUBLIC_INPUTS_COUNT = 6;

    // ========================================
    // EVENTS
    // ========================================

    event ProofVerified(bytes32 indexed proofHash, bool valid);
    event AcceptAllProofsChanged(bool accept);

    // ========================================
    // ADMIN FUNCTIONS
    // ========================================

    /**
     * @notice Set whether to accept all proofs
     * @param accept True to accept all
     */
    function setAcceptAllProofs(bool accept) external {
        acceptAllProofs = accept;
        emit AcceptAllProofsChanged(accept);
    }

    /**
     * @notice Set validity for a specific proof
     * @param proof Proof bytes
     * @param valid Whether proof is valid
     */
    function setProofValidity(bytes calldata proof, bool valid) external {
        bytes32 proofHash = keccak256(proof);
        proofValidity[proofHash] = valid;
    }

    /**
     * @notice Set validity for a specific proof hash
     * @param proofHash Proof hash
     * @param valid Whether proof is valid
     */
    function setProofValidityByHash(bytes32 proofHash, bool valid) external {
        proofValidity[proofHash] = valid;
    }

    // ========================================
    // IZKVERFIER IMPLEMENTATION
    // ========================================

    /// @inheritdoc IZKVerifier
    function verifyProof(
        bytes calldata proof,
        uint256[] calldata publicSignals
    ) external returns (bool valid) {
        // Validate public signals count
        require(publicSignals.length == PUBLIC_INPUTS_COUNT, "Invalid public signals count");

        bytes32 proofHash = keccak256(proof);

        // If accept all proofs mode is on, return true
        if (acceptAllProofs) {
            emit ProofVerified(proofHash, true);
            return true;
        }

        // Otherwise check specific proof validity
        valid = proofValidity[proofHash];

        emit ProofVerified(proofHash, valid);

        return valid;
    }

    /// @inheritdoc IZKVerifier
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata input
    ) external returns (bool r) {
        // Validate input count
        require(input.length == PUBLIC_INPUTS_COUNT, "Invalid input count");

        // In accept all mode, return true
        if (acceptAllProofs) {
            return true;
        }

        // Hash the proof components to check validity
        bytes32 proofHash = keccak256(abi.encodePacked(a, b, c));
        r = proofValidity[proofHash];

        emit ProofVerified(proofHash, r);

        return r;
    }

    /// @inheritdoc IZKVerifier
    function getPublicInputsCount() external pure returns (uint256 count) {
        return PUBLIC_INPUTS_COUNT;
    }

    // ========================================
    // HELPER FUNCTIONS
    // ========================================

    /**
     * @notice Create a mock valid proof for testing
     * @return proof Mock proof bytes
     */
    function createMockProof() external pure returns (bytes memory proof) {
        // Return some dummy bytes that look like a compressed Groth16 proof
        proof = new bytes(192); // Typical Groth16 proof size

        // Fill with deterministic values for reproducibility
        for (uint i = 0; i < 192; i++) {
            proof[i] = bytes1(uint8(i % 256));
        }

        return proof;
    }

    /**
     * @notice Get proof hash for setting validity
     * @param proof Proof bytes
     * @return hash Proof hash
     */
    function getProofHash(bytes calldata proof) external pure returns (bytes32 hash) {
        return keccak256(proof);
    }
}
