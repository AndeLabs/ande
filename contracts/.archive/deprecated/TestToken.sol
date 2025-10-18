// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestToken is ERC20, Ownable {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {}
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}