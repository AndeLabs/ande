// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IOracle
 * @dev Interfaz estandarizada para oráculos de precios, compatible con Chainlink.
 */
interface IOracle {
    /**
     * @dev Retorna la cantidad de decimales que usa el oráculo para el precio.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Retorna los datos del último round completado por el oráculo.
     * @return roundId El ID del round.
     * @return answer El precio (la respuesta).
     * @return startedAt Timestamp de cuándo comenzó el round.
     * @return updatedAt Timestamp de cuándo se actualizó el precio.
     * @return answeredInRound El ID del round en el que se obtuvo la respuesta.
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
        );
}
