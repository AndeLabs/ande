import { ethers } from 'ethers';
import { config } from '../config';

// ABI mínima para llamar a completeBridge
const ethBridgeAbi = [
    'function completeBridge(address _recipient, uint256 _amount, uint256 _sourceChainId, uint256 _sourceBlockNumber, address _sourceAddress, uint256 _celestiaBlockHeight, bytes32[] calldata _merkleProof, bytes32 _dataRoot)'
];

// Tipos para los datos del evento
interface BridgeEventData {
    recipient: string;
    amount: ethers.BigNumberish;
    sourceChainId: ethers.BigNumberish;
    sourceBlockNumber: ethers.BigNumberish;
    sourceAddress: string;
    celestiaBlockHeight: number;
    merkleProof: string[];
    merkleRoot: string;
}

export async function completeBridgeOnEthereum(data: BridgeEventData) {
    // Usamos el RPC de Ethereum (Sepolia, etc.) y la clave privada del relayer
    const provider = new ethers.JsonRpcProvider(config.ethereum.rpcUrl);
    const signer = new ethers.Wallet(config.relayer.privateKey, provider);
    const ethBridge = new ethers.Contract(config.ethereum.bridgeAddress, ethBridgeAbi, signer);

    console.log(`[Ethereum Submitter] Intentando completar bridge para ${data.recipient} en Ethereum...`);

    try {
        const tx = await ethBridge.completeBridge(
            data.recipient,
            data.amount,
            data.sourceChainId,
            data.sourceBlockNumber,
            data.sourceAddress,
            data.celestiaBlockHeight,
            data.merkleProof,
            data.merkleRoot
        );

        console.log(`[Ethereum Submitter] Transacción enviada. Esperando confirmación... TX Hash: ${tx.hash}`);
        const receipt = await tx.wait();
        console.log(`[Ethereum Submitter] ¡Bridge completado en Ethereum! Block: ${receipt.blockNumber}`);
        return receipt;

    } catch (error: any) {
        console.error("[Ethereum Submitter] Error al completar el bridge:", error.reason || error.message);
        throw error;
    }
}
