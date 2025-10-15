// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IAndeSwapFactory
 * @notice Interface for AndeSwap DEX factory
 * @dev Creates and manages trading pairs
 */
interface IAndeSwapFactory {
    
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
    // FUNCTIONS
    // ========================================
    
    /**
     * @notice Get pair address for two tokens
     * @param tokenA First token
     * @param tokenB Second token
     * @return pair Pair address (address(0) if doesn't exist)
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    
    /**
     * @notice Get all pairs
     * @param index Index in array
     * @return pair Pair address
     */
    function allPairs(uint256 index) external view returns (address pair);
    
    /**
     * @notice Get total number of pairs
     * @return Total pairs created
     */
    function allPairsLength() external view returns (uint256);
    
    /**
     * @notice Create new trading pair
     * @param tokenA First token
     * @param tokenB Second token
     * @return pair Created pair address
     */
    function createPair(address tokenA, address tokenB) external returns (address pair);
    
    /**
     * @notice Predict pair address before creation
     * @param tokenA First token
     * @param tokenB Second token
     * @return pair Predicted address
     */
    function pairFor(address tokenA, address tokenB) external view returns (address pair);
    
    /**
     * @notice Get fee recipient
     * @return Fee recipient address
     */
    function feeTo() external view returns (address);
    
    /**
     * @notice Get fee setter
     * @return Fee setter address
     */
    function feeToSetter() external view returns (address);
    
    /**
     * @notice Set fee recipient
     * @param _feeTo New fee recipient
     */
    function setFeeTo(address _feeTo) external;
    
    /**
     * @notice Set fee setter
     * @param _feeToSetter New fee setter
     */
    function setFeeToSetter(address _feeToSetter) external;
}
