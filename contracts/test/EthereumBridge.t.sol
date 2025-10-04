// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {EthereumBridge, IBlobstreamX} from "../src/EthereumBridge.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Librería auxiliar para generar árboles de Merkle en los tests
library Merkle {
    function root(bytes32[] memory leaves) internal pure returns (bytes32) {
        if (leaves.length == 0) return bytes32(0);
        if (leaves.length == 1) return leaves[0];

        uint256 nextLayerLength = (leaves.length + 1) / 2;
        bytes32[] memory nextLayer = new bytes32[](nextLayerLength);

        for (uint256 i = 0; i < nextLayerLength; i++) {
            if (2 * i + 1 < leaves.length) {
                bytes32 left = leaves[2 * i];
                bytes32 right = leaves[2 * i + 1];
                if (left < right) {
                    nextLayer[i] = keccak256(abi.encodePacked(left, right));
                } else {
                    nextLayer[i] = keccak256(abi.encodePacked(right, left));
                }
            } else {
                nextLayer[i] = leaves[2 * i];
            }
        }
        return root(nextLayer);
    }

    function proof(bytes32[] memory leaves, uint256 leafIndex) internal pure returns (bytes32[] memory) {
        uint256 proofSize = 0;
        uint256 tempLayerSize = leaves.length;
        while (tempLayerSize > 1) {
            proofSize++;
            tempLayerSize = (tempLayerSize + 1) / 2;
        }

        bytes32[] memory merkleProof = new bytes32[](proofSize);
        bytes32[] memory currentLayer = leaves;
        uint256 currentIndex = leafIndex;

        for (uint256 i = 0; i < proofSize; i++) {
            uint256 pairIndex = currentIndex % 2 == 0 ? currentIndex + 1 : currentIndex - 1;
            if (pairIndex < currentLayer.length) {
                merkleProof[i] = currentLayer[pairIndex];
            }

            uint256 nextLayerLength = (currentLayer.length + 1) / 2;
            bytes32[] memory nextLayer = new bytes32[](nextLayerLength);
            for (uint256 j = 0; j < nextLayerLength; j++) {
                if (2 * j + 1 < currentLayer.length) {
                    bytes32 left = currentLayer[2 * j];
                    bytes32 right = currentLayer[2 * j + 1];
                    if (left < right) {
                        nextLayer[j] = keccak256(abi.encodePacked(left, right));
                    } else {
                        nextLayer[j] = keccak256(abi.encodePacked(right, left));
                    }
                } else {
                    nextLayer[j] = currentLayer[2 * j];
                }
            }
            currentLayer = nextLayer;
            currentIndex = currentIndex / 2;
        }
        return merkleProof;
    }
}

// Contrato Mock para simular BlobstreamX
contract MockBlobstream is IBlobstreamX {
    mapping(uint256 => bytes32) public dataRoots;

    function setDataRoot(uint256 _blockNumber, bytes32 _root) public {
        dataRoots[_blockNumber] = _root;
    }

    function dataRootTupleRootAtBlock(uint256 _blockNumber) external view returns (bytes32) {
        return dataRoots[_blockNumber];
    }
}

contract EthereumBridgeTest is Test {
    EthereumBridge public ethBridge;
    MockERC20 public usdcToken;
    MockBlobstream public mockBlobstream;

    address public relayer = address(1);
    address public sourceAddress = address(3);
    address public recipient = address(2);
    uint256 public amount = 100 * 10**18;
    uint256 public sourceChainId = 12345;
    uint256 public sourceBlockNumber = 1;

    function setUp() public {
        usdcToken = new MockERC20("Mock USDC", "mUSDC", 18);
        mockBlobstream = new MockBlobstream();
        ethBridge = new EthereumBridge(address(mockBlobstream), address(usdcToken));

        // Proveer al bridge con fondos para liberar
        usdcToken.mint(address(ethBridge), 1_000_000 * 10**18);
    }

    function test_CompleteBridgeSuccessfully() public {
        // 1. Simular datos de un bridge iniciado
        bytes32 commitment = keccak256(abi.encodePacked(sourceAddress, recipient, amount, sourceChainId, sourceBlockNumber));
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = commitment;

        // 2. Construir un árbol de Merkle y obtener la raíz y la prueba
        bytes32 root = Merkle.root(leaves);
        bytes32[] memory proof = Merkle.proof(leaves, 0);
        uint256 celestiaBlockHeight = 500;

        // 3. Configurar el mock de Blobstream para que "confirme" esta raíz
        mockBlobstream.setDataRoot(celestiaBlockHeight, root);

        // 4. Ejecutar la función como si fuéramos el relayer
        vm.startPrank(relayer);
        ethBridge.completeBridge(recipient, amount, sourceChainId, sourceBlockNumber, sourceAddress, celestiaBlockHeight, proof, root);
        vm.stopPrank();

        // 5. Verificar que el destinatario recibió los fondos
        assertEq(usdcToken.balanceOf(recipient), amount);
        assertTrue(ethBridge.processedCommitments(commitment));
    }

     function test_FailIfCommitmentAlreadyProcessed() public {
        // Repetimos el setup del test anterior
        bytes32 commitment = keccak256(abi.encodePacked(sourceAddress, recipient, amount, sourceChainId, sourceBlockNumber));
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = commitment;
        bytes32 root = Merkle.root(leaves);
        bytes32[] memory proof = Merkle.proof(leaves, 0);
        uint256 celestiaBlockHeight = 500;
        mockBlobstream.setDataRoot(celestiaBlockHeight, root);

        // Primera llamada exitosa
        vm.prank(relayer);
        ethBridge.completeBridge(recipient, amount, sourceChainId, sourceBlockNumber, sourceAddress, celestiaBlockHeight, proof, root);

        // Segunda llamada debe fallar
        vm.prank(relayer);
        vm.expectRevert("Bridge already processed");
        ethBridge.completeBridge(recipient, amount, sourceChainId, sourceBlockNumber, sourceAddress, celestiaBlockHeight, proof, root);
    }
}
