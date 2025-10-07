import winston from 'winston';
import path from 'path';
import fs from 'fs';
import { LoggerConfig, LogLevel } from '../types';

export class Logger {
  private logger: winston.Logger;

  constructor(config: LoggerConfig) {
    // Crear directorio de logs si no existe
    if (config.file) {
      const logDir = path.dirname(config.file);
      if (!fs.existsSync(logDir)) {
        fs.mkdirSync(logDir, { recursive: true });
      }
    }

    // Crear formatters
    const consoleFormatter = winston.format.combine(
      winston.format.colorize(),
      winston.format.timestamp(),
      winston.format.printf(({ timestamp, level, message, ...meta }) => {
        const metaStr = Object.keys(meta).length ? JSON.stringify(meta, null, 2) : '';
        return `${timestamp} [${level}]: ${message} ${metaStr}`;
      })
    );

    const fileFormatter = winston.format.combine(
      winston.format.timestamp(),
      winston.format.json()
    );

    // Crear transports
    const transports: winston.transport[] = [];

    if (config.transports.includes('console')) {
      transports.push(
        new winston.transports.Console({
          level: config.level,
          format: consoleFormatter
        })
      );
    }

    if (config.transports.includes('file') && config.file) {
      transports.push(
        new winston.transports.File({
          filename: config.file,
          level: config.level,
          format: fileFormatter,
          maxsize: this.parseSize(config.maxSize || '10m'),
          maxFiles: config.maxFiles || 5
        })
      );
    }

    this.logger = winston.createLogger({
      level: config.level,
      transports,
      // Evitar logs duplicados en producción
      silent: process.env.NODE_ENV === 'test'
    });
  }

  private parseSize(size: string): number {
    const units: { [key: string]: number } = {
      'b': 1,
      'k': 1024,
      'm': 1024 * 1024,
      'g': 1024 * 1024 * 1024
    };

    const match = size.toLowerCase().match(/^(\d+)([bkmg]?)$/);
    if (!match) {
      throw new Error(`Invalid size format: ${size}`);
    }

    const [, num, unit] = match;
    return parseInt(num) * (units[unit] || 1);
  }

  debug(message: string, meta?: any): void {
    this.logger.debug(message, meta);
  }

  info(message: string, meta?: any): void {
    this.logger.info(message, meta);
  }

  warn(message: string, meta?: any): void {
    this.logger.warn(message, meta);
  }

  error(message: string, error?: Error | any): void {
    if (error instanceof Error) {
      this.logger.error(message, {
        error: error.message,
        stack: error.stack,
        ...error
      });
    } else {
      this.logger.error(message, error);
    }
  }

  // Métodos específicos para el bundler
  userOpReceived(userOpHash: string, sender: string, gasPrice: string): void {
    this.debug('UserOperation received', {
      userOpHash,
      sender,
      gasPrice
    });
  }

  userOpValidated(userOpHash: string, gasUsed: string): void {
    this.debug('UserOperation validated', {
      userOpHash,
      gasUsed
    });
  }

  userOpInvalid(userOpHash: string, reason: string): void {
    this.warn('UserOperation invalid', {
      userOpHash,
      reason
    });
  }

  bundleCreated(bundleHash: string, userOpCount: number): void {
    this.info('Bundle created', {
      bundleHash,
      userOpCount
    });
  }

  bundleSubmitted(bundleHash: string, txHash: string): void {
    this.info('Bundle submitted', {
      bundleHash,
      txHash
    });
  }

  bundleIncluded(bundleHash: string, blockNumber: number, gasUsed: string): void {
    this.info('Bundle included', {
      bundleHash,
      blockNumber,
      gasUsed
    });
  }

  bundleFailed(bundleHash: string, error: string): void {
    this.error('Bundle failed', {
      bundleHash,
      error
    });
  }

  paymasterSponsored(userOpHash: string, cost: string, paymaster: string): void {
    this.debug('Paymaster sponsored', {
      userOpHash,
      cost,
      paymaster
    });
  }

  gasPriceUpdated(oldPrice: string, newPrice: string): void {
    this.info('Gas price updated', {
      oldPrice,
      newPrice
    });
  }

  serverStarted(host: string, port: number): void {
    this.info(`Server started on ${host}:${port}`);
  }

  requestReceived(method: string, params: any, id: string | number): void {
    this.debug('Request received', {
      method,
      params,
      id
    });
  }

  requestCompleted(method: string, duration: number, result?: any): void {
    this.debug('Request completed', {
      method,
      duration,
      result
    });
  }

  requestFailed(method: string, error: string, duration: number): void {
    this.error('Request failed', {
      method,
      error,
      duration
    });
  }

  // Métricas
  mempoolStats(totalSize: number, pendingBySender: { [sender: string]: number }): void {
    this.info('Mempool stats', {
      totalSize,
      pendingBySender
    });
  }

  bundlerStats(
    totalBundles: number,
    successRate: number,
    avgProcessingTime: number,
    avgBundleSize: number
  ): void {
    this.info('Bundler stats', {
      totalBundles,
      successRate: `${(successRate * 100).toFixed(2)}%`,
      avgProcessingTime: `${avgProcessingTime}ms`,
      avgBundleSize
    });
  }

  // Métodos para estructuración de logs
  logUserOpFlow(userOpHash: string, phase: string, data: any): void {
    this.debug(`UserOperation ${phase}`, {
      userOpHash,
      phase,
      ...data
    });
  }

  logBundleFlow(bundleHash: string, phase: string, data: any): void {
    this.info(`Bundle ${phase}`, {
      bundleHash,
      phase,
      ...data
    });
  }

  logSystemMetrics(metrics: any): void {
    this.info('System metrics', metrics);
  }

  // Método para obtener logger winston crudo (si se necesita)
  getRawLogger(): winston.Logger {
    return this.logger;
  }
}

// Instancia global
let globalLogger: Logger;

export function initializeLogger(config: LoggerConfig): Logger {
  globalLogger = new Logger(config);
  return globalLogger;
}

export function getLogger(): Logger {
  if (!globalLogger) {
    throw new Error('Logger not initialized. Call initializeLogger first.');
  }
  return globalLogger;
}

// Función helper para crear logger rápidamente
export function createLogger(level: LogLevel = LogLevel.INFO): Logger {
  return new Logger({
    level,
    format: 'simple',
    transports: ['console']
  });
}