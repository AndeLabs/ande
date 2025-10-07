import { BundlerConfig, ServerConfig, LoggerConfig, NetworkConfig, MempoolConfig } from '../types';

// Configuración por defecto para AndeChain
export const DEFAULT_NETWORK_CONFIG: NetworkConfig = {
  chainId: "31337", // Local development
  name: "andechain-local",
  rpcUrl: "http://localhost:8545",
  blockTimeMs: 2000, // 2 segundos por bloque
  gasLimit: 30000000,
  entryPointAddress: "0x4337084d9e255ff0702461cf8895ce9e3b5ff108",
  andeTokenAddress: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  abobTokenAddress: "0x5FbDB2315678afecb367f032d93F642f64180aa3"
};

// Configuración de desarrollo
export const DEVELOPMENT_CONFIG: Partial<BundlerConfig> = {
  rpcUrl: "http://localhost:8545",
  entryPointAddress: DEFAULT_NETWORK_CONFIG.entryPointAddress,
  beneficiaryAddress: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  maxBundleSize: 10,
  minBundleSize: 1,
  bundleIntervalMs: 5000, // 5 segundos
  gasMultiplier: 1.1,
  maxGasPrice: "100000000000", // 100 gwei
  minPriorityFee: "1000000000", // 1 gwei
  mnemonic: "test test test test test test test test test test test junk"
};

// Configuración de producción
export const PRODUCTION_CONFIG: Partial<BundlerConfig> = {
  rpcUrl: process.env.RPC_URL || "https://rpc.andechain.org",
  entryPointAddress: DEFAULT_NETWORK_CONFIG.entryPointAddress,
  beneficiaryAddress: process.env.BENEFICIARY_ADDRESS || "",
  maxBundleSize: 50,
  minBundleSize: 3,
  bundleIntervalMs: 3000, // 3 segundos
  gasMultiplier: 1.05,
  maxGasPrice: "10000000000", // 10 gwei
  minPriorityFee: "100000000", // 0.1 gwei
  privateKey: process.env.PRIVATE_KEY
};

// Configuración del servidor
export const DEFAULT_SERVER_CONFIG: ServerConfig = {
  host: "0.0.0.0",
  port: parseInt(process.env.PORT || "3000"),
  corsOrigins: process.env.CORS_ORIGINS?.split(",") || ["http://localhost:3000", "http://localhost:9002"],
  rateLimitWindowMs: 60000, // 1 minuto
  rateLimitMax: 100, // 100 requests por minuto
  securityHeaders: {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "X-XSS-Protection": "1; mode=block",
    "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
    "Content-Security-Policy": "default-src 'self'"
  },
  healthCheckPath: "/health",
  metricsPath: "/metrics"
};

// Configuración de logging
export const DEFAULT_LOGGER_CONFIG: LoggerConfig = {
  level: (process.env.LOG_LEVEL as any) || "info",
  format: "combined",
  transports: ["console", "file"],
  file: "logs/bundler.log",
  maxSize: "10m",
  maxFiles: 5
};

// Configuración de mempool
export const DEFAULT_MEMPOOL_CONFIG: MempoolConfig = {
  maxSize: 1000,
  maxUserOpPerSender: 10,
  maxUserOpPerPaymaster: 100,
  maxGasPrice: "100000000000", // 100 gwei
  minPriorityFee: "1000000000", // 1 gwei
  ttlMs: 300000 // 5 minutos
};

// Configuración completa
export function createBundlerConfig(env: "development" | "production" = "development"): BundlerConfig {
  const baseConfig = env === "development" ? DEVELOPMENT_CONFIG : PRODUCTION_CONFIG;

  return {
    rpcUrl: process.env.RPC_URL || baseConfig.rpcUrl!,
    entryPointAddress: process.env.ENTRY_POINT_ADDRESS || baseConfig.entryPointAddress!,
    beneficiaryAddress: process.env.BENEFICIARY_ADDRESS || baseConfig.beneficiaryAddress!,
    maxBundleSize: parseInt(process.env.MAX_BUNDLE_SIZE || baseConfig.maxBundleSize!.toString()),
    minBundleSize: parseInt(process.env.MIN_BUNDLE_SIZE || baseConfig.minBundleSize!.toString()),
    bundleIntervalMs: parseInt(process.env.BUNDLE_INTERVAL_MS || baseConfig.bundleIntervalMs!.toString()),
    gasMultiplier: parseFloat(process.env.GAS_MULTIPLIER || baseConfig.gasMultiplier!.toString()),
    maxGasPrice: process.env.MAX_GAS_PRICE || baseConfig.maxGasPrice!,
    minPriorityFee: process.env.MIN_PRIORITY_FEE || baseConfig.minPriorityFee!,
    mnemonic: process.env.MNEMONIC || baseConfig.mnemonic,
    privateKey: process.env.PRIVATE_KEY || baseConfig.privateKey
  };
}

// Configuración de red específica por entorno
export function createNetworkConfig(env: "development" | "production" = "development"): NetworkConfig {
  if (env === "production") {
    return {
      ...DEFAULT_NETWORK_CONFIG,
      chainId: process.env.CHAIN_ID || "1",
      name: process.env.NETWORK_NAME || "andechain-mainnet",
      rpcUrl: process.env.RPC_URL || "https://rpc.andechain.org",
      entryPointAddress: process.env.ENTRY_POINT_ADDRESS || DEFAULT_NETWORK_CONFIG.entryPointAddress,
      andeTokenAddress: process.env.ANDE_TOKEN_ADDRESS || "",
      abobTokenAddress: process.env.ABOB_TOKEN_ADDRESS || ""
    };
  }

  return DEFAULT_NETWORK_CONFIG;
}

// Validación de configuración
export function validateConfig(config: BundlerConfig): void {
  if (!config.rpcUrl) {
    throw new Error("RPC URL is required");
  }

  if (!config.entryPointAddress) {
    throw new Error("EntryPoint address is required");
  }

  if (!config.beneficiaryAddress) {
    throw new Error("Beneficiary address is required");
  }

  if (!config.privateKey && !config.mnemonic) {
    throw new Error("Either private key or mnemonic is required");
  }

  if (config.maxBundleSize <= 0 || config.maxBundleSize > 100) {
    throw new Error("Max bundle size must be between 1 and 100");
  }

  if (config.minBundleSize <= 0 || config.minBundleSize > config.maxBundleSize) {
    throw new Error("Min bundle size must be between 1 and max bundle size");
  }

  if (config.bundleIntervalMs <= 0) {
    throw new Error("Bundle interval must be positive");
  }

  if (config.gasMultiplier <= 1 || config.gasMultiplier > 2) {
    throw new Error("Gas multiplier must be between 1 and 2");
  }
}

// Variables de entorno requeridas
export const REQUIRED_ENV_VARS = [
  "RPC_URL",
  "ENTRY_POINT_ADDRESS",
  "BENEFICIARY_ADDRESS"
];

// Variables de entorno opcionales
export const OPTIONAL_ENV_VARS = [
  "PRIVATE_KEY",
  "MNEMONIC",
  "MAX_BUNDLE_SIZE",
  "MIN_BUNDLE_SIZE",
  "BUNDLE_INTERVAL_MS",
  "GAS_MULTIPLIER",
  "MAX_GAS_PRICE",
  "MIN_PRIORITY_FEE",
  "LOG_LEVEL",
  "PORT",
  "CORS_ORIGINS"
];

// Configuración de ejemplo para .env
export const ENV_EXAMPLE = `
# Required Configuration
RPC_URL=http://localhost:8545
ENTRY_POINT_ADDRESS=0x4337084d9e255ff0702461cf8895ce9e3b5ff108
BENEFICIARY_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# Optional Configuration
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
MNEMONIC=test test test test test test test test test test test junk

# Bundle Configuration
MAX_BUNDLE_SIZE=10
MIN_BUNDLE_SIZE=1
BUNDLE_INTERVAL_MS=5000
GAS_MULTIPLIER=1.1

# Gas Configuration
MAX_GAS_PRICE=100000000000
MIN_PRIORITY_FEE=1000000000

# Server Configuration
PORT=3000
LOG_LEVEL=info
CORS_ORIGINS=http://localhost:3000,http://localhost:9002

# Token Addresses (Production)
ANDE_TOKEN_ADDRESS=0x...
ABOB_TOKEN_ADDRESS=0x...
`;