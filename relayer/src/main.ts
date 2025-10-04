import { initializeAndeChainListener, BridgeInitiatedEvent } from './listeners/andechain';
import { ethers } from 'ethers';
import { publishToCelestia } from './submitters/celestia';
import { buildMerkleTree, getMerkleRoot, getMerkleProof } from './processors/merkle';
import { completeBridgeOnEthereum } from './submitters/ethereum';

console.log("Iniciando Relayer...");

// --- Cola y Configuración del Lote ---
const BATCH_INTERVAL_MS = 15000; // Procesar la cola cada 15 segundos
const eventQueue: BridgeInitiatedEvent[] = [];
let isProcessing = false;

// --- Manejador de Eventos ---
function handleBridgeEvent(event: BridgeInitiatedEvent) {
    console.log(`[Queue] Evento con commitment ${event.commitment} añadido a la cola.`);
    eventQueue.push(event);
}

// --- Procesador Principal del Lote ---
async function processQueue() {
    if (isProcessing || eventQueue.length === 0) {
        return;
    }

    isProcessing = true;
    console.log(`
[Processor] Iniciando procesamiento de un lote de ${eventQueue.length} evento(s)...`);

    const batchToProcess = [...eventQueue];
    eventQueue.length = 0;

    try {
        const commitments = batchToProcess.map(event => event.commitment);

        // --- PASO 1: Publicar Lote en Celestia ---
        const celestiaResult = await publishToCelestia(commitments);
        const celestiaBlockHeight = celestiaResult.height;

        // --- PASO 2: Generar Árbol de Merkle para el Lote ---
        const tree = buildMerkleTree(commitments);
        const merkleRoot = getMerkleRoot(tree);
        console.log(`[Merkle Processor] Raíz de Merkle para el lote generada: ${merkleRoot}`);

        // --- PASO 3: Completar cada transacción en Ethereum ---
        for (const event of batchToProcess) {
            const merkleProof = getMerkleProof(tree, event.commitment);
            
            const bridgeData = {
                recipient: event.to,
                amount: event.amount,
                sourceChainId: event.sourceChainId,
                sourceBlockNumber: event.blockNumber, // <-- LA LÍNEA CLAVE Y CORRECTA
                sourceAddress: event.from,
                celestiaBlockHeight: celestiaBlockHeight,
                merkleProof: merkleProof,
                merkleRoot: merkleRoot,
            };

            console.log(`
[DEBUG] Enviando datos para ${event.commitment}:`, JSON.stringify(bridgeData, (k,v) => typeof v === 'bigint' ? v.toString() : v, 2));
            await completeBridgeOnEthereum(bridgeData);
            console.log(`  -> Bridge para commitment ${event.commitment} completado.`);
        }

        console.log(`[Processor] Lote de ${batchToProcess.length} evento(s) procesado exitosamente.`);

    } catch (error) {
        console.error("Fallo en el procesamiento del lote.", error);
    } finally {
        isProcessing = false;
    }
}

// --- Inicio del Servicio ---
initializeAndeChainListener(handleBridgeEvent);
setInterval(processQueue, BATCH_INTERVAL_MS);