# 🚀 CONFIGURACIÓN DE INFRAESTRUCTURA - ANDE BLOCKCHAIN

## 📋 ÍNDICE
1. [Endpoints de la Chain](#endpoints)
2. [Variables de Entorno (.env)](#env)
3. [Configuración de Red](#network)
4. [Smart Contracts Deployed](#contracts)
5. [RPC Endpoints](#rpc)
6. [API Endpoints](#api)
7. [Seguridad y Rate Limiting](#security)
8. [Monitoreo](#monitoring)

---

## 🔌 ENDPOINTS

### Production Endpoints (Cloudflare Tunnel - Global)

| Servicio | URL | Descripción | Estado |
|----------|-----|-------------|--------|
| RPC | `https://rpc.ande.network` | JSON-RPC Node | ✅ ACTIVO |
| API | `https://api.ande.network` | API REST Backend | ✅ ACTIVO |
| Explorer | `https://explorer.ande.network` | BlockScout Explorer | ✅ ACTIVO |
| Grafana | `https://grafana.ande.network` | Monitoreo | ✅ ACTIVO |
| Stats | `https://stats.ande.network` | Estadísticas | ✅ ACTIVO |
| Visualizer | `https://visualizer.ande.network` | Visualizador de Red | ✅ ACTIVO |
| Signatures | `https://signatures.ande.network` | Recolector de Firmas | ✅ ACTIVO |
| Web | `https://ande.network` | Frontend Principal | ✅ ACTIVO |

### Local Endpoints (Development)

| Servicio | URL | Puerto |
|----------|-----|--------|
| RPC | `http://localhost:8545` | 8545 |
| API | `http://localhost:4000` | 4000 |
| Explorer | `http://localhost:4001` | 4001 |
| Grafana | `http://localhost:3000` | 3000 |
| Stats | `http://localhost:8080` | 8080 |
| Visualizer | `http://localhost:8081` | 8081 |
| Signatures | `http://localhost:8082` | 8082 |

---

## 🔐 VARIABLES DE ENTORNO (.env)

### Chain Configuration

```env
# Chain Network
CHAIN_ID=6174
CHAIN_NAME=Ande Network
CHAIN_RPC_URL=https://rpc.ande.network
CHAIN_EXPLORER_URL=https://explorer.ande.network
CHAIN_CURRENCY_NAME=ANDE
CHAIN_CURRENCY_SYMBOL=ANDE
CHAIN_CURRENCY_DECIMALS=18

# Network
NETWORK_NAME=ande-network
NETWORK_ENVIRONMENT=production
NETWORK_TYPE=EVM

# API Endpoints
API_BASE_URL=https://api.ande.network
API_TIMEOUT=30000
API_RETRY_ATTEMPTS=3
API_RETRY_DELAY=1000

# RPC Configuration
RPC_URL=https://rpc.ande.network
RPC_TIMEOUT=30000
RPC_MAX_RETRIES=3
RPC_RATE_LIMIT=100

# Frontend Configuration
REACT_APP_RPC_URL=https://rpc.ande.network
REACT_APP_EXPLORER_URL=https://explorer.ande.network
REACT_APP_API_URL=https://api.ande.network
REACT_APP_CHAIN_ID=6174
REACT_APP_NETWORK_NAME=Ande Network

# Cloudflare Tunnel
CF_TUNNEL_ID=5fced6cf-92eb-4167-abd3-d0b9397613cc
CF_TUNNEL_NAME=ande-blockchain
CF_TUNNEL_DOMAIN=ande.network

# Monitoring
GRAFANA_URL=https://grafana.ande.network
GRAFANA_API_KEY=your_grafana_api_key
PROMETHEUS_URL=http://localhost:9090

# Security
ENABLE_CORS=true
ALLOWED_ORIGINS=https://ande.network,https://www.ande.network
ENABLE_RATE_LIMITING=true
RATE_LIMIT_WINDOW=10000
RATE_LIMIT_MAX_REQUESTS=100

# SSL/TLS
SSL_ENABLED=true
SSL_CERT_PATH=/etc/ssl/certs/ande-network.crt
SSL_KEY_PATH=/etc/ssl/private/ande-network.key

# DNS
DNS_PROVIDER=cloudflare
DNS_API_TOKEN=your_cloudflare_api_token
DNS_ZONE_ID=1a2374bfe74f97f24191ac70be588f13
```

---

## 🌐 CONFIGURACIÓN DE RED

### Network Details

```json
{
  "chainId": 6174,
  "chainName": "Ande Network",
  "nativeCurrency": {
    "name": "Ande",
    "symbol": "ANDE",
    "decimals": 18
  },
  "rpcUrls": [
    "https://rpc.ande.network"
  ],
  "blockExplorerUrls": [
    "https://explorer.ande.network"
  ],
  "icon": "https://ande.network/icon.png",
  "shortName": "ande",
  "networkId": 6174
}
```

### Para Agregar a MetaMask

```javascript
// JavaScript para agregar network a MetaMask
const addNetwork = async () => {
  try {
    await window.ethereum.request({
      method: 'wallet_addEthereumChain',
      params: [{
        chainId: '0x181e', // 6174 in hex
        chainName: 'Ande Network',
        rpcUrls: ['https://rpc.ande.network'],
        blockExplorerUrls: ['https://explorer.ande.network'],
        nativeCurrency: {
          name: 'Ande',
          symbol: 'ANDE',
          decimals: 18,
        },
      }],
    });
  } catch (error) {
    console.error('Error adding network:', error);
  }
};
```

---

## 📝 SMART CONTRACTS DEPLOYED

### Estado Actual de Contratos

**[COMPLETAR CON TUS CONTRATOS DEPLOYADOS]**

```json
{
  "contracts": [
    {
      "name": "Token",
      "address": "0x...",
      "network": "ande-network",
      "deploymentBlock": 0,
      "verified": false,
      "abi": "..."
    }
  ]
}
```

**Acciones necesarias:**
1. Verificar qué contratos ya están deployados
2. Agregar direcciones y ABI
3. Verificar en block explorer

---

## 🔌 RPC ENDPOINTS

### Métodos Soportados

#### eth_blockNumber
```bash
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Response
# {"jsonrpc":"2.0","id":1,"result":"0x1074"}
```

#### eth_getBalance
```bash
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0xaddress","latest"],"id":1}'
```

#### eth_call
```bash
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"eth_call",
    "params":[{
      "to":"0xcontractaddress",
      "data":"0x..."
    },"latest"],
    "id":1
  }'
```

### Rate Limiting

- **Límite**: 100 requests por IP cada 10 segundos
- **Excepciones**: Whitelist en Cloudflare disponible
- **Premium**: Contactar para límites personalizados

---

## 🔗 API ENDPOINTS

### Base URL
```
https://api.ande.network
```

### Endpoints Disponibles

**[COMPLETAR CON TUS ENDPOINTS DE API]**

Ejemplos:
- `GET /v1/health` - Health check
- `GET /v1/chain/info` - Información de la chain
- `GET /v1/stats` - Estadísticas
- `GET /v1/blocks` - Últimos bloques
- `GET /v1/transactions` - Transacciones

---

## 🔒 SEGURIDAD Y RATE LIMITING

### Configuración Cloudflare WAF

```
Regla 1: Rate Limiting para RPC
- Path: /v1/rpc*
- Rate: 100 requests / 10 segundos / IP
- Action: Block

Regla 2: Bot Management
- Score < 30: Block
- Score 30-50: Challenge

Regla 3: DDoS Protection
- Automático
- Nivel: High
```

### CORS Configuration

```
Allowed Origins:
- https://ande.network
- https://www.ande.network
- https://explorer.ande.network
- https://api.ande.network

Allowed Methods:
- GET
- POST
- OPTIONS

Allowed Headers:
- Content-Type
- Authorization
- X-Requested-With
```

---

## 📊 MONITOREO

### Prometheus Metrics

**URL**: `http://localhost:2000/metrics`

Métricas disponibles:
- `cloudflared_tunnel_bytes_sent` - Bytes enviados
- `cloudflared_tunnel_bytes_received` - Bytes recibidos
- `cloudflared_tunnel_requests_total` - Requests totales
- `cloudflared_tunnel_latency` - Latencia

### Grafana Dashboards

**URL**: `https://grafana.ande.network`

Dashboards disponibles:
- Tunnel Status
- RPC Performance
- Network Health
- API Metrics

### Logs Cloudflare

Dashboard → Analytics & Logs
- Ver todos los requests
- Filtrar por status code
- Analizar patrones
- Exportar datos

---

## 🚀 DEPLOYMENT Y ACTUALIZACIÓN

### Para Actualizar tu Web

1. **Agregar Endpoints a tu .env**
   ```env
   REACT_APP_RPC_URL=https://rpc.ande.network
   REACT_APP_API_URL=https://api.ande.network
   REACT_APP_CHAIN_ID=6174
   ```

2. **Inicializar Web3**
   ```javascript
   import Web3 from 'web3';
   
   const web3 = new Web3('https://rpc.ande.network');
   ```

3. **Conectar con Ethers.js**
   ```javascript
   import { ethers } from 'ethers';
   
   const provider = new ethers.JsonRpcProvider('https://rpc.ande.network');
   ```

4. **Agregar Network a MetaMask**
   Ver sección "Para Agregar a MetaMask" arriba

### Para Verificar Cambios

```bash
# 1. Verificar RPC
curl https://rpc.ande.network -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# 2. Verificar API
curl https://api.ande.network/health

# 3. Verificar Explorer
curl -I https://explorer.ande.network

# 4. Verificar Chain ID
curl https://rpc.ande.network -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

---

## 📞 SOPORTE Y DOCUMENTACIÓN

- **Documentación**: https://github.com/sator/andelabs
- **Issues**: GitHub Issues
- **Monitoreo**: https://grafana.ande.network
- **Explorer**: https://explorer.ande.network
- **Status**: https://status.ande.network (si aplica)

---

**Última actualización**: 2025-11-06
**Versión**: 1.0.0
**Estado**: Production Ready
