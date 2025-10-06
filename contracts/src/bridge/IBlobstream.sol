// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IBlobstream
 * @notice Interface for Celestia Blobstream proof verification
 * @dev This interface represents the Blobstream contract that verifies
 *      data availability proofs from Celestia
 *
 * Blobstream is Celestia's data availability solution that allows Ethereum
 * smart contracts to verify that data was published to Celestia.
 *
 * References:
 * - https://docs.celestia.org/developers/blobstream
 * - https://github.com/celestiaorg/blobstream-contracts
 */
interface IBlobstream {
    /**
     * @notice Data commitment stored on-chain
     * @param startBlock Starting block height in Celestia
     * @param endBlock Ending block height in Celestia
     * @param dataRoot Merkle root of the data
     */
    struct DataRootTuple {
        uint256 startBlock;
        uint256 endBlock;
        bytes32 dataRoot;
    }

    /**
     * @notice Verify that data was included in Celestia
     * @param proofNonce Nonce of the proof
     * @param tupleRootNonce Nonce of the tuple root
     * @param tuple Data root tuple
     * @param proof Merkle proof
     * @return bool True if verification succeeds
     */
    function verifyAttestation(
        uint256 proofNonce,
        uint256 tupleRootNonce,
        DataRootTuple calldata tuple,
        bytes calldata proof
    ) external view returns (bool);

    /**
     * @notice Get the latest data root tuple
     * @return DataRootTuple The latest tuple
     */
    function latestDataRootTuple() external view returns (DataRootTuple memory);

    /**
     * @notice Check if a specific data root exists
     * @param dataRoot The data root to check
     * @return bool True if exists
     */
    function dataRootExists(bytes32 dataRoot) external view returns (bool);

    /**
     * @notice Get data root at specific nonce
     * @param nonce Tuple nonce
     * @return DataRootTuple Tuple at nonce
     */
    function dataRootTupleAtNonce(uint256 nonce)
        external
        view
        returns (DataRootTuple memory);
}
