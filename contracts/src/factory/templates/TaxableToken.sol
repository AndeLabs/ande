// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title TaxableToken
 * @dev ERC20 token with automatic tax on transfers
 * @notice This token applies a tax on transfers that is sent to a tax recipient
 * @author AndeChain Team
 */
contract TaxableToken is ERC20, Ownable, Pausable {
    uint256 private _taxRate; // Basis points (10000 = 100%)
    address private _taxRecipient;
    bool private _taxEnabled;
    uint256 private _totalTaxCollected;
    
    mapping(address => bool) private _taxExempt;
    mapping(address => bool) private _authorizedTaxChangers;
    
    event TaxCollected(address indexed from, address indexed to, uint256 amount, uint256 tax);
    event TaxRateUpdated(uint256 newRate);
    event TaxRecipientUpdated(address indexed newRecipient);
    event TaxStatusChanged(bool enabled);
    event TaxExemptStatusChanged(address indexed account, bool exempt);
    event AuthorizedTaxChangerAdded(address indexed changer);
    event AuthorizedTaxChangerRemoved(address indexed changer);
    event TaxWithdrawn(address indexed recipient, uint256 amount);

    /**
     * @dev Constructor for TaxableToken
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param initialSupply The initial supply of tokens
     * @param taxRate The tax rate in basis points (max 500 = 5%)
     * @param taxRecipient The address to receive tax collections
     * @param owner The owner of the contract
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 taxRate,
        address taxRecipient,
        address owner
    ) ERC20(name, symbol) Ownable(owner) {
        require(initialSupply > 0, "TaxableToken: initial supply must be greater than 0");
        require(owner != address(0), "TaxableToken: owner cannot be zero address");
        require(taxRecipient != address(0), "TaxableToken: tax recipient cannot be zero address");
        require(taxRate <= 500, "TaxableToken: tax rate cannot exceed 5%");
        
        _taxRate = taxRate;
        _taxRecipient = taxRecipient;
        _taxEnabled = taxRate > 0;
        
        // Owner and tax recipient are tax exempt by default
        _taxExempt[owner] = true;
        _taxExempt[taxRecipient] = true;
        _taxExempt[address(this)] = true;
        
        _authorizedTaxChangers[owner] = true;
        
        _mint(owner, initialSupply);
    }

    /**
     * @dev Returns the version of the token contract
     * @return string The version string
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    /**
     * @dev Returns the token type
     * @return uint8 The token type identifier (3 for Taxable)
     */
    function tokenType() external pure returns (uint8) {
        return 3;
    }

    /**
     * @dev Returns the current tax rate
     * @return uint256 Tax rate in basis points
     */
    function getTaxRate() external view returns (uint256) {
        return _taxRate;
    }

    /**
     * @dev Returns the tax recipient address
     * @return address Tax recipient address
     */
    function getTaxRecipient() external view returns (address) {
        return _taxRecipient;
    }

    /**
     * @dev Returns whether tax is enabled
     * @return bool Whether tax is enabled
     */
    function isTaxEnabled() external view returns (bool) {
        return _taxEnabled;
    }

    /**
     * @dev Returns the total tax collected
     * @return uint256 Total tax collected
     */
    function getTotalTaxCollected() external view returns (uint256) {
        return _totalTaxCollected;
    }

    /**
     * @dev Returns whether an address is tax exempt
     * @param account The address to check
     * @return bool Whether the address is tax exempt
     */
    function isTaxExempt(address account) external view returns (bool) {
        return _taxExempt[account];
    }

    /**
     * @dev Returns whether an address is authorized to change tax settings
     * @param changer The address to check
     * @return bool Whether the address is authorized
     */
    function isAuthorizedTaxChanger(address changer) external view returns (bool) {
        return _authorizedTaxChangers[changer];
    }

    /**
     * @dev Sets the tax rate
     * @param newRate The new tax rate in basis points (max 500 = 5%)
     */
    function setTaxRate(uint256 newRate) external {
        require(_authorizedTaxChangers[_msgSender()], "TaxableToken: not authorized tax changer");
        require(newRate <= 500, "TaxableToken: tax rate cannot exceed 5%");
        
        _taxRate = newRate;
        _taxEnabled = newRate > 0;
        
        emit TaxRateUpdated(newRate);
        emit TaxStatusChanged(_taxEnabled);
    }

    /**
     * @dev Sets the tax recipient
     * @param newRecipient The new tax recipient address
     */
    function setTaxRecipient(address newRecipient) external {
        require(_authorizedTaxChangers[_msgSender()], "TaxableToken: not authorized tax changer");
        require(newRecipient != address(0), "TaxableToken: tax recipient cannot be zero address");
        
        address oldRecipient = _taxRecipient;
        _taxRecipient = newRecipient;
        
        // Update tax exempt status
        _taxExempt[oldRecipient] = false;
        _taxExempt[newRecipient] = true;
        
        emit TaxRecipientUpdated(newRecipient);
    }

    /**
     * @dev Enables or disables tax
     * @param enabled Whether to enable tax
     */
    function setTaxEnabled(bool enabled) external {
        require(_authorizedTaxChangers[_msgSender()], "TaxableToken: not authorized tax changer");
        
        _taxEnabled = enabled;
        emit TaxStatusChanged(enabled);
    }

    /**
     * @dev Sets tax exempt status for an address
     * @param account The address to set exempt status for
     * @param exempt Whether the address should be tax exempt
     */
    function setTaxExempt(address account, bool exempt) external onlyOwner {
        require(account != address(0), "TaxableToken: account cannot be zero address");
        
        _taxExempt[account] = exempt;
        emit TaxExemptStatusChanged(account, exempt);
    }

    /**
     * @dev Adds an authorized tax changer
     * @param changer The address to authorize
     */
    function addAuthorizedTaxChanger(address changer) external onlyOwner {
        require(changer != address(0), "TaxableToken: changer cannot be zero address");
        
        _authorizedTaxChangers[changer] = true;
        emit AuthorizedTaxChangerAdded(changer);
    }

    /**
     * @dev Removes an authorized tax changer
     * @param changer The address to deauthorize
     */
    function removeAuthorizedTaxChanger(address changer) external onlyOwner {
        _authorizedTaxChangers[changer] = false;
        emit AuthorizedTaxChangerRemoved(changer);
    }

    /**
     * @dev Withdraws collected tax to the tax recipient
     */
    function withdrawTax() external {
        require(_msgSender() == _taxRecipient || _msgSender() == owner(), "TaxableToken: not authorized to withdraw tax");
        
        uint256 taxBalance = balanceOf(address(this));
        require(taxBalance > 0, "TaxableToken: no tax to withdraw");
        
        _transfer(address(this), _taxRecipient, taxBalance);
        emit TaxWithdrawn(_taxRecipient, taxBalance);
    }

    /**
     * @dev Pauses the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyOwner {
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
        require(currentAllowance >= amount, "TaxableToken: burn amount exceeds allowance");
        
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
    }

    /**
     * @dev Returns detailed information about the token
     * @return name_ The token name
     * @return symbol_ The token symbol
     * @return decimals_ The token decimals
     * @return totalSupply_ The total supply
     * @return taxRate_ The tax rate
     * @return taxRecipient_ The tax recipient
     * @return taxEnabled_ Whether tax is enabled
     * @return totalTaxCollected_ The total tax collected
     * @return paused_ Whether the contract is paused
     * @return version_ The token version
     */
    function getTokenInfo() external view returns (
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        uint256 taxRate_,
        address taxRecipient_,
        bool taxEnabled_,
        uint256 totalTaxCollected_,
        bool paused_,
        string memory version_
    ) {
        return (
            name(),
            symbol(),
            decimals(),
            totalSupply(),
            _taxRate,
            _taxRecipient,
            _taxEnabled,
            _totalTaxCollected,
            paused(),
            version()
        );
    }

    /**
     * @dev Calculates tax amount for a transfer
     * @param amount The transfer amount
     * @return uint256 The tax amount
     */
    function calculateTax(uint256 amount) external view returns (uint256) {
        if (!_taxEnabled || _taxRate == 0) {
            return 0;
        }
        return (amount * _taxRate) / 10000;
    }

    /**
     * @dev Returns the amount of tax available for withdrawal
     * @return uint256 Available tax amount
     */
    function getAvailableTax() external view returns (uint256) {
        return balanceOf(address(this));
    }

    /**
     * @dev Internal function to handle transfer with tax
     * @param from The sender address
     * @param to The recipient address
     * @param amount The transfer amount
     */
    function _transferWithTax(
        address from,
        address to,
        uint256 amount
    ) internal {
        uint256 taxAmount = 0;
        
        if (_taxEnabled && _taxRate > 0 && !_taxExempt[from] && !_taxExempt[to]) {
            taxAmount = (amount * _taxRate) / 10000;
            uint256 transferAmount = amount - taxAmount;
            
            // Transfer tax to contract
            super._transfer(from, address(this), taxAmount);
            // Transfer remaining amount to recipient
            super._transfer(from, to, transferAmount);
            
            _totalTaxCollected += taxAmount;
            emit TaxCollected(from, to, amount, taxAmount);
        } else {
            // No tax, transfer full amount
            super._transfer(from, to, amount);
        }
    }

    /**
     * @dev Override transfer to include tax
     */
    function transfer(address to, uint256 amount) public virtual override whenNotPaused returns (bool) {
        address owner = _msgSender();
        _transferWithTax(owner, to, amount);
        return true;
    }

    /**
     * @dev Override transferFrom to include tax
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override whenNotPaused returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transferWithTax(from, to, amount);
        return true;
    }

    /**
     * @dev Hook that is called before any transfer of tokens
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Emergency function to rescue tokens sent to contract by mistake
     * @param token The token address to rescue
     * @param amount The amount to rescue
     */
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        require(token != address(this), "TaxableToken: cannot rescue own token");
        require(token != address(0), "TaxableToken: cannot rescue zero address");
        
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).transfer(owner(), amount);
        }
    }

    /**
     * @dev Fallback function to receive ETH
     */
    receive() external payable {
        // Allow contract to receive ETH for rescue functionality
    }
}