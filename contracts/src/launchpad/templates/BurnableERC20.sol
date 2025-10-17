// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title BurnableERC20
 * @notice ERC-20 token with burn functionality
 * @dev Holders can burn their own tokens
 */
contract BurnableERC20 is ERC20, ERC20Burnable {
    address public immutable creator;
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address _creator
    ) ERC20(name, symbol) {
        creator = _creator;
        _mint(_creator, totalSupply);
    }
}
