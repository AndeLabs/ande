// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TaxableERC20
 * @notice ERC-20 with buy/sell taxes and transaction limits
 * @dev Implements taxes on DEX trades and max transaction limits
 */
contract TaxableERC20 is ERC20, Ownable {
    address public immutable creator;
    address public taxRecipient;
    address public pairAddress;
    
    uint256 public buyTax;    // Percentage (e.g., 5 = 5%)
    uint256 public sellTax;   // Percentage
    uint256 public maxTx;     // Max transaction amount
    uint256 public maxWallet; // Max wallet holdings
    
    bool public tradingEnabled;
    uint256 public tradingEnabledTime;
    
    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isExcludedFromLimit;
    
    event TaxUpdated(uint256 buyTax, uint256 sellTax);
    event TradingEnabled(uint256 timestamp);
    
    error TradingNotEnabled();
    error ExceedsMaxTransaction();
    error ExceedsMaxWallet();
    error InvalidTaxRate();
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address _creator,
        uint256 _buyTax,
        uint256 _sellTax,
        address _taxRecipient,
        uint256 _maxTx,
        uint256 _maxWallet
    ) ERC20(name, symbol) Ownable(_creator) {
        creator = _creator;
        buyTax = _buyTax;
        sellTax = _sellTax;
        taxRecipient = _taxRecipient;
        maxTx = _maxTx;
        maxWallet = _maxWallet;
        
        // Exclude owner and contract from fees/limits
        isExcludedFromFee[_creator] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromLimit[_creator] = true;
        isExcludedFromLimit[address(this)] = true;
        
        _mint(_creator, totalSupply);
    }
    
    /**
     * @notice Override transfer to implement taxes
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (!tradingEnabled && from != owner() && to != owner()) {
            revert TradingNotEnabled();
        }
        
        // Check max transaction
        if (!isExcludedFromLimit[from] && !isExcludedFromLimit[to]) {
            if (amount > maxTx) revert ExceedsMaxTransaction();
            
            // Check max wallet
            if (to != pairAddress && balanceOf(to) + amount > maxWallet) {
                revert ExceedsMaxWallet();
            }
        }
        
        // Calculate tax
        uint256 taxAmount = 0;
        if (!isExcludedFromFee[from] && !isExcludedFromFee[to]) {
            if (from == pairAddress) {
                // Buy
                taxAmount = (amount * buyTax) / 100;
            } else if (to == pairAddress) {
                // Sell
                taxAmount = (amount * sellTax) / 100;
            }
        }
        
        if (taxAmount > 0) {
            super._update(from, taxRecipient, taxAmount);
            amount -= taxAmount;
        }
        
        super._update(from, to, amount);
    }
    
    /**
     * @notice Enable trading
     */
    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        tradingEnabledTime = block.timestamp;
        emit TradingEnabled(block.timestamp);
    }
    
    /**
     * @notice Set pair address for tax detection
     */
    function setPairAddress(address _pairAddress) external onlyOwner {
        pairAddress = _pairAddress;
    }
    
    /**
     * @notice Update tax rates
     */
    function updateTaxes(uint256 _buyTax, uint256 _sellTax) external onlyOwner {
        if (_buyTax > 25 || _sellTax > 25) revert InvalidTaxRate();
        buyTax = _buyTax;
        sellTax = _sellTax;
        emit TaxUpdated(_buyTax, _sellTax);
    }
    
    /**
     * @notice Exclude address from fees
     */
    function excludeFromFee(address account, bool excluded) external onlyOwner {
        isExcludedFromFee[account] = excluded;
    }
    
    /**
     * @notice Exclude address from limits
     */
    function excludeFromLimit(address account, bool excluded) external onlyOwner {
        isExcludedFromLimit[account] = excluded;
    }
}
