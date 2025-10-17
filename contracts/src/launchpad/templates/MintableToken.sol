// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MintableERC20
 * @notice ERC-20 token with mintable supply up to a maximum
 * @dev Owner can mint new tokens until maxSupply is reached
 */
contract MintableERC20 is ERC20, Ownable {
    uint256 public immutable maxSupply;
    address public immutable creator;
    
    error MaxSupplyExceeded();
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 _maxSupply,
        address _creator
    ) ERC20(name, symbol) Ownable(_creator) {
        creator = _creator;
        maxSupply = _maxSupply;
        _mint(_creator, initialSupply);
    }
    
    /**
     * @notice Mint new tokens
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        if (totalSupply() + amount > maxSupply) revert MaxSupplyExceeded();
        _mint(to, amount);
    }
}
