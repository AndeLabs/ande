import dotenv from 'dotenv';
import { ethers } from 'ethers';

dotenv.config();

function getEnvVariable(key: string): string {
    const variable = process.env[key];
    if (!variable) {
        throw new Error(`La variable de entorno ${key} no está definida.`);
    }
    return variable;
}

export const config = {
    andeChain: {
        rpcUrl: getEnvVariable('ANDECHAIN_RPC_URL'),
        bridgeAddress: getEnvVariable('ANDE_BRIDGE_ADDRESS'),
    },
    ethereum: {
        rpcUrl: getEnvVariable('ETHEREUM_RPC_URL'),
        bridgeAddress: getEnvVariable('ETHEREUM_BRIDGE_ADDRESS'),
    },
    celestia: {
        nodeUrl: getEnvVariable('CELESTIA_NODE_URL'),
    },
    relayer: {
        privateKey: getEnvVariable('RELAYER_PRIVATE_KEY'),
        wallet: new ethers.Wallet(getEnvVariable('RELAYER_PRIVATE_KEY')),
    },
};
