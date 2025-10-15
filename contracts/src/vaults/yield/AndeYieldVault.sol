// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AndeYieldVault
 * @notice ERC4626-compliant auto-compound yield vault
 * @dev Features:
 *      - Auto-compounds rewards from AndeSwap LP positions
 *      - Harvests and reinvests yields automatically
 *      - ERC4626 standard for maximum composability
 *      - Optimized gas for batch operations
 *      - Performance fees for sustainability
 * 
 * Yield Strategy:
 * 1. Users deposit LP tokens
 * 2. Vault stakes LP in gauges/farms
 * 3. Harvests ANDE rewards periodically
 * 4. Swaps rewards for more LP tokens
 * 5. Compounds back into position
 */
contract AndeYieldVault is ERC4626, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ========================================
    // CONSTANTS
    // ========================================
    
    uint256 public constant PRECISION = 10000;
    uint256 public constant MAX_PERFORMANCE_FEE = 2000; // 20%
    uint256 public constant MAX_WITHDRAWAL_FEE = 100; // 1%
    
    // ========================================
    // STATE VARIABLES
    // ========================================
    
    address public immutable rewardToken; // ANDE
    address public immutable router; // AndeSwapRouter
    address public gauge; // Staking contract
    address public treasury;
    
    uint256 public performanceFee = 1000; // 10%
    uint256 public withdrawalFee = 10; // 0.1%
    uint256 public lastHarvest;
    uint256 public totalHarvested;
    
    bool public paused;

    // ========================================
    // EVENTS
    // ========================================
    
    event Harvest(uint256 rewards, uint256 compounded, uint256 fee);
    event PerformanceFeeUpdated(uint256 newFee);
    event WithdrawalFeeUpdated(uint256 newFee);
    event TreasuryUpdated(address newTreasury);
    event Paused();
    event Unpaused();

    // ========================================
    // ERRORS
    // ========================================
    
    error VaultPaused();
    error InvalidFee();
    error ZeroAmount();
    error InvalidAddress();

    // ========================================
    // MODIFIERS
    // ========================================
    
    modifier whenNotPaused() {
        if (paused) revert VaultPaused();
        _;
    }

    // ========================================
    // CONSTRUCTOR
    // ========================================
    
    constructor(
        address _asset,
        address _rewardToken,
        address _router,
        address _gauge,
        address _treasury,
        string memory _name,
        string memory _symbol
    ) ERC4626(IERC20(_asset)) ERC20(_name, _symbol) Ownable(msg.sender) {
        rewardToken = _rewardToken;
        router = _router;
        gauge = _gauge;
        treasury = _treasury;
        lastHarvest = block.timestamp;
    }

    // ========================================
    // CORE VAULT FUNCTIONS
    // ========================================
    
    /**
     * @notice Deposit assets and receive vault shares
     * @param assets Amount of assets to deposit
     * @param receiver Address to receive shares
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver) 
        public 
        virtual 
        override 
        whenNotPaused 
        nonReentrant 
        returns (uint256 shares) 
    {
        if (assets == 0) revert ZeroAmount();
        
        shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);
        
        // Stake in gauge
        if (gauge != address(0)) {
            IERC20(asset()).approve(gauge, assets);
            _stakeInGauge(assets);
        }
    }
    
    /**
     * @notice Withdraw assets by burning shares
     * @param assets Amount of assets to withdraw
     * @param receiver Address to receive assets
     * @param owner Owner of the shares
     * @return shares Amount of shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        nonReentrant
        returns (uint256 shares)
    {
        if (assets == 0) revert ZeroAmount();
        
        shares = previewWithdraw(assets);
        
        // Unstake from gauge
        if (gauge != address(0)) {
            _unstakeFromGauge(assets);
        }
        
        // Apply withdrawal fee
        uint256 fee = (assets * withdrawalFee) / PRECISION;
        uint256 assetsAfterFee = assets - fee;
        
        if (fee > 0) {
            IERC20(asset()).safeTransfer(treasury, fee);
        }
        
        _withdraw(_msgSender(), receiver, owner, assetsAfterFee, shares);
    }

    // ========================================
    // YIELD HARVESTING
    // ========================================
    
    /**
     * @notice Harvest rewards and compound
     * @dev Anyone can call to trigger compound
     */
    function harvest() external nonReentrant {
        if (gauge == address(0)) return;
        
        // Claim rewards from gauge
        uint256 rewardsBefore = IERC20(rewardToken).balanceOf(address(this));
        _claimRewards();
        uint256 rewards = IERC20(rewardToken).balanceOf(address(this)) - rewardsBefore;
        
        if (rewards == 0) return;
        
        // Take performance fee
        uint256 fee = (rewards * performanceFee) / PRECISION;
        uint256 toCompound = rewards - fee;
        
        if (fee > 0) {
            IERC20(rewardToken).safeTransfer(treasury, fee);
        }
        
        // Swap rewards for LP tokens and compound
        uint256 lpTokens = _swapRewardsForLP(toCompound);
        
        // Stake additional LP
        if (lpTokens > 0 && gauge != address(0)) {
            IERC20(asset()).approve(gauge, lpTokens);
            _stakeInGauge(lpTokens);
        }
        
        totalHarvested += rewards;
        lastHarvest = block.timestamp;
        
        emit Harvest(rewards, lpTokens, fee);
    }

    // ========================================
    // VIEW FUNCTIONS
    // ========================================
    
    /**
     * @notice Total assets under management
     * @return Total assets including staked
     */
    function totalAssets() public view virtual override returns (uint256) {
        uint256 liquid = IERC20(asset()).balanceOf(address(this));
        uint256 staked = gauge != address(0) ? _getStakedBalance() : 0;
        return liquid + staked;
    }
    
    /**
     * @notice Pending rewards available to harvest
     * @return Pending reward amount
     */
    function pendingRewards() public view returns (uint256) {
        if (gauge == address(0)) return 0;
        return _getPendingRewards();
    }
    
    /**
     * @notice Current APY (simplified calculation)
     * @return APY in basis points
     */
    function getAPY() external view returns (uint256) {
        if (totalAssets() == 0 || lastHarvest == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - lastHarvest;
        if (timeElapsed == 0) return 0;
        
        uint256 pending = pendingRewards();
        uint256 annualizedRewards = (pending * 365 days) / timeElapsed;
        
        return (annualizedRewards * PRECISION) / totalAssets();
    }

    // ========================================
    // ADMIN FUNCTIONS
    // ========================================
    
    function setPerformanceFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_PERFORMANCE_FEE) revert InvalidFee();
        performanceFee = newFee;
        emit PerformanceFeeUpdated(newFee);
    }
    
    function setWithdrawalFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_WITHDRAWAL_FEE) revert InvalidFee();
        withdrawalFee = newFee;
        emit WithdrawalFeeUpdated(newFee);
    }
    
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert InvalidAddress();
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }
    
    function pause() external onlyOwner {
        paused = true;
        emit Paused();
    }
    
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused();
    }

    // ========================================
    // INTERNAL FUNCTIONS
    // ========================================
    
    function _stakeInGauge(uint256 amount) internal virtual {
        // Implement gauge staking
        // Interface with LiquidityGaugeV1
    }
    
    function _unstakeFromGauge(uint256 amount) internal virtual {
        // Implement gauge unstaking
    }
    
    function _claimRewards() internal virtual {
        // Claim rewards from gauge
    }
    
    function _getStakedBalance() internal view virtual returns (uint256) {
        // Get staked balance from gauge
        return 0;
    }
    
    function _getPendingRewards() internal view virtual returns (uint256) {
        // Get pending rewards from gauge
        return 0;
    }
    
    function _swapRewardsForLP(uint256 rewardAmount) internal virtual returns (uint256) {
        // Swap ANDE rewards for LP tokens via router
        // 1. Swap half ANDE for token0
        // 2. Swap half ANDE for token1
        // 3. Add liquidity
        return 0; // Placeholder
    }
}
