// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AndeBridge} from "../src/AndeBridge.sol";
import {EthereumBridge} from "../src/EthereumBridge.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

// Interfaz mínima para interactuar con el contrato BlobstreamX
interface IBlobstreamX {
    function dataRootTupleRootAtBlock(uint256 _blockNumber) external view returns (bytes32);
}

// Contrato Mock para simular BlobstreamX en el despliegue local
contract MockBlobstream is IBlobstreamX {
    mapping(uint256 => bytes32) public dataRoots;

    function setDataRoot(uint256 _blockNumber, bytes32 _root) public {
        dataRoots[_blockNumber] = _root;
    }

    function dataRootTupleRootAtBlock(uint256 _blockNumber) external view returns (bytes32) {
        return dataRoots[_blockNumber];
    }
}

contract DeployBridge is Script {
    function run() external {
        // Cargar la clave privada del desplegador desde las variables de entorno
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // --- 1. Desplegar Mocks ---
        console.log("Deploying MockABOB (for AndeBridge)...");
        MockERC20 mockAbob = new MockERC20("Mock ABOB", "mABOB", 18);
        console.log("-> MockABOB deployed to:", address(mockAbob));

        console.log("Deploying MockUSDC (for EthereumBridge)...");
        MockERC20 mockUsdc = new MockERC20("Mock USDC", "mUSDC", 18);
        console.log("-> MockUSDC deployed to:", address(mockUsdc));

        console.log("Deploying MockBlobstream...");
        MockBlobstream mockBlobstream = new MockBlobstream();
        console.log("-> MockBlobstream deployed to:", address(mockBlobstream));

        // --- 2. Desplegar Contratos del Bridge ---
        console.log("Deploying AndeBridge...");
        AndeBridge andeBridge = new AndeBridge(address(mockAbob));
        console.log("-> AndeBridge deployed to:", address(andeBridge));

        console.log("Deploying EthereumBridge...");
        EthereumBridge ethBridge = new EthereumBridge(address(mockBlobstream), address(mockUsdc));
        console.log("-> EthereumBridge deployed to:", address(ethBridge));

        vm.stopBroadcast();
    }
}
