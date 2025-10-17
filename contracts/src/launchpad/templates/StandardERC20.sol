// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title StandardERC20
 * @notice Basic ERC-20 token template
 * @dev Simple token with fixed supply and no special features
 */
contract StandardERC20 is ERC20 {
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
