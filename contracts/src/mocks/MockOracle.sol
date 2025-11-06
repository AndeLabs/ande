// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockOracle
 * @dev Mock para un oráculo de precios estilo Chainlink.
 * Almacena el precio con decimales configurables.
 */
contract MockOracle is Ownable {
    uint256 private _price;
    uint8 private _decimals;

    event PriceUpdated(uint256 newPrice);

    constructor(int256 initialPrice, uint8 decimals_) Ownable(msg.sender) {
        require(initialPrice >= 0, "Price must be non-negative");
        _price = uint256(initialPrice);
        _decimals = decimals_;
    }

    /**
     * @dev Retorna la cantidad de decimales que usa el oráculo.
     */
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Simula la función `latestRoundData` de Chainlink.
     * Retorna el precio actual.
     */
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            1, // roundId
            int256(_price), // answer
            block.timestamp, // startedAt
            block.timestamp, // updatedAt
            1 // answeredInRound
        );
    }

    /**
     * @dev Permite al owner establecer un nuevo precio.
     * El precio debe ser enviado con el número de decimales configurado en el constructor.
     */
    function setPrice(uint256 newPrice) external onlyOwner {
        _price = newPrice;
        emit PriceUpdated(newPrice);
    }

    /**
     * @dev Función de conveniencia para obtener solo el precio.
     */
    function getPrice() external view returns (uint256) {
        return _price;
    }
}
