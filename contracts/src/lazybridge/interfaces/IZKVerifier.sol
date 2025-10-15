// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IZKVerifier
 * @notice Interface for Groth16 ZK proof verifier
 * @dev Used to verify bridge lock proofs off-chain generated
 */
interface IZKVerifier {
    /**
     * @notice Verify a Groth16 ZK proof
     * @param proof The proof bytes (compressed)
     * @param publicSignals Public signals/inputs for the circuit
     * @return valid True if proof is valid
     */
    function verifyProof(
        bytes calldata proof,
        uint256[] calldata publicSignals
    ) external returns (bool valid);

    /**
     * @notice Verify a Groth16 ZK proof with raw components
     * @param a Proof component A
     * @param b Proof component B
     * @param c Proof component C
     * @param input Public inputs
     * @return r True if proof is valid
     */
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata input
    ) external returns (bool r);

    /**
     * @notice Get the number of public inputs expected
     * @return count Number of public inputs
     */
    function getPublicInputsCount() external pure returns (uint256 count);
}
