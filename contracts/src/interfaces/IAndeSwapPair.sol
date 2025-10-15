// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IAndeSwapPair
 * @notice Interface for AndeSwap liquidity pair
 * @dev ERC20 LP token with AMM functionality
 */
interface IAndeSwapPair {
    
    // ========================================
    // EVENTS
    // ========================================
    
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    // ========================================
    // ERRORS
    // ========================================
    
    error InsufficientLiquidity();
    error InsufficientInputAmount();
    error InsufficientOutputAmount();
    error InvalidTo();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error Overflow();
    error InvalidK();

    // ========================================
    // CONSTANTS
    // ========================================
    
    function MINIMUM_LIQUIDITY() external pure returns (uint256);
    function factory() external view returns (address);

    // ========================================
    // STATE VARIABLES
    // ========================================
    
    function token0() external view returns (address);
    function token1() external view returns (address);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function kLast() external view returns (uint256);

    // ========================================
    // FUNCTIONS
    // ========================================
    
    /**
     * @notice Initialize pair with tokens
     * @param _token0 First token
     * @param _token1 Second token
     */
    function initialize(address _token0, address _token1) external;
    
    /**
     * @notice Get current reserves
     * @return reserve0 Reserve of token0
     * @return reserve1 Reserve of token1
     * @return blockTimestampLast Last update timestamp
     */
    function getReserves() external view returns (
        uint112 reserve0,
        uint112 reserve1,
        uint32 blockTimestampLast
    );
    
    /**
     * @notice Add liquidity
     * @param to LP token recipient
     * @return liquidity LP tokens minted
     */
    function mint(address to) external returns (uint256 liquidity);
    
    /**
     * @notice Remove liquidity
     * @param to Token recipient
     * @return amount0 Amount of token0 returned
     * @return amount1 Amount of token1 returned
     */
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    
    /**
     * @notice Swap tokens
     * @param amount0Out Amount of token0 to receive
     * @param amount1Out Amount of token1 to receive
     * @param to Recipient address
     * @param data Callback data for flash swaps
     */
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
    
    /**
     * @notice Force reserves to match balances
     * @param to Address to send excess tokens
     */
    function skim(address to) external;
    
    /**
     * @notice Force balances to match reserves
     */
    function sync() external;
}
