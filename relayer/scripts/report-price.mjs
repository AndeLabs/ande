import { ethers } from 'ethers';
import 'dotenv/config';

// --- CONFIGURACIÓN ---
// Dirección del oráculo P2P desplegado en nuestro rollup local.
// NOTA: Esta dirección cambiará en cada deploy. Debemos obtenerla del archivo de broadcast de Foundry.
const P2P_ORACLE_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3'; // Reemplazar con la dirección real

// Clave privada de uno de nuestros reporters de prueba.
// Esta es una de las claves privadas estándar de Hardhat/Foundry.
const REPORTER_PRIVATE_KEY = process.env.RELAYER_PRIVATE_KEY || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

// RPC de nuestro rollup local
const RPC_URL = 'http://localhost:8545';

// ABI (Interfaz) mínima para interactuar con nuestro contrato P2POracleV2
const P2P_ORACLE_ABI = [
  'function reportPrice(uint256 price) external',
  'event PriceReported(uint256 indexed epoch, address indexed reporter, uint256 price)',
];

// Fuentes de datos para el precio USD/BOB
const API_SOURCES = [
  {
    name: 'DolarAPI',
    url: 'https://bo.dolarapi.com/v1/dolares/binance',
    parser: (data) => data.venta, // Extrae el precio del campo 'venta'
  },
  {
    name: 'CriptoYa',
    url: 'https://criptoya.com/api/binancep2p/USDT/BOB/0.1',
    parser: (data) => data.bid, // Extrae el precio del campo 'bid'
  },
];

// --- LÓGICA DEL SCRIPT ---

/**
 * Calcula la mediana de un array de números.
 * La mediana es más resistente a valores atípicos que el promedio.
 * @param {number[]} arr - El array de precios.
 * @returns {number} La mediana.
 */
function getMedian(arr) {
  if (!arr.length) return 0;
  const sorted = arr.slice().sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 0) {
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
  return sorted[mid];
}

/**
 * Función principal que se ejecuta.
 */
async function main() {
  console.log('🤖 Iniciando reporter de precios...');

  // 1. Obtener precios de todas las fuentes de forma concurrente
  console.log('📡 Obteniendo precios de las APIs...');
  const pricePromises = API_SOURCES.map(async (source) => {
    try {
      const response = await fetch(source.url);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const data = await response.json();
      const price = source.parser(data);
      if (typeof price !== 'number' || price <= 0) {
        throw new Error('Precio inválido o no encontrado en la respuesta');
      }
      console.log(`  ✅ ${source.name}: ${price} BOB por USD`);
      return price;
    } catch (error) {
      console.error(`  ❌ Error obteniendo precio de ${source.name}: ${error.message}`);
      return null;
    }
  });

  const prices = (await Promise.all(pricePromises)).filter(p => p !== null);

  if (prices.length === 0) {
    console.error('🛑 No se pudo obtener el precio de ninguna fuente. Abortando.');
    return;
  }

  // 2. Calcular la mediana de los precios obtenidos
  const medianPriceBOB = getMedian(prices);
  console.log(`
⚖️ Mediana de precios calculada: ${medianPriceBOB} BOB por USD`);

  // 3. Transformar el precio para el contrato (inversa y escalado)
  // El contrato espera el precio de 1 BOB en USD, con 18 decimales.
  const priceForContract = (1 / medianPriceBOB) * 1e18;
  const priceBigInt = BigInt(Math.round(priceForContract));
  console.log(`📐 Precio transformado para el contrato: ${priceBigInt.toString()}`);

  // 4. Conectarse a la blockchain y enviar la transacción
  try {
    console.log(`
🔗 Conectando a la blockchain en ${RPC_URL}...`);
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(REPORTER_PRIVATE_KEY, provider);
    const oracleContract = new ethers.Contract(P2P_ORACLE_ADDRESS, P2P_ORACLE_ABI, wallet);

    console.log(`
✉️ Enviando precio al contrato P2POracleV2 en la dirección ${P2P_ORACLE_ADDRESS}...`);
    console.log(`   - Reporter: ${wallet.address}`);
    console.log(`   - Precio a reportar: ${priceBigInt.toString()}`);

    const tx = await oracleContract.reportPrice(priceBigInt);
    console.log(`
⏳ Transacción enviada. Esperando confirmación... (Hash: ${tx.hash})`);

    const receipt = await tx.wait();
    console.log(`
✅ ¡Éxito! Transacción confirmada en el bloque ${receipt.blockNumber}.`);
    console.log('   Puedes verificar el evento 'PriceReported' en tu explorador de bloques.');

  } catch (error) {
    console.error(`
🛑 Error al enviar la transacción a la blockchain: ${error.message}`);
  }
}

main().catch((error) => {
  console.error('Error inesperado en la ejecución del script:', error);
  process.exit(1);
});
