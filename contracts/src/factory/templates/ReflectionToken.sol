// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title ReflectionToken
 * @dev ERC20 token with automatic reflection rewards to holders
 * @notice This token automatically distributes rewards to all holders
 * @author AndeChain Team
 */
contract ReflectionToken is ERC20, Ownable, Pausable {
    uint256 private _reflectionFee; // Basis points (10000 = 100%)
    uint256 private _totalReflections;
    uint256 private _totalDividends;
    
    mapping(address => uint256) private _reflectionBalance;
    mapping(address => uint256) private _lastReflectionIndex;
    mapping(address => bool) private _isExcludedFromReflection;
    mapping(address => bool) private _authorizedFeeChangers;
    
    address[] private _reflectionHolders;
    
    event ReflectionDistributed(address indexed holder, uint256 amount);
    event ReflectionFeeUpdated(uint256 newFee);
    event ReflectionStatusChanged(bool enabled);
    event ExcludedFromReflection(address indexed account, bool excluded);
    event AuthorizedFeeChangerAdded(address indexed changer);
    event AuthorizedFeeChangerRemoved(address indexed changer);
    event TotalReflectionsUpdated(uint256 amount);

    /**
     * @dev Constructor for ReflectionToken
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param initialSupply The initial supply of tokens
     * @param reflectionFee The reflection fee in basis points (max 300 = 3%)
     * @param owner The owner of the contract
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 reflectionFee,
        address owner
    ) ERC20(name, symbol) Ownable(owner) {
        require(initialSupply > 0, "ReflectionToken: initial supply must be greater than 0");
        require(owner != address(0), "ReflectionToken: owner cannot be zero address");
        require(reflectionFee <= 300, "ReflectionToken: reflection fee cannot exceed 3%");
        
        _reflectionFee = reflectionFee;
        
        // Exclude certain addresses from reflection
        _isExcludedFromReflection[owner] = true;
        _isExcludedFromReflection[address(this)] = true;
        _isExcludedFromReflection[address(0)] = true;
        
        _authorizedFeeChangers[owner] = true;
        
        _mint(owner, initialSupply);
        
        // Add owner to reflection holders
        if (initialSupply > 0) {
            _reflectionHolders.push(owner);
            _reflectionBalance[owner] = initialSupply;
        }
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
     * @return uint8 The token type identifier (4 for Reflection)
     */
    function tokenType() external pure returns (uint8) {
        return 4;
    }

    /**
     * @dev Returns the current reflection fee
     * @return uint256 Reflection fee in basis points
     */
    function getReflectionFee() external view returns (uint256) {
        return _reflectionFee;
    }

    /**
     * @dev Returns the total reflections distributed
     * @return uint256 Total reflections
     */
    function getTotalReflections() external view returns (uint256) {
        return _totalReflections;
    }

    /**
     * @dev Returns the total dividends available
     * @return uint256 Total dividends
     */
    function getTotalDividends() external view returns (uint256) {
        return _totalDividends;
    }

    /**
     * @dev Returns whether an address is excluded from reflection
     * @param account The address to check
     * @return bool Whether the address is excluded
     */
    function isExcludedFromReflection(address account) external view returns (bool) {
        return _isExcludedFromReflection[account];
    }

    /**
     * @dev Returns whether an address is authorized to change fee settings
     * @param changer The address to check
     * @return bool Whether the address is authorized
     */
    function isAuthorizedFeeChanger(address changer) external view returns (bool) {
        return _authorizedFeeChangers[changer];
    }

    /**
     * @dev Returns the reflection balance of an account
     * @param account The account address
     * @return uint256 Reflection balance
     */
    function getReflectionBalance(address account) external view returns (uint256) {
        return _reflectionBalance[account];
    }

    /**
     * @dev Returns the number of reflection holders
     * @return uint256 Number of holders
     */
    function getReflectionHolderCount() external view returns (uint256) {
        return _reflectionHolders.length;
    }

    /**
     * @dev Returns reflection holders at a specific index
     * @param index The index
     * @return address The holder address
     */
    function getReflectionHolder(uint256 index) external view returns (address) {
        require(index < _reflectionHolders.length, "ReflectionToken: index out of bounds");
        return _reflectionHolders[index];
    }

    /**
     * @dev Sets the reflection fee
     * @param newFee The new reflection fee in basis points (max 300 = 3%)
     */
    function setReflectionFee(uint256 newFee) external {
        require(_authorizedFeeChangers[_msgSender()], "ReflectionToken: not authorized fee changer");
        require(newFee <= 300, "ReflectionToken: reflection fee cannot exceed 3%");
        
        _reflectionFee = newFee;
        emit ReflectionFeeUpdated(newFee);
    }

    /**
     * @dev Sets exclusion status for reflection
     * @param account The address to set exclusion for
     * @param excluded Whether the address should be excluded
     */
    function setExcludedFromReflection(address account, bool excluded) external onlyOwner {
        require(account != address(0), "ReflectionToken: account cannot be zero address");
        
        if (_isExcludedFromReflection[account] != excluded) {
            _isExcludedFromReflection[account] = excluded;
            
            if (excluded) {
                // Remove from reflection holders
                _removeReflectionHolder(account);
            } else {
                // Add to reflection holders
                _addReflectionHolder(account);
            }
            
            emit ExcludedFromReflection(account, excluded);
        }
    }

    /**
     * @dev Adds an authorized fee changer
     * @param changer The address to authorize
     */
    function addAuthorizedFeeChanger(address changer) external onlyOwner {
        require(changer != address(0), "ReflectionToken: changer cannot be zero address");
        
        _authorizedFeeChangers[changer] = true;
        emit AuthorizedFeeChangerAdded(changer);
    }

    /**
     * @dev Removes an authorized fee changer
     * @param changer The address to deauthorize
     */
    function removeAuthorizedFeeChanger(address changer) external onlyOwner {
        _authorizedFeeChangers[changer] = false;
        emit AuthorizedFeeChangerRemoved(changer);
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
        _updateReflectionBalance(_msgSender(), -int256(amount));
    }

    /**
     * @dev Burns tokens from a specified account
     * @param account The account to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burnFrom(address account, uint256 amount) external whenNotPaused {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ReflectionToken: burn amount exceeds allowance");
        
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
        _updateReflectionBalance(account, -int256(amount));
    }

    /**
     * @dev Distributes reflections to all holders
     */
    function distributeReflections() external whenNotPaused {
        require(_totalDividends > 0, "ReflectionToken: no dividends to distribute");
        
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) return;
        
        uint256 dividendsPerToken = _totalDividends / totalSupply;
        
        for (uint256 i = 0; i < _reflectionHolders.length; i++) {
            address holder = _reflectionHolders[i];
            if (!_isExcludedFromReflection[holder] && balanceOf(holder) > 0) {
                uint256 reflectionAmount = (balanceOf(holder) * dividendsPerToken) / 1e18;
                if (reflectionAmount > 0) {
                    _reflectionBalance[holder] += reflectionAmount;
                    emit ReflectionDistributed(holder, reflectionAmount);
                }
            }
        }
        
        _totalReflections += _totalDividends;
        _totalDividends = 0;
        emit TotalReflectionsUpdated(_totalReflections);
    }

    /**
     * @dev Claims reflections for the caller
     */
    function claimReflections() external whenNotPaused {
        require(!_isExcludedFromReflection[_msgSender()], "ReflectionToken: account excluded from reflection");
        
        uint256 reflectionAmount = _reflectionBalance[_msgSender()];
        require(reflectionAmount > 0, "ReflectionToken: no reflections to claim");
        
        _reflectionBalance[_msgSender()] = 0;
        _mint(_msgSender(), reflectionAmount);
        
        emit ReflectionDistributed(_msgSender(), reflectionAmount);
    }

    /**
     * @dev Returns detailed information about the token
     * @return name_ The token name
     * @return symbol_ The token symbol
     * @return decimals_ The token decimals
     * @return totalSupply_ The total supply
     * @return reflectionFee_ The reflection fee
     * @return totalReflections_ The total reflections
     * @return totalDividends_ The total dividends
     * @return holderCount_ The number of holders
     * @return paused_ Whether the contract is paused
     * @return version_ The token version
     */
    function getTokenInfo() external view returns (
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        uint256 reflectionFee_,
        uint256 totalReflections_,
        uint256 totalDividends_,
        uint256 holderCount_,
        bool paused_,
        string memory version_
    ) {
        return (
            name(),
            symbol(),
            decimals(),
            totalSupply(),
            _reflectionFee,
            _totalReflections,
            _totalDividends,
            _reflectionHolders.length,
            paused(),
            version()
        );
    }

    /**
     * @dev Calculates reflection amount for a transfer
     * @param amount The transfer amount
     * @return uint256 The reflection amount
     */
    function calculateReflection(uint256 amount) external view returns (uint256) {
        if (_reflectionFee == 0) {
            return 0;
        }
        return (amount * _reflectionFee) / 10000;
    }

    /**
     * @dev Internal function to add reflection holder
     * @param holder The holder address
     */
    function _addReflectionHolder(address holder) internal {
        if (_reflectionBalance[holder] == 0 && balanceOf(holder) > 0) {
            _reflectionHolders.push(holder);
            _reflectionBalance[holder] = balanceOf(holder);
        }
    }

    /**
     * @dev Internal function to remove reflection holder
     * @param holder The holder address
     */
    function _removeReflectionHolder(address holder) internal {
        for (uint256 i = 0; i < _reflectionHolders.length; i++) {
            if (_reflectionHolders[i] == holder) {
                _reflectionHolders[i] = _reflectionHolders[_reflectionHolders.length - 1];
                _reflectionHolders.pop();
                _reflectionBalance[holder] = 0;
                break;
            }
        }
    }

    /**
     * @dev Internal function to update reflection balance
     * @param account The account address
     * @param amount The amount change (can be negative)
     */
    function _updateReflectionBalance(address account, int256 amount) internal {
        if (_isExcludedFromReflection[account]) return;
        
        if (amount > 0) {
            _reflectionBalance[account] += uint256(amount);
            if (_reflectionBalance[account] == uint256(amount)) {
                _addReflectionHolder(account);
            }
        } else if (amount < 0) {
            uint256 absAmount = uint256(-amount);
            if (_reflectionBalance[account] >= absAmount) {
                _reflectionBalance[account] -= absAmount;
                if (_reflectionBalance[account] == 0) {
                    _removeReflectionHolder(account);
                }
            }
        }
    }

    /**
     * @dev Internal function to handle transfer with reflection
     * @param from The sender address
     * @param to The recipient address
     * @param amount The transfer amount
     */
    function _transferWithReflection(
        address from,
        address to,
        uint256 amount
    ) internal {
        uint256 reflectionAmount = 0;
        
        if (_reflectionFee > 0 && !_isExcludedFromReflection[from] && !_isExcludedFromReflection[to]) {
            reflectionAmount = (amount * _reflectionFee) / 10000;
            uint256 transferAmount = amount - reflectionAmount;
            
            // Transfer reflection fee to contract
            super._transfer(from, address(this), reflectionAmount);
            // Transfer remaining amount to recipient
            super._transfer(from, to, transferAmount);
            
            _totalDividends += reflectionAmount;
        } else {
            // No reflection fee, transfer full amount
            super._transfer(from, to, amount);
        }
        
        // Update reflection balances
        _updateReflectionBalance(from, -int256(amount));
        _updateReflectionBalance(to, int256(amount));
    }

    /**
     * @dev Override transfer to include reflection
     */
    function transfer(address to, uint256 amount) public virtual override whenNotPaused returns (bool) {
        address owner = _msgSender();
        _transferWithReflection(owner, to, amount);
        return true;
    }

    /**
     * @dev Override transferFrom to include reflection
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override whenNotPaused returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transferWithReflection(from, to, amount);
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
        require(token != address(this), "ReflectionToken: cannot rescue own token");
        require(token != address(0), "ReflectionToken: cannot rescue zero address");
        
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