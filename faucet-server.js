/**
 * AndeChain Faucet Server
 * Production-ready faucet service for testnet/development
 *
 * Features:
 * - ERC20 Token Distribution (ANDE Token)
 * - Rate limiting per address
 * - Environment-based configuration
 * - Robust error handling
 * - Health monitoring
 * - Transaction tracking
 * - Graceful shutdown
 */

const express = require("express");
const cors = require("cors");
const { ethers } = require("ethers");

// ==========================================
// ERC20 ABI (Minimal)
// ==========================================

const ERC20_ABI = [
  "function transfer(address to, uint256 amount) returns (bool)",
  "function balanceOf(address account) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
];

// ==========================================
// CONFIGURATION
// ==========================================

const CONFIG = {
  // Server
  PORT: parseInt(process.env.FAUCET_PORT || "3001", 10),
  NODE_ENV: process.env.NODE_ENV || "development",

  // Blockchain
  RPC_URL: process.env.RPC_URL || "http://localhost:8545",
  CHAIN_ID: parseInt(process.env.CHAIN_ID || "1234", 10),

  // Token Contract - ANDETokenDuality (Production)
  TOKEN_ADDRESS: process.env.TOKEN_ADDRESS || "0x7a2088a1bFc9d81c55368AE168C2C02570cB814F",

  // Faucet settings
  FAUCET_AMOUNT: ethers.parseEther(process.env.FAUCET_AMOUNT || "500000"),
  PRIVATE_KEY: process.env.FAUCET_PRIVATE_KEY || "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",

  // Rate limiting
  COOLDOWN_TIME: parseInt(process.env.COOLDOWN_TIME || "60000", 10), // 1 minute default
  MAX_DAILY_REQUESTS: parseInt(process.env.MAX_DAILY_REQUESTS || "10", 10),

  // Thresholds
  MIN_FAUCET_BALANCE: ethers.parseEther("1000000"), // Alert if below 1M ANDE
  GAS_LIMIT: 21000,

  // CORS
  CORS_ORIGIN: process.env.CORS_ORIGIN || "*",
};

// ==========================================
// LOGGER
// ==========================================

class Logger {
  static info(message, ...args) {
    console.log(`[${new Date().toISOString()}] [INFO] ${message}`, ...args);
  }

  static warn(message, ...args) {
    console.warn(`[${new Date().toISOString()}] [WARN] ${message}`, ...args);
  }

  static error(message, error) {
    console.error(`[${new Date().toISOString()}] [ERROR] ${message}`, error?.message || error);
  }

  static success(message, ...args) {
    console.log(`[${new Date().toISOString()}] [SUCCESS] ${message}`, ...args);
  }
}

// ==========================================
// RATE LIMITER
// ==========================================

class RateLimiter {
  constructor() {
    this.cooldowns = new Map(); // address -> lastRequestTime
    this.dailyRequests = new Map(); // address -> { count, date }
  }

  /**
   * Check if address can request tokens
   */
  canRequest(address) {
    const now = Date.now();
    const normalizedAddress = address.toLowerCase();

    // Check cooldown
    const lastRequest = this.cooldowns.get(normalizedAddress);
    if (lastRequest) {
      const elapsed = now - lastRequest;
      if (elapsed < CONFIG.COOLDOWN_TIME) {
        const remainingTime = Math.ceil((CONFIG.COOLDOWN_TIME - elapsed) / 1000);
        return {
          allowed: false,
          reason: "COOLDOWN",
          remainingTime,
          message: `Please wait ${remainingTime} seconds`,
        };
      }
    }

    // Check daily limit
    const today = new Date().toDateString();
    const dailyData = this.dailyRequests.get(normalizedAddress);

    if (dailyData) {
      if (dailyData.date === today) {
        if (dailyData.count >= CONFIG.MAX_DAILY_REQUESTS) {
          return {
            allowed: false,
            reason: "DAILY_LIMIT",
            message: `Daily limit of ${CONFIG.MAX_DAILY_REQUESTS} requests reached`,
          };
        }
      } else {
        // New day, reset counter
        this.dailyRequests.set(normalizedAddress, { count: 0, date: today });
      }
    } else {
      this.dailyRequests.set(normalizedAddress, { count: 0, date: today });
    }

    return { allowed: true };
  }

  /**
   * Record successful request
   */
  recordRequest(address) {
    const now = Date.now();
    const today = new Date().toDateString();
    const normalizedAddress = address.toLowerCase();

    // Update cooldown
    this.cooldowns.set(normalizedAddress, now);

    // Update daily counter
    const dailyData = this.dailyRequests.get(normalizedAddress);
    if (dailyData && dailyData.date === today) {
      dailyData.count++;
    } else {
      this.dailyRequests.set(normalizedAddress, { count: 1, date: today });
    }
  }

  /**
   * Get rate limit status for address
   */
  getStatus(address) {
    const normalizedAddress = address.toLowerCase();
    const now = Date.now();
    const today = new Date().toDateString();

    const lastRequest = this.cooldowns.get(normalizedAddress);
    const dailyData = this.dailyRequests.get(normalizedAddress);

    let remainingTime = 0;
    if (lastRequest) {
      const elapsed = now - lastRequest;
      if (elapsed < CONFIG.COOLDOWN_TIME) {
        remainingTime = Math.ceil((CONFIG.COOLDOWN_TIME - elapsed) / 1000);
      }
    }

    const requestsToday = dailyData && dailyData.date === today ? dailyData.count : 0;

    return {
      canRequest: remainingTime === 0 && requestsToday < CONFIG.MAX_DAILY_REQUESTS,
      remainingTime,
      requestsToday,
      maxDailyRequests: CONFIG.MAX_DAILY_REQUESTS,
      lastRequestTime: lastRequest ? new Date(lastRequest).toISOString() : null,
    };
  }
}

// ==========================================
// FAUCET SERVICE
// ==========================================

class FaucetService {
  constructor() {
    this.provider = null;
    this.wallet = null;
    this.tokenContract = null;
    this.isConnected = false;
    this.rateLimiter = new RateLimiter();
    this.stats = {
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      totalDispensedWei: BigInt(0),
    };
  }

  /**
   * Initialize provider and wallet
   */
  async initialize() {
    try {
      Logger.info("Initializing faucet service...");

      this.provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
      this.wallet = new ethers.Wallet(CONFIG.PRIVATE_KEY, this.provider);

      // Initialize token contract
      this.tokenContract = new ethers.Contract(
        CONFIG.TOKEN_ADDRESS,
        ERC20_ABI,
        this.wallet
      );

      // Verify connection
      const network = await this.provider.getNetwork();
      const tokenBalance = await this.tokenContract.balanceOf(this.wallet.address);
      const tokenSymbol = await this.tokenContract.symbol();

      this.isConnected = true;

      Logger.success("Faucet service initialized");
      Logger.info(`Chain ID: ${network.chainId}`);
      Logger.info(`Token Address: ${CONFIG.TOKEN_ADDRESS}`);
      Logger.info(`Token Symbol: ${tokenSymbol}`);
      Logger.info(`Faucet Address: ${this.wallet.address}`);
      Logger.info(`Token Balance: ${ethers.formatEther(tokenBalance)} ${tokenSymbol}`);

      // Check if balance is sufficient
      if (tokenBalance < CONFIG.MIN_FAUCET_BALANCE) {
        Logger.warn(`Low balance warning! Current: ${ethers.formatEther(tokenBalance)} ${tokenSymbol}`);
      }

      return true;
    } catch (error) {
      this.isConnected = false;
      Logger.error("Failed to initialize faucet service", error);
      return false;
    }
  }

  /**
   * Send tokens to address
   */
  async dispense(recipientAddress) {
    this.stats.totalRequests++;

    try {
      // Validate address
      if (!ethers.isAddress(recipientAddress)) {
        throw new Error("Invalid Ethereum address");
      }

      // Check rate limit
      const rateLimitCheck = this.rateLimiter.canRequest(recipientAddress);
      if (!rateLimitCheck.allowed) {
        return {
          success: false,
          error: rateLimitCheck.reason,
          message: rateLimitCheck.message,
          remainingTime: rateLimitCheck.remainingTime,
        };
      }

      // Check faucet token balance
      const faucetBalance = await this.tokenContract.balanceOf(this.wallet.address);
      if (faucetBalance < CONFIG.FAUCET_AMOUNT) {
        Logger.error("Insufficient faucet token balance", {
          required: ethers.formatEther(CONFIG.FAUCET_AMOUNT),
          available: ethers.formatEther(faucetBalance),
        });
        return {
          success: false,
          error: "INSUFFICIENT_BALANCE",
          message: "Faucet has insufficient token balance. Please contact administrator.",
        };
      }

      // Check connection
      if (!this.isConnected) {
        const reconnected = await this.initialize();
        if (!reconnected) {
          return {
            success: false,
            error: "SERVICE_UNAVAILABLE",
            message: "Faucet service is currently unavailable",
          };
        }
      }

      // Send tokens via ANDETokenDuality
      // ANDETokenDuality uses the precompile mock, so the transfer will update native balance
      Logger.info(`Dispensing ${ethers.formatEther(CONFIG.FAUCET_AMOUNT)} ANDE tokens to ${recipientAddress}`);

      const tx = await this.tokenContract.transfer(
        recipientAddress,
        CONFIG.FAUCET_AMOUNT
      );

      Logger.success(`Token transfer transaction sent: ${tx.hash}`);

      // Record successful request
      this.rateLimiter.recordRequest(recipientAddress);
      this.stats.successfulRequests++;
      this.stats.totalDispensedWei += CONFIG.FAUCET_AMOUNT;

      // Wait for confirmation (don't block response)
      tx.wait(1, 30000)
        .then((receipt) => {
          Logger.success(`Transaction confirmed: ${tx.hash} (Block ${receipt.blockNumber})`);
        })
        .catch((err) => {
          Logger.warn(`Transaction confirmation timeout: ${tx.hash}`);
        });

      return {
        success: true,
        txHash: tx.hash,
        amount: ethers.formatEther(CONFIG.FAUCET_AMOUNT),
        from: this.wallet.address,
        to: recipientAddress,
        explorerUrl: `http://localhost:4000/tx/${tx.hash}`,
      };
    } catch (error) {
      this.stats.failedRequests++;
      Logger.error("Failed to dispense tokens", error);

      return {
        success: false,
        error: "TRANSACTION_FAILED",
        message: error.message || "Failed to send transaction",
      };
    }
  }

  /**
   * Get faucet health status
   */
  async getHealth() {
    try {
      if (!this.isConnected) {
        await this.initialize();
      }

      const tokenBalance = await this.tokenContract.balanceOf(this.wallet.address);
      const blockNumber = await this.provider.getBlockNumber();
      const network = await this.provider.getNetwork();
      const tokenSymbol = await this.tokenContract.symbol();

      const requestsRemaining = tokenBalance / CONFIG.FAUCET_AMOUNT;

      return {
        status: "healthy",
        connected: this.isConnected,
        tokenAddress: CONFIG.TOKEN_ADDRESS,
        tokenSymbol: tokenSymbol,
        faucetAddress: this.wallet.address,
        balance: ethers.formatEther(tokenBalance),
        balanceWei: tokenBalance.toString(),
        requestsRemaining: Number(requestsRemaining),
        blockNumber: blockNumber.toString(),
        chainId: network.chainId.toString(),
        faucetAmount: ethers.formatEther(CONFIG.FAUCET_AMOUNT),
        cooldownTime: `${CONFIG.COOLDOWN_TIME / 1000}s`,
        maxDailyRequests: CONFIG.MAX_DAILY_REQUESTS,
        stats: {
          totalRequests: this.stats.totalRequests,
          successfulRequests: this.stats.successfulRequests,
          failedRequests: this.stats.failedRequests,
          totalDispensed: ethers.formatEther(this.stats.totalDispensedWei),
          totalDispensedWei: this.stats.totalDispensedWei.toString(),
        },
      };
    } catch (error) {
      Logger.error("Health check failed", error);
      return {
        status: "unhealthy",
        connected: false,
        error: error.message,
      };
    }
  }

  /**
   * Get rate limit status for address
   */
  getRateLimitStatus(address) {
    if (!ethers.isAddress(address)) {
      return { error: "Invalid address" };
    }
    return this.rateLimiter.getStatus(address);
  }
}

// ==========================================
// EXPRESS APP
// ==========================================

const app = express();
const faucetService = new FaucetService();

// Middleware
app.use(cors({
  origin: CONFIG.CORS_ORIGIN,
  methods: ['GET', 'POST'],
  credentials: true,
}));
app.use(express.json());

// Request logging middleware
app.use((req, res, next) => {
  Logger.info(`${req.method} ${req.path} from ${req.ip}`);
  next();
});

// ==========================================
// ROUTES
// ==========================================

/**
 * Health check endpoint
 */
app.get("/health", async (req, res) => {
  try {
    const health = await faucetService.getHealth();
    const statusCode = health.status === "healthy" ? 200 : 503;
    res.status(statusCode).json(health);
  } catch (error) {
    Logger.error("Health check error", error);
    res.status(500).json({
      status: "error",
      message: error.message,
    });
  }
});

/**
 * Request tokens
 */
app.post("/", async (req, res) => {
  try {
    const { address } = req.body;

    if (!address) {
      return res.status(400).json({
        success: false,
        error: "MISSING_ADDRESS",
        message: "Address is required",
      });
    }

    const result = await faucetService.dispense(address);

    if (result.success) {
      res.status(200).json(result);
    } else {
      const statusCode = result.error === "COOLDOWN" ? 429 :
                        result.error === "DAILY_LIMIT" ? 429 :
                        result.error === "INSUFFICIENT_BALANCE" ? 503 : 400;
      res.status(statusCode).json(result);
    }
  } catch (error) {
    Logger.error("Request handler error", error);
    res.status(500).json({
      success: false,
      error: "INTERNAL_ERROR",
      message: error.message,
    });
  }
});

/**
 * Get rate limit status for address
 */
app.get("/status/:address", (req, res) => {
  try {
    const { address } = req.params;
    const status = faucetService.getRateLimitStatus(address);
    res.status(200).json(status);
  } catch (error) {
    Logger.error("Status check error", error);
    res.status(500).json({
      error: "INTERNAL_ERROR",
      message: error.message,
    });
  }
});

/**
 * Get faucet
 statistics
 */
app.get("/stats", (req, res) => {
  try {
    res.status(200).json({
      stats: {
        totalRequests: faucetService.stats.totalRequests,
        successfulRequests: faucetService.stats.successfulRequests,
        failedRequests: faucetService.stats.failedRequests,
        totalDispensed: ethers.formatEther(faucetService.stats.totalDispensedWei),
        totalDispensedWei: faucetService.stats.totalDispensedWei.toString(),
      },
      config: {
        faucetAmount: ethers.formatEther(CONFIG.FAUCET_AMOUNT),
        cooldownTime: `${CONFIG.COOLDOWN_TIME / 1000}s`,
        maxDailyRequests: CONFIG.MAX_DAILY_REQUESTS,
      },
    });
  } catch (error) {
    Logger.error("Stats error", error);
    res.status(500).json({
      error: "INTERNAL_ERROR",
      message: error.message,
    });
  }
});

/**
 * Root endpoint
 */
app.get("/", (req, res) => {
  res.json({
    name: "AndeChain Faucet",
    version: "2.0.0",
    endpoints: {
      health: "GET /health",
      request: "POST / { address }",
      status: "GET /status/:address",
      stats: "GET /stats",
    },
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: "NOT_FOUND",
    message: "Endpoint not found",
  });
});

// Error handler
app.use((err, req, res, next) => {
  Logger.error("Unhandled error", err);
  res.status(500).json({
    error: "INTERNAL_ERROR",
    message: CONFIG.NODE_ENV === "production" ? "Internal server error" : err.message,
  });
});

// ==========================================
// SERVER STARTUP
// ==========================================

async function startServer() {
  try {
    // Initialize faucet service
    const initialized = await faucetService.initialize();
    if (!initialized) {
      Logger.error("Failed to initialize faucet service. Exiting.");
      process.exit(1);
    }

    // Start server
    const server = app.listen(CONFIG.PORT, () => {
      console.log("");
      console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      console.log("🚰 AndeChain ERC20 Faucet Server v2.0 (Production-Ready)");
      console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      console.log(`🌐 Server:      http://localhost:${CONFIG.PORT}`);
      console.log(`💧 Amount:      ${ethers.formatEther(CONFIG.FAUCET_AMOUNT)} ANDE per request`);
      console.log(`⏱️  Cooldown:    ${CONFIG.COOLDOWN_TIME / 1000}s`);
      console.log(`📊 Daily Limit:  ${CONFIG.MAX_DAILY_REQUESTS} requests`);
      console.log(`🪙 Token:       ${CONFIG.TOKEN_ADDRESS}`);
      console.log(`🔗 RPC:         ${CONFIG.RPC_URL}`);
      console.log(`👛 Faucet:      ${faucetService.wallet.address}`);
      console.log(`🌍 Environment: ${CONFIG.NODE_ENV}`);
      console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      console.log("");
      Logger.info("ERC20 Faucet server is ready to serve requests");
    });

    // Graceful shutdown
    const shutdown = async (signal) => {
      Logger.info(`Received ${signal}. Starting graceful shutdown...`);
      server.close(() => {
        Logger.info("Server closed");
        process.exit(0);
      });

      // Force close after 10s
      setTimeout(() => {
        Logger.error("Forced shutdown after timeout");
        process.exit(1);
      }, 10000);
    };

    process.on("SIGTERM", () => shutdown("SIGTERM"));
    process.on("SIGINT", () => shutdown("SIGINT"));

  } catch (error) {
    Logger.error("Failed to start server", error);
    process.exit(1);
  }
}

// Start the server
startServer();