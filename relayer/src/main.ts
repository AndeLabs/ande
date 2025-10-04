import { initializeAndeChainListener, BridgeInitiatedEvent } from './listeners/andechain';
import { ethers } from 'ethers';
import { publishToCelestia } from './submitters/celestia';
import { buildMerkleTree, getMerkleRoot, getMerkleProof } from './processors/merkle';
import { completeBridgeOnEthereum } from './submitters/ethereum';

console.log("Iniciando Relayer...");

async function handleBridgeEvent(event: BridgeInitiatedEvent) {
    const {
        from,
        to,
        amount,
        sourceChainId,
        commitment,
        blockNumber
    } = event;

    console.log("--- Nuevo Evento de Bridge Recibido ---");
    console.log(`  Desde (AndeChain): ${from}`);
    console.log(`  Hacia (Ethereum):    ${to}`);
    console.log(`  Monto:               ${ethers.formatEther(amount)} ABOB`);
    console.log(`  Commitment:          ${commitment}`);
    console.log("-----------------------------------------");

    try {
        // --- PASO 1: Publicar en Celestia ---
        const celestiaResult = await publishToCelestia([commitment]);
        const celestiaBlockHeight = celestiaResult.height;

        // --- PASO 2: Generar Prueba de Merkle ---
        const batch = [commitment];
        const tree = buildMerkleTree(batch);
        const merkleRoot = getMerkleRoot(tree);
        const merkleProof = getMerkleProof(tree, commitment);
        console.log(`[Merkle Processor] Raíz de Merkle generada: ${merkleRoot}`);

        // --- PASO 3: Completar en Ethereum ---
        const bridgeData = {
            recipient: to,
            amount: amount,
            sourceChainId: sourceChainId,
            sourceBlockNumber: blockNumber, // <-- LA LÍNEA CLAVE
            sourceAddress: from,
            celestiaBlockHeight: celestiaBlockHeight,
            merkleProof: merkleProof,
            merkleRoot: merkleRoot,
        };

        // Log de depuración para verificar los datos
        const replacer = (key: any, value: any) =>
            typeof value === 'bigint' ? value.toString() : value;
        console.log("\n[DEBUG] Datos para completar el bridge:", JSON.stringify(bridgeData, replacer, 2));

        await completeBridgeOnEthereum(bridgeData);

    } catch (error) {
        console.error("Fallo en el procesamiento del evento de bridge.", error);
    }
}

// Iniciar el listener y pasarle nuestro manejador de eventos
initializeAndeChainListener(handleBridgeEvent);