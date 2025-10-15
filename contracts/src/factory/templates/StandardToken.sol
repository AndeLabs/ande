// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StandardToken
 * @dev Standard ERC20 token implementation for AndeChain Token Factory
 * @notice This is a basic ERC20 token with no special features
 * @author AndeChain Team
 */
contract StandardToken is ERC20, Ownable {
    /**
     * @dev Constructor for StandardToken
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param initialSupply The initial supply of tokens (in wei)
     * @param owner The owner of the contract
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) ERC20(name, symbol) Ownable(owner) {
        require(initialSupply > 0, "StandardToken: initial supply must be greater than 0");
        require(owner != address(0), "StandardToken: owner cannot be zero address");
        
        _mint(owner, initialSupply);
    }

    /**
     * @dev Returns the version of the token template
     * @return string The version string
     */
    function version() public pure returns (string memory) {
        return "1.0.0";
    }

    /**
     * @dev Returns the token type
     * @return uint8 The token type identifier (0 for Standard)
     */
    function tokenType() external pure returns (uint8) {
        return 0;
    }

    /**
     * @dev Burns tokens from the caller's account
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Burns tokens from a specified account
     * @param account The account to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burnFrom(address account, uint256 amount) external {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "StandardToken: burn amount exceeds allowance");
        
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
    }

    /**
     * @dev Mints new tokens to a specified address (only owner)
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "StandardToken: cannot mint to zero address");
        _mint(to, amount);
    }

    /**
     * @dev Returns detailed information about the token
     * @return name_ The token name
     * @return symbol_ The token symbol
     * @return decimals_ The token decimals
     * @return totalSupply_ The total supply
     * @return owner_ The token owner
     * @return version_ The token version
     */
    function getTokenInfo() external view returns (
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        address owner_,
        string memory version_
    ) {
        return (
            name(),
            symbol(),
            decimals(),
            totalSupply(),
            owner(),
            version()
        );
    }

    /**
     * @dev Emergency function to rescue tokens sent to contract by mistake
     * @param token The token address to rescue
     * @param amount The amount to rescue
     */
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        require(token != address(this), "StandardToken: cannot rescue own token");
        require(token != address(0), "StandardToken: cannot rescue zero address");
        
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).transfer(owner(), amount);
        }
    }

    /**
     * @dev Returns whether the contract supports a specific interface
     * @param interfaceId The interface identifier
     * @return bool Whether the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC20).interfaceId;
    }

    /**
     * @dev Fallback function to receive ETH
     */
    receive() external payable {
        // Allow contract to receive ETH for rescue functionality
    }
}