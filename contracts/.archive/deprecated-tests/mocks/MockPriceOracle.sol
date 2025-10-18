// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title MockPriceOracle
 * @notice Simple mock oracle for testing
 */
contract MockPriceOracle {
    mapping(address => uint256) public prices;

    function setPrice(address token, uint256 price) external {
        prices[token] = price;
    }

    function getMedianPrice(address token) external view returns (uint256) {
        return prices[token];
    }

    function getPriceWithConfidence(address token)
        external
        view
        returns (uint256 price, uint256 confidence, uint256 sourcesUsed)
    {
        return (prices[token], 10000, 3); // 100% confidence, 3 sources
    }
}
