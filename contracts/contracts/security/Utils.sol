// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Production-Ready Security Enhancements
 * @notice Características críticas que DEBES agregar a tus contratos
 */

/*
// ============================================
// 1. CIRCUIT BREAKER PATTERN (Temporarily Disabled)
// ============================================
abstract contract CircuitBreaker {
    bool public circuitBreakerActive;
    uint256 public circuitBreakerThreshold = 5000; // 50% cambio máximo
    
    event CircuitBreakerTriggered(string reason);
    event CircuitBreakerReset();
    
    modifier whenNotHalted() {
        require(!circuitBreakerActive, "Circuit breaker active");
        _;
    }
    
    function _checkPriceDeviation(uint256 oldPrice, uint256 newPrice) internal {
        if (oldPrice == 0) return;
        
        uint256 deviation;
        if (newPrice > oldPrice) {
            deviation = ((newPrice - oldPrice) * 10000) / oldPrice;
        } else {
            deviation = ((oldPrice - newPrice) * 10000) / oldPrice;
        }
        
        if (deviation > circuitBreakerThreshold) {
            circuitBreakerActive = true;
            emit CircuitBreakerTriggered("Extreme price deviation");
        }
    }
    
    function resetCircuitBreaker() public virtual {
        // Solo admin puede resetear
        circuitBreakerActive = false;
        emit CircuitBreakerReset();
    }
}
*/

// ============================================
// 2. RATE LIMITING
// ============================================
abstract contract RateLimiter {
    mapping(address => uint256) public lastActionTimestamp;
    mapping(address => uint256) public actionCount;
    
    uint256 public constant MIN_DELAY = 60; // 1 minuto entre acciones
    uint256 public constant MAX_ACTIONS_PER_HOUR = 10;
    
    modifier rateLimit() {
        require(
            block.timestamp >= lastActionTimestamp[msg.sender] + MIN_DELAY,
            "Action too soon"
        );
        
        // Reset counter si pasó más de 1 hora
        if (block.timestamp > lastActionTimestamp[msg.sender] + 1 hours) {
            actionCount[msg.sender] = 0;
        }
        
        require(
            actionCount[msg.sender] < MAX_ACTIONS_PER_HOUR,
            "Rate limit exceeded"
        );
        
        lastActionTimestamp[msg.sender] = block.timestamp;
        actionCount[msg.sender]++;
        _;
    }
}

// ============================================
// 3. PRICE VALIDATION
// ============================================
library PriceValidator {
    uint256 constant MIN_PRICE = 1e6; // $0.01 en 8 decimales
    uint256 constant MAX_PRICE = 1e15; // $10,000,000 en 8 decimales
    uint256 constant MAX_AGE = 3600; // 1 hora
    
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
    }
    
    function validatePrice(PriceData memory data) internal view returns (bool) {
        // 1. Precio debe ser positivo y dentro de rangos razonables
        if (data.price == 0 || data.price < MIN_PRICE || data.price > MAX_PRICE) {
            return false;
        }
        
        // 2. Timestamp no debe ser futuro ni muy viejo
        if (data.timestamp > block.timestamp || 
            block.timestamp - data.timestamp > MAX_AGE) {
            return false;
        }
        
        // 3. Confianza mínima (ej: 70%)
        if (data.confidence < 7000) {
            return false;
        }
        
        return true;
    }
}

// ============================================
// 4. EMERGENCY PAUSE con TIMELOCK
// ============================================
abstract contract EmergencyPausable {
    bool public paused;
    uint256 public pausedUntil;
    uint256 public constant MAX_PAUSE_DURATION = 7 days;
    
    event EmergencyPause(uint256 until);
    event Unpause();
    
    modifier whenNotPaused() {
        require(!paused || block.timestamp > pausedUntil, "Contract paused");
        if (block.timestamp > pausedUntil && paused) {
            paused = false;
        }
        _;
    }
    
    function emergencyPause(uint256 duration) external {
        require(duration <= MAX_PAUSE_DURATION, "Pause too long");
        paused = true;
        pausedUntil = block.timestamp + duration;
        emit EmergencyPause(pausedUntil);
    }
    
    function unpause() external {
        paused = false;
        pausedUntil = 0;
        emit Unpause();
    }
}

// ============================================
// 5. WITHDRAWAL PATTERN (previene reentrancy)
// ============================================
abstract contract WithdrawalPattern {
    mapping(address => uint256) public pendingWithdrawals;
    
    function _addPendingWithdrawal(address user, uint256 amount) internal {
        pendingWithdrawals[user] += amount;
    }
    
    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending withdrawal");
        
        // Actualizar estado ANTES de transferir (Checks-Effects-Interactions)
        pendingWithdrawals[msg.sender] = 0;
        
        // Transferir
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
    
    // Placeholder para nonReentrant - usa OpenZeppelin ReentrancyGuard
    modifier nonReentrant() virtual;
}

// ============================================
// 6. MULTI-SIG para operaciones críticas
// ============================================
abstract contract MultiSigProtected {
    mapping(bytes32 => uint256) public approvals;
    uint256 public requiredApprovals = 2;
    
    event OperationProposed(bytes32 indexed opHash, string operation);
    event OperationApproved(bytes32 indexed opHash, address approver);
    event OperationExecuted(bytes32 indexed opHash);
    
    modifier requiresMultiSig(string memory operation) {
        bytes32 opHash = keccak256(abi.encodePacked(operation, msg.data));
        
        approvals[opHash]++;
        emit OperationApproved(opHash, msg.sender);
        
        if (approvals[opHash] >= requiredApprovals) {
            approvals[opHash] = 0; // Reset
            emit OperationExecuted(opHash);
            _;
        } else {
            emit OperationProposed(opHash, operation);
            revert("Requires more approvals");
        }
    }
}

// ============================================
// 7. SUPPLY CAP para tokens
// ============================================
abstract contract CappedSupply {
    uint256 public immutable maxSupply;
    uint256 public totalMinted;
    
    constructor(uint256 _maxSupply) {
        maxSupply = _maxSupply;
    }
    
    modifier withinSupplyCap(uint256 amount) {
        require(
            totalMinted + amount <= maxSupply,
            "Exceeds max supply"
        );
        totalMinted += amount;
        _;
    }
}

// ============================================
// 8. ORACLE AGGREGATION con validación
// ============================================
library SafeAggregation {
    struct Source {
        address oracle;
        uint256 weight;
        uint256 lastUpdate;
        bool active;
    }
    
    function aggregateWithOutlierRemoval(
        Source[] memory sources,
        uint256[] memory prices
    ) internal pure returns (uint256, uint256) {
        require(sources.length >= 3, "Need at least 3 sources");
        require(sources.length == prices.length, "Length mismatch");
        
        // 1. Calcular mediana
        uint256 median = _calculateMedian(prices);
        
        // 2. Remover outliers (>5% de desviación de mediana)
        uint256[] memory validPrices = new uint256[](prices.length);
        uint256[] memory validWeights = new uint256[](prices.length);
        uint256 validCount = 0;
        uint256 totalWeight = 0;
        
        for (uint256 i = 0; i < prices.length; i++) {
            if (!sources[i].active) continue;
            
            uint256 deviation = prices[i] > median ? 
                (prices[i] - median) * 10000 / median :
                (median - prices[i]) * 10000 / median;
            
            if (deviation <= 500) { // 5% threshold
                validPrices[validCount] = prices[i];
                validWeights[validCount] = sources[i].weight;
                totalWeight += sources[i].weight;
                validCount++;
            }
        }
        
        require(validCount >= 2, "Too many outliers");
        
        // 3. Calcular promedio ponderado
        uint256 weightedSum = 0;
        for (uint256 i = 0; i < validCount; i++) {
            weightedSum += validPrices[i] * validWeights[i];
        }
        
        return (weightedSum / totalWeight, validCount);
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
        
        // Bubble sort (para arrays pequeños está bien)
        for (uint256 i = 0; i < len; i++) {
            for (uint256 j = i + 1; j < len; j++) {
                if (sorted[i] > sorted[j]) {
                    (sorted[i], sorted[j]) = (sorted[j], sorted[i]);
                }
            }
        }
        
        return sorted;
    }
}