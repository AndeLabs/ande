import { ethers } from 'ethers';
import { EventEmitter } from 'events';
import {
  UserOperation,
  PackedUserOperation,
  UserOpInfo,
  UserOpResult,
  BundleResult,
  UserOpStatus,
  BundlerConfig,
  MempoolConfig,
  GasEstimationOptions,
  UserOperationEvent
} from '../types';
import { Logger } from '../utils/logger';

// ABI del EntryPoint (simplificado)
const ENTRYPOINT_ABI = [
  "function handleOps(PackedUserOperation[] calldata ops, address payable beneficiary) external",
  "function getUserOpHash(PackedUserOperation calldata userOp) external view returns (bytes32)",
  "function simulateValidation(PackedUserOperation calldata userOp) external returns (bytes memory returnData)",
  "event UserOperationEvent(bytes32 indexed userOpHash, address indexed sender, address indexed paymaster, uint256 nonce, bool success, uint256 actualGasCost, uint256 actualGasUsed)"
];

export class Bundler extends EventEmitter {
  private provider: ethers.JsonRpcProvider;
  private wallet: ethers.Wallet;
  private entryPoint: ethers.Contract;
  private config: BundlerConfig;
  private mempoolConfig: MempoolConfig;
  private logger: Logger;
  private mempool: Map<string, UserOpInfo> = new Map();
  private isRunning: boolean = false;
  private bundleInterval: NodeJS.Timeout | null = null;
  private currentGasPrice: string = "0";
  private stats = {
    totalBundles: 0,
    successfulBundles: 0,
    failedBundles: 0,
    totalUserOps: 0,
    totalProcessingTime: 0
  };

  constructor(
    provider: ethers.JsonRpcProvider,
    wallet: ethers.Wallet,
    config: BundlerConfig,
    mempoolConfig: MempoolConfig,
    logger: Logger
  ) {
    super();
    this.provider = provider;
    this.wallet = wallet.connect(provider);
    this.config = config;
    this.mempoolConfig = mempoolConfig;
    this.logger = logger;

    this.entryPoint = new ethers.Contract(
      config.entryPointAddress,
      ENTRYPOINT_ABI,
      this.wallet
    );

    // Suscribirse a eventos del EntryPoint
    this.setupEventListeners();
  }

  /**
   * Inicia el bundler
   */
  public async start(): Promise<void> {
    if (this.isRunning) {
      this.logger.warn('Bundler is already running');
      return;
    }

    this.isRunning = true;
    this.logger.info('Starting AndeChain Account Abstraction Bundler');

    // Iniciar actualización de gas price
    this.startGasPriceUpdates();

    // Iniciar procesamiento de bundles
    this.startBundleProcessing();

    this.logger.info('Bundler started successfully');
    this.emit('started');
  }

  /**
   * Detiene el bundler
   */
  public async stop(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    this.isRunning = false;

    if (this.bundleInterval) {
      clearInterval(this.bundleInterval);
      this.bundleInterval = null;
    }

    this.logger.info('Bundler stopped');
    this.emit('stopped');
  }

  /**
   * Añade una UserOperation al mempool
   */
  public async addUserOp(userOp: UserOperation): Promise<string> {
    try {
      // Validar UserOperation
      await this.validateUserOp(userOp);

      // Calcular hash
      const userOpHash = await this.getUserOpHash(userOp);

      // Verificar si ya existe
      if (this.mempool.has(userOpHash)) {
        throw new Error('UserOperation already exists in mempool');
      }

      // Verificar tamaño del mempool
      if (this.mempool.size >= this.mempoolConfig.maxSize) {
        await this.evictExpiredUserOps();
        if (this.mempool.size >= this.mempoolConfig.maxSize) {
          throw new Error('Mempool is full');
        }
      }

      // Verificar límites por sender y paymaster
      await this.checkUserOpLimits(userOp);

      // Estimar gas y verificar precio
      const gasEstimate = await this.estimateUserOpGas(userOp);
      if (BigInt(gasEstimate.maxFeePerGas) > BigInt(this.mempoolConfig.maxGasPrice)) {
        throw new Error('Gas price too high');
      }

      // Añadir al mempool
      const userOpInfo: UserOpInfo = {
        userOp,
        userOpHash,
        status: UserOpStatus.PENDING,
        submitTime: Date.now(),
        expireTime: Date.now() + this.mempoolConfig.ttlMs,
        gasPrice: gasEstimate.maxFeePerGas,
        sender: userOp.sender,
        nonce: userOp.nonce.toString(),
        paymaster: userOp.paymaster !== ethers.ZeroAddress ? userOp.paymaster : undefined
      };

      this.mempool.set(userOpHash, userOpInfo);
      this.logger.userOpReceived(userOpHash, userOp.sender, gasEstimate.maxFeePerGas);

      this.emit('userOpAdded', userOpInfo);
      return userOpHash;

    } catch (error) {
      this.logger.error('Failed to add UserOperation', error);
      throw error;
    }
  }

  /**
   * Obtiene información de una UserOperation
   */
  public getUserOp(userOpHash: string): UserOpInfo | undefined {
    return this.mempool.get(userOpHash);
  }

  /**
   * Obtiene todas las UserOperations pendientes
   */
  public getPendingUserOps(): UserOpInfo[] {
    return Array.from(this.mempool.values())
      .filter(op => op.status === UserOpStatus.PENDING)
      .sort((a, b) => a.submitTime - b.submitTime);
  }

  /**
   * Elimina una UserOperation del mempool
   */
  public removeUserOp(userOpHash: string): boolean {
    const removed = this.mempool.delete(userOpHash);
    if (removed) {
      this.emit('userOpRemoved', userOpHash);
    }
    return removed;
  }

  /**
   * Simula una UserOperation sin ejecutarla
   */
  public async simulateUserOp(userOp: UserOperation): Promise<any> {
    try {
      const packedUserOp = this.packUserOp(userOp);
      const result = await this.entryPoint.simulateValidation.staticCall(packedUserOp);
      return result;
    } catch (error) {
      this.logger.error('Simulation failed', error);
      throw error;
    }
  }

  /**
   * Estima el gas para una UserOperation
   */
  public async estimateUserOpGas(userOp: UserOperation): Promise<any> {
    try {
      // Simular primero para obtener estimaciones base
      const simulationResult = await this.simulateUserOp(userOp);

      // Aplicar multiplicador y buffers
      const gasMultiplier = this.config.gasMultiplier;
      const currentGasPrice = await this.provider.getFeeData();

      return {
        callGasLimit: Math.floor(Number(userOp.callGasLimit) * gasMultiplier),
        verificationGasLimit: Math.floor(Number(userOp.verificationGasLimit) * gasMultiplier),
        preVerificationGas: Math.floor(Number(userOp.preVerificationGas) * gasMultiplier),
        maxFeePerGas: Math.max(
          Math.floor(Number(currentGasPrice.maxFeePerGas) * gasMultiplier),
          Number(this.mempoolConfig.minPriorityFee)
        ).toString(),
        maxPriorityFeePerGas: Math.max(
          Math.floor(Number(currentGasPrice.maxPriorityFeePerGas) * gasMultiplier),
          Number(this.mempoolConfig.minPriorityFee)
        ).toString()
      };
    } catch (error) {
      this.logger.error('Gas estimation failed', error);
      throw error;
    }
  }

  /**
   * Valida una UserOperation
   */
  private async validateUserOp(userOp: UserOperation): Promise<void> {
    // Validaciones básicas
    if (!userOp.sender || userOp.sender === ethers.ZeroAddress) {
      throw new Error('Invalid sender address');
    }

    if (!userOp.initCode || userOp.initCode.length === 0) {
      // Verificar que el sender tenga código
      const code = await this.provider.getCode(userOp.sender);
      if (code === '0x') {
        throw new Error('Sender is not deployed');
      }
    }

    if (!userOp.callData || userOp.callData.length === 0) {
      throw new Error('Invalid call data');
    }

    // Validar límites de gas
    if (Number(userOp.callGasLimit) <= 0 || Number(userOp.callGasLimit) > 10000000) {
      throw new Error('Invalid call gas limit');
    }

    if (Number(userOp.verificationGasLimit) <= 0 || Number(userOp.verificationGasLimit) > 5000000) {
      throw new Error('Invalid verification gas limit');
    }

    // Simular validación
    try {
      await this.simulateUserOp(userOp);
    } catch (error) {
      throw new Error(`Validation failed: ${error}`);
    }
  }

  /**
   * Convierte UserOperation a PackedUserOperation
   */
  private packUserOp(userOp: UserOperation): PackedUserOperation {
    const accountGasLimits = ethers.solidityPacked(
      ['uint128', 'uint128'],
      [userOp.callGasLimit, userOp.verificationGasLimit]
    );

    const gasFees = ethers.solidityPacked(
      ['uint128', 'uint128'],
      [userOp.maxFeePerGas, userOp.maxPriorityFeePerGas]
    );

    let paymasterAndData = ethers.solidityPacked(
      ['address', 'uint256', 'bytes'],
      [userOp.paymaster || ethers.ZeroAddress, 0, '0x']
    );

    if (userOp.paymaster && userOp.paymaster !== ethers.ZeroAddress && userOp.paymasterData) {
      paymasterAndData = ethers.solidityPacked(
        ['address', 'uint256', 'bytes'],
        [userOp.paymaster, 0, userOp.paymasterData]
      );
    }

    return {
      sender: userOp.sender,
      nonce: userOp.nonce,
      initCode: userOp.initCode,
      callData: userOp.callData,
      accountGasLimits,
      preVerificationGas: userOp.preVerificationGas,
      gasFees,
      paymasterAndData,
      signature: userOp.signature
    };
  }

  /**
   * Calcula el hash de una UserOperation
   */
  private async getUserOpHash(userOp: UserOperation): Promise<string> {
    const packedUserOp = this.packUserOp(userOp);
    return await this.entryPoint.getUserOpHash(packedUserOp);
  }

  /**
   * Verifica límites de UserOperations por sender y paymaster
   */
  private async checkUserOpLimits(userOp: UserOperation): Promise<void> {
    const senderOps = Array.from(this.mempool.values())
      .filter(op => op.sender === userOp.sender);

    if (senderOps.length >= this.mempoolConfig.maxUserOpPerSender) {
      throw new Error(`Too many pending operations for sender: ${userOp.sender}`);
    }

    if (userOp.paymaster && userOp.paymaster !== ethers.ZeroAddress) {
      const paymasterOps = Array.from(this.mempool.values())
        .filter(op => op.paymaster === userOp.paymaster);

      if (paymasterOps.length >= this.mempoolConfig.maxUserOpPerPaymaster) {
        throw new Error(`Too many pending operations for paymaster: ${userOp.paymaster}`);
      }
    }
  }

  /**
   * Evict UserOperations expiradas
   */
  private async evictExpiredUserOps(): Promise<void> {
    const now = Date.now();
    const expired: string[] = [];

    for (const [hash, userOp] of this.mempool.entries()) {
      if (userOp.expireTime && userOp.expireTime < now) {
        expired.push(hash);
      }
    }

    for (const hash of expired) {
      this.mempool.delete(hash);
      this.logger.debug(`Evicted expired UserOperation: ${hash}`);
    }
  }

  /**
   * Inicia actualización de gas price
   */
  private startGasPriceUpdates(): void {
    const updateGasPrice = async () => {
      try {
        const feeData = await this.provider.getFeeData();
        if (feeData.maxFeePerGas) {
          this.currentGasPrice = feeData.maxFeePerGas.toString();
        }
      } catch (error) {
        this.logger.error('Failed to update gas price', error);
      }
    };

    updateGasPrice();
    setInterval(updateGasPrice, 10000); // Actualizar cada 10 segundos
  }

  /**
   * Inicia procesamiento de bundles
   */
  private startBundleProcessing(): void {
    this.bundleInterval = setInterval(async () => {
      if (this.isRunning) {
        await this.processBundle();
      }
    }, this.config.bundleIntervalMs);
  }

  /**
   * Procesa un bundle de UserOperations
   */
  private async processBundle(): Promise<void> {
    const startTime = Date.now();

    try {
      // Obtener UserOperations pendientes
      const pendingOps = this.getPendingUserOps();

      if (pendingOps.length < this.config.minBundleSize) {
        return;
      }

      // Limitar tamaño del bundle
      const bundleSize = Math.min(pendingOps.length, this.config.maxBundleSize);
      const bundle = pendingOps.slice(0, bundleSize);

      // Crear bundle
      const packedUserOps = bundle.map(op => this.packUserOp(op.userOp));
      const bundleHash = ethers.keccak256(ethers.solidityPacked(
        ['bytes[]'],
        [packedUserOps.map(op => ethers.solidityPacked(
          ['address', 'uint256', 'bytes', 'bytes', 'bytes', 'uint256', 'bytes', 'bytes'],
          [op.sender, op.nonce, op.initCode, op.callData, op.accountGasLimits, op.preVerificationGas, op.gasFees, op.signature]
        ))]
      ));

      this.logger.bundleCreated(bundleHash, bundleSize);

      // Enviar bundle
      const tx = await this.entryPoint.handleOps(packedUserOps, this.config.beneficiaryAddress);
      const receipt = await tx.wait();

      // Procesar resultado
      await this.processBundleResult(bundleHash, bundle, receipt);

      // Actualizar estadísticas
      this.stats.totalBundles++;
      this.stats.successfulBundles++;
      this.stats.totalUserOps += bundleSize;
      this.stats.totalProcessingTime += Date.now() - startTime;

      this.logger.bundleIncluded(bundleHash, receipt!.blockNumber, receipt!.gasUsed.toString());

    } catch (error) {
      this.stats.totalBundles++;
      this.stats.failedBundles++;
      this.logger.bundleFailed('unknown', error as string);
    }
  }

  /**
   * Procesa el resultado de un bundle
   */
  private async processBundleResult(
    bundleHash: string,
    userOps: UserOpInfo[],
    receipt: any
  ): Promise<void> {
    // Buscar eventos UserOperationEvent
    const userOpEvents = receipt.logs
      .filter((log: any) => log.topics[0] === ethers.id('UserOperationEvent(bytes32,address,address,uint256,bool,uint256,uint256)'))
      .map((log: any) => this.entryPoint.interface.parseLog(log));

    for (const userOp of userOps) {
      const event = userOpEvents.find((e: any) => e.args.userOpHash === userOp.userOpHash);

      if (event) {
        if (event.args.success) {
          userOp.status = UserOpStatus.INCLUDED;
          this.logger.logUserOpFlow(userOp.userOpHash, 'included', {
            gasCost: event.args.actualGasCost.toString(),
            gasUsed: event.args.actualGasUsed.toString()
          });
        } else {
          userOp.status = UserOpStatus.REVERTED;
          this.logger.logUserOpFlow(userOp.userOpHash, 'reverted', {});
        }
        this.mempool.delete(userOp.userOpHash);
      } else {
        userOp.status = UserOpStatus.FAILED;
        this.logger.logUserOpFlow(userOp.userOpHash, 'failed', {
          reason: 'Event not found'
        });
      }
    }
  }

  /**
   * Configura listeners de eventos del EntryPoint
   */
  private setupEventListeners(): void {
    this.entryPoint.on('UserOperationEvent', (event: UserOperationEvent) => {
      this.emit('userOperationEvent', event);
    });
  }

  /**
   * Obtiene estadísticas del bundler
   */
  public getStats() {
    const successRate = this.stats.totalBundles > 0
      ? this.stats.successfulBundles / this.stats.totalBundles
      : 0;

    const avgProcessingTime = this.stats.totalBundles > 0
      ? this.stats.totalProcessingTime / this.stats.totalBundles
      : 0;

    const avgBundleSize = this.stats.totalBundles > 0
      ? this.stats.totalUserOps / this.stats.totalBundles
      : 0;

    return {
      ...this.stats,
      successRate,
      avgProcessingTime,
      avgBundleSize,
      mempoolSize: this.mempool.size,
      currentGasPrice: this.currentGasPrice
    };
  }
}