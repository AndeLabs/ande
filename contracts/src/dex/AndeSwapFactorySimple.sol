// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AndeSwapPairSimple.sol";
import "./AndeSwapLibrary.sol";

/**
 * @title AndeSwapFactorySimple
 * @dev Simplified factory for creating AndeSwap pairs
 * @notice This factory creates and manages AMM pairs
 * @author AndeChain Team
 */
contract AndeSwapFactorySimple is Ownable {
    using AndeSwapLibrary for address;
    
    // Mapping to store pairs
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    
    // Fee configuration
    address public feeTo;
    address public feeToSetter;
    
    // Pair template
    address public pairTemplate;
    
    // Events
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);
    event FeeToUpdated(address indexed newFeeTo);
    event FeeToSetterUpdated(address indexed newFeeToSetter);
    event PairTemplateUpdated(address indexed newTemplate);

    /**
     * @dev Constructor
     * @param _feeToSetter The address that can set the fee recipient
     */
    constructor(address _feeToSetter) Ownable(msg.sender) {
        feeToSetter = _feeToSetter;
        pairTemplate = address(new AndeSwapPairSimple());
    }

    /**
     * @dev Returns the number of pairs created
     * @return uint256 The number of pairs
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /**
     * @dev Creates a new pair
     * @param tokenA The first token address
     * @param tokenB The second token address
     * @return pair The address of the created pair
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "AndeSwapFactory: IDENTICAL_ADDRESSES");
        require(tokenA != address(0) && tokenB != address(0), "AndeSwapFactory: ZERO_ADDRESS");
        require(getPair[tokenA][tokenB] == address(0), "AndeSwapFactory: PAIR_EXISTS");
        
        (address token0, address token1) = AndeSwapLibrary.sortTokens(tokenA, tokenB);
        
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        
        // Create new pair using CREATE2
        pair = address(new AndeSwapPairSimple{salt: salt}());
        
        AndeSwapPairSimple(pair).initialize(token0, token1);
        
        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair;
        allPairs.push(pair);
        
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @dev Sets the fee recipient
     * @param _feeTo The new fee recipient address
     */
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "AndeSwapFactory: FORBIDDEN");
        feeTo = _feeTo;
        emit FeeToUpdated(_feeTo);
    }

    /**
     * @dev Sets the fee setter
     * @param _feeToSetter The new fee setter address
     */
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "AndeSwapFactory: FORBIDDEN");
        feeToSetter = _feeToSetter;
        emit FeeToSetterUpdated(_feeToSetter);
    }

    /**
     * @dev Sets the pair template
     * @param _pairTemplate The new pair template address
     */
    function setPairTemplate(address _pairTemplate) external onlyOwner {
        require(_pairTemplate != address(0), "AndeSwapFactory: ZERO_ADDRESS");
        pairTemplate = _pairTemplate;
        emit PairTemplateUpdated(_pairTemplate);
    }

    /**
     * @dev Returns pair information
     * @param tokenA The first token address
     * @param tokenB The second token address
     * @return pair The pair address
     * @return token0 The sorted token0 address
     * @return token1 The sorted token1 address
     * @return exists Whether the pair exists
     */
    function getPairInfo(address tokenA, address tokenB) external view returns (
        address pair,
        address token0,
        address token1,
        bool exists
    ) {
        (token0, token1) = AndeSwapLibrary.sortTokens(tokenA, tokenB);
        pair = getPair[tokenA][tokenB];
        exists = pair != address(0);
    }

    /**
     * @dev Returns all pairs
     * @return pairs Array of all pair addresses
     */
    function getAllPairs() external view returns (address[] memory pairs) {
        pairs = new address[](allPairs.length);
        for (uint256 i = 0; i < allPairs.length; i++) {
            pairs[i] = allPairs[i];
        }
    }

    /**
     * @dev Returns pairs for a specific token
     * @param token The token address
     * @return pairs Array of pair addresses containing the token
     */
    function getPairsForToken(address token) external view returns (address[] memory pairs) {
        uint256 count = 0;
        
        // First count the pairs
        for (uint256 i = 0; i < allPairs.length; i++) {
            AndeSwapPairSimple pair = AndeSwapPairSimple(allPairs[i]);
            if (pair.token0() == token || pair.token1() == token) {
                count++;
            }
        }
        
        // Then create the array
        pairs = new address[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allPairs.length; i++) {
            AndeSwapPairSimple pair = AndeSwapPairSimple(allPairs[i]);
            if (pair.token0() == token || pair.token1() == token) {
                pairs[index] = allPairs[i];
                index++;
            }
        }
    }

    /**
     * @dev Returns factory information
     * @return _feeTo The fee recipient
     * @return _feeToSetter The fee setter
     * @return _pairTemplate The pair template
     * @return _allPairsLength The number of pairs
     */
    function getFactoryInfo() external view returns (
        address _feeTo,
        address _feeToSetter,
        address _pairTemplate,
        uint256 _allPairsLength
    ) {
        return (
            feeTo,
            feeToSetter,
            pairTemplate,
            allPairs.length
        );
    }

    /**
     * @dev Checks if a pair exists
     * @param tokenA The first token address
     * @param tokenB The second token address
     * @return exists Whether the pair exists
     */
    function pairExists(address tokenA, address tokenB) external view returns (bool exists) {
        return getPair[tokenA][tokenB] != address(0);
    }

    /**
     * @dev Returns the pair address without creating it
     * @param tokenA The first token address
     * @param tokenB The second token address
     * @return pair The calculated pair address
     */
    function calculatePairAddress(address tokenA, address tokenB) external view returns (address pair) {
        (address token0, address token1) = AndeSwapLibrary.sortTokens(tokenA, tokenB);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        
        // Calculate CREATE2 address
        bytes32 bytecodeHash = keccak256(type(AndeSwapPairSimple).creationCode);
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            bytecodeHash
        )))));
    }

    /**
     * @dev Batch creates multiple pairs
     * @param tokenAs Array of first token addresses
     * @param tokenBs Array of second token addresses
     * @return pairs Array of created pair addresses
     */
    function batchCreatePairs(
        address[] calldata tokenAs,
        address[] calldata tokenBs
    ) external returns (address[] memory pairs) {
        require(tokenAs.length == tokenBs.length, "AndeSwapFactory: ARRAY_LENGTH_MISMATCH");
        require(tokenAs.length > 0, "AndeSwapFactory: EMPTY_ARRAYS");
        
        pairs = new address[](tokenAs.length);
        
        for (uint256 i = 0; i < tokenAs.length; i++) {
            pairs[i] = createPair(tokenAs[i], tokenBs[i]);
        }
    }

    /**
     * @dev Returns statistics about the factory
     * @return totalPairs Total number of pairs
     * @return totalLiquidity Total liquidity across all pairs (simplified)
     * @return totalVolume Total volume across all pairs (simplified)
     */
    function getFactoryStats() external view returns (
        uint256 totalPairs,
        uint256 totalLiquidity,
        uint256 totalVolume
    ) {
        totalPairs = allPairs.length;
        totalLiquidity = 0;
        totalVolume = 0;
        
        // This is a simplified version - in practice, you'd track these values
        for (uint256 i = 0; i < allPairs.length; i++) {
            AndeSwapPairSimple pair = AndeSwapPairSimple(allPairs[i]);
            (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
            totalLiquidity += reserve0 + reserve1;
        }
    }

    /**
     * @dev Emergency function to update pair template
     * @param _pairTemplate The new pair template
     */
    function emergencyUpdatePairTemplate(address _pairTemplate) external onlyOwner {
        require(_pairTemplate != address(0), "AndeSwapFactory: ZERO_ADDRESS");
        pairTemplate = _pairTemplate;
        emit PairTemplateUpdated(_pairTemplate);
    }

    /**
     * @dev Returns the version of the factory
     * @return string The version string
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    /**
     * @dev Checks if an address is a valid pair
     * @param pair The address to check
     * @return isValid Whether the address is a valid pair
     */
    function isValidPair(address pair) external view returns (bool isValid) {
        if (pair == address(0)) return false;
        
        // Check if it's a contract
        uint256 size;
        assembly {
            size := extcodesize(pair)
        }
        if (size == 0) return false;
        
        // Check if it's one of our pairs
        for (uint256 i = 0; i < allPairs.length; i++) {
            if (allPairs[i] == pair) return true;
        }
        
        return false;
    }

    /**
     * @dev Returns the top pairs by liquidity
     * @param count The number of pairs to return
     * @return pairs Array of top pair addresses
     * @return liquidities Array of corresponding liquidities
     */
    function getTopPairsByLiquidity(uint256 count) external view returns (
        address[] memory pairs,
        uint256[] memory liquidities
    ) {
        if (count == 0 || allPairs.length == 0) {
            pairs = new address[](0);
            liquidities = new uint256[](0);
            return;
        }
        
        uint256 returnCount = count > allPairs.length ? allPairs.length : count;
        pairs = new address[](returnCount);
        liquidities = new uint256[](returnCount);
        
        // Create a simple array of all pairs and their liquidities
        address[] memory allPairsArray = new address[](allPairs.length);
        uint256[] memory allLiquidities = new uint256[](allPairs.length);
        
        for (uint256 i = 0; i < allPairs.length; i++) {
            allPairsArray[i] = allPairs[i];
            AndeSwapPairSimple pair = AndeSwapPairSimple(allPairs[i]);
            (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
            allLiquidities[i] = reserve0 + reserve1;
        }
        
        // Simple selection sort (not gas efficient, but works for view functions)
        for (uint256 i = 0; i < returnCount; i++) {
            uint256 maxIndex = i;
            for (uint256 j = i + 1; j < allPairs.length; j++) {
                if (allLiquidities[j] > allLiquidities[maxIndex]) {
                    maxIndex = j;
                }
            }
            
            // Swap
            if (maxIndex != i) {
                (allPairsArray[i], allPairsArray[maxIndex]) = (allPairsArray[maxIndex], allPairsArray[i]);
                (allLiquidities[i], allLiquidities[maxIndex]) = (allLiquidities[maxIndex], allLiquidities[i]);
            }
            
            pairs[i] = allPairsArray[i];
            liquidities[i] = allLiquidities[i];
        }
    }
}