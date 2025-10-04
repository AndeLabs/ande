import { ethers } from 'ethers';
import { config } from '../config';

// ABI mínima para escuchar el evento
const andeBridgeAbi = [
    'event BridgeInitiated(address indexed from, address indexed to, uint256 amount, uint256 sourceChainId, bytes32 commitment)'
];

// Definimos una interfaz para la data que pasaremos
export interface BridgeInitiatedEvent {
    from: string;
    to: string;
    amount: ethers.BigNumberish;
    sourceChainId: ethers.BigNumberish;
    commitment: string;
    blockNumber: number;
}

export function initializeAndeChainListener(eventHandler: (event: BridgeInitiatedEvent) => void) {
    const provider = new ethers.JsonRpcProvider(config.andeChain.rpcUrl);
    const andeBridge = new ethers.Contract(config.andeChain.bridgeAddress, andeBridgeAbi, provider);

    console.log(`[AndeChain Listener] Conectado y escuchando eventos en el contrato ${config.andeChain.bridgeAddress}...`);

    andeBridge.on('BridgeInitiated', (from, to, amount, sourceChainId, commitment, event) => {
        console.log(`[AndeChain Listener] ¡Evento BridgeInitiated detectado!`);
        
        // Construimos un objeto limpio y se lo pasamos al manejador
        eventHandler({
            from,
            to,
            amount,
            sourceChainId,
            commitment,
            blockNumber: event.blockNumber
        });
    });

    provider.on('error', (error) => {
        console.error('[AndeChain Listener] Error de proveedor RPC:', error);
    });
}
