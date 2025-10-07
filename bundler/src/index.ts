import dotenv from 'dotenv';
import { ethers } from 'ethers';
import { Bundler } from './core/bundler';
import { BundlerServer } from './server';
import { Logger } from './utils/logger';
import {
  createBundlerConfig,
  createNetworkConfig,
  DEFAULT_SERVER_CONFIG,
  DEFAULT_LOGGER_CONFIG,
  DEFAULT_MEMPOOL_CONFIG,
  validateConfig
} from './config';

// Cargar variables de entorno
dotenv.config();

export class AndeChainAABundler {
  private bundler: Bundler;
  private server: BundlerServer;
  private logger: Logger;
  private isRunning: boolean = false;

  constructor(
    private env: 'development' | 'production' = 'development'
  ) {
    this.initialize();
  }

  /**
   * Inicializa todos los componentes
   */
  private async initialize(): Promise<void> {
    try {
      // 1. Crear logger
      const loggerConfig = {
        ...DEFAULT_LOGGER_CONFIG,
        level: process.env.LOG_LEVEL as any || 'info',
        file: this.env === 'production' ? 'logs/bundler.log' : undefined
      };
      this.logger = new Logger(loggerConfig);

      this.logger.info('🚀 Initializing AndeChain Account Abstraction Bundler');
      this.logger.info(`📍 Environment: ${this.env}`);

      // 2. Crear configuración
      const bundlerConfig = createBundlerConfig(this.env);
      const networkConfig = createNetworkConfig(this.env);

      validateConfig(bundlerConfig);

      this.logger.info('⚙️ Configuration loaded', {
        rpcUrl: bundlerConfig.rpcUrl,
        entryPoint: bundlerConfig.entryPointAddress,
        beneficiary: bundlerConfig.beneficiaryAddress,
        maxBundleSize: bundlerConfig.maxBundleSize,
        bundleInterval: `${bundlerConfig.bundleIntervalMs}ms`
      });

      // 3. Crear provider y wallet
      const provider = new ethers.JsonRpcProvider(bundlerConfig.rpcUrl);
      this.logger.info(`🔗 Connected to RPC: ${bundlerConfig.rpcUrl}`);

      let wallet: ethers.Wallet;
      if (bundlerConfig.privateKey) {
        wallet = new ethers.Wallet(bundlerConfig.privateKey, provider);
        this.logger.info(`👛 Using wallet: ${wallet.address}`);
      } else if (bundlerConfig.mnemonic) {
        wallet = ethers.Wallet.fromPhrase(bundlerConfig.mnemonic, provider);
        this.logger.info(`👛 Using wallet from mnemonic: ${wallet.address}`);
      } else {
        throw new Error('No private key or mnemonic provided');
      }

      // 4. Crear mempool config
      const mempoolConfig = {
        ...DEFAULT_MEMPOOL_CONFIG,
        maxGasPrice: bundlerConfig.maxGasPrice,
        minPriorityFee: bundlerConfig.minPriorityFee
      };

      // 5. Crear bundler
      this.bundler = new Bundler(provider, wallet, bundlerConfig, mempoolConfig, this.logger);
      this.logger.info('📦 Bundler created');

      // 6. Crear servidor
      const serverConfig = {
        ...DEFAULT_SERVER_CONFIG,
        port: parseInt(process.env.PORT || '3000')
      };
      this.server = new BundlerServer(this.bundler, this.logger, serverConfig);
      this.logger.info('🌐 Server created');

      // 7. Configurar event listeners
      this.setupEventListeners();

      this.logger.info('✅ Initialization completed');

    } catch (error) {
      if (this.logger) {
        this.logger.error('❌ Initialization failed', error);
      } else {
        console.error('❌ Initialization failed:', error);
      }
      throw error;
    }
  }

  /**
   * Configura listeners de eventos
   */
  private setupEventListeners(): void {
    // Eventos del bundler
    this.bundler.on('userOpAdded', (userOp) => {
      this.logger.info(`📥 UserOperation added: ${userOp.userOpHash}`);
    });

    this.bundler.on('userOpRemoved', (userOpHash) => {
      this.logger.debug(`📤 UserOperation removed: ${userOpHash}`);
    });

    this.bundler.on('userOperationEvent', (event) => {
      this.logger.info('🔄 UserOperation event', {
        hash: event.userOpHash,
        success: event.success,
        gasCost: event.actualGasCost
      });
    });

    this.bundler.on('started', () => {
      this.logger.info('🔄 Bundler started');
    });

    this.bundler.on('stopped', () => {
      this.logger.info('⏹️ Bundler stopped');
    });

    // Eventos del servidor
    this.server.on('started', (server) => {
      this.logger.info('🌐 Server started');
    });

    this.server.on('stopped', () => {
      this.logger.info('🌐 Server stopped');
    });

    // Manejo de errores no capturados
    process.on('SIGINT', () => {
      this.logger.info('📡 SIGINT received, shutting down gracefully...');
      this.shutdown().then(() => {
        process.exit(0);
      }).catch((error) => {
        this.logger.error('Error during shutdown', error);
        process.exit(1);
      });
    });

    process.on('SIGTERM', () => {
      this.logger.info('📡 SIGTERM received, shutting down gracefully...');
      this.shutdown().then(() => {
        process.exit(0);
      }).catch((error) => {
        this.logger.error('Error during shutdown', error);
        process.exit(1);
      });
    });
  }

  /**
   * Inicia el bundler y servidor
   */
  public async start(): Promise<void> {
    if (this.isRunning) {
      this.logger.warn('⚠️ Bundler is already running');
      return;
    }

    try {
      this.logger.info('🚀 Starting AndeChain AA Bundler...');

      // Iniciar bundler
      await this.bundler.start();
      this.logger.info('✅ Bundler started');

      // Iniciar servidor
      await this.server.start();
      this.logger.info('✅ Server started');

      this.isRunning = true;

      // Mostrar información de inicio
      this.showStartupInfo();

      // Iniciar reporte periódico de estadísticas
      this.startStatsReporting();

    } catch (error) {
      this.logger.error('❌ Failed to start', error);
      throw error;
    }
  }

  /**
   * Detiene el bundler y servidor
   */
  public async shutdown(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    try {
      this.logger.info('🛑 Shutting down AndeChain AA Bundler...');

      // Detener servidor
      await this.server.stop();

      // Detener bundler
      await this.bundler.stop();

      this.isRunning = false;
      this.logger.info('✅ Shutdown completed');

    } catch (error) {
      this.logger.error('❌ Error during shutdown', error);
      throw error;
    }
  }

  /**
   * Muestra información de inicio
   */
  private showStartupInfo(): void {
    const stats = this.bundler.getStats();

    console.log(`
╔══════════════════════════════════════════════════════════════╗
║           🌟 ANDECHAIN ACCOUNT ABSTRACTION BUNDLER 🌟      ║
╠══════════════════════════════════════════════════════════════╣
║ Environment: ${this.env.padEnd(52)} ║
║ Server URL: http://localhost:3000${''.padEnd(40)} ║
║ Health Check: http://localhost:3000/health${''.padEnd(31)} ║
║ Metrics: http://localhost:3000/metrics${''.padEnd(38)} ║
║                                                              ║
║ 📊 Current Stats:                                           ║
║ Mempool Size: ${stats.mempoolSize.toString().padEnd(42)} ║
║ Current Gas Price: ${stats.currentGasPrice.padEnd(37)} ║
║ Total Bundles: ${stats.totalBundles.toString().padEnd(41)} ║
║ Success Rate: ${(stats.successRate * 100).toFixed(2)}%${''.padEnd(41)} ║
╚══════════════════════════════════════════════════════════════╝
    `);
  }

  /**
   * Inicia reporte periódico de estadísticas
   */
  private startStatsReporting(): void {
    setInterval(() => {
      const stats = this.bundler.getStats();
      this.logger.bundlerStats(
        stats.totalBundles,
        stats.successRate,
        stats.avgProcessingTime,
        stats.avgBundleSize
      );
    }, 60000); // Cada minuto
  }

  /**
   * Obtiene estadísticas actuales
   */
  public getStats() {
    return this.bundler.getStats();
  }

  /**
   * Obtiene el logger
   */
  public getLogger(): Logger {
    return this.logger;
  }

  /**
   * Verifica salud del sistema
   */
  public async healthCheck(): Promise<{
    status: 'healthy' | 'unhealthy';
    bundler: any;
    server: any;
    timestamp: number;
  }> {
    try {
      const bundlerStats = this.bundler.getStats();
      const isHealthy = this.isRunning && bundlerStats.mempoolSize >= 0;

      return {
        status: isHealthy ? 'healthy' : 'unhealthy',
        bundler: bundlerStats,
        server: {
          isRunning: this.isRunning
        },
        timestamp: Date.now()
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        bundler: null,
        server: { isRunning: false },
        timestamp: Date.now()
      };
    }
  }
}

// Función para crear instancia rápidamente
export function createBundler(env: 'development' | 'production' = 'development'): AndeChainAABundler {
  return new AndeChainAABundler(env);
}

// Ejecutar directamente si es el entry point
if (require.main === module) {
  const env = (process.env.NODE_ENV as 'development' | 'production') || 'development';
  const bundler = createBundler(env);

  bundler.start().catch((error) => {
    console.error('❌ Failed to start bundler:', error);
    process.exit(1);
  });
}