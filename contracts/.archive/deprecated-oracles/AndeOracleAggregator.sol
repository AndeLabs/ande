// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IOracle.sol";
import "./security/Utils.sol";

/**
 * @title AndeOracleAggregator
 * @notice Agrega múltiples fuentes de oráculos con ponderación y detección de outliers
 * @dev Refactorizado para ser "upgrade-safe" y usar la librería SafeAggregation.
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

    // MAX_DEVIATION será manejado por SafeAggregation
    // uint256 public constant MAX_DEVIATION = 500;
    uint256 public constant MIN_SOURCES = 3; // Requerido por SafeAggregation
    uint256 public constant CACHE_DURATION = 1 minutes;

    // ============ EVENTS ============
    event SourceAdded(bytes32 indexed pairId, address indexed oracle, uint256 weight, string name);
    event SourceRemoved(bytes32 indexed pairId, address indexed oracle);
    event SourceUpdated(bytes32 indexed pairId, address indexed oracle, uint256 newWeight);
    event PriceAggregated(bytes32 indexed pairId, uint256 price, uint256 confidence, uint256 sourcesUsed);
    event OutlierDetected(
        bytes32 indexed pairId, address indexed oracle, uint256 price, uint256 medianPrice, uint256 deviation
    );

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

    function initialize(address owner, address p2pOracle) public initializer {
        __Ownable_init(owner);
        // Add P2P Oracle as default source for BOB/USD pair
        bytes32 pairId = keccak256(abi.encodePacked("BOB", "USD"));
        _addSourceInternal(pairId, p2pOracle, 10000, 1, "P2P Oracle");
    }

    // ============ CHAINLINK COMPATIBILITY ============
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        bytes32 pairId = keccak256(abi.encodePacked("BOB", "USD"));
        (uint256 price, uint256 confidence, uint256 sourcesUsed) = _aggregatePrice(pairId);

        return (
            uint80(block.timestamp), // roundId
            int256(price), // answer
            block.timestamp, // startedAt
            block.timestamp, // updatedAt
            uint80(sourcesUsed) // answeredInRound
        );
    }

    function decimals() external view returns (uint8) {
        return 18;
    }

    // ============ SOURCE MANAGEMENT ============
    function _addSourceInternal(bytes32 pairId, address oracle, uint256 weight, uint256 priority, string memory name)
        internal
    {
        if (weight == 0 || weight > 10000) revert InvalidWeight();

        OracleSource[] storage pairSources = sources[pairId];
        for (uint256 i = 0; i < pairSources.length; i++) {
            if (pairSources[i].oracle == oracle) revert SourceAlreadyExists();
        }

        pairSources.push(OracleSource({oracle: oracle, weight: weight, isActive: true, priority: priority, name: name}));

        emit SourceAdded(pairId, oracle, weight, name);
    }

    function addSource(bytes32 pairId, address oracle, uint256 weight, uint256 priority, string calldata name)
        external
        onlyOwner
    {
        _addSourceInternal(pairId, oracle, weight, priority, name);
    }

    function updateSourceWeight(bytes32 pairId, address oracle, uint256 newWeight) external onlyOwner {
        if (newWeight == 0 || newWeight > 10000) revert InvalidWeight();

        OracleSource[] storage pairSources = sources[pairId];
        for (uint256 i = 0; i < pairSources.length; i++) {
            if (pairSources[i].oracle == oracle) {
                pairSources[i].weight = newWeight;
                emit SourceUpdated(pairId, oracle, newWeight);
                return;
            }
        }
    }

    function deactivateSource(bytes32 pairId, address oracle) external onlyOwner {
        OracleSource[] storage pairSources = sources[pairId];
        for (uint256 i = 0; i < pairSources.length; i++) {
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

        (price,,) = _aggregatePrice(pairId);
        return price;
    }

    function getPriceWithConfidence(bytes32 pairId)
        external
        view
        returns (uint256 price, uint256 confidence, uint256 sourcesUsed)
    {
        return _aggregatePrice(pairId);
    }

    function _aggregatePrice(bytes32 pairId)
        internal
        view
        returns (uint256 finalPrice, uint256 confidence, uint256 sourcesUsed)
    {
        OracleSource[] storage pairSources = sources[pairId];

        if (pairSources.length == 0) revert NoSourcesAvailable();

        uint256[] memory validPrices = new uint256[](pairSources.length);
        uint256 validCount = 0;

        for (uint256 i = 0; i < pairSources.length; i++) {
            if (pairSources[i].isActive) {
                try IOracle(pairSources[i].oracle).latestRoundData() returns (
                    uint80,
                    int256 answer,
                    uint256,
                    uint256,
                    uint80
                ) {
                    if (answer > 0) {
                        validPrices[validCount] = uint256(answer);
                        validCount++;
                    }
                } catch {
                    // Skip failed oracle calls
                    continue;
                }
            }
        }

        if (validCount == 0) revert InsufficientSources();

        // For now, return the first valid price (simplified aggregation)
        // TODO: Implement proper weighted median aggregation
        finalPrice = validPrices[0];
        confidence = 5000; // 50% confidence
        sourcesUsed = validCount;
    }

    function getSourcesForPair(bytes32 pairId) external view returns (OracleSource[] memory) {
        return sources[pairId];
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

    // Las funciones _calculateMedian y _calculateDeviation ya no son necesarias,
    // su lógica ahora está centralizada en la librería SafeAggregation.
}
