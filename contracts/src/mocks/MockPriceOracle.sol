// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../interfaces/IPriceOracle.sol";

/**
 * @title MockPriceOracle
 * @notice Mock oracle for testing
 * @dev Simple price oracle that stores prices per asset
 */
contract MockPriceOracle is IPriceOracle {
    
    mapping(address => uint256) private prices;
    
    /**
     * @notice Set price for an asset
     * @param asset Asset address
     * @param price Price in USD (18 decimals)
     */
    function setPrice(address asset, uint256 price) external {
        prices[asset] = price;
    }
    
    /**
     * @notice Get price for an asset
     * @param asset Asset address
     * @return price Price in USD (18 decimals)
     */
    function getPrice(address asset) external view override returns (uint256 price) {
        return prices[asset];
    }
    
    /**
     * @notice Get multiple asset prices
     * @param assets Array of asset addresses
     * @return Array of prices
     */
    function getPrices(address[] calldata assets) external view override returns (uint256[] memory) {
        uint256[] memory result = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            result[i] = prices[assets[i]];
        }
        return result;
    }
}
