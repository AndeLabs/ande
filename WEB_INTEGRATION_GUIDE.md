# 🚀 GUÍA DE INTEGRACIÓN PARA WEB - ANDE BLOCKCHAIN

## 📋 ÍNDICE
1. [Datos de Conexión](#datos-conexion)
2. [Environment Variables (.env)](#env-variables)
3. [Smart Contracts](#smart-contracts)
4. [Información de la Chain](#chain-info)
5. [Código de Ejemplo](#codigo-ejemplo)
6. [Verificación y Testing](#testing)

---

## 🔌 DATOS DE CONEXIÓN

### URLs de Producción (ACTIVOS Y FUNCIONANDO)

```
┌─────────────────────────────────────────────────────────────┐
│         ANDE BLOCKCHAIN - PRODUCTION ENDPOINTS              │
├─────────────────────────────────────────────────────────────┤
│ RPC Node       → https://rpc.ande.network                  │
│ API REST       → https://api.ande.network                  │
│ Block Explorer → https://explorer.ande.network             │
│ Grafana        → https://grafana.ande.network              │
│ Stats          → https://stats.ande.network                │
│ Visualizer     → https://visualizer.ande.network           │
│ Signatures     → https://signatures.ande.network           │
│ Web            → https://ande.network                      │
│ Web (WWW)      → https://www.ande.network                  │
└─────────────────────────────────────────────────────────────┘
```

### URLs Locales (Development)

```
RPC Node       → http://localhost:8545
API REST       → http://localhost:4000
Block Explorer → http://localhost:4001
Grafana        → http://localhost:3000
Stats          → http://localhost:8080
Visualizer     → http://localhost:8081
Signatures     → http://localhost:8082
```

---

## 🔐 ENVIRONMENT VARIABLES (.env)

### Copiar y Usar en tu Proyecto

```env
# ==========================================
# ANDE BLOCKCHAIN CONFIGURATION
# ==========================================

# Chain Network
REACT_APP_CHAIN_ID=6174
REACT_APP_CHAIN_ID_HEX=0x181e
REACT_APP_CHAIN_NAME=Ande Network
REACT_APP_NETWORK_NAME=Ande Network
REACT_APP_CURRENCY_NAME=ANDE
REACT_APP_CURRENCY_SYMBOL=ANDE
REACT_APP_CURRENCY_DECIMALS=18

# RPC Endpoints
REACT_APP_RPC_URL=https://rpc.ande.network
REACT_APP_RPC_FALLBACK=https://rpc.ande.network
REACT_APP_RPC_TIMEOUT=30000
REACT_APP_RPC_RETRIES=3

# API Endpoints
REACT_APP_API_URL=https://api.ande.network
REACT_APP_API_TIMEOUT=30000
REACT_APP_API_RETRIES=3

# Explorer
REACT_APP_EXPLORER_URL=https://explorer.ande.network
REACT_APP_EXPLORER_TX_URL=https://explorer.ande.network/tx
REACT_APP_EXPLORER_ADDRESS_URL=https://explorer.ande.network/address

# Monitoring & Analytics
REACT_APP_GRAFANA_URL=https://grafana.ande.network
REACT_APP_STATS_URL=https://stats.ande.network

# Security
REACT_APP_ENABLE_CORS=true
REACT_APP_ALLOWED_ORIGINS=https://ande.network,https://www.ande.network

# Feature Flags
REACT_APP_ENABLE_WALLET_CONNECT=true
REACT_APP_ENABLE_METAMASK=true
REACT_APP_ENABLE_WEB3_MODAL=true
REACT_APP_ENABLE_ETHERS_JS=true

# Network Detection
REACT_APP_AUTO_SWITCH_NETWORK=true
REACT_APP_SHOW_NETWORK_WARNING=true
```

---

## 📝 INFORMACIÓN DE LA CHAIN

### Chain Identifier

```json
{
  "chainId": 6174,
  "chainIdHex": "0x181e",
  "chainName": "Ande Network",
  "shortName": "ande",
  "networkId": 6174
}
```

### Native Currency

```json
{
  "name": "ANDE",
  "symbol": "ANDE",
  "decimals": 18,
  "type": "EVM"
}
```

### Network Configuration para MetaMask

```json
{
  "chainId": "0x181e",
  "chainName": "Ande Network",
  "nativeCurrency": {
    "name": "ANDE",
    "symbol": "ANDE",
    "decimals": 18
  },
  "rpcUrls": ["https://rpc.ande.network"],
  "blockExplorerUrls": ["https://explorer.ande.network"]
}
```

---

## 💡 SMART CONTRACTS DEPLOYED

### Estado Actual

**IMPORTANTE**: Necesitas completar esta información con tus contratos deployados.

```json
{
  "contracts": [
    {
      "name": "Token",
      "address": "0x...",
      "network": "ande-network",
      "chainId": 6174,
      "deploymentBlock": 0,
      "deploymentDate": "2025-11-06",
      "verified": false,
      "abi": [],
      "description": "ANDE Token Contract"
    }
  ]
}
```

### Acciones Necesarias

1. **Obtener direcciones de contratos deployados**
   ```bash
   # Ver en tu historial de deployment
   cat deployed-addresses.json
   ```

2. **Verificar en BlockScout**
   - Ve a: https://explorer.ande.network
   - Busca tu contrato por dirección
   - Verifica el bytecode

3. **Obtener ABI**
   ```bash
   # Desde Foundry/Hardhat
   cat artifacts/contracts/Token.json | jq '.abi'
   ```

4. **Verificar Contratos (Opcional)**
   - En BlockScout: Verify Contract
   - Agregar source code
   - Verificar ABI

---

## 🔌 CÓDIGO DE EJEMPLO

### React + Web3.js

```javascript
import Web3 from 'web3';

// Inicializar Web3
const web3 = new Web3(process.env.REACT_APP_RPC_URL);

// Obtener bloque actual
async function getBlockNumber() {
  try {
    const blockNumber = await web3.eth.getBlockNumber();
    console.log('Current block:', blockNumber);
    return blockNumber;
  } catch (error) {
    console.error('Error:', error);
  }
}

// Obtener balance de cuenta
async function getBalance(address) {
  try {
    const balance = await web3.eth.getBalance(address);
    const balanceInEther = web3.utils.fromWei(balance, 'ether');
    console.log('Balance:', balanceInEther, 'ANDE');
    return balanceInEther;
  } catch (error) {
    console.error('Error:', error);
  }
}

// Obtener información de red
async function getNetworkInfo() {
  try {
    const chainId = await web3.eth.getChainId();
    const gasPrice = await web3.eth.getGasPrice();
    console.log('Chain ID:', chainId);
    console.log('Gas Price:', web3.utils.fromWei(gasPrice, 'gwei'), 'gwei');
    return { chainId, gasPrice };
  } catch (error) {
    console.error('Error:', error);
  }
}

export { web3, getBlockNumber, getBalance, getNetworkInfo };
```

### React + Ethers.js

```javascript
import { ethers } from 'ethers';

// Inicializar provider
const provider = new ethers.JsonRpcProvider(process.env.REACT_APP_RPC_URL);

// Obtener bloque actual
async function getBlockNumber() {
  try {
    const blockNumber = await provider.getBlockNumber();
    console.log('Current block:', blockNumber);
    return blockNumber;
  } catch (error) {
    console.error('Error:', error);
  }
}

// Obtener balance
async function getBalance(address) {
  try {
    const balance = await provider.getBalance(address);
    const balanceInEther = ethers.formatEther(balance);
    console.log('Balance:', balanceInEther, 'ANDE');
    return balanceInEther;
  } catch (error) {
    console.error('Error:', error);
  }
}

// Obtener network info
async function getNetworkInfo() {
  try {
    const network = await provider.getNetwork();
    console.log('Chain ID:', network.chainId);
    console.log('Network Name:', network.name);
    return network;
  } catch (error) {
    console.error('Error:', error);
  }
}

// Conectar wallet y obtener signer
async function connectWallet() {
  try {
    const signer = await provider.getSigner();
    const address = await signer.getAddress();
    console.log('Connected address:', address);
    return { signer, address };
  } catch (error) {
    console.error('Error:', error);
  }
}

export { provider, getBlockNumber, getBalance, getNetworkInfo, connectWallet };
```

### Agregar Network a MetaMask

```javascript
async function addAndeNetworkToMetaMask() {
  if (!window.ethereum) {
    alert('MetaMask is not installed!');
    return false;
  }

  try {
    await window.ethereum.request({
      method: 'wallet_addEthereumChain',
      params: [{
        chainId: '0x181e', // 6174 in hex
        chainName: 'Ande Network',
        rpcUrls: ['https://rpc.ande.network'],
        blockExplorerUrls: ['https://explorer.ande.network'],
        nativeCurrency: {
          name: 'ANDE',
          symbol: 'ANDE',
          decimals: 18,
        },
      }],
    });
    console.log('Network added successfully!');
    return true;
  } catch (error) {
    console.error('Error adding network:', error);
    return false;
  }
}

// Ejecutar cuando usuario carga la web
useEffect(() => {
  addAndeNetworkToMetaMask();
}, []);
```

### Verificar Chain ID Correcto

```javascript
async function verifyChainId() {
  const expectedChainId = parseInt(process.env.REACT_APP_CHAIN_ID, 10);
  
  if (window.ethereum) {
    const chainId = parseInt(window.ethereum.chainId, 16);
    
    if (chainId !== expectedChainId) {
      console.warn(`Wrong network! Expected ${expectedChainId}, got ${chainId}`);
      // Pedir al usuario que cambie de network
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: '0x181e' }],
      });
    }
  }
}

useEffect(() => {
  verifyChainId();
}, []);
```

---

## 🧪 VERIFICACIÓN Y TESTING

### 1. Verificar RPC Endpoint

```bash
# Test bloque actual
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Response esperado:
# {"jsonrpc":"2.0","id":1,"result":"0x1074"}
```

### 2. Verificar Chain ID

```bash
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Response esperado:
# {"jsonrpc":"2.0","id":1,"result":"0x181e"}
```

### 3. Verificar Conexión en React

```javascript
// Agregar a tu componente
useEffect(() => {
  const testConnection = async () => {
    try {
      const blockNumber = await web3.eth.getBlockNumber();
      const chainId = await web3.eth.getChainId();
      console.log('✅ Connected to Ande Network');
      console.log(`Block: ${blockNumber}, Chain ID: ${chainId}`);
    } catch (error) {
      console.error('❌ Connection failed:', error);
    }
  };
  testConnection();
}, []);
```

### 4. Verificar desde Terminal

```bash
# Test RPC
npm run test:rpc

# O manualmente:
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq

# Test API
curl https://api.ande.network/health

# Test Explorer
curl -I https://explorer.ande.network
```

---

## 🐛 TROUBLESHOOTING

### Problema: RPC Timeout

```javascript
// Solución: Aumentar timeout en .env
REACT_APP_RPC_TIMEOUT=60000

// O en Web3.js:
const web3 = new Web3(new Web3.providers.HttpProvider(
  process.env.REACT_APP_RPC_URL,
  { timeout: 60000 }
));
```

### Problema: Network Not Found en MetaMask

```javascript
// Asegúrate que Chain ID es correcto:
chainId: '0x181e' // 6174 en hex

// Verifica que tu .env tiene:
REACT_APP_CHAIN_ID=6174
```

### Problema: CORS Error

```javascript
// Si obtienes CORS error, el túnel de Cloudflare ya lo maneja
// Pero si ocurre, configura:

// En Next.js (next.config.js):
async headers() {
  return [
    {
      source: '/:path*',
      headers: [
        {
          key: 'Access-Control-Allow-Origin',
          value: '*',
        },
      ],
    },
  ];
}
```

### Problema: Contrato No Encontrado

```javascript
// Verifica que:
1. La dirección es correcta (copy-paste desde explorer)
2. El contrato está deployado en esa dirección
3. El ABI es correcto
4. Estás en la red correcta (6174)

// Debug:
const code = await provider.getCode(contractAddress);
console.log('Contract code:', code); // Debe ser más que '0x'
```

---

## 📊 INFORMACIÓN PARA TU DASHBOARD

### Datos a Mostrar en Tu Web

```javascript
const dashboardData = {
  networkName: 'Ande Network',
  chainId: 6174,
  rpcUrl: 'https://rpc.ande.network',
  explorerUrl: 'https://explorer.ande.network',
  currency: {
    name: 'ANDE',
    symbol: 'ANDE',
    decimals: 18,
  },
  status: 'Operational',
  uptime: '99.99%',
  latency: '<100ms',
  endpoints: {
    rpc: 'https://rpc.ande.network',
    api: 'https://api.ande.network',
    explorer: 'https://explorer.ande.network',
  },
};
```

### Monitoreo en Tiempo Real

```javascript
// Verificar salud del RPC cada 30 segundos
setInterval(async () => {
  try {
    const blockNumber = await provider.getBlockNumber();
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Block: ${blockNumber} - ✅ RPC Healthy`);
  } catch (error) {
    console.error(`❌ RPC Error: ${error.message}`);
    // Notificar usuario o cambiar a fallback
  }
}, 30000);
```

---

## 🚀 DEPLOY CHECKLIST

- [ ] `.env` configurado con URLs de producción
- [ ] Chain ID verificado (6174)
- [ ] RPC endpoint respondiendo
- [ ] MetaMask network agregado
- [ ] Smart contracts direcciones correctas
- [ ] ABI de contratos incluido
- [ ] Conexión a Web3 probada
- [ ] Transacciones de prueba exitosas
- [ ] Explorer mostrando transacciones
- [ ] API respondiendo correctamente
- [ ] CORS habilitado
- [ ] SSL/TLS funcionando
- [ ] Monitoreo configurado

---

## 📞 SOPORTE

- **Documentación**: https://github.com/AndeLabs/ande
- **Issues**: https://github.com/AndeLabs/ande/issues
- **Explorer**: https://explorer.ande.network
- **Grafana Monitoring**: https://grafana.ande.network

---

**Última actualización**: 2025-11-06
**Versión**: 1.0.0
**Estado**: Production Ready ✅
