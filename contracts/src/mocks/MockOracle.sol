// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title MockOracle
 * @dev Mock para un oráculo de precios estilo Chainlink.
 * Almacena el precio con 8 decimales, como es estándar en los pares USD de Chainlink.
 */
contract MockOracle is Ownable {
    uint256 private _price; // Precio almacenado con 8 decimales

    event PriceUpdated(uint256 newPrice);

    constructor() Ownable(msg.sender) {
        // Precio inicial por defecto (ej. 1 USD)
        _price = 1 * 10**8;
    }

    /**
     * @dev Retorna la cantidad de decimales que usa el oráculo.
     */
    function decimals() external pure returns (uint8) {
        return 8;
    }

    /**
     * @dev Simula la función `latestRoundData` de Chainlink.
     * Retorna el precio actual.
     */
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
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
     * El precio debe ser enviado con 8 decimales.
     * Ejemplo: para 1.5 USD, enviar 150000000.
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