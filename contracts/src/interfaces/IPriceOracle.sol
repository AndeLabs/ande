// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IPriceOracle
 * @notice Interface for price oracle
 * @dev Provides USD prices for assets
 */
interface IPriceOracle {
    
    /**
     * @notice Get asset price in USD
     * @param asset Asset address
     * @return price Price in USD (18 decimals)
     */
    function getPrice(address asset) external view returns (uint256 price);
    
    /**
     * @notice Get multiple asset prices
     * @param assets Array of asset addresses
     * @return prices Array of prices in USD (18 decimals)
     */
    function getPrices(address[] calldata assets) external view returns (uint256[] memory prices);
}
