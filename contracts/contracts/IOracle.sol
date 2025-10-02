// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IOracle
 * @notice Interface estándar para oráculos en Ande Chain
 */
interface IOracle {
    function getPrice(bytes32 pairId) external view returns (uint256);
    function getPriceWithMetadata(bytes32 pairId) 
        external 
        view 
        returns (
            uint256 price,
            uint256 timestamp,
            bool isStale,
            address source
        );
}
