// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title ICelestiaLightClient
 * @notice Interface for Celestia IBC light client
 * @dev Verifies data availability and IBC packets from Celestia
 */
interface ICelestiaLightClient {
    /**
     * @notice Verify that data was posted to Celestia at a specific height
     * @param height Celestia block height
     * @param dataRoot Data root commitment
     * @param proof Merkle proof of inclusion
     * @return valid True if data is available
     */
    function verifyDataAvailability(
        uint64 height,
        bytes32 dataRoot,
        bytes calldata proof
    ) external returns (bool valid);

    /**
     * @notice Verify an IBC packet from Celestia
     * @param packet IBC packet data
     * @param proof Proof of packet commitment
     * @return valid True if packet is valid
     */
    function verifyIBCPacket(
        bytes calldata packet,
        bytes calldata proof
    ) external returns (bool valid);

    /**
     * @notice Get the latest verified Celestia height
     * @return height Latest height
     */
    function getLatestHeight() external view returns (uint64 height);

    /**
     * @notice Get the data root for a specific height
     * @param height Block height
     * @return dataRoot Data root commitment
     */
    function getDataRoot(uint64 height) external view returns (bytes32 dataRoot);

    /**
     * @notice Verify a Celestia header
     * @param header Block header
     * @param validatorSetProof Proof of validator set
     * @return valid True if header is valid
     */
    function verifyHeader(
        bytes calldata header,
        bytes calldata validatorSetProof
    ) external returns (bool valid);
}
