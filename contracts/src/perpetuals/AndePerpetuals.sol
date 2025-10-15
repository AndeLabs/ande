// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AndePerpetuals
 * @notice Perpetual futures trading protocol for AndeChain
 * @dev Features:
 *      - Long/Short positions with leverage (up to 50x)
 *      - Dynamic funding rates (hourly)
 *      - Automatic liquidations
 *      - Real-time PnL tracking
 *      - Oracle-based mark pricing
 *      - Take profit / Stop loss orders
 * 
 * Architecture inspired by: GMX, dYdX, Perpetual Protocol
 * 
 * Key Concepts:
 * - Mark Price: Oracle price used for liquidations
 * - Index Price: Oracle price used for funding rate
 * - Entry Price: Price when position opened
 * - Liquidation Price: Price that triggers liquidation
 * - Funding Rate: Hourly payment between longs and shorts
 * - Margin: Collateral backing the position
 */
contract AndePerpetuals is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ========================================
    // CONSTANTS
    // ========================================
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_LEVERAGE = 50; // 50x max
    uint256 public constant MIN_LEVERAGE = 2;  // 2x min
    uint256 public constant LIQUIDATION_FEE_RATE = 50; // 0.5%
    uint256 public constant TRADING_FEE_RATE = 10; // 0.1%
    uint256 public constant FUNDING_RATE_PRECISION = 1e10;
    uint256 public constant FUNDING_INTERVAL = 1 hours;
    uint256 public constant MAX_FUNDING_RATE = 500; // 0.05% per hour max
    
    // Maintenance margin: position liquidated if margin < 1%
    uint256 public constant MAINTENANCE_MARGIN_RATE = 100; // 1%

    // ========================================
    // ENUMS
    // ========================================
    
    enum PositionSide {
        LONG,
        SHORT
    }
    
    enum OrderType {
        MARKET,
        LIMIT,
        STOP
    }

    // ========================================
    // STRUCTS
    // ========================================
    
    struct Position {
        PositionSide side;          // Long or Short
        uint256 size;               // Position size in USD
        uint256 collateral;         // Collateral amount
        uint256 entryPrice;         // Entry price (18 decimals)
        uint256 leverage;           // Leverage multiplier
        int256 lastFundingIndex;    // Last funding index paid (can be negative)
        uint256 openTimestamp;      // When position opened
        uint256 takeProfitPrice;    // Take profit trigger (0 = none)
        uint256 stopLossPrice;      // Stop loss trigger (0 = none)
        bool isOpen;                // Is position currently open
    }
    
    struct Market {
        address indexToken;         // Token being traded (e.g., BTC, ETH)
        uint256 longOpenInterest;   // Total long positions size
        uint256 shortOpenInterest;  // Total short positions size
        uint256 maxOpenInterest;    // Maximum open interest allowed
        uint256 fundingRatePerHour; // Current funding rate
        uint256 lastFundingTime;    // Last funding update
        int256 cumulativeFundingRate; // Cumulative funding (can be negative)
        bool isActive;              // Is market active
    }
    
    struct LiquidationInfo {
        address user;
        bytes32 positionKey;
        uint256 liquidationPrice;
        uint256 markPrice;
        uint256 marginLeft;
    }

    // ========================================
    // STATE VARIABLES
    // ========================================
    
    // Position tracking: user => market => Position
    mapping(address => mapping(address => Position)) public positions;
    
    // Markets
    mapping(address => Market) public markets;
    address[] public allMarkets;
    
    // Protocol state
    address public collateralToken; // USDC or stablecoin for collateral
    address public priceOracle;
    address public insuranceFund;
    address public feeRecipient;
    
    uint256 public totalCollateral;
    uint256 public protocolFees;
    
    // Paused state
    bool public paused;

    // ========================================
    // EVENTS
    // ========================================
    
    event PositionOpened(
        address indexed user,
        address indexed market,
        PositionSide side,
        uint256 size,
        uint256 collateral,
        uint256 leverage,
        uint256 entryPrice
    );
    
    event PositionClosed(
        address indexed user,
        address indexed market,
        uint256 exitPrice,
        int256 pnl,
        uint256 feesPaid
    );
    
    event PositionLiquidated(
        address indexed user,
        address indexed market,
        address indexed liquidator,
        uint256 liquidationPrice,
        uint256 liquidationFee
    );
    
    event FundingRateUpdated(
        address indexed market,
        int256 fundingRate,
        uint256 timestamp
    );
    
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);

    // ========================================
    // ERRORS
    // ========================================
    
    error MarketNotActive();
    error PositionAlreadyOpen();
    error NoOpenPosition();
    error InvalidLeverage();
    error InsufficientCollateral();
    error PositionTooSmall();
    error MaxOpenInterestReached();
    error LiquidationNotAllowed();
    error ContractPaused();
    error InvalidPrice();

    // ========================================
    // MODIFIERS
    // ========================================
    
    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }
    
    modifier marketActive(address market) {
        if (!markets[market].isActive) revert MarketNotActive();
        _;
    }

    // ========================================
    // CONSTRUCTOR
    // ========================================
    
    constructor(
        address _collateralToken,
        address _priceOracle,
        address _insuranceFund,
        address _feeRecipient
    ) Ownable(msg.sender) {
        collateralToken = _collateralToken;
        priceOracle = _priceOracle;
        insuranceFund = _insuranceFund;
        feeRecipient = _feeRecipient;
    }

    // ========================================
    // POSITION MANAGEMENT
    // ========================================
    
    /**
     * @notice Open a new perpetual position
     * @param market Index token (e.g., WBTC, WETH)
     * @param side Long or Short
     * @param collateralAmount Collateral to use
     * @param leverage Leverage multiplier (2-50x)
     * @param takeProfitPrice Take profit price (0 = none)
     * @param stopLossPrice Stop loss price (0 = none)
     */
    function openPosition(
        address market,
        PositionSide side,
        uint256 collateralAmount,
        uint256 leverage,
        uint256 takeProfitPrice,
        uint256 stopLossPrice
    ) external nonReentrant whenNotPaused marketActive(market) {
        // Validate inputs
        if (leverage < MIN_LEVERAGE || leverage > MAX_LEVERAGE) revert InvalidLeverage();
        if (collateralAmount == 0) revert InsufficientCollateral();
        if (positions[msg.sender][market].isOpen) revert PositionAlreadyOpen();
        
        // Update funding before opening position
        _updateFundingRate(market);
        
        // Get current price from oracle
        uint256 entryPrice = _getMarkPrice(market);
        if (entryPrice == 0) revert InvalidPrice();
        
        // Calculate position size
        uint256 positionSize = collateralAmount * leverage;
        
        // Check open interest limits
        Market storage marketData = markets[market];
        if (side == PositionSide.LONG) {
            if (marketData.longOpenInterest + positionSize > marketData.maxOpenInterest) {
                revert MaxOpenInterestReached();
            }
            marketData.longOpenInterest += positionSize;
        } else {
            if (marketData.shortOpenInterest + positionSize > marketData.maxOpenInterest) {
                revert MaxOpenInterestReached();
            }
            marketData.shortOpenInterest += positionSize;
        }
        
        // Collect collateral from user
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);
        totalCollateral += collateralAmount;
        
        // Charge trading fee
        uint256 tradingFee = (positionSize * TRADING_FEE_RATE) / BASIS_POINTS;
        uint256 collateralAfterFee = collateralAmount - tradingFee;
        protocolFees += tradingFee;
        
        // Create position
        positions[msg.sender][market] = Position({
            side: side,
            size: positionSize,
            collateral: collateralAfterFee,
            entryPrice: entryPrice,
            leverage: leverage,
            lastFundingIndex: marketData.cumulativeFundingRate,
            openTimestamp: block.timestamp,
            takeProfitPrice: takeProfitPrice,
            stopLossPrice: stopLossPrice,
            isOpen: true
        });
        
        emit PositionOpened(
            msg.sender,
            market,
            side,
            positionSize,
            collateralAfterFee,
            leverage,
            entryPrice
        );
    }
    
    /**
     * @notice Close an open position
     * @param market Index token
     */
    function closePosition(address market) 
        external 
        nonReentrant 
        whenNotPaused 
        marketActive(market) 
    {
        Position storage position = positions[msg.sender][market];
        if (!position.isOpen) revert NoOpenPosition();
        
        // Update funding
        _updateFundingRate(market);
        
        // Get current price
        uint256 exitPrice = _getMarkPrice(market);
        
        // Calculate PnL
        (int256 pnl, uint256 fundingFee) = _calculatePnL(msg.sender, market, exitPrice);
        
        // Charge closing fee
        uint256 closingFee = (position.size * TRADING_FEE_RATE) / BASIS_POINTS;
        
        // Calculate final payout
        int256 finalPayout = int256(position.collateral) + pnl - int256(fundingFee) - int256(closingFee);
        
        // Update open interest
        Market storage marketData = markets[market];
        if (position.side == PositionSide.LONG) {
            marketData.longOpenInterest -= position.size;
        } else {
            marketData.shortOpenInterest -= position.size;
        }
        
        // Close position
        position.isOpen = false;
        totalCollateral -= position.collateral;
        protocolFees += closingFee;
        
        // Transfer payout (if positive)
        if (finalPayout > 0) {
            IERC20(collateralToken).safeTransfer(msg.sender, uint256(finalPayout));
        }
        // If negative, collateral is lost (already accounted for)
        
        emit PositionClosed(
            msg.sender,
            market,
            exitPrice,
            pnl,
            closingFee + fundingFee
        );
    }

    // ========================================
    // LIQUIDATION
    // ========================================
    
    /**
     * @notice Liquidate an underwater position
     * @param user User to liquidate
     * @param market Market of position
     */
    function liquidate(address user, address market) 
        external 
        nonReentrant 
        marketActive(market) 
    {
        Position storage position = positions[user][market];
        if (!position.isOpen) revert NoOpenPosition();
        
        // Update funding
        _updateFundingRate(market);
        
        // Get current price
        uint256 markPrice = _getMarkPrice(market);
        
        // Check if liquidation is allowed
        if (!_canLiquidate(user, market, markPrice)) {
            revert LiquidationNotAllowed();
        }
        
        // Calculate liquidation fee (paid to liquidator)
        uint256 liquidationFee = (position.collateral * LIQUIDATION_FEE_RATE) / BASIS_POINTS;
        uint256 remainingCollateral = position.collateral - liquidationFee;
        
        // Update open interest
        Market storage marketData = markets[market];
        if (position.side == PositionSide.LONG) {
            marketData.longOpenInterest -= position.size;
        } else {
            marketData.shortOpenInterest -= position.size;
        }
        
        // Close position
        position.isOpen = false;
        totalCollateral -= position.collateral;
        
        // Pay liquidation fee to liquidator
        IERC20(collateralToken).safeTransfer(msg.sender, liquidationFee);
        
        // Send remaining to insurance fund
        if (remainingCollateral > 0) {
            IERC20(collateralToken).safeTransfer(insuranceFund, remainingCollateral);
        }
        
        emit PositionLiquidated(user, market, msg.sender, markPrice, liquidationFee);
    }

    // ========================================
    // FUNDING RATE
    // ========================================
    
    /**
     * @notice Update funding rate for a market
     * @param market Index token
     */
    function _updateFundingRate(address market) internal {
        Market storage marketData = markets[market];
        
        uint256 timeSinceLastFunding = block.timestamp - marketData.lastFundingTime;
        if (timeSinceLastFunding < FUNDING_INTERVAL) return;
        
        // Calculate funding rate based on open interest imbalance
        int256 fundingRate = _calculateFundingRate(
            marketData.longOpenInterest,
            marketData.shortOpenInterest
        );
        
        // Update cumulative funding rate
        int256 fundingPayment = (fundingRate * int256(timeSinceLastFunding)) / int256(FUNDING_INTERVAL);
        marketData.cumulativeFundingRate += fundingPayment;
        marketData.fundingRatePerHour = uint256(fundingRate > 0 ? fundingRate : -fundingRate);
        marketData.lastFundingTime = block.timestamp;
        
        emit FundingRateUpdated(market, fundingRate, block.timestamp);
    }
    
    /**
     * @notice Calculate funding rate based on open interest
     * @param longOI Long open interest
     * @param shortOI Short open interest
     * @return fundingRate Funding rate (can be negative)
     * 
     * Security:
     * - Clamped to MAX_FUNDING_RATE to prevent infinite funding
     * - Linear scaling based on OI imbalance
     */
    function _calculateFundingRate(uint256 longOI, uint256 shortOI) 
        internal 
        pure 
        returns (int256 fundingRate) 
    {
        if (longOI == 0 && shortOI == 0) return 0;
        
        // If more longs than shorts, longs pay shorts
        // If more shorts than longs, shorts pay longs
        int256 imbalance = int256(longOI) - int256(shortOI);
        int256 totalOI = int256(longOI + shortOI);
        
        // Prevent division by zero (should never happen due to check above)
        if (totalOI == 0) return 0;
        
        // fundingRate = imbalance / totalOI * maxRate
        fundingRate = (imbalance * int256(MAX_FUNDING_RATE)) / totalOI;
        
        // Clamp to MAX_FUNDING_RATE bounds [-MAX, +MAX]
        if (fundingRate > int256(MAX_FUNDING_RATE)) {
            fundingRate = int256(MAX_FUNDING_RATE);
        } else if (fundingRate < -int256(MAX_FUNDING_RATE)) {
            fundingRate = -int256(MAX_FUNDING_RATE);
        }
    }

    // ========================================
    // PNL & LIQUIDATION CHECKS
    // ========================================
    
    /**
     * @notice Calculate PnL for a position
     * @param user User address
     * @param market Market address
     * @param currentPrice Current mark price
     * @return pnl Profit/Loss (capped to prevent insolvency)
     * @return fundingFee Funding fee owed
     * 
     * Security:
     * - Loss is capped at 100% of collateral to prevent protocol insolvency
     * - Prevents negative equity scenarios
     */
    function _calculatePnL(address user, address market, uint256 currentPrice)
        internal
        view
        returns (int256 pnl, uint256 fundingFee)
    {
        Position storage position = positions[user][market];
        
        // Calculate price PnL
        if (position.side == PositionSide.LONG) {
            // Long: profit when price goes up
            int256 priceDiff = int256(currentPrice) - int256(position.entryPrice);
            pnl = (priceDiff * int256(position.size)) / int256(position.entryPrice);
        } else {
            // Short: profit when price goes down
            int256 priceDiff = int256(position.entryPrice) - int256(currentPrice);
            pnl = (priceDiff * int256(position.size)) / int256(position.entryPrice);
        }
        
        // Cap maximum loss to collateral amount to prevent protocol insolvency
        // User can never lose more than they deposited
        int256 maxLoss = -int256(position.collateral);
        if (pnl < maxLoss) {
            pnl = maxLoss;
        }
        
        // Calculate funding fee
        Market storage marketData = markets[market];
        int256 fundingDelta = marketData.cumulativeFundingRate - position.lastFundingIndex;
        
        if (position.side == PositionSide.LONG) {
            // Longs pay when funding is positive
            fundingFee = fundingDelta > 0 ? uint256(fundingDelta) : 0;
        } else {
            // Shorts pay when funding is negative
            fundingFee = fundingDelta < 0 ? uint256(-fundingDelta) : 0;
        }
        
        fundingFee = (fundingFee * position.size) / FUNDING_RATE_PRECISION;
        
        // Cap funding fee to remaining collateral after PnL
        int256 remainingCollateral = int256(position.collateral) + pnl;
        if (remainingCollateral < 0) {
            fundingFee = 0; // No collateral left to pay funding
        } else if (fundingFee > uint256(remainingCollateral)) {
            fundingFee = uint256(remainingCollateral);
        }
    }
    
    /**
     * @notice Check if position can be liquidated
     * @param user User address
     * @param market Market address
     * @param markPrice Current mark price
     * @return canLiquidate True if position is underwater
     */
    function _canLiquidate(address user, address market, uint256 markPrice)
        internal
        view
        returns (bool)
    {
        Position storage position = positions[user][market];
        
        (int256 pnl, uint256 fundingFee) = _calculatePnL(user, market, markPrice);
        
        // Calculate current margin ratio
        int256 currentMargin = int256(position.collateral) + pnl - int256(fundingFee);
        
        // Liquidate if margin < 1% of position size
        uint256 maintenanceMargin = (position.size * MAINTENANCE_MARGIN_RATE) / BASIS_POINTS;
        
        return currentMargin < int256(maintenanceMargin);
    }
    
    /**
     * @notice Get mark price from oracle
     * @param market Index token
     * @return price Mark price (18 decimals)
     */
    function _getMarkPrice(address market) internal view returns (uint256) {
        return IPriceOracle(priceOracle).getPrice(market);
    }

    // ========================================
    // VIEW FUNCTIONS
    // ========================================
    
    /**
     * @notice Get position details
     * @param user User address
     * @param market Market address
     * @return position Position struct
     */
    function getPosition(address user, address market) 
        external 
        view 
        returns (Position memory) 
    {
        return positions[user][market];
    }
    
    /**
     * @notice Get real-time PnL for a position
     * @param user User address
     * @param market Market address
     * @return pnl Current PnL
     * @return fundingFee Funding fee owed
     */
    function getPositionPnL(address user, address market)
        external
        view
        returns (int256 pnl, uint256 fundingFee)
    {
        uint256 markPrice = _getMarkPrice(market);
        return _calculatePnL(user, market, markPrice);
    }
    
    /**
     * @notice Get liquidation price for a position
     * @param user User address
     * @param market Market address
     * @return liquidationPrice Price that triggers liquidation
     */
    function getLiquidationPrice(address user, address market)
        external
        view
        returns (uint256 liquidationPrice)
    {
        Position storage position = positions[user][market];
        if (!position.isOpen) return 0;
        
        // Simplified liquidation price calculation
        uint256 maintenanceMargin = (position.size * MAINTENANCE_MARGIN_RATE) / BASIS_POINTS;
        
        if (position.side == PositionSide.LONG) {
            // Long liquidation: entryPrice - (collateral - maintenance) / size
            uint256 buffer = position.collateral - maintenanceMargin;
            liquidationPrice = position.entryPrice - (buffer * position.entryPrice) / position.size;
        } else {
            // Short liquidation: entryPrice + (collateral - maintenance) / size
            uint256 buffer = position.collateral - maintenanceMargin;
            liquidationPrice = position.entryPrice + (buffer * position.entryPrice) / position.size;
        }
    }

    // ========================================
    // ADMIN FUNCTIONS
    // ========================================
    
    /**
     * @notice Add a new market
     * @param indexToken Token to trade (e.g., WBTC)
     * @param maxOpenInterest Maximum open interest
     */
    function addMarket(address indexToken, uint256 maxOpenInterest) external onlyOwner {
        markets[indexToken] = Market({
            indexToken: indexToken,
            longOpenInterest: 0,
            shortOpenInterest: 0,
            maxOpenInterest: maxOpenInterest,
            fundingRatePerHour: 0,
            lastFundingTime: block.timestamp,
            cumulativeFundingRate: 0,
            isActive: true
        });
        
        allMarkets.push(indexToken);
    }
    
    /**
     * @notice Pause/unpause trading
     * @param _paused True to pause
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }
    
    /**
     * @notice Withdraw protocol fees
     */
    function withdrawFees() external onlyOwner {
        uint256 fees = protocolFees;
        protocolFees = 0;
        IERC20(collateralToken).safeTransfer(feeRecipient, fees);
    }
}

import "../interfaces/IPriceOracle.sol";
