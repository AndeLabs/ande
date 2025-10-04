import { MerkleTree } from 'merkletreejs';
import { ethers } from 'ethers';

/**
 * Construye un Árbol de Merkle a partir de una lista de commitments.
 * @param commitments Un array de hashes de compromiso (bytes32).
 * @returns Una instancia del Árbol de Merkle.
 */
export function buildMerkleTree(commitments: string[]): MerkleTree {
    const leaves = commitments.map(ethers.keccak256);
    const tree = new MerkleTree(leaves, ethers.keccak256, { sortPairs: true });
    return tree;
}

/**
 * Obtiene la raíz del Árbol de Merkle en formato hexadecimal.
 * @param tree La instancia del Árbol de Merkle.
 * @returns El hash de la raíz como un string hexadecimal.
 */
export function getMerkleRoot(tree: MerkleTree): string {
    return tree.getHexRoot();
}

/**
 * Obtiene la prueba de Merkle para una hoja específica (commitment).
 * @param tree La instancia del Árbol de Merkle.
 * @param commitment El commitment para el cual se necesita la prueba.
 * @returns Un array de hashes (la prueba) en formato hexadecimal.
 */
export function getMerkleProof(tree: MerkleTree, commitment: string): string[] {
    const leaf = ethers.keccak256(commitment);
    return tree.getHexProof(leaf);
}
