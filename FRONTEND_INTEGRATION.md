# Frontend Integration Guide - ANDE Chain

## 📋 Información de la Chain para el Frontend

Esta guía contiene toda la información que el frontend necesita para conectarse y operar con ANDE Chain.

---

## 🔌 Endpoints RPC

### Para Desarrollo Local
```typescript
const RPC_HTTP = "http://localhost:8545"
const RPC_WS = "ws://localhost:8546"
```

### Para Testnet Público (via Nginx)
```typescript
const RPC_HTTP = "http://localhost/rpc"        // O tu IP pública
const RPC_WS = "ws://localhost/ws"             // O tu IP pública
```

### Direct Connection (Sin Proxy)
```typescript
const RPC_HTTP = "http://localhost:8545"
const RPC_WS = "ws://localhost:8546"
```

---

## 🪙 Contratos Inteligentes

### ANDE Token (DEPLOYADO ✅)
```typescript
const ANDE_TOKEN = {
  address: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
  implementation: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
  precompile: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  decimals: 18,
  name: "ANDE",
  symbol: "ANDE",
  totalSupply: "100000000000000000000000000",  // 100M with 18 decimals
  type: "Token Duality (Native + ERC20)",
}
```

### Governance (READY TO DEPLOY)
```typescript
const GOVERNANCE_CONTRACTS = {
  AndeGovernor: {
    status: "ready",
    address: null,  // Deploy when needed
  },
  AndeTimelockController: {
    status: "ready",
    address: null,  // Deploy when needed
  },
}
```

### Staking (READY TO DEPLOY)
```typescript
const STAKING_CONTRACTS = {
  VotingEscrow: {
    name: "veANDE",
    status: "ready",
    address: null,
  },
  GaugeController: {
    status: "ready",
    address: null,
  },
}
```

### DEX (READY TO DEPLOY)
```typescript
const DEX_CONTRACTS = {
  AndeSwapFactory: {
    status: "ready",
    address: null,
    versions: ["V2", "V3"],
  },
  AndeSwapRouter: {
    status: "ready",
    address: null,
  },
}
```

---

## 🌐 Chain Información

```typescript
const CHAIN_INFO = {
  chainId: 6174,
  chainName: "AndeChain",
  nativeCurrency: {
    name: "Ethereum",
    symbol: "ETH",
    decimals: 18,
  },
  rpcUrls: {
    http: ["http://localhost:8545"],
    ws: ["ws://localhost:8546"],
  },
  blockExplorerUrls: [
    "http://localhost:3000",  // Grafana
  ],
}
```

---

## ⚙️ MetaMask / Wallet Configuration

### Agregar a MetaMask
```typescript
const addAndeChainToMetaMask = async () => {
  try {
    await window.ethereum.request({
      method: "wallet_addEthereumChain",
      params: [
        {
          chainId: "0x1826",  // 6174 in hex
          chainName: "AndeChain Testnet",
          nativeCurrency: {
            name: "Ethereum",
            symbol: "ETH",
            decimals: 18,
          },
          rpcUrls: ["http://localhost:8545"],
          blockExplorerUrls: ["http://localhost:3000"],
        },
      ],
    });
  } catch (error) {
    console.error("Error adding chain:", error);
  }
};
```

### Switch Network (Si ya está agregada)
```typescript
const switchToAndeChain = async () => {
  try {
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: "0x1826" }],
    });
  } catch (error) {
    if (error.code === 4902) {
      addAndeChainToMetaMask();
    }
  }
};
```

---

## 📊 Block & Network Parameters

```typescript
const NETWORK_PARAMS = {
  blockTime: 2,                    // segundos
  estimatedFinality: 30,           // segundos
  gasLimit: 30_000_000,            // 30M por bloque
  baseFeePerGas: "1000000000",     // 1 gwei
  maxTPS: 1000,                    // Transacciones por segundo
  confirmationBlocks: 1,           // Bloques para confirmar
  maxSlippage: 0.5,                // 0.5% para swaps
}
```

---

## 💰 Token Information

### ANDE Token
```typescript
const ANDE = {
  address: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
  symbol: "ANDE",
  name: "ANDE Token",
  decimals: 18,
  icon: "/assets/ande-token.svg",
  color: "#8B5CF6",
  coingeckoId: null,  // Add after listing
}
```

### Test ETH
```typescript
const ETH = {
  symbol: "ETH",
  name: "Ethereum (Test)",
  decimals: 18,
  isNative: true,
  icon: "/assets/eth.svg",
  color: "#627EEA",
}
```

---

## 🔑 Test Accounts (Hardhat)

```typescript
const TEST_ACCOUNTS = [
  {
    address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    name: "Admin",
    balance: "10000 ETH",
    privateKey: "0xac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f02d45b19e8bfb81",
  },
  {
    address: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    name: "User 1",
    balance: "10000 ETH",
  },
  {
    address: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
    name: "User 2",
    balance: "10000 ETH",
  },
]
```

---

## 📡 API Endpoints

### Status & Info
```
GET http://localhost/api/info
```

Response:
```json
{
  "chain": "andechain",
  "chainId": 6174,
  "network": "testnet-mocha-4",
  "rpcUrl": "http://localhost/rpc",
  "wsUrl": "ws://localhost/ws",
  "evolveUrl": "http://localhost/evolve",
  "metricsUrl": "http://localhost/metrics",
  "grafanaUrl": "http://localhost/grafana"
}
```

### Monitoring Endpoints
```
Grafana:    http://localhost:3000
Prometheus: http://localhost:9090
Loki:       http://localhost:3100
cAdvisor:   http://localhost:8080
```

---

## 📦 Installation & Setup

### 1. Copy Configuration Files

```bash
# Copy to your frontend project
cp /ande/chain.config.ts ./src/config/
cp /ande/chain.config.json ./public/config/
```

### 2. Import in Your Frontend

#### TypeScript (React/Next.js)
```typescript
import { ANDE_CHAIN_CONFIG, useAndeChain } from './config/chain.config'

export default function App() {
  const chainConfig = useAndeChain()
  const tokens = chainConfig.helpers.getTokens?.()

  return (
    <div>
      <h1>{chainConfig.network.chainName}</h1>
      <p>Chain ID: {chainConfig.network.chainId}</p>
    </div>
  )
}
```

#### JavaScript (Vanilla/Vue)
```javascript
const config = require('./config/chain.config.json')

console.log('Chain ID:', config.network.chainId)
console.log('RPC:', config.rpc.local.http)
```

### 3. Web3 Integration

```typescript
import Web3 from 'web3'
import ANDE_CHAIN_CONFIG from './config/chain.config'

const web3 = new Web3(ANDE_CHAIN_CONFIG.rpc.local.http)

// Get current block number
const blockNumber = await web3.eth.getBlockNumber()
console.log('Current Block:', blockNumber)

// Get balance
const balance = await web3.eth.getBalance(ANDE_CHAIN_CONFIG.accounts.admin.address)
console.log('Admin Balance:', web3.utils.fromWei(balance, 'ether'), 'ETH')
```

### 4. Ethers.js Integration

```typescript
import { ethers } from 'ethers'
import ANDE_CHAIN_CONFIG from './config/chain.config'

const provider = new ethers.JsonRpcProvider(ANDE_CHAIN_CONFIG.rpc.local.http)

// Get block
const block = await provider.getBlock('latest')
console.log('Latest Block:', block.number)

// Get balance
const balance = await provider.getBalance(ANDE_CHAIN_CONFIG.accounts.admin.address)
console.log('Admin Balance:', ethers.formatEther(balance), 'ETH')

// Read contract
const andeToken = new ethers.Contract(
  ANDE_CHAIN_CONFIG.contracts.tokens.ANDE.address,
  ['function balanceOf(address) view returns (uint256)'],
  provider
)

const andBalance = await andeToken.balanceOf(ANDE_CHAIN_CONFIG.accounts.admin.address)
console.log('ANDE Balance:', ethers.formatUnits(andBalance, 18))
```

---

## 🔄 Update Configuration

Cuando depliegues nuevos contratos, actualiza la configuración:

```typescript
// chain.config.ts
contracts: {
  governance: {
    AndeGovernor: {
      status: 'deployed',
      address: '0x...',  // Agregar dirección deployada
    },
  },
}
```

---

## ✅ Validation Checklist

- [ ] Chain ID: 6174
- [ ] RPC HTTP: http://localhost:8545 (o tu IP)
- [ ] RPC WS: ws://localhost:8546 (o tu IP)
- [ ] ANDE Token: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
- [ ] Block Time: 2 seconds
- [ ] Test accounts loaded
- [ ] MetaMask configured
- [ ] Web3/Ethers connected
- [ ] Token balance readable
- [ ] Transactions possible

---

## 🚀 Quick Test

```bash
# Test RPC connection
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Expected response:
# {"jsonrpc":"2.0","id":1,"result":"0x..."}
```

---

## 📚 Additional Resources

- **Chain Config (TypeScript)**: `/ande/chain.config.ts`
- **Chain Config (JSON)**: `/ande/chain.config.json`
- **Setup Guide**: `/ande/TESTNET_SETUP.md`
- **Quick Start**: `/ande/QUICK_START.md`
- **API Docs**: `/ande/TESTNET_ENDPOINTS.md`

---

**Last Updated**: 2025-10-30
**Status**: Ready for Integration ✅
