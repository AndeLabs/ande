# ✅ ANDECHAIN - CHECKLIST PRODUCCIÓN INTERNET

**Fecha**: 2025-11-06  
**Estado**: 🟢 LISTO PARA INTERNET (con ajustes DNS)  
**Chain ID**: 6174  
**Bloque Actual**: #1269+

---

## 🎯 ACCIONES INMEDIATAS (HOY)

### 1️⃣ ACTUALIZAR DNS (CRÍTICO)

Tu proveedor de DNS (Claro):

```
ANTES:
www     → 216.198.79.1         ❌ INCORRECTO
faucet  → (no existe)           ❌ FALTA

DESPUÉS:
www     → 189.28.81.202        ✅ CORRECTO
faucet  → 189.28.81.202        ✅ NUEVO
```

**Instrucciones**:
1. Ir a panel de control de Claro (DNS)
2. Editar registro `www` → cambiar IP a `189.28.81.202`
3. Crear nuevo registro `faucet` → `189.28.81.202`
4. Guardar cambios
5. Esperar propagación (5 min - 48h máximo)

### 2️⃣ VERIFICAR CERTIFICADOS SSL

```bash
# En tu servidor:
cd /mnt/c/Users/sator/andelabs/ande

# Obtener certs para NUEVOS dominios
docker compose run --rm certbot certonly --webroot \
  -w /var/www/certbot \
  -d www.ande.network \
  -d faucet.ande.network \
  --email admin@ande.network \
  --agree-tos

# Reiniciar nginx
docker compose restart nginx
```

### 3️⃣ VALIDAR DESDE INTERNET

```bash
# Test desde otra máquina o móvil:

# 1. RPC
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Expected: {"jsonrpc":"2.0","id":1,"result":"0x..."}

# 2. Chain ID
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Expected: {"jsonrpc":"2.0","id":1,"result":"0x181e"}

# 3. Explorer
curl -I https://explorer.ande.network

# Expected: HTTP/1.1 200 OK

# 4. Faucet
curl -I https://faucet.ande.network

# Expected: HTTP/1.1 200 OK
```

---

## 📋 SERVICIOS CORRIENDO

```
✅ ev-reth-sequencer      (Puerto 8545, 8546)
✅ evolve-sequencer       (Puerto 7331)
✅ celestia-light         (Puerto 26658)
✅ blockscout             (Puerto 4000)
✅ nginx-proxy            (Puerto 80, 443)
✅ ande-faucet            (Puerto 8081)
✅ prometheus             (Puerto 9090)
✅ grafana                (Puerto 3000)
✅ postgres               (interno)
✅ certbot                (renewer)
```

---

## 🌐 ENDPOINTS PÚBLICOS FINALES

Después de actualizar DNS:

```
ENDPOINT                    | STATUS
────────────────────────────┼──────────────────────
https://rpc.ande.network    | RPC HTTP (para dApps)
wss://ws.ande.network       | WebSocket (real-time)
https://api.ande.network    | Evolve API
https://explorer.ande.network | Block Explorer
https://faucet.ande.network | Token Faucet 🆕
https://status.ande.network | Monitoring (Grafana)
https://www.ande.network    | Website
```

---

## 📝 DATOS PARA TU FRONTEND (www.ande.network)

Copiar a tu código:

### TypeScript/JavaScript

```typescript
// Frontend_CONFIG.ts (ya creado)
import { ANDE_CHAIN_CONFIG } from './FRONTEND_CONFIG';

const rpcUrl = ANDE_CHAIN_CONFIG.rpc.http;        // https://rpc.ande.network
const wsUrl = ANDE_CHAIN_CONFIG.rpc.ws;           // wss://ws.ande.network
const chainId = ANDE_CHAIN_CONFIG.chainId;        // 6174
const explorer = ANDE_CHAIN_CONFIG.services.explorer; // explorer.ande.network
```

### JSON (chainlist.json)

```json
// chainlist.json (ya creado)
{
  "name": "AndeChain Testnet",
  "chainId": 6174,
  "rpc": ["https://rpc.ande.network"],
  "faucets": ["https://faucet.ande.network"]
}
```

### MetaMask Network Config

```javascript
{
  chainId: "0x181E",
  chainName: "AndeChain Testnet",
  nativeCurrency: { name: "ANDE", symbol: "ANDE", decimals: 18 },
  rpcUrls: ["https://rpc.ande.network"],
  blockExplorerUrls: ["https://explorer.ande.network"]
}
```

---

## 🔐 CONFIGURACIÓN SEGURIDAD

### Rate Limiting Activo

```
RPC:       100 requests/segundo (burst 200)
Faucet:    5 requests/minuto
Explorer:  30 requests/segundo
API:       50 requests/segundo
```

### Protecciones Anti-Bot

```
✅ IP-based rate limiting
✅ User-agent filtering
✅ CORS configurado
✅ hCaptcha en faucet
✅ Health checks automáticos
```

### SSL/TLS

```
✅ HTTPS obligatorio (HTTP redirige a HTTPS)
✅ TLS 1.2 + 1.3
✅ Let's Encrypt certificates
✅ Auto-renewal cada 3 meses
```

---

## 🔧 CONFIGURACIÓN DEL FAUCET

**Wallet del Faucet**: Debe estar fondeada con ANDE

```bash
# Generar wallet (si no lo hiciste)
cast wallet new

# Output:
# Successfully created new keypair.
# Address: 0x...
# Private key: 0x...

# Guardar private key en .env.testnet:
FAUCET_PRIVATE_KEY=0x...

# Fondear con genesis wallet o wallet existente
cast send 0xFAUCET_ADDRESS \
  --value 1000ether \
  --rpc-url http://localhost:8545 \
  --private-key $DEPLOYER_KEY

# Iniciar faucet
docker compose up -d ande-faucet

# Verificar
make faucet-status
```

---

## 🚀 DEPLOY DE CONTRATOS (desde otra PC)

Para desplegar contratos desde otra máquina:

```bash
# 1. Tener web3.py o forge instalado
# 2. Usar RPC endpoint
export RPC_URL="https://rpc.ande.network"
export CHAIN_ID=6174

# Con Foundry
forge script script/Deploy.s.sol \
  --rpc-url $RPC_URL \
  --broadcast

# Con Web3.py
python deploy.py --rpc-url $RPC_URL
```

**IMPORTANTE**: 
- Chain ID: `6174`
- RPC: `https://rpc.ande.network`
- Token nativo: ANDE (precompilado en `0x00...FD`)

---

## 📊 MONITOREO EN TIEMPO REAL

### Grafana Dashboard
```
URL: https://grafana.ande.network
User: admin
Password: andechain-admin-2025
```

Métricas disponibles:
- Block production rate
- Transaction throughput
- Consensus health
- Memory/CPU usage
- Network peers

### Logs en Tiempo Real

```bash
# RPC/EVM
docker logs -f ev-reth-sequencer | tail -20

# Consensus
docker logs -f evolve-sequencer | tail -20

# Faucet
docker logs -f ande-faucet | tail -20

# Nginx (acceso público)
docker logs -f nginx-proxy | tail -20
```

---

## ⚠️ TROUBLESHOOTING

### DNS no resuelve después de 48h

```bash
# Borrar cache local
# macOS
dscacheutil -flushcache

# Linux
sudo systemctl restart systemd-resolved

# Windows
ipconfig /flushdns

# Verificar propagación
nslookup rpc.ande.network
dig rpc.ande.network
```

### RPC connection refused

```bash
# Verificar nginx corriendo
docker ps | grep nginx-proxy

# Ver logs
docker logs nginx-proxy | tail -50

# Reiniciar
docker compose restart nginx

# Test local
curl http://localhost:8545 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Certificado SSL error

```bash
# Verificar certs
for domain in rpc ws api explorer faucet www; do
  echo "=== $domain.ande.network ==="
  openssl s_client -servername $domain.ande.network \
    -connect $domain.ande.network:443 2>/dev/null | \
    openssl x509 -noout -dates
done

# Renovar si necesario
docker compose run --rm certbot renew --force-renewal
docker compose restart nginx
```

### Faucet sin fondos

```bash
# Ver balance
FAUCET_ADDR=$(cast wallet address --private-key $FAUCET_PRIVATE_KEY)
cast balance $FAUCET_ADDR --rpc-url https://rpc.ande.network

# Si está bajo, fondear
cast send $FAUCET_ADDR \
  --value 1000ether \
  --rpc-url https://rpc.ande.network \
  --private-key $DEPLOYER_KEY
```

---

## 📱 AGREGAR A METAMASK AUTOMÁTICAMENTE

En tu página www.ande.network:

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
    });
  } catch (error) {
    console.error('Error adding chain:', error);
  }
}

// Botón en HTML
<button onclick="addAndeChainToMetaMask()">
  Add AndeChain to MetaMask
</button>
```

---

## 🎯 CHECKLIST FINAL

### Networking & DNS
- [ ] DNS www actualizado a 189.28.81.202
- [ ] DNS faucet creado → 189.28.81.202
- [ ] DNS propagado (nslookup verifica)
- [ ] Puertos 80/443 abiertos en firewall

### Certificates
- [ ] SSL certs obtenidos para www, faucet
- [ ] Certbot auto-renewal configurado
- [ ] HTTPS obligatorio activo

### Servicios
- [ ] ev-reth corriendo (bloque #1269+)
- [ ] evolve-sequencer sincronizado
- [ ] blockscout respondiendo
- [ ] ande-faucet respondiendo
- [ ] nginx proxying correctamente

### Endpoints Públicos
- [ ] https://rpc.ande.network ✅ RPC
- [ ] wss://ws.ande.network ✅ WebSocket
- [ ] https://explorer.ande.network ✅ Explorer
- [ ] https://faucet.ande.network ✅ Faucet
- [ ] https://www.ande.network ✅ Web

### Frontend/Integration
- [ ] FRONTEND_CONFIG.ts en tu repo
- [ ] chainlist.json preparado
- [ ] MetaMask config en página
- [ ] RPC URLs correctas
- [ ] Chain ID 6174 confirmado

### Deployment de Contratos
- [ ] Bridge/test wallet creada
- [ ] RPC testeado desde PC remota
- [ ] Contratos listos para desplegar
- [ ] Direcciones de deployment documentadas

### Monitoreo
- [ ] Grafana accesible
- [ ] Logs monitoreados
- [ ] Alertas configuradas
- [ ] Balance del faucet checkeado regularmente

---

## 🎉 RESULTADO FINAL

**Tu AndeChain está 100% lista para:**

✅ Que desarrolladores desde cualquier lugar desplieguen contratos  
✅ Que usuarios conecten con MetaMask  
✅ Que wallets interactúen vía RPC  
✅ Que el mundo vea transacciones en explorer  
✅ Que testers consigan ANDE en el faucet  

---

## 📞 SOPORTE RÁPIDO

| Problema | Solución |
|----------|----------|
| RPC no responde | Revisar nginx logs, reiniciar |
| DNS no resuelve | Esperar propagación, borrar cache |
| Certificado error | Renovar con certbot |
| Faucet sin fondos | Fondear wallet del faucet |
| Rate limit | Esperar o usar fallback IP |

---

**Próximo paso**: Actualizar DNS y hacer tests desde internet.

**Tiempo estimado**: 1 hora (DNS propagación puede tomar más)

🚀 **¡Tu AndeChain está lista para el mundo!** 🌍
