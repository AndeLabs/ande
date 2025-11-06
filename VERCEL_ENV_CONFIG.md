# 🚀 CONFIGURACIÓN VERCEL - ANDE BLOCKCHAIN (PRODUCTION)

## 📋 ENVIRONMENT VARIABLES ACTUALIZADAS

### Copiar y Pegar en Vercel Dashboard

```
# ==========================================
# BLOCKCHAIN NETWORK CONFIGURATION
# ==========================================

NEXT_PUBLIC_CHAIN_ID=6174
NEXT_PUBLIC_CHAIN_ID_HEX=0x181e
NEXT_PUBLIC_NETWORK_NAME=Ande Network
NEXT_PUBLIC_NETWORK_SHORT_NAME=ande
NEXT_PUBLIC_CURRENCY_NAME=ANDE
NEXT_PUBLIC_CURRENCY_SYMBOL=ANDE
NEXT_PUBLIC_CURRENCY_DECIMALS=18

# ==========================================
# PRODUCTION RPC & API ENDPOINTS (CLOUDFLARE)
# ==========================================

NEXT_PUBLIC_RPC_URL=https://rpc.ande.network
NEXT_PUBLIC_RPC_FALLBACK=https://rpc.ande.network
NEXT_PUBLIC_RPC_TIMEOUT=30000
NEXT_PUBLIC_RPC_RETRIES=3

NEXT_PUBLIC_API_URL=https://api.ande.network
NEXT_PUBLIC_API_TIMEOUT=30000
NEXT_PUBLIC_API_RETRIES=3

# ==========================================
# EXPLORERS & TOOLS
# ==========================================

NEXT_PUBLIC_EXPLORER_URL=https://explorer.ande.network
NEXT_PUBLIC_EXPLORER_TX_URL=https://explorer.ande.network/tx
NEXT_PUBLIC_EXPLORER_ADDRESS_URL=https://explorer.ande.network/address
NEXT_PUBLIC_EXPLORER_BLOCK_URL=https://explorer.ande.network/block

# ==========================================
# MONITORING & ANALYTICS
# ==========================================

NEXT_PUBLIC_GRAFANA_URL=https://grafana.ande.network
NEXT_PUBLIC_STATS_URL=https://stats.ande.network
NEXT_PUBLIC_VISUALIZER_URL=https://visualizer.ande.network

# ==========================================
# BLOCKCHAIN SERVICES
# ==========================================

NEXT_PUBLIC_FAUCET_URL=https://faucet.ande.network
NEXT_PUBLIC_SIGNATURES_URL=https://signatures.ande.network
NEXT_PUBLIC_CELESTIA_EXPLORER=https://mocha-4.celenium.io

# ==========================================
# DOCUMENTATION & SUPPORT
# ==========================================

NEXT_PUBLIC_DOCS_URL=https://docs.ande.network
NEXT_PUBLIC_SUPPORT_URL=https://discord.gg/andelabs
NEXT_PUBLIC_GITHUB_URL=https://github.com/AndeLabs/ande
NEXT_PUBLIC_STATUS_URL=https://status.ande.network

# ==========================================
# FEATURE FLAGS (OPTIONAL)
# ==========================================

NEXT_PUBLIC_ENABLE_STAKING=false
NEXT_PUBLIC_ENABLE_GOVERNANCE=false
NEXT_PUBLIC_ENABLE_DEX=false
NEXT_PUBLIC_ENABLE_BRIDGE=false
NEXT_PUBLIC_ENABLE_WALLET_CONNECT=true
NEXT_PUBLIC_ENABLE_METAMASK=true

# ==========================================
# NETWORK DETECTION & UI
# ==========================================

NEXT_PUBLIC_AUTO_SWITCH_NETWORK=true
NEXT_PUBLIC_SHOW_NETWORK_WARNING=true
NEXT_PUBLIC_ENABLE_DARK_MODE=true

# ==========================================
# SECURITY & CORS
# ==========================================

NEXT_PUBLIC_ENABLE_CORS=true
NEXT_PUBLIC_ALLOWED_ORIGINS=https://ande.network,https://www.ande.network,https://vercel.app

# ==========================================
# BUILD ENVIRONMENT
# ==========================================

NODE_ENV=production
NEXT_PUBLIC_APP_ENV=production
```

---

## 📊 TABLA DE CAMBIOS

| Variable | Antes | Ahora | Tipo |
|----------|-------|-------|------|
| `NEXT_PUBLIC_RPC_URL` | `http://189.28.81.202:8545` | `https://rpc.ande.network` | ✅ ACTUALIZADO |
| `NEXT_PUBLIC_EXPLORER_URL` | `http://189.28.81.202:4000` | `https://explorer.ande.network` | ✅ ACTUALIZADO |
| `NEXT_PUBLIC_GRAFANA_URL` | `http://189.28.81.202:3000` | `https://grafana.ande.network` | ✅ ACTUALIZADO |
| `NEXT_PUBLIC_FAUCET_URL` | `http://189.28.81.202:3001` | `https://faucet.ande.network` | ✅ ACTUALIZADO |
| `NEXT_PUBLIC_NETWORK_NAME` | `AndeChain Testnet` | `Ande Network` | ✅ ACTUALIZADO |
| *Nuevas variables* | - | `NEXT_PUBLIC_CHAIN_ID`, `NEXT_PUBLIC_RPC_FALLBACK`, etc | ✅ AGREGADAS |

---

## 🔄 PASOS PARA ACTUALIZAR EN VERCEL

### 1. Acceder al Dashboard de Vercel

```
https://vercel.com/dashboard
```

### 2. Seleccionar tu Proyecto

```
AndeLabs → ande (o tu proyecto)
```

### 3. Ir a Settings → Environment Variables

```
Vercel Dashboard → Tu Proyecto → Settings → Environment Variables
```

### 4. Actualizar Variables Existentes

| Variable | Nuevo Valor |
|----------|------------|
| `NEXT_PUBLIC_RPC_URL` | `https://rpc.ande.network` |
| `NEXT_PUBLIC_EXPLORER_URL` | `https://explorer.ande.network` |
| `NEXT_PUBLIC_GRAFANA_URL` | `https://grafana.ande.network` |
| `NEXT_PUBLIC_FAUCET_URL` | `https://faucet.ande.network` |
| `NEXT_PUBLIC_NETWORK_NAME` | `Ande Network` |

### 5. Agregar Variables Nuevas

Copiar y pegar del bloque anterior todas las nuevas variables.

### 6. Redeploy

```
Vercel Dashboard → Deployments → Latest → Redeploy
```

---

## ✅ VERIFICACIÓN POST-DEPLOY

### 1. Verificar Variables en Console

```javascript
// En tu página web, abrir console y ejecutar:
console.log({
  rpcUrl: process.env.NEXT_PUBLIC_RPC_URL,
  chainId: process.env.NEXT_PUBLIC_CHAIN_ID,
  explorerUrl: process.env.NEXT_PUBLIC_EXPLORER_URL
});

// Debe mostrar:
// {
//   rpcUrl: "https://rpc.ande.network",
//   chainId: "6174",
//   explorerUrl: "https://explorer.ande.network"
// }
```

### 2. Verificar Conexión RPC

```javascript
// Test desde tu app
const testRPC = async () => {
  try {
    const response = await fetch(process.env.NEXT_PUBLIC_RPC_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'eth_blockNumber',
        params: [],
        id: 1
      })
    });
    const data = await response.json();
    console.log('✅ RPC Working:', data);
  } catch (error) {
    console.error('❌ RPC Error:', error);
  }
};
testRPC();
```

### 3. Verificar MetaMask Network

```javascript
// Verificar que MetaMask puede conectarse
const addNetwork = async () => {
  try {
    await window.ethereum.request({
      method: 'wallet_addEthereumChain',
      params: [{
        chainId: '0x181e',
        chainName: process.env.NEXT_PUBLIC_NETWORK_NAME,
        rpcUrls: [process.env.NEXT_PUBLIC_RPC_URL],
        blockExplorerUrls: [process.env.NEXT_PUBLIC_EXPLORER_URL],
        nativeCurrency: {
          name: process.env.NEXT_PUBLIC_CURRENCY_NAME,
          symbol: process.env.NEXT_PUBLIC_CURRENCY_SYMBOL,
          decimals: 18,
        },
      }],
    });
  } catch (error) {
    console.error('Error:', error);
  }
};
```

---

## 📋 CHECKLIST DE ACTUALIZACIÓN

- [ ] Backup de variables actuales en Vercel
- [ ] Actualizar `NEXT_PUBLIC_RPC_URL` a `https://rpc.ande.network`
- [ ] Actualizar `NEXT_PUBLIC_EXPLORER_URL` a `https://explorer.ande.network`
- [ ] Actualizar `NEXT_PUBLIC_GRAFANA_URL` a `https://grafana.ande.network`
- [ ] Actualizar `NEXT_PUBLIC_FAUCET_URL` a `https://faucet.ande.network`
- [ ] Actualizar `NEXT_PUBLIC_NETWORK_NAME` a `Ande Network`
- [ ] Agregar nuevas variables (CHAIN_ID, RPC_FALLBACK, etc)
- [ ] Verificar que NODE_ENV=production
- [ ] Triggerear rebuild en Vercel
- [ ] Esperar 2-3 minutos para que se propaguen los cambios
- [ ] Probar RPC desde console
- [ ] Verificar MetaMask network
- [ ] Hacer commit en GitHub
- [ ] Verificar que la web está usando nuevos endpoints

---

## 🔗 IMPORTANCIA DE LOS CAMBIOS

### Antes (Testnet Local)
```
RPC:      http://189.28.81.202:8545
Explorer: http://189.28.81.202:4000
Estado:   Solo accesible localmente
```

### Ahora (Production Cloudflare)
```
RPC:      https://rpc.ande.network
Explorer: https://explorer.ande.network
Estado:   ✅ Accesible globalmente
          ✅ HTTPS automático
          ✅ DDoS Protection
          ✅ 99.99% Uptime
```

---

## 📊 INFORMACIÓN CLAVE

```javascript
const config = {
  blockchain: {
    chainId: 6174,
    chainIdHex: '0x181e',
    networkName: 'Ande Network',
    currency: {
      name: 'ANDE',
      symbol: 'ANDE',
      decimals: 18
    }
  },
  endpoints: {
    rpc: 'https://rpc.ande.network',
    api: 'https://api.ande.network',
    explorer: 'https://explorer.ande.network',
    grafana: 'https://grafana.ande.network'
  },
  infrastructure: {
    provider: 'Cloudflare Tunnel',
    datacenters: 4,
    location: 'São Paulo (Brazil)',
    protocol: 'QUIC',
    uptime: '99.99%',
    latency: '<100ms'
  }
};
```

---

## 🚀 DEPLOYMENT FINAL

### En Vercel

1. Ve a: https://vercel.com/dashboard
2. Selecciona tu proyecto
3. Settings → Environment Variables
4. Actualiza/agrega todas las variables
5. Save
6. Deployments → Latest → Redeploy
7. Espera a que se complete (2-5 minutos)
8. Verifica en tu sitio live

### En GitHub (Opcional pero recomendado)

```bash
# Actualizar documentación
git add VERCEL_ENV_CONFIG.md
git commit -m "docs: Update Vercel environment variables for production Cloudflare endpoints"
git push origin main
```

---

## 🆘 TROUBLESHOOTING

### Problema: "RPC Connection Error"

**Solución:**
1. Verificar que `NEXT_PUBLIC_RPC_URL=https://rpc.ande.network`
2. Hacer redeploy en Vercel
3. Esperar 3 minutos
4. Limpiar cache del navegador (Ctrl+Shift+Delete)

### Problema: "MetaMask Network Not Found"

**Solución:**
1. Asegurar que `NEXT_PUBLIC_CHAIN_ID=6174`
2. Verificar que `NEXT_PUBLIC_RPC_URL` está correcto
3. Hacer redeploy
4. Reiniciar MetaMask

### Problema: "Old Endpoints Still Loading"

**Solución:**
1. Hard refresh: `Ctrl+F5` (Windows) o `Cmd+Shift+R` (Mac)
2. Limpiar cookies y cache
3. Abrir en modo incógnito
4. Verificar console para ver que URLs se están usando

---

## 📞 RECURSOS

- **Vercel Docs**: https://vercel.com/docs/environment-variables
- **Next.js Env Vars**: https://nextjs.org/docs/basic-features/environment-variables
- **RPC Endpoint**: https://rpc.ande.network
- **GitHub Config**: https://github.com/AndeLabs/ande/blob/main/VERCEL_ENV_CONFIG.md

---

## ⏰ ÚLTIMA ACTUALIZACIÓN

**Fecha**: 2025-11-06  
**Hora**: 16:35 UTC  
**Versión**: 1.0.0  
**Estado**: Production Ready ✅

---

**¡Tu web en Vercel está lista para conectarse al blockchain ANDE en producción! 🚀**
