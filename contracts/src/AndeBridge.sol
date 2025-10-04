// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AndeBridge
 * @notice Contrato en AndeChain para iniciar un bridge hacia Ethereum.
 * Bloquea los tokens y emite un evento para que un relayer lo procese.
 */
contract AndeBridge is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable ABOB_TOKEN; // El token que se va a puentear (ej. $ABOB)

    event BridgeInitiated(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 sourceChainId,
        bytes32 commitment
    );

    constructor(address _abobTokenAddress) {
        ABOB_TOKEN = IERC20(_abobTokenAddress);
    }

    /**
     * @notice Inicia el proceso de bridge desde AndeChain hacia Ethereum.
     * @param _amount La cantidad de tokens a enviar.
     * @param _recipientOnEthereum La dirección que recibirá los fondos en Ethereum.
     */
    function bridgeToEthereum(uint256 _amount, address _recipientOnEthereum) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");

        // 1. Transferir los tokens desde el usuario hacia este contrato (lock)
        // Usamos safeTransferFrom para revertir si la transferencia falla.
        ABOB_TOKEN.safeTransferFrom(msg.sender, address(this), _amount);

        // 2. Crear un compromiso único para esta transacción.
        // Este hash es lo que se publicará en Celestia y se verificará en Ethereum.
        bytes32 commitment = keccak256(abi.encodePacked(
            msg.sender,
            _recipientOnEthereum,
            _amount,
            block.chainid,
            block.number // Usar block.number como nonce previene repeticiones
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
