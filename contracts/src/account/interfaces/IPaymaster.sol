// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./IEntryPoint.sol";

/**
 * @title IPaymaster
 * @notice Interface specifically for ANDE Paymaster
 * @dev Claude can extend this interface for ANDE-specific functionality
 */
interface IPaymaster {
    /**
     * @notice Get the ANDE token address used for gas payments
     * @return andeToken Address of ANDE token contract
     */
    function getANDEToken() external view returns (address andeToken);

    /**
     * @notice Get the price oracle for ANDE/ETH conversion
     * @return oracle Address of price oracle contract
     */
    function getPriceOracle() external view returns (address oracle);

    /**
     * @notice Get the maximum gas amount this paymaster will sponsor
     * @return maxGas Maximum gas limit in wei
     */
    function getMaxGasLimit() external view returns (uint256 maxGas);

    /**
     * @notice Check if an address is whitelisted for sponsored transactions
     * @param user Address to check
     * @return isWhitelisted Whether the user is whitelisted
     */
    function isWhitelisted(address user) external view returns (bool isWhitelisted);

    /**
     * @notice Get current ANDE to ETH exchange rate
     * @return rate Exchange rate with 18 decimals
     */
    function getCurrentExchangeRate() external view returns (uint256 rate);

    /**
     * @notice Calculate gas cost in ANDE tokens
     * @param gasUsed Amount of gas used
     * @param gasPrice Gas price in wei
     * @return andeCost Cost in ANDE tokens (with 18 decimals)
     */
    function calculateANDECost(
        uint256 gasUsed,
        uint256 gasPrice
    ) external view returns (uint256 andeCost);
}