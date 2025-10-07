import { ethers } from 'ethers';
import 'dotenv/config';

// --- CONFIGURACIÓN ---
// Dirección del oráculo P2P desplegado en nuestro rollup local.
// NOTA: Esta dirección cambiará en cada deploy. Debemos obtenerla del archivo de broadcast de Foundry.
const P2P_ORACLE_ADDRESS = process.env.P2P_ORACLE_ADDRESS || '0x5FbDB2315678afecb367f032d93F642f64180aa3';

// Clave privada del reporter
const REPORTER_PRIVATE_KEY = process.env.RELAYER_PRIVATE_KEY || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

// RPC de nuestro rollup local
const RPC_URL = process.env.RPC_URL || 'http://localhost:8545';

// ABI (Interfaz) para interactuar con nuestro contrato P2POracle
const P2P_ORACLE_ABI = [
  'function reportPrice(uint256 price) external',
  'function register() external',
  'function increaseStake(uint256 additionalAmount) external',
  'function decreaseStake(uint256 withdrawalAmount) external',
  'function unregister() external',
  'function reporters(address) view returns (bool isRegistered, uint256 stake, uint256 registrationTime, uint256 lastReportEpoch)',
  'function minStake() view returns (uint256)',
  'event PriceReported(uint256 indexed epoch, address indexed reporter, uint256 price)',
  'event ReporterRegistered(address indexed reporter, uint256 stake)',
];

// Fuentes de datos para el precio USD/BOB
const API_SOURCES = [
  {
    name: 'DolarAPI',
    url: 'https://bo.dolarapi.com/v1/dolares/binance',
    parser: (data) => data.venta,
  },
  {
    name: 'CriptoYa',
    url: 'https://criptoya.com/api/binancep2p/USDT/BOB/0.1',
    parser: (data) => data.bid,
  },
];

// --- LÓGICA DEL SCRIPT ---

/**
 * Calcula la mediana de un array de números.
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
 * Muestra el menú de ayuda
 */
function showHelp() {
  console.log(`
🤖 Oracle Reporter - AndeChain P2P Oracle

Uso:
  node oracle-reporter.mjs [comando] [opciones]

Comandos:
  report [precio]           Reporta un precio (automático desde APIs o manual)
  register                  Registra como reporter (staking mínimo)
  stake <cantidad>          Aumenta el stake
  unstake <cantidad>        Disminuye el stake
  status                    Muestra estado del reporter
  help                      Muestra esta ayuda

Ejemplos:
  node oracle-reporter.mjs report           # Obtiene precio de APIs y reporta
  node oracle-reporter.mjs report 6.91      # Reporta precio manual de 6.91 BOB/USD
  node oracle-reporter.mjs register         # Registra como reporter
  node oracle-reporter.mjs stake 1000       # Aumenta stake en 1000 ANDE
  node oracle-reporter.mjs status           # Ver estado del reporter

Variables de entorno:
  P2P_ORACLE_ADDRESS    Dirección del contrato P2POracle
  RELAYER_PRIVATE_KEY   Clave privada del reporter
  RPC_URL               URL del RPC (default: http://localhost:8545)
`);
}

/**
 * Obtiene precios de las APIs
 */
async function fetchPricesFromAPIs() {
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
    throw new Error('No se pudo obtener el precio de ninguna fuente');
  }

  return getMedian(prices);
}

/**
 * Transforma el precio para el contrato
 */
function transformPriceForContract(priceBOB) {
  // El contrato espera el precio de 1 BOB en USD, con 18 decimales
  const priceForContract = (1 / priceBOB) * 1e18;
  return BigInt(Math.round(priceForContract));
}

/**
 * Crea conexión al contrato
 */
function createContractConnection() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(REPORTER_PRIVATE_KEY, provider);
  const contract = new ethers.Contract(P2P_ORACLE_ADDRESS, P2P_ORACLE_ABI, wallet);

  return { provider, wallet, contract };
}

/**
 * Reporta un precio
 */
async function reportPrice(manualPrice = null) {
  try {
    console.log('🤖 Iniciando reporte de precio...');

    let priceBOB;
    if (manualPrice) {
      priceBOB = parseFloat(manualPrice);
      if (isNaN(priceBOB) || priceBOB <= 0) {
        throw new Error('Precio manual inválido');
      }
      console.log(`💰 Usando precio manual: ${priceBOB} BOB por USD`);
    } else {
      priceBOB = await fetchPricesFromAPIs();
      console.log(`⚖️ Mediana de precios calculada: ${priceBOB} BOB por USD`);
    }

    const priceBigInt = transformPriceForContract(priceBOB);
    console.log(`📐 Precio transformado para el contrato: ${priceBigInt.toString()}`);

    const { wallet, contract } = createContractConnection();

    console.log(`🔗 Conectando a la blockchain...`);
    console.log(`   - Reporter: ${wallet.address}`);
    console.log(`   - Contrato: ${P2P_ORACLE_ADDRESS}`);

    const tx = await contract.reportPrice(priceBigInt);
    console.log(`⏳ Transacción enviada. Hash: ${tx.hash}`);

    const receipt = await tx.wait();
    console.log(`✅ ¡Éxito! Transacción confirmada en el bloque ${receipt.blockNumber}`);

  } catch (error) {
    console.error(`🛑 Error al reportar precio: ${error.message}`);
    process.exit(1);
  }
}

/**
 * Registra como reporter
 */
async function registerReporter() {
  try {
    console.log('📝 Registrando como reporter...');

    const { wallet, contract } = createContractConnection();

    // Verificar si ya está registrado
    const reporterInfo = await contract.reporters(wallet.address);
    if (reporterInfo.isRegistered) {
      console.log('ℹ️  Ya estás registrado como reporter');
      console.log(`   - Stake actual: ${ethers.formatEther(reporterInfo.stake)} ANDE`);
      return;
    }

    const minStake = await contract.minStake();
    console.log(`💰 Stake mínimo requerido: ${ethers.formatEther(minStake)} ANDE`);

    const tx = await contract.register();
    console.log(`⏳ Transacción enviada. Hash: ${tx.hash}`);

    const receipt = await tx.wait();
    console.log(`✅ ¡Registro exitoso! Bloque: ${receipt.blockNumber}`);

  } catch (error) {
    console.error(`🛑 Error al registrar: ${error.message}`);
    process.exit(1);
  }
}

/**
 * Muestra el estado del reporter
 */
async function showStatus() {
  try {
    const { wallet, contract } = createContractConnection();

    const reporterInfo = await contract.reporters(wallet.address);
    const minStake = await contract.minStake();

    console.log(`📊 Estado del Reporter`);
    console.log(`======================`);
    console.log(`📍 Dirección: ${wallet.address}`);
    console.log(`📝 Registrado: ${reporterInfo.isRegistered ? 'Sí' : 'No'}`);

    if (reporterInfo.isRegistered) {
      console.log(`💰 Stake: ${ethers.formatEther(reporterInfo.stake)} ANDE`);
      console.log(`📅 Registro: ${new Date(Number(reporterInfo.registrationTime) * 1000).toLocaleString()}`);
      console.log(`🔄 Último epoch: ${reporterInfo.lastReportEpoch.toString()}`);
    }

    console.log(`💸 Stake mínimo: ${ethers.formatEther(minStake)} ANDE`);

  } catch (error) {
    console.error(`🛑 Error al obtener estado: ${error.message}`);
    process.exit(1);
  }
}

/**
 * Maneja el stake
 */
async function handleStake(amount, isIncrease = true) {
  try {
    const action = isIncrease ? 'aumentando' : 'disminuyendo';
    console.log(`💰 ${action.charAt(0).toUpperCase() + action.slice(1)} stake en ${amount} ANDE...`);

    const { wallet, contract } = createContractConnection();
    const amountWei = ethers.parseEther(amount);

    const tx = isIncrease
      ? await contract.increaseStake(amountWei)
      : await contract.decreaseStake(amountWei);

    console.log(`⏳ Transacción enviada. Hash: ${tx.hash}`);

    const receipt = await tx.wait();
    console.log(`✅ ¡Stake actualizado! Bloque: ${receipt.blockNumber}`);

  } catch (error) {
    console.error(`🛑 Error al actualizar stake: ${error.message}`);
    process.exit(1);
  }
}

/**
 * Función principal
 */
async function main() {
  const args = process.argv.slice(2);
  const command = args[0];

  switch (command) {
    case 'report':
      await reportPrice(args[1]);
      break;
    case 'register':
      await registerReporter();
      break;
    case 'stake':
      if (!args[1]) {
        console.error('❌ Debes especificar la cantidad de ANDE');
        process.exit(1);
      }
      await handleStake(args[1], true);
      break;
    case 'unstake':
      if (!args[1]) {
        console.error('❌ Debes especificar la cantidad de ANDE');
        process.exit(1);
      }
      await handleStake(args[1], false);
      break;
    case 'status':
      await showStatus();
      break;
    case 'help':
    case '--help':
    case '-h':
      showHelp();
      break;
    default:
      console.error('❌ Comando no reconocido');
      showHelp();
      process.exit(1);
  }
}

main().catch((error) => {
  console.error('Error inesperado:', error);
  process.exit(1);
});