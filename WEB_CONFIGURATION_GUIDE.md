# 🌐 CONFIGURACIÓN WEB - www.ande.network

Guía para configurar el frontend de AndeChain en otra PC (Vercel, otro servidor, etc).

---

## 📦 ARCHIVOS NECESARIOS

Copia estos archivos a tu proyecto web:

### 1. `FRONTEND_CONFIG.ts`
```typescript
// Copiar el contenido de /ande/FRONTEND_CONFIG.ts
// Este archivo contiene toda la configuración de la chain
```

### 2. `chainlist.json`
```json
// Copiar el contenido de /ande/chainlist.json
// Para integración con wallets y chainlist.org
```

---

## 🔧 INTEGRACIÓN EN TU WEB

### Para Next.js / React con wagmi:

```typescript
// config/chain.ts
import { defineChain } from 'viem'
import { ANDE_CHAIN_CONFIG } from './FRONTEND_CONFIG'

export const andechain = defineChain({
  id: ANDE_CHAIN_CONFIG.chainId,
  name: ANDE_CHAIN_CONFIG.chainName,
  nativeCurrency: ANDE_CHAIN_CONFIG.nativeCurrency,
  rpcUrls: {
    default: {
      http: [ANDE_CHAIN_CONFIG.rpc.http],
      webSocket: [ANDE_CHAIN_CONFIG.rpc.ws]
    }
  },
  blockExplorers: {
    default: {
      name: 'AndeChain Explorer',
      url: ANDE_CHAIN_CONFIG.services.explorer
    }
  },
  testnet: true
})
```

### Para ethers.js:

```javascript
// config/provider.ts
import { ethers } from 'ethers'
import { ANDE_CHAIN_CONFIG } from './FRONTEND_CONFIG'

export const provider = new ethers.JsonRpcProvider(
  ANDE_CHAIN_CONFIG.rpc.http,
  {
    chainId: ANDE_CHAIN_CONFIG.chainId,
    name: ANDE_CHAIN_CONFIG.chainName
  }
)
```

---

## 🔗 CONECTAR CON METAMASK

### Botón "Add AndeChain":

```javascript
async function addAndeChainToMetaMask() {
  try {
    await window.ethereum.request({
      method: 'wallet_addEthereumChain',
      params: [{
        chainId: '0x181E',
        chainName: 'AndeChain Testnet',
        nativeCurrency: {
          name: 'ANDE',
          symbol: 'ANDE',
          decimals: 18
        },
        rpcUrls: ['https://rpc.ande.network'],
        blockExplorerUrls: ['https://explorer.ande.network']
      }]
    })
  } catch (error) {
    console.error('Error adding chain:', error)
  }
}
```

---

## 📝 VARIABLES DE ENTORNO

Crear `.env.local`:

```bash
# AndeChain Configuration
NEXT_PUBLIC_CHAIN_ID=6174
NEXT_PUBLIC_CHAIN_NAME="AndeChain Testnet"
NEXT_PUBLIC_RPC_HTTP=https://rpc.ande.network
NEXT_PUBLIC_RPC_WS=wss://ws.ande.network
NEXT_PUBLIC_EXPLORER=https://explorer.ande.network
NEXT_PUBLIC_FAUCET=https://faucet.ande.network

# Contract Addresses (actualizar después del deployment)
NEXT_PUBLIC_ANDE_TOKEN=0x...
NEXT_PUBLIC_STAKING=0x...
NEXT_PUBLIC_GOVERNOR=0x...
```

---

## 🚀 DEPLOYMENT EN VERCEL

```bash
# 1. Instalar Vercel CLI
npm i -g vercel

# 2. Login
vercel login

# 3. Deploy
vercel --prod

# 4. Configurar variables de entorno en Vercel dashboard
```

---

## ✅ VERIFICACIÓN

### Test RPC Connection:
```javascript
const response = await fetch('https://rpc.ande.network', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    jsonrpc: '2.0',
    method: 'eth_chainId',
    params: [],
    id: 1
  })
})
const data = await response.json()
console.log('Chain ID:', parseInt(data.result, 16)) // Debe ser 6174
```

---

## 📚 ENDPOINTS

```
RPC HTTP:   https://rpc.ande.network
WebSocket:  wss://ws.ande.network
Explorer:   https://explorer.ande.network
Faucet:     https://faucet.ande.network
Status:     https://status.ande.network
```

---

**¿Problemas? Verifica que DNS esté propagado y que los endpoints estén accesibles.**
