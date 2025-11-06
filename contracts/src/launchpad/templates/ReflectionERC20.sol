// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ReflectionERC20
 * @notice ERC-20 with reflection mechanism (holders earn passively)
 * @dev Implements RFI tokenomics - holders earn from every transaction
 */
contract ReflectionERC20 is ERC20, Ownable {
    address public immutable creator;
    uint256 public reflectionFee; // Percentage distributed to holders
    
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;
    
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => bool) public isExcludedFromReward;
    address[] private _excluded;
    
    event ReflectionFeeUpdated(uint256 newFee);
    event ExcludedFromReward(address account);
    event IncludedInReward(address account);
    
    error InvalidFeeRate();
    error AlreadyExcluded();
    error NotExcluded();
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address _creator,
        uint256 _reflectionFee
    ) ERC20(name, symbol) Ownable(_creator) {
        creator = _creator;
        reflectionFee = _reflectionFee;
        
        _tTotal = initialSupply;
        _rTotal = (MAX - (MAX % initialSupply));
        
        _rOwned[_creator] = _rTotal;
        emit Transfer(address(0), _creator, initialSupply);
    }
    
    /**
     * @notice Get total supply
     */
    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }
    
    function getReflectionFee() external view returns (uint256) {
        return reflectionFee;
    }
    
    /**
     * @notice Get balance of account
     */
    function balanceOf(address account) public view override returns (uint256) {
        if (isExcludedFromReward[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }
    
    /**
     * @notice Transfer with reflection
     */
    function _update(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(sender != address(0), "ERC20: transfer from zero address");
        require(recipient != address(0), "ERC20: transfer to zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        
        // Calculate reflection fee
        uint256 reflectionAmount = (amount * reflectionFee) / 100;
        uint256 transferAmount = amount - reflectionAmount;
        
        uint256 currentRate = _getRate();
        uint256 rAmount = amount * currentRate;
        uint256 rReflection = reflectionAmount * currentRate;
        uint256 rTransferAmount = rAmount - rReflection;
        
        // Update balances
        if (isExcludedFromReward[sender]) {
            _tOwned[sender] -= amount;
        }
        _rOwned[sender] -= rAmount;
        
        if (isExcludedFromReward[recipient]) {
            _tOwned[recipient] += transferAmount;
        }
        _rOwned[recipient] += rTransferAmount;
        
        // Reflect to all holders
        _reflectFee(rReflection, reflectionAmount);
        
        emit Transfer(sender, recipient, transferAmount);
    }
    
    /**
     * @notice Reflect fee to all holders
     */
    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal -= rFee;
        _tFeeTotal += tFee;
    }
    
    /**
     * @notice Get reflection rate
     */
    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }
    
    /**
     * @notice Get current supply
     */
    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) {
                return (_rTotal, _tTotal);
            }
            rSupply -= _rOwned[_excluded[i]];
            tSupply -= _tOwned[_excluded[i]];
        }
        
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    /**
     * @notice Convert reflection to token amount
     */
    function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }
    
    /**
     * @notice Exclude account from rewards
     */
    function excludeFromReward(address account) external onlyOwner {
        require(!isExcludedFromReward[account], "Already excluded");
        
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        
        isExcludedFromReward[account] = true;
        _excluded.push(account);
        
        emit ExcludedFromReward(account);
    }
    
    /**
     * @notice Include account in rewards
     */
    function includeInReward(address account) external onlyOwner {
        require(isExcludedFromReward[account], "Not excluded");
        
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                isExcludedFromReward[account] = false;
                _excluded.pop();
                break;
            }
        }
        
        emit IncludedInReward(account);
    }
    
    /**
     * @notice Update reflection fee
     */
    function updateReflectionFee(uint256 newFee) external onlyOwner {
        if (newFee > 10) revert InvalidFeeRate();
        reflectionFee = newFee;
        emit ReflectionFeeUpdated(newFee);
    }
    
    /**
     * @notice Get total fees distributed
     */
    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }
}
