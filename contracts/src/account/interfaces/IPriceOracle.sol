// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/**
 * @title IPriceOracle
 * @notice Interface for price oracle used by ANDEPaymaster
 */
interface IPriceOracle {
    /**
     * @notice Get the median price for a token
     * @param token Token address
     * @return price Price in wei (e.g., ANDE tokens per 1 ETH with 18 decimals)
     */
    function getMedianPrice(address token) external view returns (uint256 price);
}
