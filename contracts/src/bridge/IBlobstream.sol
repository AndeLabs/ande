// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IBlobstream
 * @notice Interface for the Celestia Blobstream verifier contract.
 * @dev This interface defines the function required to verify a transaction's
 *      inclusion in the Celestia Data Availability layer.
 */
interface IBlobstream {
    /**
     * @notice Verifies a data root attestation from the Blobstream contract.
     * @param txHash The transaction hash to verify.
     * @param sourceChain The source chain ID of the transaction.
     * @param proof The Merkle proof of the transaction's inclusion.
     * @param minConfirmations The minimum number of confirmations required.
     * @return bool True if the proof is valid and has sufficient confirmations.
     */
    function verifyAttestation(
        bytes32 txHash,
        uint256 sourceChain,
        bytes calldata proof,
        uint256 minConfirmations
    ) external view returns (bool);
}