// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./AndeSwapPair.sol";

/**
 * @title AndeSwapFactory
 * @notice Factory contract for creating AndeSwap pairs
 * @dev Uses CREATE2 for deterministic pair addresses
 * 
 * Architecture Decisions:
 * 1. CREATE2 deployment enables address prediction
 * 2. Fee recipient controlled by governance
 * 3. Single pair per token combination
 * 4. Pair creation permissionless
 * 5. Integration with ANDE governance
 */
contract AndeSwapFactory {
    
    // ========================================
    // STATE VARIABLES
    // ========================================
    
    /// @notice Address that receives protocol fees
    address public feeTo;
    
    /// @notice Address that can change feeTo
    address public feeToSetter;
    
    /// @notice Mapping of token pairs to pair addresses
    mapping(address => mapping(address => address)) public getPair;
    
    /// @notice Array of all created pairs
    address[] public allPairs;

    // ========================================
    // EVENTS
    // ========================================
    
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256 pairIndex
    );
    
    event FeeToSet(address indexed oldFeeTo, address indexed newFeeTo);
    event FeeToSetterSet(address indexed oldSetter, address indexed newSetter);

    // ========================================
    // ERRORS
    // ========================================
    
    error IdenticalAddresses();
    error ZeroAddress();
    error PairExists();
    error Unauthorized();

    // ========================================
    // CONSTRUCTOR
    // ========================================
    
    /**
     * @notice Initialize factory with fee setter
     * @param _feeToSetter Address that can change fee recipient
     */
    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    // ========================================
    // CORE FUNCTIONS
    // ========================================
    
    /**
     * @notice Create a new pair for two tokens
     * @dev Uses CREATE2 for deterministic address
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return pair Address of created pair
     * 
     * Security:
     * - Sorts tokens to ensure single pair per combination
     * - Reverts if pair already exists
     * - CREATE2 salt based on sorted token addresses
     */
    function createPair(address tokenA, address tokenB) 
        external 
        returns (address pair) 
    {
        if (tokenA == tokenB) revert IdenticalAddresses();
        
        // Sort tokens
        (address token0, address token1) = tokenA < tokenB 
            ? (tokenA, tokenB) 
            : (tokenB, tokenA);
        
        if (token0 == address(0)) revert ZeroAddress();
        if (getPair[token0][token1] != address(0)) revert PairExists();
        
        // Create pair using CREATE2
        bytes memory bytecode = type(AndeSwapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        // Initialize pair
        AndeSwapPair(pair).initialize(token0, token1);
        
        // Store pair in mappings
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // Bidirectional mapping
        allPairs.push(pair);
        
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    // ========================================
    // VIEW FUNCTIONS
    // ========================================
    
    /**
     * @notice Get total number of pairs created
     * @return Total number of pairs
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /**
     * @notice Predict pair address before creation
     * @dev Uses same CREATE2 salt as createPair
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return pair Predicted pair address
     */
    function pairFor(address tokenA, address tokenB) 
        external 
        view 
        returns (address pair) 
    {
        (address token0, address token1) = tokenA < tokenB 
            ? (tokenA, tokenB) 
            : (tokenB, tokenA);
        
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(type(AndeSwapPair).creationCode)
        )))));
    }

    // ========================================
    // ADMIN FUNCTIONS
    // ========================================
    
    /**
     * @notice Set fee recipient address
     * @dev Only callable by feeToSetter
     * @param _feeTo New fee recipient address
     */
    function setFeeTo(address _feeTo) external {
        if (msg.sender != feeToSetter) revert Unauthorized();
        
        emit FeeToSet(feeTo, _feeTo);
        feeTo = _feeTo;
    }

    /**
     * @notice Set fee setter address
     * @dev Only callable by current feeToSetter
     * @param _feeToSetter New fee setter address
     */
    function setFeeToSetter(address _feeToSetter) external {
        if (msg.sender != feeToSetter) revert Unauthorized();
        
        emit FeeToSetterSet(feeToSetter, _feeToSetter);
        feeToSetter = _feeToSetter;
    }
}
