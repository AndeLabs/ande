// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../IOracle.sol";

// A simple mock oracle for testing purposes
contract MockOracle is IOracle {
    uint256 private _price;

    function getPrice(bytes32) external view override returns (uint256) {
        return _price;
    }

    function getPriceWithMetadata(bytes32) external view override returns (uint256 price, uint256 timestamp, bool isStale, address source) {
        return (_price, block.timestamp, false, address(this));
    }

    // --- Test-only functions ---
    function setPrice(uint256 newPrice) external {
        _price = newPrice;
    }
}