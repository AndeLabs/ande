// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AndeSwapFactory.sol";
import "./AndeSwapPair.sol";
import "./AndeSwapLibrary.sol";

/**
 * @title AndeSwapRouter
 * @notice Router contract for easy interaction with AndeSwap pairs
 * @dev Handles multi-hop swaps, liquidity provision, and deadline checks
 * 
 * Architecture Decisions:
 * 1. Deadline protection against long pending transactions
 * 2. Slippage protection with amountMin parameters
 * 3. Support for multi-hop swaps through path array
 * 4. Integration with ANDE Token Duality (native ETH/ANDE)
 * 5. Gas-optimized routing algorithms
 */
contract AndeSwapRouter {
    using SafeERC20 for IERC20;

    // ========================================
    // IMMUTABLES
    // ========================================
    
    /// @notice Factory contract address
    address public immutable factory;
    
    /// @notice ANDE precompile address (native dual token)
    address public constant ANDE = 0x00000000000000000000000000000000000000fd;

    // ========================================
    // ERRORS
    // ========================================
    
    error Expired();
    error InsufficientOutputAmount();
    error InsufficientAmount();
    error InsufficientLiquidity();
    error InvalidPath();
    error ExcessiveInputAmount();
    error InsufficientAAmount();
    error InsufficientBAmount();

    // ========================================
    // MODIFIERS
    // ========================================
    
    /**
     * @notice Ensure transaction executes before deadline
     * @param deadline Unix timestamp deadline
     */
    modifier ensure(uint256 deadline) {
        if (block.timestamp > deadline) revert Expired();
        _;
    }

    // ========================================
    // CONSTRUCTOR
    // ========================================
    
    /**
     * @notice Initialize router with factory address
     * @param _factory AndeSwap factory address
     * @dev ANDE is precompile at fixed address 0xFD
     */
    constructor(address _factory) {
        factory = _factory;
    }

    // ========================================
    // LIQUIDITY FUNCTIONS
    // ========================================
    
    /**
     * @notice Add liquidity to a pair
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param amountADesired Desired amount of tokenA
     * @param amountBDesired Desired amount of tokenB
     * @param amountAMin Minimum amount of tokenA (slippage protection)
     * @param amountBMin Minimum amount of tokenB (slippage protection)
     * @param to Address to receive LP tokens
     * @param deadline Transaction deadline
     * @return amountA Actual amount of tokenA added
     * @return amountB Actual amount of tokenB added
     * @return liquidity LP tokens received
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        ensure(deadline)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        
        address pair = AndeSwapFactory(factory).getPair(tokenA, tokenB);
        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amountB);
        
        liquidity = AndeSwapPair(pair).mint(to);
    }

    /**
     * @notice Remove liquidity from a pair
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param liquidity Amount of LP tokens to burn
     * @param amountAMin Minimum amount of tokenA to receive
     * @param amountBMin Minimum amount of tokenB to receive
     * @param to Address to receive tokens
     * @param deadline Transaction deadline
     * @return amountA Amount of tokenA received
     * @return amountB Amount of tokenB received
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) 
        external 
        ensure(deadline) 
        returns (uint256 amountA, uint256 amountB) 
    {
        address pair = AndeSwapFactory(factory).getPair(tokenA, tokenB);
        IERC20(pair).safeTransferFrom(msg.sender, pair, liquidity);
        
        (uint256 amount0, uint256 amount1) = AndeSwapPair(pair).burn(to);
        
        (address token0,) = _sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 
            ? (amount0, amount1) 
            : (amount1, amount0);
        
        if (amountA < amountAMin) revert InsufficientAAmount();
        if (amountB < amountBMin) revert InsufficientBAmount();
    }

    // ========================================
    // SWAP FUNCTIONS
    // ========================================
    
    /**
     * @notice Swap exact tokens for tokens
     * @dev Supports multi-hop swaps through path array
     * @param amountIn Exact amount of input tokens
     * @param amountOutMin Minimum amount of output tokens (slippage protection)
     * @param path Array of token addresses for swap route
     * @param to Address to receive output tokens
     * @param deadline Transaction deadline
     * @return amounts Array of amounts for each step in the path
     * 
     * Example path: [ANDE, ABOB, USDC] = ANDE → ABOB → USDC
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) 
        external 
        ensure(deadline) 
        returns (uint256[] memory amounts) 
    {
        amounts = _getAmountsOut(amountIn, path);
        
        if (amounts[amounts.length - 1] < amountOutMin) {
            revert InsufficientOutputAmount();
        }
        
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            AndeSwapFactory(factory).getPair(path[0], path[1]),
            amounts[0]
        );
        
        _swap(amounts, path, to);
    }

    /**
     * @notice Swap tokens for exact tokens
     * @dev Calculates required input amount for desired output
     * @param amountOut Exact amount of output tokens desired
     * @param amountInMax Maximum amount of input tokens (slippage protection)
     * @param path Array of token addresses for swap route
     * @param to Address to receive output tokens
     * @param deadline Transaction deadline
     * @return amounts Array of amounts for each step in the path
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) 
        external 
        ensure(deadline) 
        returns (uint256[] memory amounts) 
    {
        amounts = _getAmountsIn(amountOut, path);
        
        if (amounts[0] > amountInMax) revert ExcessiveInputAmount();
        
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            AndeSwapFactory(factory).getPair(path[0], path[1]),
            amounts[0]
        );
        
        _swap(amounts, path, to);
    }

    // ========================================
    // QUOTE & CALCULATION FUNCTIONS
    // ========================================
    
    /**
     * @notice Quote output amount for given input
     * @dev Uses constant product formula with 0.3% fee
     * @param amountIn Input amount
     * @param reserveIn Reserve of input token
     * @param reserveOut Reserve of output token
     * @return amountOut Output amount
     */
    function quote(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        
        amountOut = (amountIn * reserveOut) / reserveIn;
    }

    /**
     * @notice Calculate output amount for exact input with fee
     * @param amountIn Input amount
     * @param reserveIn Reserve of input token
     * @param reserveOut Reserve of output token
     * @return amountOut Output amount after 0.3% fee
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        
        amountOut = numerator / denominator;
    }

    /**
     * @notice Calculate input amount needed for exact output
     * @param amountOut Desired output amount
     * @param reserveIn Reserve of input token
     * @param reserveOut Reserve of output token
     * @return amountIn Required input amount
     */
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountIn) {
        if (amountOut == 0) revert InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        
        amountIn = (numerator / denominator) + 1;
    }

    /**
     * @notice Calculate amounts out for multi-hop swap
     * @param amountIn Input amount
     * @param path Array of token addresses
     * @return amounts Array of amounts for each hop
     */
    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        return _getAmountsOut(amountIn, path);
    }

    /**
     * @notice Calculate amounts in for multi-hop swap
     * @param amountOut Output amount
     * @param path Array of token addresses
     * @return amounts Array of amounts for each hop
     */
    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        return _getAmountsIn(amountOut, path);
    }

    // ========================================
    // INTERNAL FUNCTIONS
    // ========================================
    
    /**
     * @notice Internal function to add liquidity
     * @dev Calculates optimal amounts based on current reserves
     */
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        address pair = AndeSwapFactory(factory).getPair(tokenA, tokenB);
        
        // Create pair if doesn't exist
        if (pair == address(0)) {
            pair = AndeSwapFactory(factory).createPair(tokenA, tokenB);
        }
        
        (uint112 reserveA, uint112 reserveB,) = AndeSwapPair(pair).getReserves();
        (address token0,) = _sortTokens(tokenA, tokenB);
        
        if (tokenA != token0) {
            (reserveA, reserveB) = (reserveB, reserveA);
        }
        
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = quote(amountADesired, reserveA, reserveB);
            
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal < amountBMin) revert InsufficientBAmount();
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                
                if (amountAOptimal < amountAMin) revert InsufficientAAmount();
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    /**
     * @notice Internal swap execution through path
     */
    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address to
    ) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = _sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            
            address recipient = i < path.length - 2
                ? AndeSwapFactory(factory).getPair(output, path[i + 2])
                : to;
            
            AndeSwapPair(AndeSwapFactory(factory).getPair(input, output)).swap(
                amount0Out,
                amount1Out,
                recipient,
                new bytes(0)
            );
        }
    }

    /**
     * @notice Get amounts out for path
     */
    function _getAmountsOut(uint256 amountIn, address[] memory path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        if (path.length < 2) revert InvalidPath();
        
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        
        for (uint256 i; i < path.length - 1; i++) {
            (uint112 reserveIn, uint112 reserveOut) = _getReserves(path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @notice Get amounts in for path
     */
    function _getAmountsIn(uint256 amountOut, address[] memory path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        if (path.length < 2) revert InvalidPath();
        
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        
        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint112 reserveIn, uint112 reserveOut) = _getReserves(path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @notice Get reserves for token pair
     */
    function _getReserves(address tokenA, address tokenB)
        internal
        view
        returns (uint112 reserveA, uint112 reserveB)
    {
        (address token0,) = _sortTokens(tokenA, tokenB);
        address pair = AndeSwapFactory(factory).getPair(tokenA, tokenB);
        (uint112 reserve0, uint112 reserve1,) = AndeSwapPair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /**
     * @notice Sort two token addresses
     */
    function _sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    // ========================================
    // ANDE NATIVE FUNCTIONS
    // ========================================

    /**
     * @notice Swap exact ANDE for tokens
     * @param amountOutMin Minimum tokens to receive
     * @param path Trading path (must start with ANDE)
     * @param to Recipient address
     * @param deadline Transaction deadline
     * @return amounts Array of amounts swapped
     */
    function swapExactANDEForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        if (path[0] != ANDE) revert InvalidPath();
        
        amounts = AndeSwapLibrary.getAmountsOut(factory, msg.value, path);
        if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount();
        
        // Transfer ANDE to first pair via precompile
        IERC20(ANDE).transfer(
            AndeSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    /**
     * @notice Swap tokens for exact ANDE
     * @param amountOut Exact ANDE amount to receive
     * @param amountInMax Maximum tokens to spend
     * @param path Trading path (must end with ANDE)
     * @param to Recipient address
     * @param deadline Transaction deadline
     * @return amounts Array of amounts swapped
     */
    function swapTokensForExactANDE(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        if (path[path.length - 1] != ANDE) revert InvalidPath();
        
        amounts = AndeSwapLibrary.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > amountInMax) revert ExcessiveInputAmount();
        
        IERC20(path[0]).transferFrom(
            msg.sender,
            AndeSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        
        // Transfer ANDE to recipient
        payable(to).transfer(amounts[amounts.length - 1]);
    }

    /**
     * @notice Add liquidity with ANDE
     * @param token Token to pair with ANDE
     * @param amountTokenDesired Desired token amount
     * @param amountTokenMin Minimum token amount
     * @param amountANDEMin Minimum ANDE amount
     * @param to Recipient of LP tokens
     * @param deadline Transaction deadline
     */
    function addLiquidityANDE(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountANDEMin,
        address to,
        uint256 deadline
    )
        external
        payable
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountANDE, uint256 liquidity)
    {
        (amountToken, amountANDE) = _addLiquidity(
            token,
            ANDE,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountANDEMin
        );
        
        address pair = AndeSwapLibrary.pairFor(factory, token, ANDE);
        IERC20(token).transferFrom(msg.sender, pair, amountToken);
        IERC20(ANDE).transfer(pair, amountANDE);
        liquidity = AndeSwapPair(pair).mint(to);
        
        // Refund excess ANDE
        if (msg.value > amountANDE) {
            payable(msg.sender).transfer(msg.value - amountANDE);
        }
    }

    /**
     * @notice Remove liquidity and receive ANDE
     * @param token Token paired with ANDE
     * @param liquidity LP tokens to burn
     * @param amountTokenMin Minimum token amount
     * @param amountANDEMin Minimum ANDE amount
     * @param to Recipient address
     * @param deadline Transaction deadline
     */
    function removeLiquidityANDE(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountANDEMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountToken, uint256 amountANDE) {
        address pair = AndeSwapLibrary.pairFor(factory, token, ANDE);
        AndeSwapPair(pair).transferFrom(msg.sender, pair, liquidity);
        (uint256 amount0, uint256 amount1) = AndeSwapPair(pair).burn(address(this));
        (address token0,) = AndeSwapLibrary.sortTokens(token, ANDE);
        (amountToken, amountANDE) = token == token0 ? (amount0, amount1) : (amount1, amount0);
        
        if (amountToken < amountTokenMin) revert InsufficientAAmount();
        if (amountANDE < amountANDEMin) revert InsufficientBAmount();
        
        IERC20(token).transfer(to, amountToken);
        payable(to).transfer(amountANDE);
    }

    /**
     * @notice Receive ANDE (for native transfers)
     */
    receive() external payable {}
}
