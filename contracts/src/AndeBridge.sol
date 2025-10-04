// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AndeBridge
 * @author Ande Labs
 * @notice Este contrato es el punto de entrada para puentear tokens desde AndeChain hacia otra red EVM (como Ethereum).
 * Los usuarios llaman a `bridgeToEthereum` para bloquear sus tokens y emitir un evento que un relayer procesará.
 */
contract AndeBridge is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice El token ERC20 que este puente está configurado para manejar (ej. $ABOB).
    IERC20 public immutable ABOB_TOKEN;

    /**
     * @notice Se emite cuando un usuario ha iniciado exitosamente un proceso de bridge.
     * @param from La dirección del usuario que inicia el bridge en AndeChain.
     * @param to La dirección del destinatario en la red de destino.
     * @param amount La cantidad de tokens bloqueados.
     * @param sourceChainId El ID de la cadena de origen (AndeChain).
     * @param commitment Un hash único que representa esta transacción de bridge específica.
     */
    event BridgeInitiated(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 sourceChainId,
        bytes32 commitment
    );

    /**
     * @dev Configura el contrato con la dirección del token a puentear.
     * @param _abobTokenAddress La dirección del contrato del token ERC20 (ej. $ABOB).
     */
    constructor(address _abobTokenAddress) {
        ABOB_TOKEN = IERC20(_abobTokenAddress);
    }

    /**
     * @notice Inicia el proceso de bridge bloqueando los tokens del usuario y emitiendo un evento.
     * @dev El usuario debe haber aprobado previamente a este contrato para gastar `_amount` de sus tokens.
     * @param _amount La cantidad de tokens a enviar.
     * @param _recipientOnEthereum La dirección que recibirá los fondos en la red de destino.
     */
    function bridgeToEthereum(uint256 _amount, address _recipientOnEthereum) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");

        // 1. Transferir los tokens desde el usuario hacia este contrato (lock)
        ABOB_TOKEN.safeTransferFrom(msg.sender, address(this), _amount);

        // 2. Crear un compromiso único para esta transacción.
        bytes32 commitment = keccak256(abi.encodePacked(
            msg.sender,
            _recipientOnEthereum,
            _amount,
            block.chainid,
            block.number
        ));

        // 3. Emitir el evento que el relayer off-chain estará escuchando.
        emit BridgeInitiated(
            msg.sender,
            _recipientOnEthereum,
            _amount,
            block.chainid,
            commitment
        );
    }
}
