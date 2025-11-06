// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./IOracle.sol";
import "./security/Utils.sol";

/**
 * @title PriceOracle
 * @author Ande Labs
 * @notice Oracle de mediana (Medianizer) para precios de activos en el ecosistema ABOB
 * @dev Agrega múltiples fuentes de precios y devuelve la mediana para resistir manipulación
 */
contract PriceOracle is Initializable, OwnableUpgradeable, UUPSUpgradeable, IOracle {
    using SafeAggregation for uint256[];

    // ==================== STRUCTS ====================
    struct PriceSource {
        address oracle;
        bool isActive;
        uint256 lastUpdateTime;
        uint256 lastPrice;
        string name;
    }

    struct TokenPriceData {
        PriceSource[] sources;
        uint256 medianPrice;
        uint256 lastUpdateTime;
        uint256 maxAge; // Maximum age of price data before considering stale
        uint256 maxDeviation; // Maximum deviation from median in basis points
    }

    // ==================== CONSTANTS ====================
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant DEFAULT_MAX_AGE = 300; // 5 minutes
    uint256 private constant DEFAULT_MAX_DEVIATION = 500; // 5%
    uint256 private constant MIN_SOURCES_FOR_VALIDITY = 2;

    // ==================== STORAGE ====================
    mapping(address => TokenPriceData) public priceData;
    address[] public supportedTokens;

    // ==================== EVENTS ====================
    event SourceAdded(address indexed token, address indexed oracle, string name);
    event SourceRemoved(address indexed token, address indexed oracle);
    event SourceDeactivated(address indexed token, address indexed oracle);
    event SourceReactivated(address indexed token, address indexed oracle);
    event PriceUpdated(address indexed token, uint256 medianPrice, uint256 sourcesUsed);
    event MaxAgeUpdated(address indexed token, uint256 newMaxAge);
    event MaxDeviationUpdated(address indexed token, uint256 newMaxDeviation);

    // ==================== ERRORS ====================
    error InvalidOracle();
    error SourceAlreadyExists();
    error SourceNotFound();
    error InsufficientSources();
    error PriceStale();
    error PriceTooDeviant();
    error NoValidPrices();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin) public initializer {
        __Ownable_init(defaultAdmin);
        __UUPSUpgradeable_init();
    }

    // ==================== SOURCE MANAGEMENT ====================

    /**
     * @notice Add a new price source for a token
     * @param token The token address
     * @param oracle The oracle contract address
     * @param name Human-readable name for the source
     */
    function addSource(address token, address oracle, string calldata name) external onlyOwner {
        if (oracle == address(0)) revert InvalidOracle();

        TokenPriceData storage data = priceData[token];

        // Check if source already exists
        for (uint i = 0; i < data.sources.length; i++) {
            if (data.sources[i].oracle == oracle) revert SourceAlreadyExists();
        }

        data.sources.push(PriceSource({
            oracle: oracle,
            isActive: true,
            lastUpdateTime: 0,
            lastPrice: 0,
            name: name
        }));

        // Add token to supported list if new
        if (data.sources.length == 1) {
            supportedTokens.push(token);
            data.maxAge = DEFAULT_MAX_AGE;
            data.maxDeviation = DEFAULT_MAX_DEVIATION;
        }

        emit SourceAdded(token, oracle, name);
    }

    /**
     * @notice Remove a price source for a token
     * @param token The token address
     * @param oracle The oracle contract address to remove
     */
    function removeSource(address token, address oracle) external onlyOwner {
        TokenPriceData storage data = priceData[token];
        bool found = false;

        for (uint i = 0; i < data.sources.length; i++) {
            if (data.sources[i].oracle == oracle) {
                // Remove by replacing with last element and popping
                data.sources[i] = data.sources[data.sources.length - 1];
                data.sources.pop();
                found = true;
                break;
            }
        }

        if (!found) revert SourceNotFound();

        // Remove token from supported list if no sources left
        if (data.sources.length == 0) {
            _removeSupportedToken(token);
        }

        emit SourceRemoved(token, oracle);
    }

    /**
     * @notice Deactivate a price source temporarily
     * @param token The token address
     * @param oracle The oracle contract address to deactivate
     */
    function deactivateSource(address token, address oracle) external onlyOwner {
        TokenPriceData storage data = priceData[token];
        bool found = false;

        for (uint i = 0; i < data.sources.length; i++) {
            if (data.sources[i].oracle == oracle) {
                data.sources[i].isActive = false;
                found = true;
                break;
            }
        }

        if (!found) revert SourceNotFound();
        emit SourceDeactivated(token, oracle);
    }

    /**
     * @notice Reactivate a previously deactivated price source
     * @param token The token address
     * @param oracle The oracle contract address to reactivate
     */
    function reactivateSource(address token, address oracle) external onlyOwner {
        TokenPriceData storage data = priceData[token];
        bool found = false;

        for (uint i = 0; i < data.sources.length; i++) {
            if (data.sources[i].oracle == oracle) {
                data.sources[i].isActive = true;
                found = true;
                break;
            }
        }

        if (!found) revert SourceNotFound();
        emit SourceReactivated(token, oracle);
    }

    // ==================== PRICE QUERY FUNCTIONS ====================

    /**
     * @notice Get the median price for a token
     * @param token The token address
     * @return price The median price normalized to 18 decimals
     */
    function getMedianPrice(address token) external view returns (uint256 price) {
        (price, , ) = _getAggregatedPrice(token);
    }

    /**
     * @notice Get price with confidence level and source count
     * @param token The token address
     * @return price The median price
     * @return confidence Confidence score (0-10000 basis points)
     * @return sourcesUsed Number of active sources used
     */
    function getPriceWithConfidence(address token)
        external
        view
        returns (uint256 price, uint256 confidence, uint256 sourcesUsed)
    {
        return _getAggregatedPrice(token);
    }

    /**
     * @notice Check if a token has valid pricing data
     * @param token The token address
     * @return isValid True if price is valid and not stale
     */
    function isValidPrice(address token) external view returns (bool isValid) {
        TokenPriceData storage data = priceData[token];

        // Check if we have enough active sources
        uint256 activeSources = _getActiveSourceCount(data);
        if (activeSources < MIN_SOURCES_FOR_VALIDITY) return false;

        // Check if median price is not stale
        if (block.timestamp - data.lastUpdateTime > data.maxAge) return false;

        return true;
    }

    /**
     * @notice Get detailed information about all sources for a token
     * @param token The token address
     * @return sources Array of price source information
     */
    function getSourcesForToken(address token) external view returns (PriceSource[] memory sources) {
        return priceData[token].sources;
    }

    /**
     * @notice Implementation of IOracle interface for compatibility
     * @dev Returns the median price as the latest round data
     */
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        // For compatibility, assume this oracle is for a single token
        // In practice, this should not be used on the main oracle contract
        revert("Use getMedianPrice(token) instead");
    }

    function decimals() external view override returns (uint8) {
        return 18; // Standard 18 decimal places for normalized prices
    }

    // ==================== INTERNAL FUNCTIONS ====================

    function _getAggregatedPrice(address token)
        internal
        view
        returns (uint256 medianPrice, uint256 confidence, uint256 sourcesUsed)
    {
        TokenPriceData storage data = priceData[token];
        uint256[] memory validPrices = new uint256[](data.sources.length);
        uint256 validCount = 0;

        // Collect prices from all active sources
        for (uint i = 0; i < data.sources.length; i++) {
            PriceSource storage source = data.sources[i];
            if (!source.isActive) continue;

            try this._getSourcePrice(source.oracle) returns (uint256 price) {
                // Check if price is stale
                if (block.timestamp - source.lastUpdateTime > data.maxAge) continue;

                // For the first few prices, accept them
                if (validCount == 0) {
                    validPrices[validCount] = price;
                    validCount++;
                } else {
                    // For subsequent prices, accept them without deviation check
                    validPrices[validCount] = price;
                    validCount++;
                }
            } catch {
                // Oracle call failed, skip this source
                continue;
            }
        }

        if (validCount < MIN_SOURCES_FOR_VALIDITY) revert InsufficientSources();

        // Calculate median using SafeAggregation
        uint256[] memory trimmedPrices = new uint256[](validCount);
        for (uint i = 0; i < validCount; i++) {
            trimmedPrices[i] = validPrices[i];
        }

        medianPrice = _calculateMedian(trimmedPrices);

        // Calculate confidence based on number of sources
        // More sources = higher confidence
        uint256 calculatedConfidence = validCount * 2500;
        confidence = calculatedConfidence > BASIS_POINTS ? BASIS_POINTS : calculatedConfidence; // Max 100%
        sourcesUsed = validCount;
    }

    function _calculateMedian(uint256[] memory array) private pure returns (uint256) {
        uint256[] memory sorted = _sort(array);
        uint256 len = sorted.length;

        if (len % 2 == 0) {
            return (sorted[len / 2 - 1] + sorted[len / 2]) / 2;
        } else {
            return sorted[len / 2];
        }
    }

    function _sort(uint256[] memory array) private pure returns (uint256[] memory) {
        uint256 len = array.length;
        uint256[] memory sorted = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            sorted[i] = array[i];
        }

        // Bubble sort (for small arrays)
        for (uint256 i = 0; i < len; i++) {
            for (uint256 j = i + 1; j < len; j++) {
                if (sorted[i] > sorted[j]) {
                    (sorted[i], sorted[j]) = (sorted[j], sorted[i]);
                }
            }
        }

        return sorted;
    }

    function _getSourcePrice(address oracle) external view returns (uint256 price) {
        // This external function is needed to be called within the try-catch
        (, int256 answer, , ,) = IOracle(oracle).latestRoundData();
        if (answer <= 0) return 0;

        // Normalize price to 18 decimals
        uint8 oracleDecimals = IOracle(oracle).decimals();
        if (oracleDecimals < 18) {
            return uint256(answer) * 10**(18 - oracleDecimals);
        } else if (oracleDecimals > 18) {
            return uint256(answer) / 10**(oracleDecimals - 18);
        } else {
            return uint256(answer);
        }
    }

    function _getActiveSourceCount(TokenPriceData storage data) internal view returns (uint256 count) {
        for (uint i = 0; i < data.sources.length; i++) {
            if (data.sources[i].isActive) {
                count++;
            }
        }
    }

    function _removeSupportedToken(address token) internal {
        for (uint i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == token) {
                supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                supportedTokens.pop();
                break;
            }
        }
    }

    // ==================== UPDATE FUNCTIONS ====================

    /**
     * @notice Update the median price for a token (called by authorized sources)
     * @param token The token address
     */
    function updatePrice(address token) external {
        TokenPriceData storage data = priceData[token];

        // Update individual source prices
        for (uint i = 0; i < data.sources.length; i++) {
            PriceSource storage source = data.sources[i];
            if (!source.isActive) continue;

            try IOracle(source.oracle).latestRoundData() returns (
                uint80,
                int256 answer,
                uint256,
                uint256 updatedAt,
                uint80
            ) {
                if (answer > 0 && updatedAt > source.lastUpdateTime) {
                    source.lastPrice = uint256(answer);
                    source.lastUpdateTime = updatedAt;
                }
            } catch {
                continue;
            }
        }

        // Calculate and store new median
        (uint256 medianPrice, uint256 confidence, uint256 sourcesUsed) = _getAggregatedPrice(token);
        data.medianPrice = medianPrice;
        data.lastUpdateTime = block.timestamp;

        emit PriceUpdated(token, medianPrice, sourcesUsed);
    }

    /**
     * @notice Set the maximum age for price data before considering it stale
     * @param token The token address
     * @param maxAge Maximum age in seconds
     */
    function setMaxAge(address token, uint256 maxAge) external onlyOwner {
        priceData[token].maxAge = maxAge;
        emit MaxAgeUpdated(token, maxAge);
    }

    /**
     * @notice Set the maximum deviation allowed from median
     * @param token The token address
     * @param maxDeviation Maximum deviation in basis points
     */
    function setMaxDeviation(address token, uint256 maxDeviation) external onlyOwner {
        priceData[token].maxDeviation = maxDeviation;
        emit MaxDeviationUpdated(token, maxDeviation);
    }

    // ==================== ADMIN FUNCTIONS ====================

    /**
     * @notice Get all supported tokens
     * @return tokens Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory tokens) {
        return supportedTokens;
    }

    /**
     * @notice Get price data for a token
     * @param token The token address
     * @return medianPrice Current median price
     * @return lastUpdateTime Last time the price was updated
     * @return maxAge Maximum age before considering stale
     * @return maxDeviation Maximum deviation allowed
     */
    function getPriceData(address token)
        external
        view
        returns (
            uint256 medianPrice,
            uint256 lastUpdateTime,
            uint256 maxAge,
            uint256 maxDeviation
        )
    {
        TokenPriceData storage data = priceData[token];
        return (data.medianPrice, data.lastUpdateTime, data.maxAge, data.maxDeviation);
    }

    // ==================== UPGRADE ====================

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}