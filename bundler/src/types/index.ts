import { BigNumberish, BytesLike } from "ethers";

// Interfaz para UserOperation compatible con ERC-4337
export interface UserOperation {
  sender: string;
  nonce: BigNumberish;
  initCode: BytesLike;
  callData: BytesLike;
  callGasLimit: BigNumberish;
  verificationGasLimit: BigNumberish;
  preVerificationGas: BigNumberish;
  maxFeePerGas: BigNumberish;
  maxPriorityFeePerGas: BigNumberish;
  paymaster: string;
  paymasterVerificationGasLimit: BytesLike;
  paymasterPostOpGasLimit: BytesLike;
  paymasterData: BytesLike;
  signature: BytesLike;
}

// Interfaz para PackedUserOperation
export interface PackedUserOperation {
  sender: string;
  nonce: BigNumberish;
  initCode: BytesLike;
  callData: BytesLike;
  accountGasLimits: BytesLike;
  preVerificationGas: BigNumberish;
  gasFees: BytesLike;
  paymasterAndData: BytesLike;
  signature: BytesLike;
}

// Configuración del Bundler
export interface BundlerConfig {
  rpcUrl: string;
  entryPointAddress: string;
  beneficiaryAddress: string;
  maxBundleSize: number;
  minBundleSize: number;
  bundleIntervalMs: number;
  gasMultiplier: number;
  maxGasPrice: string;
  minPriorityFee: string;
  mnemonic?: string;
  privateKey?: string;
}

// Estadísticas del Bundler
export interface BundlerStats {
  totalBundles: number;
  totalUserOps: number;
  successfulBundles: number;
  failedBundles: number;
  averageBundleSize: number;
  averageProcessingTime: number;
  lastBundleTimestamp: number;
}

// Estado de UserOperation
export enum UserOpStatus {
  PENDING = "pending",
  INCLUDED = "included",
  REVERTED = "reverted",
  FAILED = "failed"
}

// Información de UserOperation en mempool
export interface UserOpInfo {
  userOp: UserOperation;
  userOpHash: string;
  status: UserOpStatus;
  submitTime: number;
  expireTime?: number;
  gasPrice: string;
  sender: string;
  nonce: string;
  target?: string;
  paymaster?: string;
}

// Resultado del procesamiento de UserOperation
export interface UserOpResult {
  userOpHash: string;
  success: boolean;
  reason?: string;
  gasUsed?: string;
  actualGasCost?: string;
  logs?: any[];
}

// Resultado de bundle
export interface BundleResult {
  bundleHash: string;
  transactionHash: string;
  blockNumber: number;
  gasUsed: string;
  actualGasCost: string;
  userOpResults: UserOpResult[];
  success: boolean;
  reason?: string;
}

// Eventos del EntryPoint
export interface UserOperationEvent {
  userOpHash: string;
  sender: string;
  paymaster?: string;
  nonce: string;
  success: boolean;
  actualGasCost: string;
  actualGasUsed: string;
}

// Configuración de red
export interface NetworkConfig {
  chainId: string;
  name: string;
  rpcUrl: string;
  blockTimeMs: number;
  gasLimit?: number;
  entryPointAddress: string;
  andeTokenAddress: string;
  abobTokenAddress: string;
}

// Mempool configuration
export interface MempoolConfig {
  maxSize: number;
  maxUserOpPerSender: number;
  maxUserOpPerPaymaster: number;
  maxGasPrice: string;
  minPriorityFee: string;
  ttlMs: number;
}

// Opciones de estimación de gas
export interface GasEstimationOptions {
  multiplier: number;
  maxGasPrice: string;
  minPriorityFee: string;
  bufferPercent: number;
}

// Paymaster data
export interface PaymasterData {
  validUntil?: number;
  validAfter?: number;
  signature: string;
}

// Log levels
export enum LogLevel {
  ERROR = "error",
  WARN = "warn",
  INFO = "info",
  DEBUG = "debug"
}

// Configuración de logging
export interface LoggerConfig {
  level: LogLevel;
  format: string;
  transports: string[];
  file?: string;
  maxSize?: string;
  maxFiles?: number;
}

// Headers de seguridad
export interface SecurityHeaders {
  [key: string]: string;
}

// Configuración del servidor
export interface ServerConfig {
  host: string;
  port: number;
  corsOrigins: string[];
  rateLimitWindowMs: number;
  rateLimitMax: number;
  securityHeaders: SecurityHeaders;
  healthCheckPath: string;
  metricsPath: string;
}

// Métricas del sistema
export interface SystemMetrics {
  uptime: number;
  memoryUsage: NodeJS.MemoryUsage;
  cpuUsage: NodeJS.CpuUsage;
  activeConnections: number;
  requestsPerSecond: number;
  errorRate: number;
}

// Response types para API
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: any;
  };
  timestamp: number;
}

// Batch request
export interface BatchRequest {
  jsonrpc: "2.0";
  id: string | number;
  method: string;
  params: any[];
}

// Batch response
export interface BatchResponse {
  jsonrpc: "2.0";
  id: string | number | null;
  result?: any;
  error?: {
    code: number;
    message: string;
    data?: any;
  };
}