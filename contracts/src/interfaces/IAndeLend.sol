// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IAndeLend
 * @notice Interface for AndeLend protocol
 * @dev Lending and borrowing with collateralization
 */
interface IAndeLend {
    
    // ========================================
    // STRUCTS
    // ========================================
    
    struct Market {
        bool isActive;
        address aToken;
        uint256 totalSupply;
        uint256 totalBorrows;
        uint256 borrowIndex;
        uint256 lastUpdateTimestamp;
        uint256 collateralFactor;
        uint256 liquidationIncentive;
        uint256 reserveFactor;
    }
    
    struct UserMarketData {
        uint256 principal;
        uint256 borrowBalance;
        uint256 borrowIndex;
        bool useAsCollateral;
    }

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
    // CORE FUNCTIONS
    // ========================================
    
    /**
     * @notice Deposit tokens to earn interest
     * @param token Asset to deposit
     * @param amount Amount to deposit
     * @param useAsCollateral Use as collateral for borrowing
     */
    function deposit(address token, uint256 amount, bool useAsCollateral) external;
    
    /**
     * @notice Withdraw deposited tokens
     * @param token Asset to withdraw
     * @param amount Amount to withdraw (0 = all)
     */
    function withdraw(address token, uint256 amount) external;
    
    /**
     * @notice Borrow tokens against collateral
     * @param token Asset to borrow
     * @param amount Amount to borrow
     */
    function borrow(address token, uint256 amount) external;
    
    /**
     * @notice Repay borrowed tokens
     * @param token Asset to repay
     * @param amount Amount to repay (0 = all)
     */
    function repay(address token, uint256 amount) external;
    
    /**
     * @notice Liquidate undercollateralized position
     * @param borrower Address to liquidate
     * @param debtToken Token to repay
     * @param collateralToken Token to seize
     * @param debtAmount Debt to repay
     */
    function liquidate(
        address borrower,
        address debtToken,
        address collateralToken,
        uint256 debtAmount
    ) external;

    // ========================================
    // VIEW FUNCTIONS
    // ========================================
    
    /**
     * @notice Get user's health factor
     * @param user User address
     * @return Health factor (1e18 = 1.0)
     */
    function getHealthFactor(address user) external view returns (uint256);
    
    /**
     * @notice Get user's total collateral value
     * @param user User address
     * @return Total collateral in USD
     */
    function getUserCollateralValue(address user) external view returns (uint256);
    
    /**
     * @notice Get user's total borrow value
     * @param user User address
     * @return Total borrow in USD
     */
    function getUserBorrowValue(address user) external view returns (uint256);
    
    /**
     * @notice Get current borrow APR
     * @param token Market token
     * @return Borrow APR (basis points)
     */
    function getBorrowAPR(address token) external view returns (uint256);
    
    /**
     * @notice Get current supply APR
     * @param token Market token
     * @return Supply APR (basis points)
     */
    function getSupplyAPR(address token) external view returns (uint256);
    
    /**
     * @notice Get market info
     * @param token Market token
     * @return Market struct
     */
    function markets(address token) external view returns (Market memory);
}
