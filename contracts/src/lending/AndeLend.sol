// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title AndeLend
 * @notice Decentralized lending and borrowing protocol for AndeChain
 * @dev Inspired by Compound/Aave with optimizations for ANDE ecosystem:
 *      - Collateralized lending with dynamic interest rates
 *      - Health factor-based liquidations
 *      - Interest-bearing aTokens (ERC20)
 *      - Flash loan support
 *      - ANDE token integration for rewards
 * 
 * Architecture:
 * 1. Markets: Each ERC20 asset has a lending market
 * 2. Collateral: Users deposit assets to borrow others
 * 3. Interest: Dynamic rates based on utilization
 * 4. Liquidation: Underwater positions liquidated with bonus
 * 5. aTokens: Receipt tokens earning interest
 */
contract AndeLend is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ========================================
    // CONSTANTS
    // ========================================
    
    uint256 public constant LIQUIDATION_THRESHOLD = 8000; // 80% LTV
    uint256 public constant LIQUIDATION_BONUS = 500; // 5% bonus for liquidators
    uint256 public constant MIN_HEALTH_FACTOR = 1e18; // 1.0
    uint256 public constant PRECISION = 10000;
    uint256 public constant SECONDS_PER_YEAR = 31536000;
    
    // Interest rate model parameters
    uint256 public constant BASE_RATE = 200; // 2% APR
    uint256 public constant SLOPE1 = 400; // 4% APR at optimal utilization
    uint256 public constant SLOPE2 = 6000; // 60% APR above optimal
    uint256 public constant OPTIMAL_UTILIZATION = 8000; // 80%

    // ========================================
    // STRUCTS
    // ========================================
    
    struct Market {
        bool isActive;
        address aToken; // Interest-bearing token
        uint256 totalSupply; // Total supplied
        uint256 totalBorrows; // Total borrowed
        uint256 borrowIndex; // Accumulator for interest
        uint256 lastUpdateTimestamp;
        uint256 collateralFactor; // Basis points (e.g., 7500 = 75%)
        uint256 liquidationIncentive; // Basis points
        uint256 reserveFactor; // % of interest to reserves
    }
    
    struct UserMarketData {
        uint256 principal; // Amount deposited
        uint256 borrowBalance; // Amount borrowed
        uint256 borrowIndex; // Index when user borrowed
        bool useAsCollateral; // If deposit is collateral
    }

    // ========================================
    // STATE VARIABLES
    // ========================================
    
    mapping(address => Market) public markets;
    mapping(address => mapping(address => UserMarketData)) public userMarkets; // user => token => data
    mapping(address => address[]) public userCollateralTokens; // user => tokens used as collateral
    mapping(address => address[]) public userBorrowedTokens; // user => tokens borrowed
    
    address[] public allMarkets;
    address public priceOracle;
    address public rewardsController;
    uint256 public flashLoanFee = 9; // 0.09%

    // ========================================
    // EVENTS
    // ========================================
    
    event MarketCreated(address indexed token, address indexed aToken, uint256 collateralFactor);
    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 aTokens);
    event Withdraw(address indexed user, address indexed token, uint256 amount, uint256 aTokens);
    event Borrow(address indexed user, address indexed token, uint256 amount);
    event Repay(address indexed user, address indexed token, uint256 amount);
    event Liquidation(
        address indexed liquidator,
        address indexed borrower,
        address indexed collateralToken,
        address debtToken,
        uint256 debtAmount,
        uint256 collateralAmount
    );
    event FlashLoan(address indexed receiver, address indexed token, uint256 amount, uint256 fee);

    // ========================================
    // ERRORS
    // ========================================
    
    error MarketNotActive();
    error MarketAlreadyExists();
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error HealthFactorOK();
    error HealthFactorTooLow();
    error InvalidAmount();
    error InvalidMarket();
    error Unauthorized();
    error FlashLoanFailed();

    // ========================================
    // CONSTRUCTOR
    // ========================================
    
    constructor(address _priceOracle) Ownable(msg.sender) {
        priceOracle = _priceOracle;
    }

    // ========================================
    // CORE LENDING FUNCTIONS
    // ========================================
    
    /**
     * @notice Deposit tokens to earn interest
     * @param token Asset to deposit
     * @param amount Amount to deposit
     * @param useAsCollateral Whether to use deposit as collateral
     */
    function deposit(
        address token,
        uint256 amount,
        bool useAsCollateral
    ) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        
        Market storage market = markets[token];
        if (!market.isActive) revert MarketNotActive();
        
        _accrueInterest(token);
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        UserMarketData storage userData = userMarkets[msg.sender][token];
        userData.principal += amount;
        userData.useAsCollateral = useAsCollateral;
        
        market.totalSupply += amount;
        
        // Mint aTokens (1:1 for now, can implement exchange rate)
        uint256 aTokenAmount = amount;
        _mintAToken(market.aToken, msg.sender, aTokenAmount);
        
        if (useAsCollateral) {
            _addCollateralToken(msg.sender, token);
        }
        
        emit Deposit(msg.sender, token, amount, aTokenAmount);
    }
    
    /**
     * @notice Withdraw deposited tokens
     * @param token Asset to withdraw
     * @param amount Amount to withdraw (0 = withdraw all)
     */
    function withdraw(address token, uint256 amount) external nonReentrant {
        Market storage market = markets[token];
        if (!market.isActive) revert MarketNotActive();
        
        _accrueInterest(token);
        
        UserMarketData storage userData = userMarkets[msg.sender][token];
        uint256 withdrawAmount = amount == 0 ? userData.principal : amount;
        
        if (withdrawAmount > userData.principal) revert InvalidAmount();
        if (withdrawAmount > market.totalSupply - market.totalBorrows) {
            revert InsufficientLiquidity();
        }
        
        // Check health factor if used as collateral
        if (userData.useAsCollateral) {
            userData.useAsCollateral = false; // Temporarily disable
            if (_getHealthFactor(msg.sender) < MIN_HEALTH_FACTOR) {
                userData.useAsCollateral = true;
                revert HealthFactorTooLow();
            }
        }
        
        userData.principal -= withdrawAmount;
        market.totalSupply -= withdrawAmount;
        
        // Burn aTokens
        uint256 aTokenAmount = withdrawAmount;
        _burnAToken(market.aToken, msg.sender, aTokenAmount);
        
        IERC20(token).safeTransfer(msg.sender, withdrawAmount);
        
        emit Withdraw(msg.sender, token, withdrawAmount, aTokenAmount);
    }
    
    /**
     * @notice Borrow tokens against collateral
     * @param token Asset to borrow
     * @param amount Amount to borrow
     */
    function borrow(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        
        Market storage market = markets[token];
        if (!market.isActive) revert MarketNotActive();
        
        _accrueInterest(token);
        
        uint256 availableLiquidity = market.totalSupply - market.totalBorrows;
        if (amount > availableLiquidity) revert InsufficientLiquidity();
        
        UserMarketData storage userData = userMarkets[msg.sender][token];
        
        // Update borrow balance with accrued interest
        if (userData.borrowBalance > 0) {
            uint256 borrowIndexDelta = market.borrowIndex - userData.borrowIndex;
            userData.borrowBalance += (userData.borrowBalance * borrowIndexDelta) / 1e18;
        }
        
        userData.borrowBalance += amount;
        userData.borrowIndex = market.borrowIndex;
        market.totalBorrows += amount;
        
        _addBorrowedToken(msg.sender, token);
        
        // Check health factor
        uint256 healthFactor = _getHealthFactor(msg.sender);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert InsufficientCollateral();
        }
        
        IERC20(token).safeTransfer(msg.sender, amount);
        
        emit Borrow(msg.sender, token, amount);
    }
    
    /**
     * @notice Repay borrowed tokens
     * @param token Asset to repay
     * @param amount Amount to repay (0 = repay all)
     */
    function repay(address token, uint256 amount) external nonReentrant {
        Market storage market = markets[token];
        if (!market.isActive) revert MarketNotActive();
        
        _accrueInterest(token);
        
        UserMarketData storage userData = userMarkets[msg.sender][token];
        
        // Update borrow balance with accrued interest
        if (userData.borrowBalance > 0) {
            uint256 borrowIndexDelta = market.borrowIndex - userData.borrowIndex;
            userData.borrowBalance += (userData.borrowBalance * borrowIndexDelta) / 1e18;
        }
        
        uint256 repayAmount = amount == 0 ? userData.borrowBalance : amount;
        if (repayAmount > userData.borrowBalance) {
            repayAmount = userData.borrowBalance;
        }
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), repayAmount);
        
        userData.borrowBalance -= repayAmount;
        userData.borrowIndex = market.borrowIndex;
        market.totalBorrows -= repayAmount;
        
        emit Repay(msg.sender, token, repayAmount);
    }

    // ========================================
    // LIQUIDATION
    // ========================================
    
    /**
     * @notice Liquidate undercollateralized position
     * @param borrower Address to liquidate
     * @param debtToken Token to repay
     * @param collateralToken Token to seize
     * @param debtAmount Amount of debt to repay
     */
    function liquidate(
        address borrower,
        address debtToken,
        address collateralToken,
        uint256 debtAmount
    ) external nonReentrant {
        if (_getHealthFactor(borrower) >= MIN_HEALTH_FACTOR) {
            revert HealthFactorOK();
        }
        
        _accrueInterest(debtToken);
        _accrueInterest(collateralToken);
        
        // Calculate collateral to seize (with liquidation bonus)
        uint256 debtValue = _getAssetValue(debtToken, debtAmount);
        uint256 collateralValue = (debtValue * (PRECISION + LIQUIDATION_BONUS)) / PRECISION;
        uint256 collateralAmount = _getAssetAmount(collateralToken, collateralValue);
        
        // Transfer debt from liquidator
        IERC20(debtToken).safeTransferFrom(msg.sender, address(this), debtAmount);
        
        // Update borrower's debt
        UserMarketData storage borrowerDebt = userMarkets[borrower][debtToken];
        borrowerDebt.borrowBalance -= debtAmount;
        markets[debtToken].totalBorrows -= debtAmount;
        
        // Transfer collateral to liquidator
        UserMarketData storage borrowerCollateral = userMarkets[borrower][collateralToken];
        borrowerCollateral.principal -= collateralAmount;
        markets[collateralToken].totalSupply -= collateralAmount;
        
        IERC20(collateralToken).safeTransfer(msg.sender, collateralAmount);
        
        emit Liquidation(msg.sender, borrower, collateralToken, debtToken, debtAmount, collateralAmount);
    }

    // ========================================
    // VIEW FUNCTIONS
    // ========================================
    
    /**
     * @notice Get user's health factor
     * @param user User address
     * @return healthFactor Health factor (1e18 = 1.0)
     */
    function getHealthFactor(address user) external view returns (uint256) {
        return _getHealthFactor(user);
    }
    
    /**
     * @notice Get user's total collateral value
     * @param user User address
     * @return totalCollateral Collateral value in USD (1e18)
     */
    function getUserCollateralValue(address user) external view returns (uint256) {
        return _getUserCollateralValue(user);
    }
    
    /**
     * @notice Get user's total borrow value
     * @param user User address
     * @return totalBorrow Borrow value in USD (1e18)
     */
    function getUserBorrowValue(address user) external view returns (uint256) {
        return _getUserBorrowValue(user);
    }
    
    /**
     * @notice Get current borrow APR for a market
     * @param token Market token
     * @return borrowAPR Annual percentage rate (basis points)
     */
    function getBorrowAPR(address token) external view returns (uint256) {
        Market storage market = markets[token];
        return _calculateBorrowRate(market);
    }
    
    /**
     * @notice Get current supply APR for a market
     * @param token Market token
     * @return supplyAPR Annual percentage rate (basis points)
     */
    function getSupplyAPR(address token) external view returns (uint256) {
        Market storage market = markets[token];
        uint256 borrowRate = _calculateBorrowRate(market);
        uint256 utilization = _getUtilizationRate(market);
        return (borrowRate * utilization * (PRECISION - market.reserveFactor)) / (PRECISION * PRECISION);
    }

    // ========================================
    // ADMIN FUNCTIONS
    // ========================================
    
    /**
     * @notice Create a new lending market
     * @param token Asset token
     * @param aToken Interest-bearing token
     * @param collateralFactor LTV ratio (basis points)
     */
    function createMarket(
        address token,
        address aToken,
        uint256 collateralFactor
    ) external onlyOwner {
        if (markets[token].isActive) revert MarketAlreadyExists();
        
        markets[token] = Market({
            isActive: true,
            aToken: aToken,
            totalSupply: 0,
            totalBorrows: 0,
            borrowIndex: 1e18,
            lastUpdateTimestamp: block.timestamp,
            collateralFactor: collateralFactor,
            liquidationIncentive: LIQUIDATION_BONUS,
            reserveFactor: 1000 // 10%
        });
        
        allMarkets.push(token);
        
        emit MarketCreated(token, aToken, collateralFactor);
    }
    
    /**
     * @notice Update price oracle
     * @param newOracle New oracle address
     */
    function setPriceOracle(address newOracle) external onlyOwner {
        priceOracle = newOracle;
    }

    // ========================================
    // INTERNAL FUNCTIONS
    // ========================================
    
    function _accrueInterest(address token) internal {
        Market storage market = markets[token];
        
        uint256 timeElapsed = block.timestamp - market.lastUpdateTimestamp;
        if (timeElapsed == 0) return;
        
        uint256 borrowRate = _calculateBorrowRate(market);
        uint256 interestFactor = (borrowRate * timeElapsed) / SECONDS_PER_YEAR;
        uint256 interestAccumulated = (market.totalBorrows * interestFactor) / PRECISION;
        
        market.totalBorrows += interestAccumulated;
        market.borrowIndex += (market.borrowIndex * interestFactor) / PRECISION;
        market.lastUpdateTimestamp = block.timestamp;
    }
    
    function _calculateBorrowRate(Market storage market) internal view returns (uint256) {
        uint256 utilization = _getUtilizationRate(market);
        
        if (utilization <= OPTIMAL_UTILIZATION) {
            return BASE_RATE + (SLOPE1 * utilization) / PRECISION;
        } else {
            uint256 excessUtilization = utilization - OPTIMAL_UTILIZATION;
            return BASE_RATE + SLOPE1 + (SLOPE2 * excessUtilization) / PRECISION;
        }
    }
    
    function _getUtilizationRate(Market storage market) internal view returns (uint256) {
        if (market.totalSupply == 0) return 0;
        return (market.totalBorrows * PRECISION) / market.totalSupply;
    }
    
    function _getHealthFactor(address user) internal view returns (uint256) {
        uint256 totalCollateralValue = _getUserTotalCollateralValue(user); // Raw value
        uint256 totalBorrow = _getUserBorrowValue(user);
        
        if (totalBorrow == 0) return type(uint256).max;
        
        // Apply liquidation threshold (80%)
        uint256 collateralWithThreshold = (totalCollateralValue * LIQUIDATION_THRESHOLD) / PRECISION;
        return (collateralWithThreshold * 1e18) / totalBorrow;
    }
    
    function _getUserCollateralValue(address user) internal view returns (uint256 totalValue) {
        // Returns borrowing power (collateral * collateral factor)
        address[] memory collateralTokens = userCollateralTokens[user];
        
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            UserMarketData storage userData = userMarkets[user][token];
            
            if (userData.useAsCollateral && userData.principal > 0) {
                uint256 value = _getAssetValue(token, userData.principal);
                uint256 collateralFactor = markets[token].collateralFactor;
                totalValue += (value * collateralFactor) / PRECISION;
            }
        }
    }
    
    function _getUserTotalCollateralValue(address user) internal view returns (uint256 totalValue) {
        // Returns raw collateral value (without collateral factor)
        address[] memory collateralTokens = userCollateralTokens[user];
        
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            UserMarketData storage userData = userMarkets[user][token];
            
            if (userData.useAsCollateral && userData.principal > 0) {
                totalValue += _getAssetValue(token, userData.principal);
            }
        }
    }
    
    function _getUserBorrowValue(address user) internal view returns (uint256 totalValue) {
        address[] memory borrowedTokens = userBorrowedTokens[user];
        
        for (uint256 i = 0; i < borrowedTokens.length; i++) {
            address token = borrowedTokens[i];
            UserMarketData storage userData = userMarkets[user][token];
            
            if (userData.borrowBalance > 0) {
                totalValue += _getAssetValue(token, userData.borrowBalance);
            }
        }
    }
    
    function _getAssetValue(address token, uint256 amount) internal view returns (uint256) {
        // Get token decimals
        uint8 decimals = _getDecimals(token);
        
        // Normalize amount to 18 decimals first
        uint256 normalizedAmount = amount;
        if (decimals < 18) {
            normalizedAmount = amount * (10 ** (18 - decimals));
        } else if (decimals > 18) {
            normalizedAmount = amount / (10 ** (decimals - 18));
        }
        
        // Get price from oracle
        if (priceOracle == address(0)) {
            // No oracle: assume 1:1 USD (for testing only)
            return normalizedAmount;
        }
        
        // Get price from oracle (price is in USD with 18 decimals)
        uint256 priceInUSD = IPriceOracle(priceOracle).getPrice(token);
        
        // Calculate value: normalizedAmount * price / 1e18
        return (normalizedAmount * priceInUSD) / 1e18;
    }
    
    function _getAssetAmount(address token, uint256 value) internal view returns (uint256) {
        // Get price from oracle
        if (priceOracle == address(0)) {
            // No oracle: assume 1:1 USD (for testing only)
            uint8 decimals = _getDecimals(token);
            if (decimals < 18) {
                return value / (10 ** (18 - decimals));
            } else if (decimals > 18) {
                return value * (10 ** (decimals - 18));
            }
            return value;
        }
        
        // Get price from oracle (price is in USD with 18 decimals)
        uint256 priceInUSD = IPriceOracle(priceOracle).getPrice(token);
        
        // Calculate amount: value * 1e18 / price
        uint256 normalizedAmount = (value * 1e18) / priceInUSD;
        
        // Denormalize to token decimals
        uint8 decimals = _getDecimals(token);
        if (decimals < 18) {
            return normalizedAmount / (10 ** (18 - decimals));
        } else if (decimals > 18) {
            return normalizedAmount * (10 ** (decimals - 18));
        }
        return normalizedAmount;
    }
    
    function _getDecimals(address token) internal view returns (uint8) {
        try IERC20Metadata(token).decimals() returns (uint8 decimals) {
            return decimals;
        } catch {
            return 18; // Default to 18 decimals
        }
    }
    
    function _addCollateralToken(address user, address token) internal {
        address[] storage tokens = userCollateralTokens[user];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) return;
        }
        tokens.push(token);
    }
    
    function _addBorrowedToken(address user, address token) internal {
        address[] storage tokens = userBorrowedTokens[user];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) return;
        }
        tokens.push(token);
    }
    
    function _mintAToken(address aToken, address to, uint256 amount) internal {
        // Mint aTokens to user
        IAToken(aToken).mint(to, amount);
    }
    
    function _burnAToken(address aToken, address from, uint256 amount) internal {
        // Burn aTokens from user
        IAToken(aToken).burn(from, amount);
    }
}

// ========================================
// INTERFACES
// ========================================

interface IAToken {
    function mint(address user, uint256 amount) external;
    function burn(address user, uint256 amount) external;
}

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256 price);
}
