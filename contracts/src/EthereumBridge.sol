// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Interfaz mínima para interactuar con el contrato BlobstreamX
interface IBlobstreamX {
    function dataRootTupleRootAtBlock(uint256 _blockNumber) external view returns (bytes32);
}

/**
 * @title EthereumBridge
 * @author Ande Labs
 * @notice Este contrato es el punto de salida del bridge en la red de destino (ej. Ethereum).
 * Verifica una prueba de disponibilidad de datos de Celestia y libera los fondos al destinatario.
 */
contract EthereumBridge is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice La dirección del contrato BlobstreamX en esta cadena, usado para verificar las raíces de datos de Celestia.
    IBlobstreamX public immutable BLOBSTREAM;
    /// @notice La dirección del token que se liberará a los usuarios (ej. USDC).
    IERC20 public immutable USDC_TOKEN;

    /// @dev Mapeo para prevenir que un mismo bridge se procese más de una vez.
    mapping(bytes32 => bool) public processedCommitments;

    /**
     * @notice Se emite cuando un bridge se ha completado exitosamente y los fondos han sido transferidos.
     * @param recipient La dirección del destinatario que ha recibido los fondos.
     * @param amount La cantidad de tokens transferidos.
     * @param commitment El hash único de la transacción de bridge original.
     */
    event BridgeCompleted(
        address indexed recipient,
        uint256 amount,
        bytes32 indexed commitment
    );

    /**
     * @dev Configura las direcciones inmutables del contrato Blobstream y del token a liberar.
     * @param _blobstreamAddress La dirección del contrato BlobstreamX.
     * @param _usdcTokenAddress La dirección del token ERC20 (ej. USDC).
     */
    constructor(address _blobstreamAddress, address _usdcTokenAddress) {
        BLOBSTREAM = IBlobstreamX(_blobstreamAddress);
        USDC_TOKEN = IERC20(_usdcTokenAddress);
    }

    /**
     * @notice Completa el proceso de bridge. Es llamado por un relayer después de verificar la publicación en Celestia.
     * @dev Reconstruye el commitment, lo verifica contra la prueba de Merkle y la raíz de Celestia, y luego transfiere los tokens.
     * @param _recipient La dirección que finalmente recibirá los fondos en Ethereum.
     * @param _amount La cantidad de tokens a liberar.
     * @param _sourceChainId El ID de la cadena de origen (AndeChain).
     * @param _sourceBlockNumber El número de bloque en AndeChain donde se inició el bridge.
     * @param _sourceAddress La dirección que inició el bridge en AndeChain.
     * @param _celestiaBlockHeight La altura del bloque de Celestia donde se publicó el dato.
     * @param _merkleProof La prueba de Merkle que demuestra la inclusión del commitment en el data root.
     * @param _dataRoot El data root del árbol de Merkle de las transacciones en el blob.
     */
    function completeBridge(
        address _recipient,
        uint256 _amount,
        uint256 _sourceChainId,
        uint256 _sourceBlockNumber,
        address _sourceAddress,
        uint256 _celestiaBlockHeight,
        bytes32[] calldata _merkleProof,
        bytes32 _dataRoot
    ) external nonReentrant {
        // 1. Reconstruir el commitment con los datos explícitos para verificar la integridad
        bytes32 commitment = keccak256(abi.encodePacked(
            _sourceAddress,
            _recipient,
            _amount,
            _sourceChainId,
            _sourceBlockNumber
        ));

        // 2. Verificar que este bridge no se haya procesado antes
        require(!processedCommitments[commitment], "Bridge already processed");

        // 3. Obtener el data root oficial de Celestia para esa altura desde Blobstream
        bytes32 trustedDataRoot = BLOBSTREAM.dataRootTupleRootAtBlock(_celestiaBlockHeight);
        require(trustedDataRoot != bytes32(0), "Data root not found for this block");

        // 4. Verificar que el data root proporcionado por el relayer coincide con el de Blobstream
        require(_dataRoot == trustedDataRoot, "Data root does not match Blobstream");

        // 5. Verificar que el commitment de la transacción está en el árbol de Merkle
        require(MerkleProof.verify(_merkleProof, _dataRoot, commitment), "Invalid Merkle proof");

        // 6. Marcar como procesado para evitar re-entradas y repeticiones
        processedCommitments[commitment] = true;

        // 7. Liberar los fondos (transferir USDC al destinatario final)
        USDC_TOKEN.safeTransfer(_recipient, _amount);

        emit BridgeCompleted(_recipient, _amount, commitment);
    }
}
