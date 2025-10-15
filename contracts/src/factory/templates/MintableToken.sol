// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title MintableToken
 * @dev ERC20 token with minting capabilities and access control
 * @notice This token allows authorized addresses to mint new tokens
 * @author AndeChain Team
 */
contract MintableToken is ERC20, AccessControlEnumerable, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    uint256 private _maxSupply;
    bool private _mintingEnabled;
    
    event MintingStatusChanged(bool enabled);
    event MaxSupplyUpdated(uint256 newMaxSupply);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    /**
     * @dev Constructor for MintableToken
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param initialSupply The initial supply of tokens
     * @param maxSupply The maximum supply of tokens (0 for unlimited)
     * @param owner The owner of the contract
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        address owner
    ) ERC20(name, symbol) {
        require(initialSupply > 0, "MintableToken: initial supply must be greater than 0");
        require(owner != address(0), "MintableToken: owner cannot be zero address");
        require(maxSupply == 0 || maxSupply >= initialSupply, "MintableToken: max supply must be >= initial supply");
        
        _maxSupply = maxSupply;
        _mintingEnabled = true;
        
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(MINTER_ROLE, owner);
        _grantRole(PAUSER_ROLE, owner);
        
        if (initialSupply > 0) {
            _mint(owner, initialSupply);
        }
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
     * @return uint8 The token type identifier (1 for Mintable)
     */
    function tokenType() external pure returns (uint8) {
        return 1;
    }

    /**
     * @dev Returns the maximum supply of tokens
     * @return uint256 The maximum supply (0 for unlimited)
     */
    function maxSupply() external view returns (uint256) {
        return _maxSupply;
    }

    /**
     * @dev Returns whether minting is enabled
     * @return bool Whether minting is enabled
     */
    function mintingEnabled() external view returns (bool) {
        return _mintingEnabled;
    }

    /**
     * @dev Mints new tokens to a specified address
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(_mintingEnabled, "MintableToken: minting is disabled");
        require(to != address(0), "MintableToken: cannot mint to zero address");
        require(amount > 0, "MintableToken: mint amount must be greater than 0");
        
        if (_maxSupply > 0) {
            require(totalSupply() + amount <= _maxSupply, "MintableToken: mint amount exceeds max supply");
        }
        
        _mint(to, amount);
    }

    /**
     * @dev Batch mint tokens to multiple addresses
     * @param recipients The addresses to mint tokens to
     * @param amounts The amounts of tokens to mint
     */
    function batchMint(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(recipients.length == amounts.length, "MintableToken: arrays length mismatch");
        require(recipients.length > 0, "MintableToken: empty arrays");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        if (_maxSupply > 0) {
            require(totalSupply() + totalAmount <= _maxSupply, "MintableToken: batch mint exceeds max supply");
        }
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "MintableToken: cannot mint to zero address");
            require(amounts[i] > 0, "MintableToken: mint amount must be greater than 0");
            _mint(recipients[i], amounts[i]);
        }
    }

    /**
     * @dev Sets the maximum supply
     * @param newMaxSupply The new maximum supply (0 for unlimited)
     */
    function setMaxSupply(uint256 newMaxSupply) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newMaxSupply == 0 || newMaxSupply >= totalSupply(), "MintableToken: new max supply must be >= current supply");
        _maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(newMaxSupply);
    }

    /**
     * @dev Enables or disables minting
     * @param enabled Whether to enable minting
     */
    function setMintingEnabled(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _mintingEnabled = enabled;
        emit MintingStatusChanged(enabled);
    }

    /**
     * @dev Adds a minter role to an address
     * @param minter The address to add as minter
     */
    function addMinter(address minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(minter != address(0), "MintableToken: minter cannot be zero address");
        _grantRole(MINTER_ROLE, minter);
        emit MinterAdded(minter);
    }

    /**
     * @dev Removes minter role from an address
     * @param minter The address to remove as minter
     */
    function removeMinter(address minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, minter);
        emit MinterRemoved(minter);
    }

    /**
     * @dev Pauses the contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Burns tokens from the caller's account
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external whenNotPaused {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Burns tokens from a specified account
     * @param account The account to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burnFrom(address account, uint256 amount) external whenNotPaused {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "MintableToken: burn amount exceeds allowance");
        
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
    }

    /**
     * @dev Returns detailed information about the token
     * @return name_ The token name
     * @return symbol_ The token symbol
     * @return decimals_ The token decimals
     * @return totalSupply_ The total supply
     * @return maxSupply_ The maximum supply
     * @return mintingEnabled_ Whether minting is enabled
     * @return paused_ Whether the contract is paused
     * @return version_ The token version
     */
    function getTokenInfo() external view returns (
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        uint256 maxSupply_,
        bool mintingEnabled_,
        bool paused_,
        string memory version_
    ) {
        return (
            name(),
            symbol(),
            decimals(),
            totalSupply(),
            _maxSupply,
            _mintingEnabled,
            paused(),
            version()
        );
    }

    /**
     * @dev Returns the number of minters
     * @return uint256 The number of addresses with minter role
     */
    function getMinterCount() external view returns (uint256) {
        return getRoleMemberCount(MINTER_ROLE);
    }

    /**
     * @dev Returns whether an address is a minter
     * @param account The address to check
     * @return bool Whether the address is a minter
     */
    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    /**
     * @dev Emergency function to rescue tokens sent to contract by mistake
     * @param token The token address to rescue
     * @param amount The amount to rescue
     */
    function rescueTokens(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(this), "MintableToken: cannot rescue own token");
        require(token != address(0), "MintableToken: cannot rescue zero address");
        
        if (token == address(0)) {
            payable(getRoleMember(DEFAULT_ADMIN_ROLE, 0)).transfer(amount);
        } else {
            IERC20(token).transfer(getRoleMember(DEFAULT_ADMIN_ROLE, 0), amount);
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal view whenNotPaused {
        // Hook for future extensions
    }

    /**
     * @dev Fallback function to receive ETH
     */
    receive() external payable {
        // Allow contract to receive ETH for rescue functionality
    }
}