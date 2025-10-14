// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AndeSwapLibrary
 * @dev Library for AndeSwap AMM calculations and utilities
 * @notice Provides mathematical functions for AMM operations
 * @author AndeChain Team
 */
library AndeSwapLibrary {
    // Error declarations
    error InsufficientLiquidity();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error InsufficientOutputAmount();
    error InsufficientInputAmount();
    error InvalidK();
    error Overflow();
    error ZeroAddress();

    /**
     * @dev Calculates the output amount for a given input amount and reserves
     * @param amountIn The input amount
     * @param reserveIn The input reserve
     * @param reserveOut The output reserve
     * @return amountOut The calculated output amount
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientInputAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        
        amountOut = numerator / denominator;
    }

    /**
     * @dev Calculates the required input amount for a desired output amount
     * @param amountOut The desired output amount
     * @param reserveIn The input reserve
     * @param reserveOut The output reserve
     * @return amountIn The required input amount
     */
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        if (amountOut == 0) revert InsufficientOutputAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        
        amountIn = (numerator / denominator) + 1;
    }

    /**
     * @dev Calculates the optimal amount of tokens to add for liquidity
     * @param amountA The amount of token A
     * @param reserveA The reserve of token A
     * @param reserveB The reserve of token B
     * @return amountB The optimal amount of token B
     */
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        if (amountA == 0) revert InsufficientInputAmount();
        if (reserveA == 0 || reserveB == 0) revert InsufficientLiquidity();
        
        amountB = (amountA * reserveB) / reserveA;
    }

    /**
     * @dev Sorts two token addresses
     * @param tokenA The first token address
     * @param tokenB The second token address
     * @return token0 The sorted token0 address
     * @return token1 The sorted token1 address
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert ZeroAddress();
        
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
    }

    /**
     * @dev Calculates the pair address for two tokens using CREATE2
     * @param factory The factory address
     * @param tokenA The first token address
     * @param tokenB The second token address
     * @return pair The calculated pair address
     */
    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        
        // This is a simplified version - in production, you'd use the actual CREATE2 formula
        // For now, we'll use a deterministic approach
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
            hex'ff',
            factory,
            keccak256(abi.encodePacked(token0, token1)),
            hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
        )))));
    }

    /**
     * @dev Fetches reserves for a pair
     * @param factory The factory address
     * @param tokenA The first token address
     * @param tokenB The second token address
     * @return reserveA The reserve of tokenA
     * @return reserveB The reserve of tokenB
     */
    function getReserves(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB);
        
        // In a real implementation, you'd call the pair contract
        // For now, we'll return dummy values
        (reserveA, reserveB) = tokenA == token0 ? (0, 0) : (0, 0);
    }

    /**
     * @dev Calculates liquidity amount to mint
     * @param amountA The amount of tokenA
     * @param reserveA The reserve of tokenA
     * @param reserveB The reserve of tokenB
     * @param totalSupply The total supply of LP tokens
     * @return liquidity The amount of liquidity to mint
     */
    function getLiquidityMinted(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB,
        uint256 totalSupply
    ) internal pure returns (uint256 liquidity) {
        if (totalSupply == 0) {
            liquidity = sqrt(amountA * amountB) - 1000;
        } else {
            liquidity = min(
                (amountA * totalSupply) / reserveA,
                (amountB * totalSupply) / reserveB
            );
        }
        
        if (liquidity == 0) revert InsufficientLiquidityMinted();
    }

    /**
     * @dev Calculates liquidity amount to burn
     * @param amountA The amount of tokenA to receive
     * @param amountB The amount of tokenB to receive
     * @param reserveA The reserve of tokenA
     * @param reserveB The reserve of tokenB
     * @param totalSupply The total supply of LP tokens
     * @param liquidity The amount of liquidity to burn
     * @return amountAOut The amount of tokenA to receive
     * @return amountBOut The amount of tokenB to receive
     */
    function getLiquidityBurned(
        uint256 amountA,
        uint256 amountB,
        uint256 reserveA,
        uint256 reserveB,
        uint256 totalSupply,
        uint256 liquidity
    ) internal pure returns (uint256 amountAOut, uint256 amountBOut) {
        amountAOut = (amountA * liquidity) / totalSupply;
        amountBOut = (amountB * liquidity) / totalSupply;
        
        if (amountAOut == 0 || amountBOut == 0) revert InsufficientLiquidityBurned();
    }

    /**
     * @dev Calculates the minimum amount out for a swap
     * @param amountIn The input amount
     * @param reserveIn The input reserve
     * @param reserveOut The output reserve
     * @param slippageTolerance The slippage tolerance in basis points
     * @return amountOutMin The minimum output amount
     */
    function getAmountOutMin(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 slippageTolerance
    ) internal pure returns (uint256 amountOutMin) {
        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        amountOutMin = (amountOut * (10000 - slippageTolerance)) / 10000;
    }

    /**
     * @dev Calculates the maximum amount in for a swap
     * @param amountOut The desired output amount
     * @param reserveIn The input reserve
     * @param reserveOut The output reserve
     * @param slippageTolerance The slippage tolerance in basis points
     * @return amountInMax The maximum input amount
     */
    function getAmountInMax(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 slippageTolerance
    ) internal pure returns (uint256 amountInMax) {
        uint256 amountIn = getAmountIn(amountOut, reserveIn, reserveOut);
        amountInMax = (amountIn * (10000 + slippageTolerance)) / 10000;
    }

    /**
     * @dev Calculates the optimal amount of tokens to add for balanced liquidity
     * @param amountADesired The desired amount of tokenA
     * @param amountBDesired The desired amount of tokenB
     * @param reserveA The reserve of tokenA
     * @param reserveB The reserve of tokenB
     * @return amountA The optimal amount of tokenA
     * @return amountB The optimal amount of tokenB
     */
    function getOptimalLiquidity(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountA, uint256 amountB) {
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = quote(amountADesired, reserveA, reserveB);
            
            if (amountBOptimal <= amountBDesired) {
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = quote(amountBDesired, reserveB, reserveA);
                (amountA, amountB) = (amountAOptimal <= amountADesired) ? (amountAOptimal, amountBDesired) : (amountADesired, amountBDesired);
            }
        }
    }

    /**
     * @dev Calculates price impact of a swap
     * @param amountIn The input amount
     * @param reserveIn The input reserve
     * @param reserveOut The output reserve
     * @return priceImpact The price impact in basis points
     */
    function getPriceImpact(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 priceImpact) {
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        
        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        uint256 spotPrice = (reserveOut * 1e18) / reserveIn;
        uint256 executionPrice = (amountOut * 1e18) / amountIn;
        
        if (executionPrice > spotPrice) {
            priceImpact = ((executionPrice - spotPrice) * 10000) / spotPrice;
        } else {
            priceImpact = ((spotPrice - executionPrice) * 10000) / spotPrice;
        }
    }

    /**
     * @dev Calculates the effective APR for liquidity providers
     * @param feesCollected The total fees collected
     * @param liquidity The total liquidity
     * @param period The period in seconds
     * @return apr The effective APR in basis points
     */
    function getEffectiveAPR(
        uint256 feesCollected,
        uint256 liquidity,
        uint256 period
    ) internal pure returns (uint256 apr) {
        if (liquidity == 0 || period == 0) return 0;
        
        uint256 yearlyFees = (feesCollected * 31536000) / period; // 365 days in seconds
        apr = (yearlyFees * 10000) / liquidity;
    }

    /**
     * @dev Returns the minimum of two values
     * @param a The first value
     * @param b The second value
     * @return The minimum value
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the maximum of two values
     * @param a The first value
     * @param b The second value
     * @return The maximum value
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Calculates the square root of a value
     * @param y The value to calculate the square root of
     * @return z The square root
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /**
     * @dev Checks if K is valid (for AMM invariant)
     * @param reserveA The reserve of tokenA
     * @param reserveB The reserve of tokenB
     * @return valid Whether K is valid
     */
    function isKValid(uint256 reserveA, uint256 reserveB) internal pure returns (bool valid) {
        if (reserveA == 0 || reserveB == 0) return false;
        
        uint256 k = reserveA * reserveB;
        return k > 0;
    }

    /**
     * @dev Calculates the K value (AMM invariant)
     * @param reserveA The reserve of tokenA
     * @param reserveB The reserve of tokenB
     * @return k The K value
     */
    function getK(uint256 reserveA, uint256 reserveB) internal pure returns (uint256 k) {
        k = reserveA * reserveB;
    }

    /**
     * @dev Validates that reserves are properly set
     * @param reserveA The reserve of tokenA
     * @param reserveB The reserve of tokenB
     */
    function validateReserves(uint256 reserveA, uint256 reserveB) internal pure {
        if (reserveA == 0 || reserveB == 0) revert InsufficientLiquidity();
    }

    /**
     * @dev Calculates the optimal swap amount for arbitrage
     * @param reserve1A The reserve of tokenA in pool1
     * @param reserve1B The reserve of tokenB in pool1
     * @param reserve2A The reserve of tokenA in pool2
     * @param reserve2B The reserve of tokenB in pool2
     * @return amount The optimal swap amount
     */
    function getOptimalArbitrageAmount(
        uint256 reserve1A,
        uint256 reserve1B,
        uint256 reserve2A,
        uint256 reserve2B
    ) internal pure returns (uint256 amount) {
        // This is a simplified calculation for arbitrage
        // In practice, you'd need more sophisticated calculations
        uint256 price1 = (reserve1B * 1e18) / reserve1A;
        uint256 price2 = (reserve2B * 1e18) / reserve2A;
        
        if (price1 > price2) {
            // Arbitrage opportunity exists
            amount = sqrt((reserve1A * reserve2B * 997) / (reserve1B * 1000)) - reserve1A;
        }
    }

    /**
     * @dev Calculates the impermanent loss for liquidity providers
     * @param priceInitial The initial price
     * @param priceCurrent The current price
     * @return impermanentLoss The impermanent loss in basis points
     */
    function getImpermanentLoss(
        uint256 priceInitial,
        uint256 priceCurrent
    ) internal pure returns (uint256 impermanentLoss) {
        if (priceInitial == 0) return 0;
        
        uint256 priceRatio = (priceCurrent * 10000) / priceInitial;
        uint256 sqrtRatio = sqrt(priceRatio * 10000);
        
        uint256 currentValue = 2 * sqrtRatio;
        uint256 hodlValue = 10000 + priceRatio;
        
        if (currentValue < hodlValue) {
            impermanentLoss = ((hodlValue - currentValue) * 10000) / hodlValue;
        }
    }

    /**
     * @dev Calculates the liquidity depth score
     * @param reserveA The reserve of tokenA
     * @param reserveB The reserve of tokenB
     * @param volumeA The volume of tokenA
     * @param volumeB The volume of tokenB
     * @return score The liquidity depth score
     */
    function getLiquidityDepthScore(
        uint256 reserveA,
        uint256 reserveB,
        uint256 volumeA,
        uint256 volumeB
    ) internal pure returns (uint256 score) {
        if (reserveA == 0 || reserveB == 0) return 0;
        
        uint256 totalReserve = reserveA + reserveB;
        uint256 totalVolume = volumeA + volumeB;
        
        // Score is based on volume/reserve ratio
        score = (totalVolume * 10000) / totalReserve;
    }

    /**
     * @dev Safely adds two uint256 values
     * @param a The first value
     * @param b The second value
     * @return result The sum
     */
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256 result) {
        unchecked {
            uint256 c = a + b;
            if (c < a) revert Overflow();
            result = c;
        }
    }

    /**
     * @dev Safely subtracts two uint256 values
     * @param a The first value
     * @param b The second value
     * @return result The difference
     */
    function safeSub(uint256 a, uint256 b) internal pure returns (uint256 result) {
        if (b > a) revert InsufficientLiquidity();
        result = a - b;
    }

    /**
     * @dev Safely multiplies two uint256 values
     * @param a The first value
     * @param b The second value
     * @return result The product
     */
    function safeMul(uint256 a, uint256 b) internal pure returns (uint256 result) {
        unchecked {
            if (a == 0) return 0;
            uint256 c = a * b;
            if (c / a != b) revert Overflow();
            result = c;
        }
    }

    /**
     * @dev Safely divides two uint256 values
     * @param a The numerator
     * @param b The denominator
     * @return result The quotient
     */
    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256 result) {
        if (b == 0) revert InvalidK();
        result = a / b;
    }
}