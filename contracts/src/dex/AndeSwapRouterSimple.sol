// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./AndeSwapLibrary.sol";
import "./AndeSwapFactorySimple.sol";
import "./AndeSwapPairSimple.sol";

/**
 * @title AndeSwapRouterSimple
 * @dev Simplified router for AndeSwap operations
 * @notice This router handles swaps and liquidity operations
 * @author AndeChain Team
 */
contract AndeSwapRouterSimple is ReentrancyGuard, Ownable {
    using AndeSwapLibrary for address;
    
    // Factory address
    address public immutable factory;
    
    // WETH address (for ETH handling)
    address public immutable WETH;
    
    // Events
    event LiquidityAdded(
        address indexed tokenA,
        address indexed tokenB,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    
    event LiquidityRemoved(
        address indexed tokenA,
        address indexed tokenB,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    
    event Swap(
        address indexed tokenIn,
        address indexed tokenOut,
        address indexed recipient,
        uint256 amountIn,
        uint256 amountOut
    );

    /**
     * @dev Constructor
     * @param _factory The factory address
     * @param _WETH The WETH address
     */
    constructor(address _factory, address _WETH) Ownable(msg.sender) {
        factory = _factory;
        WETH = _WETH;
    }

    /**
     * @dev Adds liquidity to a pair
     * @param tokenA The first token address
     * @param tokenB The second token address
     * @param amountADesired The desired amount of tokenA
     * @param amountBDesired The desired amount of tokenB
     * @param amountAMin The minimum amount of tokenA
     * @param amountBMin The minimum amount of tokenB
     * @param to The recipient address
     * @param deadline The deadline for the transaction
     * @return amountA The amount of tokenA added
     * @return amountB The amount of tokenB added
     * @return liquidity The amount of liquidity tokens received
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
    ) external nonReentrant returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(deadline >= block.timestamp, "AndeSwapRouter: EXPIRED");
        
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        
        address pair = AndeSwapFactorySimple(factory).getPair(tokenA, tokenB);
        
        // Transfer tokens to pair
        _safeTransferFrom(tokenA, msg.sender, pair, amountA);
        _safeTransferFrom(tokenB, msg.sender, pair, amountB);
        
        liquidity = AndeSwapPairSimple(pair).mint(to);
        
        emit LiquidityAdded(tokenA, tokenB, to, amountA, amountB, liquidity);
    }

    /**
     * @dev Adds liquidity with ETH
     * @param token The token address
     * @param amountTokenDesired The desired amount of token
     * @param amountTokenMin The minimum amount of token
     * @param amountETHMin The minimum amount of ETH
     * @param to The recipient address
     * @param deadline The deadline for the transaction
     * @return amountToken The amount of token added
     * @return amountETH The amount of ETH added
     * @return liquidity The amount of liquidity tokens received
     */
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable nonReentrant returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        require(deadline >= block.timestamp, "AndeSwapRouter: EXPIRED");
        
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        
        address pair = AndeSwapFactorySimple(factory).getPair(token, WETH);
        
        // Transfer token to pair
        _safeTransferFrom(token, msg.sender, pair, amountToken);
        
        // Wrap ETH and transfer to pair
        IWETH(WETH).deposit{value: amountETH}();
        _safeTransfer(WETH, pair, amountETH);
        
        liquidity = AndeSwapPairSimple(pair).mint(to);
        
        // Refund unused ETH
        if (msg.value > amountETH) {
            _safeTransferETH(msg.sender, msg.value - amountETH);
        }
        
        emit LiquidityAdded(token, WETH, to, amountToken, amountETH, liquidity);
    }

    /**
     * @dev Removes liquidity from a pair
     * @param tokenA The first token address
     * @param tokenB The second token address
     * @param liquidity The amount of liquidity to remove
     * @param amountAMin The minimum amount of tokenA to receive
     * @param amountBMin The minimum amount of tokenB to receive
     * @param to The recipient address
     * @param deadline The deadline for the transaction
     * @return amountA The amount of tokenA received
     * @return amountB The amount of tokenB received
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public nonReentrant returns (uint256 amountA, uint256 amountB) {
        require(deadline >= block.timestamp, "AndeSwapRouter: EXPIRED");
        
        address pair = AndeSwapFactorySimple(factory).getPair(tokenA, tokenB);
        
        // Transfer LP tokens to pair
        _safeTransferFrom(pair, msg.sender, pair, liquidity);
        
        (amountA, amountB) = AndeSwapPairSimple(pair).burn(to);
        
        require(amountA >= amountAMin, "AndeSwapRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "AndeSwapRouter: INSUFFICIENT_B_AMOUNT");
        
        emit LiquidityRemoved(tokenA, tokenB, to, amountA, amountB, liquidity);
    }

    /**
     * @dev Removes liquidity and receives ETH
     * @param token The token address
     * @param liquidity The amount of liquidity to remove
     * @param amountTokenMin The minimum amount of token to receive
     * @param amountETHMin The minimum amount of ETH to receive
     * @param to The recipient address
     * @param deadline The deadline for the transaction
     * @return amountToken The amount of token received
     * @return amountETH The amount of ETH received
     */
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountToken, uint256 amountETH) {
        require(deadline >= block.timestamp, "AndeSwapRouter: EXPIRED");
        
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        
        // Unwrap WETH to ETH
        IWETH(WETH).withdraw(amountETH);
        _safeTransferETH(to, amountETH);
        _safeTransfer(token, to, amountToken);
    }

    /**
     * @dev Swaps exact tokens for tokens
     * @param amountIn The exact amount of input tokens
     * @param amountOutMin The minimum amount of output tokens
     * @param path The swap path
     * @param to The recipient address
     * @param deadline The deadline for the transaction
     * @return amounts Array of input and output amounts
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external nonReentrant returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "AndeSwapRouter: EXPIRED");
        require(path.length >= 2, "AndeSwapRouter: INVALID_PATH");
        
        amounts = AndeSwapLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "AndeSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        
        _safeTransferFrom(
            path[0],
            msg.sender,
            AndeSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        
        _swap(amounts, path, to);
        
        emit Swap(path[0], path[path.length - 1], to, amountIn, amounts[amounts.length - 1]);
    }

    /**
     * @dev Swaps tokens for exact tokens
     * @param amountOut The exact amount of output tokens
     * @param amountInMax The maximum amount of input tokens
     * @param path The swap path
     * @param to The recipient address
     * @param deadline The deadline for the transaction
     * @return amounts Array of input and output amounts
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external nonReentrant returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "AndeSwapRouter: EXPIRED");
        require(path.length >= 2, "AndeSwapRouter: INVALID_PATH");
        
        amounts = AndeSwapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "AndeSwapRouter: EXCESSIVE_INPUT_AMOUNT");
        
        _safeTransferFrom(
            path[0],
            msg.sender,
            AndeSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        
        _swap(amounts, path, to);
        
        emit Swap(path[0], path[path.length - 1], to, amounts[0], amountOut);
    }

    /**
     * @dev Swaps exact ETH for tokens
     * @param amountOutMin The minimum amount of output tokens
     * @param path The swap path (must start with WETH)
     * @param to The recipient address
     * @param deadline The deadline for the transaction
     * @return amounts Array of input and output amounts
     */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable nonReentrant returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "AndeSwapRouter: EXPIRED");
        require(path.length >= 2, "AndeSwapRouter: INVALID_PATH");
        require(path[0] == WETH, "AndeSwapRouter: INVALID_PATH");
        
        amounts = AndeSwapLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "AndeSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        
        IWETH(WETH).deposit{value: amounts[0]}();
        _safeTransfer(WETH, AndeSwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        
        _swap(amounts, path, to);
        
        emit Swap(WETH, path[path.length - 1], to, msg.value, amounts[amounts.length - 1]);
    }

    /**
     * @dev Swaps tokens for exact ETH
     * @param amountOut The exact amount of ETH to receive
     * @param amountInMax The maximum amount of input tokens
     * @param path The swap path (must end with WETH)
     * @param to The recipient address
     * @param deadline The deadline for the transaction
     * @return amounts Array of input and output amounts
     */
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external nonReentrant returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "AndeSwapRouter: EXPIRED");
        require(path.length >= 2, "AndeSwapRouter: INVALID_PATH");
        require(path[path.length - 1] == WETH, "AndeSwapRouter: INVALID_PATH");
        
        amounts = AndeSwapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "AndeSwapRouter: EXCESSIVE_INPUT_AMOUNT");
        
        _safeTransferFrom(
            path[0],
            msg.sender,
            AndeSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        
        _swap(amounts, path, address(this));
        
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        _safeTransferETH(to, amounts[amounts.length - 1]);
        
        emit Swap(path[0], WETH, to, amounts[0], amountOut);
    }

    /**
     * @dev Swaps exact tokens for ETH
     * @param amountIn The exact amount of input tokens
     * @param amountOutMin The minimum amount of ETH to receive
     * @param path The swap path (must end with WETH)
     * @param to The recipient address
     * @param deadline The deadline for the transaction
     * @return amounts Array of input and output amounts
     */
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external nonReentrant returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "AndeSwapRouter: EXPIRED");
        require(path.length >= 2, "AndeSwapRouter: INVALID_PATH");
        require(path[path.length - 1] == WETH, "AndeSwapRouter: INVALID_PATH");
        
        amounts = AndeSwapLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "AndeSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        
        _safeTransferFrom(
            path[0],
            msg.sender,
            AndeSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        
        _swap(amounts, path, address(this));
        
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        _safeTransferETH(to, amounts[amounts.length - 1]);
        
        emit Swap(path[0], WETH, to, amountIn, amounts[amounts.length - 1]);
    }

    /**
     * @dev Quotes an amount out
     * @param amountA The input amount
     * @param reserveA The input reserve
     * @param reserveB The output reserve
     * @return amountB The output amount
     */
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB) {
        return AndeSwapLibrary.quote(amountA, reserveA, reserveB);
    }

    /**
     * @dev Gets amount out for a given amount in
     * @param amountIn The input amount
     * @param reserveIn The input reserve
     * @param reserveOut The output reserve
     * @return amountOut The output amount
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut) {
        return AndeSwapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /**
     * @dev Gets amount in for a given amount out
     * @param amountOut The output amount
     * @param reserveIn The input reserve
     * @param reserveOut The output reserve
     * @return amountIn The input amount
     */
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn) {
        return AndeSwapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    /**
     * @dev Gets amounts out for a swap path
     * @param amountIn The input amount
     * @param path The swap path
     * @return amounts Array of amounts for each step
     */
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts) {
        return AndeSwapLibrary.getAmountsOut(factory, amountIn, path);
    }

    /**
     * @dev Gets amounts in for a swap path
     * @param amountOut The output amount
     * @param path The swap path
     * @return amounts Array of amounts for each step
     */
    function getAmountsIn(uint256 amountOut, address[] calldata path) external view returns (uint256[] memory amounts) {
        return AndeSwapLibrary.getAmountsIn(factory, amountOut, path);
    }

    // Internal functions

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (AndeSwapFactorySimple(factory).getPair(tokenA, tokenB) == address(0)) {
            AndeSwapFactorySimple(factory).createPair(tokenA, tokenB);
        }
        
        (uint256 reserveA, uint256 reserveB) = AndeSwapLibrary.getReserves(factory, tokenA, tokenB);
        
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = AndeSwapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "AndeSwapRouter: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = AndeSwapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "AndeSwapRouter: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = AndeSwapLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2 ? AndeSwapLibrary.pairFor(factory, output, path[i + 2]) : _to;
            AndeSwapPairSimple(AndeSwapLibrary.pairFor(factory, input, output)).swap(
                amount0Out,
                amount1Out,
                to,
                new bytes(0)
            );
        }
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "AndeSwapRouter: TRANSFER_FAILED");
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "AndeSwapRouter: TRANSFER_FAILED");
    }

    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "AndeSwapRouter: ETH_TRANSFER_FAILED");
    }
}

/**
 * @title IWETH
 * @dev Interface for WETH
 */
interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function withdraw(uint256) external;
}