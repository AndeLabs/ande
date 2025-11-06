// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockANDEToken
 * @notice Simple mock for testing - not upgradeable
 */
contract MockANDEToken is ERC20 {
    constructor() ERC20("ANDE Token", "ANDE") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
