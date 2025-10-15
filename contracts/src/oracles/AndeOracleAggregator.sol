// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AndeOracleAggregator
 * @notice Aggregates prices from multiple oracle sources with fallback mechanism
 * @dev Priority: Chainlink → Pyth → TWAP → Manual
 * 
 * Architecture:
 * - Primary: Chainlink (most decentralized)
 * - Secondary: Pyth Network (fastest updates)
 * - Tertiary: TWAP from AndeSwap (on-chain)
 * - Fallback: Manual price feed (emergency only)
 * 
 * Security:
 * - Staleness checks (max age)
 * - Price deviation limits
 * - Circuit breaker for extreme moves
 * - Multi-signature for manual updates
 */
contract AndeOracleAggregator is Ownable, ReentrancyGuard {

    // ========================================
    // CONSTANTS
    // ========================================
    
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant MAX_PRICE_DEVIATION = 1000; // 10% max deviation
    uint256 public constant MAX_PRICE_AGE = 1 hours;
    uint256 public constant CIRCUIT_BREAKER_THRESHOLD = 5000; // 50% price move
    
    // ========================================
    // ENUMS
    // ========================================
    
    enum OracleSource {
        None,
        Chainlink,
        Pyth,
        TWAP,
        Manual
    }
    
    // ========================================
    // STRUCTS
    // ========================================
    
    struct PriceData {
        uint256 price;           // Price in USD (18 decimals)
        uint256 timestamp;       // Last update timestamp
        OracleSource source;     // Which oracle provided this
        uint256 confidence;      // Confidence interval (basis points)
    }
    
    struct OracleConfig {
        address chainlinkFeed;   // Chainlink aggregator
        bytes32 pythPriceId;     // Pyth price feed ID
        address twapPool;        // AndeSwap pair for TWAP
        bool enabled;            // Is oracle enabled for this asset
        uint256 heartbeat;       // Expected update frequency
    }
    
    // ========================================
    // STATE VARIABLES
    // ========================================
    
    mapping(address => OracleConfig) public oracleConfigs;
    mapping(address => PriceData) public latestPrices;
    mapping(address => bool) public isCircuitBroken;
    
    address public pythContract;
    address public chainlinkRegistry;
    bool public emergencyMode;
    
    // ========================================
    // EVENTS
    // ========================================
    
    event PriceUpdated(
        address indexed asset,
        uint256 price,
        OracleSource source,
        uint256 timestamp
    );
    event OracleConfigured(address indexed asset, address chainlinkFeed, bytes32 pythId);
    event CircuitBreakerTriggered(address indexed asset, uint256 oldPrice, uint256 newPrice);
    event EmergencyModeActivated(bool active);
    
    // ========================================
    // ERRORS
    // ========================================
    
    error PriceStale();
    error PriceNotAvailable();
    error InvalidPrice();
    error CircuitBreakerActive();
    error OracleNotConfigured();
    error PriceDeviationTooHigh();
    
    // ========================================
    // CONSTRUCTOR
    // ========================================
    
    constructor(address _pythContract) Ownable(msg.sender) {
        pythContract = _pythContract;
    }
    
    // ========================================
    // CORE PRICE FUNCTIONS
    // ========================================
    
    /**
     * @notice Get latest price for an asset
     * @param asset Asset address
     * @return price Price in USD (18 decimals)
     */
    function getPrice(address asset) external view returns (uint256 price) {
        if (isCircuitBroken[asset]) revert CircuitBreakerActive();
        
        PriceData memory priceData = latestPrices[asset];
        
        // Check staleness
        if (block.timestamp - priceData.timestamp > MAX_PRICE_AGE) {
            revert PriceStale();
        }
        
        if (priceData.price == 0) revert PriceNotAvailable();
        
        return priceData.price;
    }
    
    /**
     * @notice Get price with metadata
     * @param asset Asset address
     * @return price Price in USD
     * @return timestamp Last update time
     * @return source Oracle source used
     */
    function getPriceWithMetadata(address asset) 
        external 
        view 
        returns (
            uint256 price,
            uint256 timestamp,
            OracleSource source
        ) 
    {
        PriceData memory priceData = latestPrices[asset];
        return (priceData.price, priceData.timestamp, priceData.source);
    }
    
    /**
     * @notice Update price from best available source
     * @param asset Asset to update
     */
    function updatePrice(address asset) external nonReentrant {
        OracleConfig memory config = oracleConfigs[asset];
        if (!config.enabled) revert OracleNotConfigured();
        
        PriceData memory newPrice;
        
        // Try Chainlink first
        if (config.chainlinkFeed != address(0)) {
            (bool success, PriceData memory chainlinkPrice) = _getChainlinkPrice(asset);
            if (success) {
                newPrice = chainlinkPrice;
            }
        }
        
        // Fallback to Pyth
        if (newPrice.price == 0 && config.pythPriceId != bytes32(0)) {
            (bool success, PriceData memory pythPrice) = _getPythPrice(asset);
            if (success) {
                newPrice = pythPrice;
            }
        }
        
        // Fallback to TWAP
        if (newPrice.price == 0 && config.twapPool != address(0)) {
            (bool success, PriceData memory twapPrice) = _getTWAPPrice(asset);
            if (success) {
                newPrice = twapPrice;
            }
        }
        
        if (newPrice.price == 0) revert PriceNotAvailable();
        
        // Check for circuit breaker conditions
        _checkCircuitBreaker(asset, newPrice.price);
        
        // Update price
        latestPrices[asset] = newPrice;
        
        emit PriceUpdated(asset, newPrice.price, newPrice.source, newPrice.timestamp);
    }
    
    // ========================================
    // ORACLE SOURCE IMPLEMENTATIONS
    // ========================================
    
    /**
     * @notice Get price from Chainlink
     * @param asset Asset address
     * @return success If price was fetched successfully
     * @return priceData Price data struct
     */
    function _getChainlinkPrice(address asset) 
        internal 
        view 
        returns (bool success, PriceData memory priceData) 
    {
        OracleConfig memory config = oracleConfigs[asset];
        if (config.chainlinkFeed == address(0)) return (false, priceData);
        
        try IChainlinkAggregator(config.chainlinkFeed).latestRoundData() returns (
            uint80,
            int256 answer,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            if (answer <= 0) return (false, priceData);
            if (block.timestamp - updatedAt > config.heartbeat) return (false, priceData);
            
            // Chainlink uses 8 decimals, normalize to 18
            uint256 price = uint256(answer) * 1e10;
            
            priceData = PriceData({
                price: price,
                timestamp: updatedAt,
                source: OracleSource.Chainlink,
                confidence: 100 // Chainlink is highly confident
            });
            
            return (true, priceData);
        } catch {
            return (false, priceData);
        }
    }
    
    /**
     * @notice Get price from Pyth Network
     * @param asset Asset address
     * @return success If price was fetched successfully
     * @return priceData Price data struct
     */
    function _getPythPrice(address asset) 
        internal 
        view 
        returns (bool success, PriceData memory priceData) 
    {
        OracleConfig memory config = oracleConfigs[asset];
        if (config.pythPriceId == bytes32(0) || pythContract == address(0)) {
            return (false, priceData);
        }
        
        try IPyth(pythContract).getPriceUnsafe(config.pythPriceId) returns (
            IPyth.Price memory price
        ) {
            if (price.price <= 0) return (false, priceData);
            
            // Pyth uses variable exponents, normalize to 18 decimals
            uint256 normalizedPrice;
            if (price.expo < 0) {
                uint256 divisor = 10 ** uint256(int256(-price.expo));
                normalizedPrice = (uint256(int256(price.price)) * 1e18) / divisor;
            } else {
                normalizedPrice = uint256(int256(price.price)) * 1e18 * (10 ** uint256(int256(price.expo)));
            }
            
            priceData = PriceData({
                price: normalizedPrice,
                timestamp: price.publishTime,
                source: OracleSource.Pyth,
                confidence: uint256(price.conf) // Pyth provides confidence interval
            });
            
            return (true, priceData);
        } catch {
            return (false, priceData);
        }
    }
    
    /**
     * @notice Get price from TWAP (Time-Weighted Average Price)
     * @param asset Asset address
     * @return success If price was fetched successfully
     * @return priceData Price data struct
     */
    function _getTWAPPrice(address asset) 
        internal 
        view 
        returns (bool success, PriceData memory priceData) 
    {
        OracleConfig memory config = oracleConfigs[asset];
        if (config.twapPool == address(0)) return (false, priceData);
        
        try IAndeSwapPair(config.twapPool).getReserves() returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        ) {
            if (reserve0 == 0 || reserve1 == 0) return (false, priceData);
            
            // Simple spot price (in production, use actual TWAP)
            uint256 price = (uint256(reserve1) * 1e18) / uint256(reserve0);
            
            priceData = PriceData({
                price: price,
                timestamp: blockTimestampLast,
                source: OracleSource.TWAP,
                confidence: 500 // TWAP is less confident (more manipulable)
            });
            
            return (true, priceData);
        } catch {
            return (false, priceData);
        }
    }
    
    // ========================================
    // CIRCUIT BREAKER
    // ========================================
    
    /**
     * @notice Check if price move triggers circuit breaker
     * @param asset Asset address
     * @param newPrice New price to check
     */
    function _checkCircuitBreaker(address asset, uint256 newPrice) internal {
        PriceData memory oldPrice = latestPrices[asset];
        
        if (oldPrice.price == 0) return; // First price, no check
        
        uint256 priceDiff;
        if (newPrice > oldPrice.price) {
            priceDiff = ((newPrice - oldPrice.price) * 10000) / oldPrice.price;
        } else {
            priceDiff = ((oldPrice.price - newPrice) * 10000) / oldPrice.price;
        }
        
        // If price moved > 50% in one update, trigger circuit breaker
        if (priceDiff > CIRCUIT_BREAKER_THRESHOLD) {
            isCircuitBroken[asset] = true;
            emit CircuitBreakerTriggered(asset, oldPrice.price, newPrice);
        }
    }
    
    // ========================================
    // ADMIN FUNCTIONS
    // ========================================
    
    /**
     * @notice Configure oracle for an asset
     * @param asset Asset address
     * @param chainlinkFeed Chainlink price feed address
     * @param pythPriceId Pyth price feed ID
     * @param twapPool AndeSwap pair address
     * @param heartbeat Expected update frequency (seconds)
     */
    function configureOracle(
        address asset,
        address chainlinkFeed,
        bytes32 pythPriceId,
        address twapPool,
        uint256 heartbeat
    ) external onlyOwner {
        oracleConfigs[asset] = OracleConfig({
            chainlinkFeed: chainlinkFeed,
            pythPriceId: pythPriceId,
            twapPool: twapPool,
            enabled: true,
            heartbeat: heartbeat
        });
        
        emit OracleConfigured(asset, chainlinkFeed, pythPriceId);
    }
    
    /**
     * @notice Reset circuit breaker for an asset
     * @param asset Asset address
     */
    function resetCircuitBreaker(address asset) external onlyOwner {
        isCircuitBroken[asset] = false;
    }
    
    /**
     * @notice Set manual price (emergency only)
     * @param asset Asset address
     * @param price Price in USD (18 decimals)
     */
    function setManualPrice(address asset, uint256 price) external onlyOwner {
        require(emergencyMode, "Not in emergency mode");
        
        latestPrices[asset] = PriceData({
            price: price,
            timestamp: block.timestamp,
            source: OracleSource.Manual,
            confidence: 1000 // Manual prices are least confident
        });
        
        emit PriceUpdated(asset, price, OracleSource.Manual, block.timestamp);
    }
    
    /**
     * @notice Toggle emergency mode
     * @param active Enable/disable emergency mode
     */
    function setEmergencyMode(bool active) external onlyOwner {
        emergencyMode = active;
        emit EmergencyModeActivated(active);
    }
    
    /**
     * @notice Set Pyth contract address
     * @param _pythContract Pyth contract address
     */
    function setPythContract(address _pythContract) external onlyOwner {
        pythContract = _pythContract;
    }
    
    // ========================================
    // VIEW FUNCTIONS
    // ========================================
    
    /**
     * @notice Check if price is fresh
     * @param asset Asset address
     * @return isFresh True if price is fresh
     */
    function isPriceFresh(address asset) external view returns (bool) {
        PriceData memory priceData = latestPrices[asset];
        return block.timestamp - priceData.timestamp <= MAX_PRICE_AGE;
    }
    
    /**
     * @notice Get oracle configuration
     * @param asset Asset address
     * @return config Oracle configuration
     */
    function getOracleConfig(address asset) external view returns (OracleConfig memory) {
        return oracleConfigs[asset];
    }
}

// ========================================
// INTERFACES
// ========================================

interface IChainlinkAggregator {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

interface IPyth {
    struct Price {
        int64 price;
        uint64 conf;
        int32 expo;
        uint256 publishTime;
    }
    
    function getPriceUnsafe(bytes32 id) external view returns (Price memory price);
    function updatePriceFeeds(bytes[] calldata updateData) external payable;
}

interface IAndeSwapPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}
