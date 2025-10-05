// SPDX-License-Identifier: MIT
// A simple mock ERC20 token for testing purposes.
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice A mock ERC20 contract for testing that allows setting decimals.
 * This correctly overrides the decimals() function for modern OpenZeppelin versions.
 */
contract MockERC20 is ERC20 {
    uint8 private _mockDecimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _mockDecimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _mockDecimals;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}