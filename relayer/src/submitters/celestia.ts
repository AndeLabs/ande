import axios from 'axios';
import { config } from '../config';

// Un namespace válido de 29 bytes. El primer byte es la versión.
const ANDEBRIDGE_NAMESPACE_HEX = '0000000000000000000000000000000000000000000000000000000001';
const ANDEBRIDGE_NAMESPACE_BASE64 = Buffer.from(ANDEBRIDGE_NAMESPACE_HEX, 'hex').toString('base64');

/**
 * Publica un lote de datos (commitments) como un blob en la red de Celestia usando JSON-RPC.
 * @param commitments Un array de hashes de compromiso de las transacciones de bridge.
 * @returns El resultado de la API de Celestia, incluyendo la altura del bloque.
 */
export async function publishToCelestia(commitments: string[]) {
    const nodeUrl = config.celestia.nodeUrl;
    const endpoint = nodeUrl;

    // 1. Preparamos los datos: cada commitment se trata como un blob individual y se codifica a Base64.
    const blobsBase64 = commitments.map(commitment => {
        // Asumimos que el commitment es un string hexadecimal, lo convertimos a Buffer y luego a Base64.
        const buffer = Buffer.from(commitment.startsWith('0x') ? commitment.substring(2) : commitment, 'hex');
        return buffer.toString('base64');
    });

    // 2. Construimos el cuerpo de la petición JSON-RPC para el `local-da`.
    const requestBody = {
        jsonrpc: "2.0",
        id: 1,
        method: "da.Submit", // El método correcto es `da.Submit`
        params: [
            blobsBase64, // El primer parámetro es el array de blobs
            0.002,       // El segundo es un gasPrice (float)
            ANDEBRIDGE_NAMESPACE_BASE64 // El tercero es el namespace en Base64
        ]
    };

    try {
        console.log(`[Celestia Submitter] Enviando blob JSON-RPC a ${endpoint}...`);
        const response = await axios.post(endpoint, requestBody, {
            headers: { 'Content-Type': 'application/json' },
        });

        if (response.data.result) {
            // La respuesta de este método es un array de IDs, no una altura.
            // Para nuestro simulador, la altura no es crítica, solo el éxito.
            console.log(`[Celestia Submitter] ¡Blob publicado exitosamente! IDs: ${response.data.result}`);
            // Simulamos una altura para que el resto del flujo continúe.
            return { height: 1 }; 
        } else if (response.data.error) {
            throw new Error(`La API de Celestia respondió con un error: ${response.data.error.message}`);
        } else {
            throw new Error(`Respuesta inesperada de la API de Celestia`);
        }
    } catch (error: any) {
        console.error("[Celestia Submitter] Error al publicar el blob:", error.response?.data || error.message);
        throw error;
    }
}
