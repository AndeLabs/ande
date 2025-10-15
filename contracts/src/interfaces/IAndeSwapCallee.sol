// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IAndeSwapCallee
 * @notice Interface for flash swap callback
 * @dev Implement this to receive flash swap callbacks
 */
interface IAndeSwapCallee {
    
    /**
     * @notice Callback for flash swaps
     * @param sender Address that initiated swap
     * @param amount0 Amount of token0 sent
     * @param amount1 Amount of token1 sent
     * @param data Arbitrary data passed from swap call
     */
    function andeSwapCall(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}
