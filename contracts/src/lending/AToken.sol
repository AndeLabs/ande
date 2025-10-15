// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AToken
 * @notice Interest-bearing token for AndeLend protocol
 * @dev Represents a deposit in the lending protocol
 *      - 1:1 exchange with underlying asset initially
 *      - Earns interest through exchange rate appreciation
 *      - Fully ERC20 compatible
 */
contract AToken is ERC20, Ownable {
    
    address public immutable underlyingAsset;
    address public immutable lendingPool;
    
    error OnlyLendingPool();
    
    modifier onlyLendingPool() {
        if (msg.sender != lendingPool) revert OnlyLendingPool();
        _;
    }
    
    constructor(
        string memory name,
        string memory symbol,
        address _underlyingAsset,
        address _lendingPool
    ) ERC20(name, symbol) Ownable(msg.sender) {
        underlyingAsset = _underlyingAsset;
        lendingPool = _lendingPool;
    }
    
    function mint(address user, uint256 amount) external onlyLendingPool {
        _mint(user, amount);
    }
    
    function burn(address user, uint256 amount) external onlyLendingPool {
        _burn(user, amount);
    }
}
