const express = require('express');
const cors = require('cors');
const { ethers } = require('ethers');

const app = express();
const PORT = 8081;

// Middleware
app.use(cors());
app.use(express.json());

// Configuration
const FAUCET_AMOUNT = ethers.parseEther('10'); // 10 ANDE
const COOLDOWN_TIME = 60 * 1000; // 1 minute in milliseconds
const RPC_URL = process.env.RPC_URL || 'http://localhost:8545';
const PRIVATE_KEY = process.env.FAUCET_PRIVATE_KEY || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

// Provider and wallet
const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

// Cooldown tracking
const cooldowns = new Map();

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    const balance = await provider.getBalance(wallet.address);
    const blockNumber = await provider.getBlockNumber();
    const network = await provider.getNetwork();

    res.json({
      status: 'healthy',
      faucetAddress: wallet.address,
      balance: ethers.formatEther(balance),
      blockNumber: blockNumber.toString(),
      chainId: network.chainId.toString(),
      cooldownTime: COOLDOWN_TIME / 1000 + 's',
      faucetAmount: ethers.formatEther(FAUCET_AMOUNT)
    });
  } catch (error) {
    res.status(500).json({
      status: 'unhealthy',
      error: error.message
    });
  }
});

// Faucet endpoint
app.post('/', async (req, res) => {
  const { address } = req.body;

  // Validate address
  if (!address || !ethers.isAddress(address)) {
    return res.status(400).json({
      success: false,
      message: 'Dirección inválida. Proporciona una dirección Ethereum válida.'
    });
  }

  // Check cooldown
  const now = Date.now();
  const lastRequest = cooldowns.get(address.toLowerCase());

  if (lastRequest && (now - lastRequest) < COOLDOWN_TIME) {
    const remainingTime = Math.ceil((COOLDOWN_TIME - (now - lastRequest)) / 1000);
    return res.status(429).json({
      success: false,
      message: `Por favor espera ${remainingTime} segundos antes de solicitar más fondos.`,
      remainingTime
    });
  }

  try {
    // Check faucet balance
    const faucetBalance = await provider.getBalance(wallet.address);
    if (faucetBalance < FAUCET_AMOUNT) {
      return res.status(503).json({
        success: false,
        message: 'El faucet no tiene suficientes fondos. Por favor contacta al administrador.'
      });
    }

    // Send transaction
    const tx = await wallet.sendTransaction({
      to: address,
      value: FAUCET_AMOUNT
    });

    // Wait for confirmation
    const receipt = await tx.wait();

    // Update cooldown
    cooldowns.set(address.toLowerCase(), now);

    res.json({
      success: true,
      message: `¡${ethers.formatEther(FAUCET_AMOUNT)} ANDE enviados exitosamente!`,
      txHash: receipt.hash,
      blockNumber: receipt.blockNumber,
      from: wallet.address,
      to: address,
      amount: ethers.formatEther(FAUCET_AMOUNT)
    });

  } catch (error) {
    console.error('Faucet error:', error);
    res.status(500).json({
      success: false,
      message: 'Error al procesar la transacción: ' + error.message
    });
  }
});

// Get cooldown status
app.get('/cooldown/:address', (req, res) => {
  const { address } = req.params;

  if (!ethers.isAddress(address)) {
    return res.status(400).json({
      success: false,
      message: 'Dirección inválida'
    });
  }

  const lastRequest = cooldowns.get(address.toLowerCase());
  if (!lastRequest) {
    return res.json({
      canRequest: true,
      remainingTime: 0
    });
  }

  const now = Date.now();
  const elapsed = now - lastRequest;
  const canRequest = elapsed >= COOLDOWN_TIME;
  const remainingTime = canRequest ? 0 : Math.ceil((COOLDOWN_TIME - elapsed) / 1000);

  res.json({
    canRequest,
    remainingTime,
    lastRequestTime: new Date(lastRequest).toISOString()
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚰 Faucet server running on http://localhost:${PORT}`);
  console.log(`💧 Faucet amount: ${ethers.formatEther(FAUCET_AMOUNT)} ANDE`);
  console.log(`⏱️  Cooldown: ${COOLDOWN_TIME / 1000}s`);
  console.log(`👛 Faucet address: ${wallet.address}`);
  console.log(`🔗 RPC: ${RPC_URL}`);
});
