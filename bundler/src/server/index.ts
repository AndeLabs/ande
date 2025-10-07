import express, { Application, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { EventEmitter } from 'events';
import { v4 as uuidv4 } from 'uuid';
import { Bundler } from '../core/bundler';
import { Logger } from '../utils/logger';
import {
  UserOperation,
  UserOpInfo,
  ApiResponse,
  BatchRequest,
  BatchResponse,
  ServerConfig,
  SystemMetrics
} from '../types';

// Interfaces para JSON-RPC
interface JsonRpcRequest {
  jsonrpc: "2.0";
  id: string | number;
  method: string;
  params: any[];
}

interface JsonRpcResponse {
  jsonrpc: "2.0";
  id: string | number | null;
  result?: any;
  error?: {
    code: number;
    message: string;
    data?: any;
  };
}

// Error codes
enum JsonRpcError {
  INVALID_REQUEST = -32600,
  METHOD_NOT_FOUND = -32601,
  INVALID_PARAMS = -32602,
  INTERNAL_ERROR = -32603,
  PARSE_ERROR = -32700
}

export class BundlerServer extends EventEmitter {
  private app: Application;
  private bundler: Bundler;
  private logger: Logger;
  private config: ServerConfig;
  private isRunning: boolean = false;
  private requestStats = {
    totalRequests: 0,
    successfulRequests: 0,
    failedRequests: 0,
    startTime: Date.now()
  };

  constructor(
    bundler: Bundler,
    logger: Logger,
    config: ServerConfig
  ) {
    super();
    this.bundler = bundler;
    this.logger = logger;
    this.config = config;
    this.app = express();

    this.setupMiddleware();
    this.setupRoutes();
    this.setupErrorHandling();
  }

  /**
   * Inicia el servidor
   */
  public async start(): Promise<void> {
    if (this.isRunning) {
      this.logger.warn('Server is already running');
      return;
    }

    return new Promise((resolve, reject) => {
      const server = this.app.listen(this.config.port, this.config.host, () => {
        this.isRunning = true;
        this.logger.serverStarted(this.config.host, this.config.port);
        this.emit('started', server);
        resolve();
      });

      server.on('error', (error) => {
        this.logger.error('Failed to start server', error);
        reject(error);
      });
    });
  }

  /**
   * Detiene el servidor
   */
  public async stop(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    this.isRunning = false;
    this.logger.info('Server stopped');
    this.emit('stopped');
  }

  /**
   * Configura middleware
   */
  private setupMiddleware(): void {
    // Seguridad
    this.app.use(helmet(this.config.securityHeaders));

    // CORS
    this.app.use(cors({
      origin: this.config.corsOrigins,
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
    }));

    // Rate limiting
    const limiter = rateLimit({
      windowMs: this.config.rateLimitWindowMs,
      max: this.config.rateLimitMax,
      message: {
        error: 'Too many requests',
        retryAfter: Math.ceil(this.config.rateLimitWindowMs / 1000)
      },
      standardHeaders: true,
      legacyHeaders: false
    });
    this.app.use(limiter);

    // Body parsing
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));

    // Request logging
    this.app.use((req, res, next) => {
      const startTime = Date.now();

      res.on('finish', () => {
        const duration = Date.now() - startTime;
        this.requestStats.totalRequests++;

        if (res.statusCode >= 200 && res.statusCode < 400) {
          this.requestStats.successfulRequests++;
        } else {
          this.requestStats.failedRequests++;
        }

        this.logger.requestReceived(req.method, req.body, req.body?.id || 'unknown');
        this.logger.requestCompleted(req.method, duration, res.statusCode);
      });

      next();
    });
  }

  /**
   * Configura las rutas
   */
  private setupRoutes(): void {
    // Health check
    this.app.get(this.config.healthCheckPath, this.healthCheck.bind(this));

    // Metrics
    this.app.get(this.config.metricsPath, this.getMetrics.bind(this));

    // JSON-RPC endpoint
    this.app.post('/', this.handleJsonRpc.bind(this));
    this.app.post('/rpc', this.handleJsonRpc.bind(this));

    // REST API endpoints (opcionales para conveniencia)
    this.app.post('/sendUserOperation', this.sendUserOperation.bind(this));
    this.app.get('/getUserOperation/:hash', this.getUserOperation.bind(this));
    this.app.get('/pendingUserOperations', this.getPendingUserOperations.bind(this));
    this.app.get('/stats', this.getStats.bind(this));

    // Static files (para documentación, etc.)
    this.app.use('/docs', express.static('public/docs'));

    // 404 handler
    this.app.use('*', (req, res) => {
      res.status(404).json(this.createErrorResponse(
        null,
        JsonRpcError.METHOD_NOT_FOUND,
        'Method not found'
      ));
    });
  }

  /**
   * Health check endpoint
   */
  private async healthCheck(req: Request, res: Response): Promise<void> {
    try {
      const bundlerStats = this.bundler.getStats();
      const systemMetrics = this.getSystemMetrics();

      const health = {
        status: 'healthy',
        timestamp: Date.now(),
        uptime: process.uptime(),
        bundler: {
          isRunning: bundlerStats.mempoolSize >= 0,
          mempoolSize: bundlerStats.mempoolSize,
          currentGasPrice: bundlerStats.currentGasPrice
        },
        system: systemMetrics,
        version: process.env.npm_package_version || '1.0.0'
      };

      res.json(health);
    } catch (error) {
      res.status(500).json({
        status: 'unhealthy',
        error: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  /**
   * Metrics endpoint
   */
  private async getMetrics(req: Request, res: Response): Promise<void> {
    try {
      const bundlerStats = this.bundler.getStats();
      const systemMetrics = this.getSystemMetrics();

      const metrics = {
        timestamp: Date.now(),
        uptime: process.uptime(),
        bundler: bundlerStats,
        server: this.requestStats,
        system: systemMetrics
      };

      res.json(metrics);
    } catch (error) {
      res.status(500).json({
        error: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  /**
   * Maneja requests JSON-RPC
   */
  private async handleJsonRpc(req: Request, res: Response): Promise<void> {
    try {
      const isBatch = Array.isArray(req.body);
      const requests = isBatch ? req.body : [req.body];
      const responses: JsonRpcResponse[] = [];

      for (const request of requests) {
        const response = await this.processJsonRpcRequest(request);
        responses.push(response);
      }

      if (isBatch) {
        res.json(responses);
      } else {
        res.json(responses[0]);
      }
    } catch (error) {
      res.status(400).json(this.createErrorResponse(
        null,
        JsonRpcError.PARSE_ERROR,
        'Invalid JSON-RPC request'
      ));
    }
  }

  /**
   * Procesa un request JSON-RPC individual
   */
  private async processJsonRpcRequest(request: any): Promise<JsonRpcResponse> {
    try {
      // Validar request
      if (!request || typeof request !== 'object') {
        return this.createErrorResponse(
          null,
          JsonRpcError.INVALID_REQUEST,
          'Invalid request'
        );
      }

      if (request.jsonrpc !== '2.0') {
        return this.createErrorResponse(
          request.id,
          JsonRpcError.INVALID_REQUEST,
          'Invalid JSON-RPC version'
        );
      }

      if (!request.method || typeof request.method !== 'string') {
        return this.createErrorResponse(
          request.id,
          JsonRpcError.INVALID_REQUEST,
          'Method is required'
        );
      }

      // Procesar método
      const result = await this.handleJsonRpcMethod(request.method, request.params || []);

      return {
        jsonrpc: '2.0',
        id: request.id,
        result
      };

    } catch (error) {
      this.logger.error('JSON-RPC error', error);
      return this.createErrorResponse(
        request.id,
        JsonRpcError.INTERNAL_ERROR,
        error instanceof Error ? error.message : 'Internal error'
      );
    }
  }

  /**
   * Maneja métodos JSON-RPC específicos
   */
  private async handleJsonRpcMethod(method: string, params: any[]): Promise<any> {
    switch (method) {
      case 'eth_sendUserOperation':
        return await this.sendUserOperationRpc(params[0]);

      case 'eth_estimateUserOperationGas':
        return await this.estimateUserOperationGasRpc(params[0]);

      case 'eth_supportedEntryPoints':
        return [await this.getSupportedEntryPoints()];

      case 'eth_chainId':
        return await this.getChainId();

      case 'eth_getUserOperationByHash':
        return await this.getUserOperationByHashRpc(params[0]);

      case 'eth_getUserOperationReceipt':
        return await this.getUserOperationReceiptRpc(params[0]);

      case 'debug_bundler_clearState':
        return await this.debugClearState();

      case 'debug_bundler_dumpMempool':
        return await this.debugDumpMempool();

      case 'debug_bundler_sendBundleNow':
        return await this.debugSendBundleNow();

      case 'debug_bundler_setBundlingMode':
        return await this.debugSetBundlingMode(params[0]);

      case 'web3_clientVersion':
        return 'ande-chain-bundler/1.0.0';

      default:
        throw new Error(`Method not found: ${method}`);
    }
  }

  /**
   * Envia una UserOperation (JSON-RPC)
   */
  private async sendUserOperationRpc(userOp: UserOperation): Promise<string> {
    if (!userOp) {
      throw new Error('UserOperation is required');
    }

    return await this.bundler.addUserOp(userOp);
  }

  /**
   * Estima gas para UserOperation (JSON-RPC)
   */
  private async estimateUserOperationGasRpc(userOp: UserOperation): Promise<any> {
    if (!userOp) {
      throw new Error('UserOperation is required');
    }

    return await this.bundler.estimateUserOpGas(userOp);
  }

  /**
   * Obtiene EntryPoint soportado
   */
  private async getSupportedEntryPoints(): Promise<string> {
    // Esto debería venir de la configuración del bundler
    return '0x4337084d9e255ff0702461cf8895ce9e3b5ff108';
  }

  /**
   * Obtiene chain ID
   */
  private async getChainId(): Promise<string> {
    return '31337'; // Development chain ID
  }

  /**
   * Obtiene UserOperation por hash (JSON-RPC)
   */
  private async getUserOperationByHashRpc(hash: string): Promise<UserOpInfo | null> {
    if (!hash) {
      throw new Error('Hash is required');
    }

    const userOp = this.bundler.getUserOp(hash);
    return userOp || null;
  }

  /**
   * Obtiene receipt de UserOperation (JSON-RPC)
   */
  private async getUserOperationReceiptRpc(hash: string): Promise<any> {
    // En una implementación real, esto buscaría en los eventos del blockchain
    // Por ahora, devolvemos la información disponible
    const userOp = this.bundler.getUserOp(hash);
    if (!userOp) {
      return null;
    }

    return {
      userOpHash: hash,
      entryPoint: await this.getSupportedEntryPoints(),
      blockNumber: null, // Se llenaría cuando se incluye en bloque
      blockHash: null,
      transactionHash: null,
      gasUsed: '0x0',
      effectiveGasPrice: '0x0',
      logs: []
    };
  }

  /**
   * Debug: limpiar estado del mempool
   */
  private async debugClearState(): Promise<string> {
    // En una implementación real, esto limpiaría el mempool
    return 'State cleared';
  }

  /**
   * Debug: volcar mempool
   */
  private async debugDumpMempool(): Promise<UserOpInfo[]> {
    return this.bundler.getPendingUserOps();
  }

  /**
   * Debug: enviar bundle ahora
   */
  private async debugSendBundleNow(): Promise<string> {
    // En una implementación real, esto forzaría el procesamiento inmediato
    return 'Bundle sent';
  }

  /**
   * Debug: establecer modo de bundling
   */
  private async debugSetBundlingMode(mode: string): Promise<string> {
    // En una implementación real, esto cambiaría el modo del bundler
    return `Bundling mode set to: ${mode}`;
  }

  /**
   * Envia UserOperation (REST endpoint)
   */
  private async sendUserOperation(req: Request, res: Response): Promise<void> {
    try {
      const userOp: UserOperation = req.body;
      const userOpHash = await this.bundler.addUserOp(userOp);

      res.json(this.createSuccessResponse({
        userOpHash
      }));
    } catch (error) {
      this.logger.error('Failed to send UserOperation', error);
      res.status(400).json(this.createErrorResponse(
        null,
        JsonRpcError.INVALID_PARAMS,
        error instanceof Error ? error.message : 'Failed to send UserOperation'
      ));
    }
  }

  /**
   * Obtiene UserOperation (REST endpoint)
   */
  private async getUserOperation(req: Request, res: Response): Promise<void> {
    try {
      const hash = req.params.hash;
      const userOp = this.bundler.getUserOp(hash);

      if (!userOp) {
        res.status(404).json(this.createErrorResponse(
          null,
          JsonRpcError.INVALID_PARAMS,
          'UserOperation not found'
        ));
        return;
      }

      res.json(this.createSuccessResponse(userOp));
    } catch (error) {
      this.logger.error('Failed to get UserOperation', error);
      res.status(500).json(this.createErrorResponse(
        null,
        JsonRpcError.INTERNAL_ERROR,
        'Failed to get UserOperation'
      ));
    }
  }

  /**
   * Obtiene UserOperations pendientes (REST endpoint)
   */
  private async getPendingUserOperations(req: Request, res: Response): Promise<void> {
    try {
      const pendingOps = this.bundler.getPendingUserOps();
      res.json(this.createSuccessResponse(pendingOps));
    } catch (error) {
      this.logger.error('Failed to get pending UserOperations', error);
      res.status(500).json(this.createErrorResponse(
        null,
        JsonRpcError.INTERNAL_ERROR,
        'Failed to get pending UserOperations'
      ));
    }
  }

  /**
   * Obtiene estadísticas (REST endpoint)
   */
  private async getStats(req: Request, res: Response): Promise<void> {
    try {
      const bundlerStats = this.bundler.getStats();
      const systemMetrics = this.getSystemMetrics();

      const stats = {
        timestamp: Date.now(),
        uptime: process.uptime(),
        bundler: bundlerStats,
        server: this.requestStats,
        system: systemMetrics
      };

      res.json(this.createSuccessResponse(stats));
    } catch (error) {
      this.logger.error('Failed to get stats', error);
      res.status(500).json(this.createErrorResponse(
        null,
        JsonRpcError.INTERNAL_ERROR,
        'Failed to get stats'
      ));
    }
  }

  /**
   * Obtiene métricas del sistema
   */
  private getSystemMetrics(): SystemMetrics {
    const memUsage = process.memoryUsage();
    const cpuUsage = process.cpuUsage();

    return {
      uptime: process.uptime(),
      memoryUsage: memUsage,
      cpuUsage: cpuUsage,
      activeConnections: 0, // En una implementación real, esto trackearía conexiones activas
      requestsPerSecond: this.requestStats.totalRequests / ((Date.now() - this.requestStats.startTime) / 1000),
      errorRate: this.requestStats.failedRequests / this.requestStats.totalRequests
    };
  }

  /**
   * Configura manejo de errores
   */
  private setupErrorHandling(): void {
    // Manejo de errores síncronos
    this.app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
      this.logger.error('Unhandled error', err);
      res.status(500).json(this.createErrorResponse(
        null,
        JsonRpcError.INTERNAL_ERROR,
        'Internal server error'
      ));
    });

    // Manejo de promesas rechazadas
    process.on('unhandledRejection', (reason, promise) => {
      this.logger.error('Unhandled rejection', { reason, promise });
    });

    process.on('uncaughtException', (error) => {
      this.logger.error('Uncaught exception', error);
      process.exit(1);
    });
  }

  /**
   * Crea response de éxito
   */
  private createSuccessResponse(data: any): ApiResponse {
    return {
      success: true,
      data,
      timestamp: Date.now()
    };
  }

  /**
   * Crea response de error
   */
  private createErrorResponse(
    id: string | number | null,
    code: number,
    message: string,
    data?: any
  ): JsonRpcResponse {
    return {
      jsonrpc: '2.0',
      id,
      error: {
        code,
        message,
        data
      }
    };
  }
}