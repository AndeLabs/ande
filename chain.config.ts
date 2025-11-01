/**
 * ANDE Chain Configuration
 * Configuración centralizada para el frontend
 * Esta es la "fuente única de verdad" para toda la información de la chain
 */

export const ANDE_CHAIN_CONFIG = {
  // ============================================
  // Red Information
  // ============================================
  network: {
    name: 'AndeChain',
    chainName: 'AndeChain Testnet',
    chainId: 6174,
    networkType: 'testnet',
    environment: 'production',
    dataAvailability: 'Celestia Mocha-4',
    consensus: 'Evolve Sequencer',
    executionClient: 'ev-reth (modified Reth)',
  },

  // ============================================
  // RPC Endpoints (Actualizar con IP pública si aplica)
  // ============================================
  rpc: {
    // LOCAL (Development)
    local: {
      http: 'http://localhost:8545',
      ws: 'ws://localhost:8546',
      engineApi: 'http://localhost:8551',
      evolveRpc: 'http://localhost:7331',
    },
    // PUBLIC (via Nginx Reverse Proxy)
    public: {
      http: 'http://localhost/rpc',
      ws: 'ws://localhost/ws',
      evolveRpc: 'http://localhost/evolve',
    },
    // PUBLIC INTERNET ACCESS (HTTPS - Production)
    // Domain: ande.network
    publicInternet: {
      http: 'https://rpc.ande.network',
      ws: 'wss://ws.ande.network',
      evolveRpc: 'https://api.ande.network/evolve',
    },
  },

  // ============================================
  // Block & Performance Parameters
  // ============================================
  blockchain: {
    blockTime: 2, // seconds
    blockTimeMs: 2000,
    averageBlockTime: 2,
    estimatedFinality: 30, // seconds (after Celestia inclusion)
    gasLimit: 30_000_000, // 30M per block
    baseFeePerGas: '1000000000', // 1 gwei (wei)
    maxTPS: 1000, // estimated max transactions per second
  },

  // ============================================
  // Contratos Desplegados
  // ============================================
  contracts: {
    tokens: {
      ANDE: {
        name: 'ANDE',
        symbol: 'ANDE',
        address: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
        implementation: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
        precompile: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
        decimals: 18,
        totalSupply: '100000000000000000000000000', // 100M ANDE with 18 decimals
        type: 'native+erc20', // Token Duality
        chainDeployed: 6174,
        deploymentBlock: 1,
        features: ['ERC1967Proxy', 'TokenDuality', 'Precompile', 'AccessControl'],
        interfaces: ['ERC20', 'IERC1967', 'IAccessControl', 'ITokenDuality'],
      },
    },
    governance: {
      // Ready to deploy
      AndeGovernor: {
        status: 'ready',
        address: null,
        description: 'Governor with enhanced security extensions',
      },
      AndeTimelockController: {
        status: 'ready',
        address: null,
        description: 'Timelock for governance security',
      },
    },
    staking: {
      // Ready to deploy
      VotingEscrow: {
        status: 'ready',
        address: null,
        description: 'veANDE vote-escrowed token',
      },
      GaugeController: {
        status: 'ready',
        address: null,
        description: 'Liquidity gauge controller',
      },
    },
    dex: {
      // Ready to deploy
      AndeSwapFactory: {
        status: 'ready',
        address: null,
        description: 'DEX Factory (V2 + V3)',
      },
    },
    bridge: {
      // Ready to deploy
      AndeChainBridge: {
        status: 'ready',
        address: null,
        description: 'Cross-chain bridge (xERC20)',
      },
    },
    accountAbstraction: {
      // Ready to deploy
      EntryPoint: {
        status: 'ready',
        address: null,
        description: 'ERC-4337 Entry Point',
      },
    },
  },

  // ============================================
  // Default Accounts (Hardhat)
  // ============================================
  accounts: {
    admin: {
      address: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      name: 'Admin Account',
      balance: '10000000000000000000000', // 10,000 ETH
      roles: ['admin', 'minter', 'deployer'],
      privateKey: '0xac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f02d45b19e8bfb81', // ⚠️ ONLY FOR TESTNET
    },
    user1: {
      address: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
      name: 'Test User 1',
      balance: '10000000000000000000000',
    },
    user2: {
      address: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
      name: 'Test User 2',
      balance: '10000000000000000000000',
    },
    user3: {
      address: '0x1234567890123456789012345678901234567890',
      name: 'Test User 3',
      balance: '10000000000000000000000',
    },
  },

  // ============================================
  // Monitoring & Analytics
  // ============================================
  monitoring: {
    grafana: {
      url: 'http://localhost:3000',
      publicUrl: 'https://api.ande.network/grafana',
      credentials: {
        username: 'admin',
        password: 'andechain-admin-2025',
      },
    },
    prometheus: {
      url: 'http://localhost:9090',
      publicUrl: 'https://api.ande.network/prometheus',
    },
    loki: {
      url: 'http://localhost:3100',
      publicUrl: 'https://api.ande.network/loki',
    },
    cadvisor: {
      url: 'http://localhost:8080',
      publicUrl: 'https://api.ande.network/cadvisor',
    },
  },

  // ============================================
  // API Endpoints
  // ============================================
  api: {
    blockExplorer: 'http://localhost/api/blocks',
    transactions: 'http://localhost/api/transactions',
    status: 'http://localhost/api/status',
    info: 'http://localhost/api/info',
    metrics: {
      blockHeight: 'http://localhost:9090/api/v1/query?query=eth_blockNumber',
      gasUsage: 'http://localhost:9090/api/v1/query?query=eth_gasUsed',
    },
  },

  // ============================================
  // Asset Information
  // ============================================
  assets: {
    ANDE: {
      symbol: 'ANDE',
      name: 'ANDE Token',
      decimals: 18,
      address: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
      icon: '/assets/ande-token.svg',
      color: '#8B5CF6', // Purple
      coingeckoId: null, // Add after listing
      description: 'Native token of ANDE Chain with token duality',
    },
    ETH: {
      symbol: 'ETH',
      name: 'Ethereum (Test)',
      decimals: 18,
      isNative: true,
      icon: '/assets/eth.svg',
      color: '#627EEA',
      description: 'Test ETH for gas fees',
    },
  },

  // ============================================
  // Feature Flags
  // ============================================
  features: {
    tokenDuality: true,
    governance: false, // Requires deployment
    staking: false, // Requires deployment
    swap: false, // Requires deployment
    bridge: false, // Requires deployment
    accountAbstraction: false, // Requires deployment
    nftMinting: false,
  },

  // ============================================
  // Error Handling & Messages
  // ============================================
  errors: {
    chainMismatch: 'Please switch to AndeChain (Chain ID: 6174)',
    accountNotConnected: 'Please connect your wallet',
    insufficientBalance: 'Insufficient balance',
    contractNotDeployed: 'Contract not yet deployed. Check chain.config.ts',
  },

  // ============================================
  // Transaction Settings
  // ============================================
  transactions: {
    defaultGasLimit: 100_000,
    estimatedGasMultiplier: 1.2,
    maxSlippage: 0.5, // 0.5% for swaps
    confirmationBlocks: 1,
    waitForFinality: true,
  },

  // ============================================
  // Constants
  // ============================================
  constants: {
    ZERO_ADDRESS: '0x0000000000000000000000000000000000000000',
    MAX_UINT256: '115792089237316195423570985008687907853269984665640564039457584007913129639935',
    MIN_UINT256: '0',
    PRECISION: 18,
  },

  // ============================================
  // Helper Functions
  // ============================================
  helpers: {
    /**
     * Get RPC URL based on environment
     */
    getRpcUrl: (env: 'local' | 'public' | 'publicInternet' = 'local') => {
      return ANDE_CHAIN_CONFIG.rpc[env].http;
    },

    /**
     * Get WebSocket URL
     */
    getWsUrl: (env: 'local' | 'public' | 'publicInternet' = 'local') => {
      return ANDE_CHAIN_CONFIG.rpc[env].ws;
    },

    /**
     * Check if contract is deployed
     */
    isContractDeployed: (contractName: string): boolean => {
      const contracts = Object.values(ANDE_CHAIN_CONFIG.contracts).flat() as any[];
      const contract = contracts.find((c) => c.name === contractName);
      return contract ? contract.address !== null : false;
    },

    /**
     * Get contract address
     */
    getContractAddress: (contractName: string): string | null => {
      const contracts = Object.values(ANDE_CHAIN_CONFIG.contracts).flat() as any[];
      const contract = contracts.find((c) => c.address);
      return contract?.address || null;
    },

    /**
     * Format token amount
     */
    formatTokenAmount: (amount: string | number, decimals: number = 18): string => {
      if (!amount) return '0';
      const num = typeof amount === 'string' ? parseFloat(amount) : amount;
      const divisor = Math.pow(10, decimals);
      return (num / divisor).toFixed(6);
    },

    /**
     * Parse token amount to wei
     */
    parseTokenAmount: (amount: string | number, decimals: number = 18): string => {
      if (!amount) return '0';
      const num = typeof amount === 'string' ? parseFloat(amount) : amount;
      const multiplier = Math.pow(10, decimals);
      return Math.floor(num * multiplier).toString();
    },
  },

  // ============================================
  // Version & Metadata
  // ============================================
  metadata: {
    version: '1.0.0',
    lastUpdated: '2025-10-30',
    status: 'production',
    environment: 'testnet',
    website: 'https://andelabs.io',
    docs: 'https://docs.andelabs.io',
    github: 'https://github.com/andelabs',
  },
};

/**
 * Export type for TypeScript support
 */
export type AndeChainConfig = typeof ANDE_CHAIN_CONFIG;

/**
 * Hook-friendly exports for React
 */
export const useAndeChain = () => ANDE_CHAIN_CONFIG;

export const useChainRpc = (env: 'local' | 'public' | 'publicInternet' = 'local') => ({
  http: ANDE_CHAIN_CONFIG.rpc[env].http,
  ws: ANDE_CHAIN_CONFIG.rpc[env].ws,
});

export const useTokens = () => ANDE_CHAIN_CONFIG.assets;

export const useContracts = () => ANDE_CHAIN_CONFIG.contracts;

export const useMonitoring = () => ANDE_CHAIN_CONFIG.monitoring;

/**
 * Default export
 */
export default ANDE_CHAIN_CONFIG;
