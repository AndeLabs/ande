// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
 * @notice Contrato en Ethereum para completar el bridge desde AndeChain.
 * Verifica una prueba de inclusión en Celestia y libera los fondos.
 */
contract EthereumBridge is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IBlobstreamX public immutable BLOBSTREAM;
    IERC20 public immutable USDC_TOKEN; // El token a liberar (ej. USDC)

    mapping(bytes32 => bool) public processedCommitments;

    event BridgeCompleted(
        address indexed recipient,
        uint256 amount,
        bytes32 indexed commitment
    );

    constructor(address _blobstreamAddress, address _usdcTokenAddress) {
        BLOBSTREAM = IBlobstreamX(_blobstreamAddress);
        USDC_TOKEN = IERC20(_usdcTokenAddress);
    }

    /**
     * @notice Completa el bridge, llamado por un relayer.
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
