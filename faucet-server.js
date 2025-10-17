const express = require("express");
const cors = require("cors");
const { ethers } = require("ethers");

const app = express();
const PORT = process.env.FAUCET_PORT || 3001;

const CONFIG = {
  FAUCET_AMOUNT: ethers.parseEther("10"),
  COOLDOWN_TIME: 60 * 1000,
  RPC_URL: process.env.RPC_URL || "http://localhost:8545",
  PRIVATE_KEY: process.env.FAUCET_PRIVATE_KEY || "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
};

app.use(cors({ origin: '*', methods: ['GET', 'POST'] }));
app.use(express.json());
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

let provider;
let wallet;
let isConnected = false;

async function initializeProvider() {
  try {
    provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
    wallet = new ethers.Wallet(CONFIG.PRIVATE_KEY, provider);
    const network = await provider.getNetwork();
    const balance = await provider.getBalance(wallet.address);
    isConnected = true;
    console.log('✅ Provider initialized');
    console.log(`   Chain ID: ${network.chainId}`);
    console.log(`   Faucet: ${wallet.address}`);
    console.log(`   Balance: ${ethers.formatEther(balance)} ANDE`);
    return true;
  } catch (error) {
    isConnected = false;
    console.error('❌ Provider failed:', error.message);
    return false;
  }
}

initializeProvider();

const cooldowns = new Map();

function checkCooldown(address) {
  const now = Date.now();
  const lastRequest = cooldowns.get(address.toLowerCase());
  if (!lastRequest) return { canRequest: true, remainingTime: 0 };
  const elapsed = now - lastRequest;
  const canRequest = elapsed >= CONFIG.COOLDOWN_TIME;
  const remainingTime = canRequest ? 0 : Math.ceil((CONFIG.COOLDOWN_TIME - elapsed) / 1000);
  return { canRequest, remainingTime };
}

app.get("/health", async (req, res) => {
  try {
    if (!isConnected) await initializeProvider();
    const balance = await provider.getBalance(wallet.address);
    const blockNumber = await provider.getBlockNumber();
    const network = await provider.getNetwork();
    res.json({
      status: "healthy",
      connected: isConnected,
      faucetAddress: wallet.address,
      balance: ethers.formatEther(balance),
      blockNumber: blockNumber.toString(),
      chainId: network.chainId.toString(),
      cooldownTime: `${CONFIG.COOLDOWN_TIME / 1000}s`,
      faucetAmount: ethers.formatEther(CONFIG.FAUCET_AMOUNT),
    });
  } catch (error) {
    res.status(500).json({ status: "unhealthy", error: error.message });
  }
});

app.post("/", async (req, res) => {
  const { address } = req.body;
  
  try {
    if (!address || !ethers.isAddress(address)) {
      return res.status(400).json({ success: false, message: "Invalid address" });
    }

    if (!isConnected) {
      const reconnected = await initializeProvider();
      if (!reconnected) {
        return res.status(503).json({ success: false, message: "Service unavailable" });
      }
    }

    const cooldownStatus = checkCooldown(address);
    if (!cooldownStatus.canRequest) {
      return res.status(429).json({
        success: false,
        message: `Wait ${cooldownStatus.remainingTime}s`,
        remainingTime: cooldownStatus.remainingTime,
      });
    }

    const faucetBalance = await provider.getBalance(wallet.address);
    if (faucetBalance < CONFIG.FAUCET_AMOUNT) {
      return res.status(503).json({ success: false, message: "Insufficient balance" });
    }

    console.log(`📤 Sending ${ethers.formatEther(CONFIG.FAUCET_AMOUNT)} ANDE to ${address}`);

    const tx = await wallet.sendTransaction({ 
      to: address, 
      value: CONFIG.FAUCET_AMOUNT,
      gasLimit: 21000
    });

    console.log(`✅ TX sent: ${tx.hash}`);
    cooldowns.set(address.toLowerCase(), Date.now());

    res.json({
      success: true,
      message: `Sent ${ethers.formatEther(CONFIG.FAUCET_AMOUNT)} ANDE`,
      txHash: tx.hash,
      from: wallet.address,
      to: address,
      amount: ethers.formatEther(CONFIG.FAUCET_AMOUNT),
      explorerUrl: `http://localhost:4000/tx/${tx.hash}`,
    });

    tx.wait(1, 30000).then(receipt => {
      console.log(`✅ Confirmed: ${tx.hash} in block ${receipt.blockNumber}`);
    }).catch(err => {
      console.warn(`⚠️  Confirmation timeout: ${tx.hash}`);
    });

  } catch (error) {
    console.error(`❌ Failed:`, error.message);
    res.status(500).json({ 
      success: false, 
      message: error.message,
      error: error.message 
    });
  }
});

app.get("/cooldown/:address", (req, res) => {
  const { address } = req.params;
  if (!ethers.isAddress(address)) {
    return res.status(400).json({ success: false, message: "Invalid address" });
  }
  const cooldownStatus = checkCooldown(address);
  const lastRequest = cooldowns.get(address.toLowerCase());
  res.json({
    canRequest: cooldownStatus.canRequest,
    remainingTime: cooldownStatus.remainingTime,
    lastRequestTime: lastRequest ? new Date(lastRequest).toISOString() : null,
  });
});

app.listen(PORT, () => {
  console.log('');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🚰 AndeChain Faucet Server');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`🌐 Server:    http://localhost:${PORT}`);
  console.log(`💧 Amount:    ${ethers.formatEther(CONFIG.FAUCET_AMOUNT)} ANDE`);
  console.log(`⏱️  Cooldown:  ${CONFIG.COOLDOWN_TIME / 1000}s`);
  console.log(`🔗 RPC:       ${CONFIG.RPC_URL}`);
  console.log(`👛 Faucet:    ${wallet.address}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
});

process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
