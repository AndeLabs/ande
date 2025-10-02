// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IOracle.sol";
import "./security/Utils.sol";

/**
 * @title TrustedRelayerOracle
 * @notice Oracle simple con relayers de confianza para bootstrap de Ande Chain
 * @dev Refactorizado para ser "upgrade-safe". Lógica de Circuit Breaker desactivada temporalmente.
 */
contract TrustedRelayerOracle is Initializable, AccessControlUpgradeable, PausableUpgradeable, IOracle, RateLimiter { // CircuitBreaker removed
    
    using PriceValidator for PriceValidator.PriceData;

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 blockNumber;
        address relayer;
        uint256 updateCount;
    }
    
    struct RelayerInfo {
        bool isActive;
        uint256 totalUpdates;
        uint256 lastUpdate;
        string endpoint;
    }
    
    mapping(bytes32 => PriceData) public prices;
    mapping(address => RelayerInfo) public relayers;
    mapping(bytes32 => mapping(address => uint256)) public relayerPrices;
    
    uint256 public constant MAX_PRICE_AGE = 5 minutes;
    uint256 public constant MIN_RELAYERS = 2;
    
    uint256 public totalRelayers;
    uint256 public totalUpdates;
    
    event PriceUpdated(bytes32 indexed pairId, uint256 price, uint256 timestamp, address indexed relayer);
    event RelayerAdded(address indexed relayer, string endpoint);
    event RelayerRemoved(address indexed relayer);
    event RelayerPaused(address indexed relayer);
    event PriceDeviation(bytes32 indexed pairId, uint256 oldPrice, uint256 newPrice, uint256 deviation);
    
    error OnlyRelayer();
    error PriceStale();
    error InvalidPrice();
    error DeviationTooHigh(uint256 deviation);
    error NotEnoughRelayers();
    error RelayerAlreadyExists();
    

    function initialize() public initializer {
        __AccessControl_init();
        __Pausable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    function addRelayer(address relayer, string calldata endpoint) external onlyRole(ADMIN_ROLE) {
        if (hasRole(RELAYER_ROLE, relayer)) revert RelayerAlreadyExists();
        _grantRole(RELAYER_ROLE, relayer);
        relayers[relayer] = RelayerInfo({
            isActive: true,
            totalUpdates: 0,
            lastUpdate: 0,
            endpoint: endpoint
        });
        totalRelayers++;
        emit RelayerAdded(relayer, endpoint);
    }
    
    function removeRelayer(address relayer) external onlyRole(ADMIN_ROLE) {
        _revokeRole(RELAYER_ROLE, relayer);
        relayers[relayer].isActive = false;
        totalRelayers--;
        emit RelayerRemoved(relayer);
    }
    
    function updatePrice(bytes32 pairId, uint256 newPrice) public onlyRole(RELAYER_ROLE) whenNotPaused rateLimit {
        PriceValidator.PriceData memory priceToValidate = PriceValidator.PriceData({
            price: newPrice,
            timestamp: block.timestamp,
            confidence: 10000
        });
        require(priceToValidate.validatePrice(), "Invalid price data");

        if (!relayers[msg.sender].isActive) revert OnlyRelayer();

        PriceData storage data = prices[pairId];

        // NOTE: Lógica de Circuit Breaker desactivada temporalmente.

        data.price = newPrice;
        data.timestamp = block.timestamp;
        data.blockNumber = block.number;
        data.relayer = msg.sender;
        data.updateCount++;
        
        relayerPrices[pairId][msg.sender] = newPrice;
        
        relayers[msg.sender].totalUpdates++;
        relayers[msg.sender].lastUpdate = block.timestamp;
        
        totalUpdates++;
        
        emit PriceUpdated(pairId, newPrice, block.timestamp, msg.sender);
    }
    
    function updatePricesBatch(
        bytes32[] calldata pairIds,
        uint256[] calldata newPrices
    ) external onlyRole(RELAYER_ROLE) whenNotPaused {
        require(pairIds.length == newPrices.length, "Length mismatch");
        for (uint256 i = 0; i < pairIds.length; i++) {
            updatePrice(pairIds[i], newPrices[i]);
        }
    }
    
    function getPrice(bytes32 pairId) external view override returns (uint256 price) {
        PriceData memory data = prices[pairId];
        if (data.price == 0) revert InvalidPrice();
        if (block.timestamp - data.timestamp > MAX_PRICE_AGE) revert PriceStale();
        return data.price;
    }
    
    function getPriceWithMetadata(bytes32 pairId) external view override returns (uint256 price, uint256 timestamp, bool isStale, address source) {
        PriceData memory data = prices[pairId];
        isStale = block.timestamp - data.timestamp > MAX_PRICE_AGE;
        return (data.price, data.timestamp, isStale, data.relayer);
    }
    
    function getAggregatedPrice(bytes32 pairId) external view returns (uint256 price, uint256 confidence) {
        PriceData memory data = prices[pairId];
        if (data.price == 0) revert InvalidPrice();
        if (block.timestamp - data.timestamp > MAX_PRICE_AGE) revert PriceStale();
        return (data.price, 10000);
    }
    
    function getPairId(string calldata base, string calldata quote) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(base, "/", quote));
    }
    
    function getSystemHealth() external view returns (bool isHealthy, uint256 activeRelayers, uint256 stalePairs) {
        activeRelayers = totalRelayers;
        isHealthy = activeRelayers >= MIN_RELAYERS && !paused();
        stalePairs = 0;
        return (isHealthy, activeRelayers, stalePairs);
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}