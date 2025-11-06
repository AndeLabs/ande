// 🔗 AndeChain Frontend Configuration
// Usado para www.ande.network - copia esto a tu frontend

export const ANDE_CHAIN_CONFIG = {
  // ==========================================
  // CHAIN IDENTIFICATION
  // ==========================================
  chainId: 6174,
  chainIdHex: "0x181E",
  chainName: "AndeChain Testnet",
  networkType: "testnet",
  status: "active",
  
  // ==========================================
  // RPC ENDPOINTS (CRÍTICO PARA LA WEB)
  // ==========================================
  rpc: {
    // Endpoint primario (HTTPS requerido para web)
    http: "https://rpc.ande.network",
    
    // WebSocket para subscripciones en tiempo real
    ws: "wss://ws.ande.network",
    
    // Fallback si DNS falla (usar IP pública)
    fallback: "http://189.28.81.202:8545",
    
    // Para desarrollo local
    local: "http://localhost:8545",
    localWs: "ws://localhost:8546"
  },

  // ==========================================
  // SERVICIOS PÚBLICOS
  // ==========================================
  services: {
    explorer: "https://explorer.ande.network",
    faucet: "https://faucet.ande.network",
    grafana: "https://grafana.ande.network",
    monitoring: "https://status.ande.network",
    docs: "https://docs.ande.network"
  },

  // ==========================================
  // TOKEN NATIVO (ANDE)
  // ==========================================
  nativeCurrency: {
    name: "ANDE",
    symbol: "ANDE",
    decimals: 18,
    // Precompilado en la chain (no es un contrato ERC20 normal)
    precompile: "0x00000000000000000000000000000000000000FD"
  },

  // ==========================================
  // BLOCKCHAIN CHARACTERISTICS
  // ==========================================
  blockchain: {
    blockTime: 2000, // milliseconds
    blockTimeSeconds: 2,
    consensus: "Evolve Sequencer",
    dataAvailability: "Celestia Mocha-4",
    type: "Sovereign Rollup",
    architecture: "EVM-compatible"
  },

  // ==========================================
  // CARACTERÍSTICAS ESPECIALES
  // ==========================================
  features: {
    tokenDuality: true,        // Native + ERC20 simultáneamente
    parallelEvm: true,         // Ejecución paralela de txs
    adaptiveBlockTime: true,   // Ajusta según carga
    lazyMode: true,            // Blocks bajo demanda
    celestiaDA: true           // Data Availability en Celestia
  },

  // ==========================================
  // METAMASK NETWORK CONFIG
  // Usar en: window.ethereum.request({ method: 'wallet_addEthereumChain', ... })
  // ==========================================
  metamaskConfig: {
    chainId: "0x181E",
    chainName: "AndeChain Testnet",
    nativeCurrency: {
      name: "ANDE",
      symbol: "ANDE",
      decimals: 18
    },
    rpcUrls: ["https://rpc.ande.network"],
    blockExplorerUrls: ["https://explorer.ande.network"],
    iconUrls: ["https://www.ande.network/icon.png"]
  },

  // ==========================================
  // WAGMI/VIEM CONFIGURATION
  // Para aplicaciones React/Vue/Web3
  // ==========================================
  viemChain: {
    id: 6174,
    name: "AndeChain Testnet",
    nativeCurrency: {
      decimals: 18,
      name: "ANDE",
      symbol: "ANDE"
    },
    rpcUrls: {
      default: {
        http: ["https://rpc.ande.network"],
        webSocket: ["wss://ws.ande.network"]
      },
      public: {
        http: ["https://rpc.ande.network"],
        webSocket: ["wss://ws.ande.network"]
      }
    },
    blockExplorers: {
      default: { name: "Explorer", url: "https://explorer.ande.network" }
    },
    testnet: true
  },

  // ==========================================
  // CONTRATO PRECOMPILADO ANDE
  // ==========================================
  contracts: {
    ANDE: {
      address: "0x00000000000000000000000000000000000000FD",
      type: "precompile",
      description: "Native ANDE token (no ERC20, es el token de la chain)",
      interface: "ANDETokenDuality",
      deployed: true
    }
  },

  // ==========================================
  // INFORMACIÓN PARA USUARIOS
  // ==========================================
  userInfo: {
    description: "AndeChain es una red soberana basada en Evolve",
    website: "https://www.ande.network",
    docs: "https://docs.ande.network",
    github: "https://github.com/ande-labs",
    twitter: "https://twitter.com/andelabs",
    discord: "https://discord.gg/ande"
  },

  // ==========================================
  // LÍMITES Y PARÁMETROS
  // ==========================================
  parameters: {
    maxGasPerBlock: 30000000,
    minGasPrice: 1000000000, // 1 gwei
    targetGasPerBlock: 15000000,
    maxTxSize: 10485760 // 10 MB
  },

  // ==========================================
  // ENDPOINTS DISPONIBLES (MÉTODOS RPC)
  // ==========================================
  supportedMethods: [
    // Standard Ethereum JSON-RPC
    "eth_blockNumber",
    "eth_chainId",
    "eth_gasPrice",
    "eth_getBalance",
    "eth_sendTransaction",
    "eth_sign",
    "eth_accounts",
    
    // Subscriptions (WebSocket solo)
    "eth_subscribe",
    "eth_unsubscribe",
    
    // Additional
    "net_version",
    "net_peerCount",
    "web3_clientVersion"
  ],

  // ==========================================
  // VERIFICACIÓN DE SALUD
  // ==========================================
  healthCheck: {
    endpoint: "https://rpc.ande.network",
    method: "eth_blockNumber",
    expectedResponse: "number",
    timeout: 5000 // ms
  },

  // ==========================================
  // LÍMITES DE RATE LIMITING
  // (Información para usuarios)
  // ==========================================
  rateLimits: {
    rpc: {
      requestsPerSecond: 100,
      burst: 200,
      note: "Límite global"
    },
    faucet: {
      requestsPerMinute: 5,
      cooldownPerAddress: 86400, // 24 horas
      maxAmountPerRequest: 10 // ANDE
    }
  }
};

// ==========================================
// EXPORTS PARA DIFERENTES FRAMEWORKS
// ==========================================

// Para wagmi/viem (React)
export const andechainTestnet = ANDE_CHAIN_CONFIG.viemChain;

// Para MetaMask/ethers.js
export const getAddNetworkParams = () => ({
  method: 'wallet_addEthereumChain',
  params: [ANDE_CHAIN_CONFIG.metamaskConfig]
});

// RPC URLs simples
export const RPC_URLS = {
  http: ANDE_CHAIN_CONFIG.rpc.http,
  ws: ANDE_CHAIN_CONFIG.rpc.ws,
  fallback: ANDE_CHAIN_CONFIG.rpc.fallback
};

// Export todo para imports
export default ANDE_CHAIN_CONFIG;
