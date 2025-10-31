// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title MockOracle
 * @notice Simple mock oracle for testing
 */
contract MockOracle {
    mapping(address => uint256) public prices;
    
    function setPrice(address asset, uint256 price) external {
        prices[asset] = price;
    }
    
    function getPrice(address asset) external view returns (uint256) {
        uint256 price = prices[asset];
        require(price > 0, "Price not set");
        return price;
    }
}
