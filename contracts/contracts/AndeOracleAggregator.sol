// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IOracle.sol";

/**
 * @title AndeOracleAggregator
 * @notice Agrega múltiples fuentes de oráculos con ponderación y detección de outliers
 * @dev Refactorizado para ser "upgrade-safe" usando un inicializador.
 */
contract AndeOracleAggregator is Initializable, OwnableUpgradeable {
    
    // ============ STRUCTURES ============    
    struct OracleSource {
        address oracle;
        uint256 weight;
        bool isActive;
        uint256 priority;
        string name;
    }
    
    struct AggregatedPrice {
        uint256 price;
        uint256 confidence;
        uint256 timestamp;
        uint256 sourcesUsed;
    }
    
    // ============ STORAGE ============    
    mapping(bytes32 => OracleSource[]) public sources;
    mapping(bytes32 => AggregatedPrice) private priceCache;
    
    uint256 public constant MAX_DEVIATION = 500;
    uint256 public constant MIN_SOURCES = 1;
    uint256 public constant CACHE_DURATION = 1 minutes;
    
    // ============ EVENTS ============    
    event SourceAdded(bytes32 indexed pairId, address indexed oracle, uint256 weight, string name);
    event SourceRemoved(bytes32 indexed pairId, address indexed oracle);
    event SourceUpdated(bytes32 indexed pairId, address indexed oracle, uint256 newWeight);
    event PriceAggregated(bytes32 indexed pairId, uint256 price, uint256 confidence, uint256 sourcesUsed);
    event OutlierDetected(bytes32 indexed pairId, address indexed oracle, uint256 price, uint256 medianPrice, uint256 deviation);
    
    // ============ ERRORS ============    
    error NoSourcesAvailable();
    error InvalidWeight();
    error SourceAlreadyExists();
    error InsufficientSources();
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }
    
    // ============ SOURCE MANAGEMENT ============    
    function addSource(
        bytes32 pairId,
        address oracle,
        uint256 weight,
        uint256 priority,
        string calldata name
    ) external onlyOwner {
        if (weight == 0 || weight > 10000) revert InvalidWeight();
        
        OracleSource[] storage pairSources = sources[pairId];
        for (uint i = 0; i < pairSources.length; i++) {
            if (pairSources[i].oracle == oracle) revert SourceAlreadyExists();
        }
        
        pairSources.push(OracleSource({
            oracle: oracle,
            weight: weight,
            isActive: true,
            priority: priority,
            name: name
        }));
        
        emit SourceAdded(pairId, oracle, weight, name);
    }
    
    function updateSourceWeight(
        bytes32 pairId,
        address oracle,
        uint256 newWeight
    ) external onlyOwner {
        if (newWeight == 0 || newWeight > 10000) revert InvalidWeight();
        
        OracleSource[] storage pairSources = sources[pairId];
        for (uint i = 0; i < pairSources.length; i++) {
            if (pairSources[i].oracle == oracle) {
                pairSources[i].weight = newWeight;
                emit SourceUpdated(pairId, oracle, newWeight);
                return;
            }
        }
    }
    
    function deactivateSource(bytes32 pairId, address oracle) external onlyOwner {
        OracleSource[] storage pairSources = sources[pairId];
        for (uint i = 0; i < pairSources.length; i++) {
            if (pairSources[i].oracle == oracle) {
                pairSources[i].isActive = false;
                emit SourceRemoved(pairId, oracle);
                return;
            }
        }
    }
    
    // ============ PRICE AGGREGATION ============    
    function getPrice(bytes32 pairId) external view returns (uint256 price) {
        AggregatedPrice memory cached = priceCache[pairId];
        if (block.timestamp - cached.timestamp < CACHE_DURATION) {
            return cached.price;
        }
        
        (price, , ) = _aggregatePrice(pairId);
        return price;
    }
    
    function getPriceWithConfidence(bytes32 pairId) 
        external 
        view 
        returns (
            uint256 price,
            uint256 confidence,
            uint256 sourcesUsed
        ) 
    {
        return _aggregatePrice(pairId);
    }
    
    function _aggregatePrice(bytes32 pairId) 
        internal 
        view 
        returns (
            uint256 finalPrice,
            uint256 confidence,
            uint256 sourcesUsed
        ) 
    {
        OracleSource[] storage pairSources = sources[pairId];
        
        if (pairSources.length == 0) revert NoSourcesAvailable();
        
        uint256[] memory prices = new uint256[](pairSources.length);
        uint256[] memory weights = new uint256[](pairSources.length);
        uint256 validCount = 0;
        uint256 totalWeight = 0;
        
        for (uint i = 0; i < pairSources.length; i++) {
            if (!pairSources[i].isActive) continue;
            
            try IOracle(pairSources[i].oracle).getPrice(pairId) returns (uint256 price) {
                if (price > 0) {
                    prices[validCount] = price;
                    weights[validCount] = pairSources[i].weight;
                    totalWeight += pairSources[i].weight;
                    validCount++;
                }
            } catch {
                continue;
            }
        }
        
        if (validCount == 0) revert InsufficientSources();
        
        uint256 medianPrice = _calculateMedian(prices, validCount);
        
        uint256 weightedSum = 0;
        uint256 validWeight = 0;
        uint256 finalSourceCount = 0;
        
        for (uint i = 0; i < validCount; i++) {
            uint256 deviation = _calculateDeviation(medianPrice, prices[i]);
            
            if (deviation > MAX_DEVIATION) {
                continue;
            }
            
            weightedSum += prices[i] * weights[i];
            validWeight += weights[i];
            finalSourceCount++;
        }
        
        if (validWeight == 0) {
            return (medianPrice, 5000, validCount);
        }
        
        finalPrice = weightedSum / validWeight;
        confidence = (validWeight * 10000) / totalWeight;
        sourcesUsed = finalSourceCount;
        
        return (finalPrice, confidence, sourcesUsed);
    }
    
    function updateCache(bytes32 pairId) external {
        (uint256 price, uint256 confidence, uint256 sourcesUsed) = _aggregatePrice(pairId);
        
        priceCache[pairId] = AggregatedPrice({
            price: price,
            confidence: confidence,
            timestamp: block.timestamp,
            sourcesUsed: sourcesUsed
        });
        
        emit PriceAggregated(pairId, price, confidence, sourcesUsed);
    }
    
    // ============ UTILITIES ============    
    function _calculateMedian(uint256[] memory data, uint256 length) 
        internal 
        pure 
        returns (uint256) 
    {
        if (length == 0) return 0;
        if (length == 1) return data[0];
        
        for (uint i = 0; i < length - 1; i++) {
            for (uint j = 0; j < length - i - 1; j++) {
                if (data[j] > data[j + 1]) {
                    uint256 temp = data[j];
                    data[j] = data[j + 1];
                    data[j + 1] = temp;
                }
            }
        }
        
        if (length % 2 == 0) {
            return (data[length / 2 - 1] + data[length / 2]) / 2;
        } else {
            return data[length / 2];
        }
    }

    function _calculateDeviation(uint256 oldPrice, uint256 newPrice) 
        internal 
        pure 
        returns (uint256 deviation) 
    {
        if (oldPrice == 0) return 0;
        
        uint256 diff = newPrice > oldPrice 
            ? newPrice - oldPrice 
            : oldPrice - newPrice;
        
        return (diff * 10000) / oldPrice;
    }
}
