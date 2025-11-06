# 🌍 AndeChain - Configuración para Internet

**Estado Actual**: Chain corriendo en internet ✅
**Bloque Actual**: #1269
**Chain ID**: 6174
**Tipo**: Red Soberana en Celestia Mocha-4

---

## ✅ VERIFICACIÓN DE CONECTIVIDAD

### 1. DNS Configuration (TU CONFIGURACIÓN)

```
Host        Tipo   Valor              Status
────────────────────────────────────────────────
@           A      216.198.79.1       ✅ www.ande.network
api         A      189.28.81.202      ✅ api.ande.network
explorer    A      189.28.81.202      ✅ explorer.ande.network
rpc         A      189.28.81.202      ✅ rpc.ande.network
ws          A      189.28.81.202      ✅ ws.ande.network
www         A      ???                ⚠️  FALTA ACTUALIZAR
faucet      A      189.28.81.202      ⚠️  FALTA CREAR
```

### 2. Endpoints Públicos a Validar

```bash
# RPC HTTP
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# WebSocket
wscat -c wss://ws.ande.network

# Explorer
curl -I https://explorer.ande.network

# API
curl https://api.ande.network/status

# Faucet
curl -I https://faucet.ande.network
```

### 3. Verificar desde localhost que está escuchando

```bash
# Revisar que nginx está en puerto 80/443
netstat -tulpn | grep -E ':(80|443)'

# Ver contenedores corriendo
docker ps | grep -E 'nginx|reth|evolve|blockscout|faucet'

# Revisar logs de nginx
docker logs nginx-proxy | tail -50
```

---

## 🔧 CAMBIOS NECESARIOS EN CONFIGURACIÓN

### OPCIÓN 1: Tu www subdomain apunta a 216.198.79.1 (no 189.28.81.202)

**Problema**: www apunta a IP diferente que los otros subdominios

**Soluciones**:

#### A. Actualizar DNS (RECOMENDADO)
```
www.ande.network A 189.28.81.202
```

#### B. O configurar www como alias
```
www  CNAME  ande.network
```

### OPCIÓN 2: Agregar subdominio faucet

```
faucet  A  189.28.81.202
```

---

## 📋 CHECKLIST DE CONFIGURACIÓN INTERNET

### Networking

- [ ] **IP pública**: 189.28.81.202 confirmada
- [ ] **Puertos abiertos**: 80, 443 en firewall
- [ ] **DNS propagado**: Esperar 24-48h máximo
- [ ] **TTL bajo**: Para cambios rápidos (recomendado 300s)

### SSL/TLS

- [ ] **Certificados Let's Encrypt**: Obtenidos para todos los dominios
- [ ] **Auto-renewal**: Certbot configurado
- [ ] **HTTPS obligatorio**: Todos los endpoints

### Nginx

- [ ] **Rate limiting**: Activo en todos los endpoints
- [ ] **CORS**: Configurado correctamente
- [ ] **Health checks**: Respondiendo en /health
- [ ] **Proxy correcto**: routing a puertos internos correctos

### Servicios Internos

- [ ] **ev-reth**: Escuchando en 8545 (HTTP), 8546 (WS)
- [ ] **evolve-sequencer**: Escuchando en 7331
- [ ] **blockscout**: Escuchando en 4000
- [ ] **ande-faucet**: Escuchando en 8081
- [ ] **grafana**: Escuchando en 3000

### Cadena Blockchain

- [ ] **Génesis correcto**: Chain ID 6174
- [ ] **Bloques siendo producidos**: Confirmado
- [ ] **Celestia DA**: Conectada
- [ ] **Consensus**: Evolve sincronizado

---

## 🔐 DATOS CRÍTICOS PARA TU WEB

```javascript
// config/chain.ts
export const ANDE_CHAIN = {
  // Network
  id: 6174,
  name: "AndeChain Testnet",
  type: "testnet",
  status: "active",
  
  // RPC Endpoints
  rpc: {
    http: "https://rpc.ande.network",
    ws: "wss://ws.ande.network",
    fallback: "http://189.28.81.202:8545" // IP si DNS falla
  },
  
  // Servicios
  explorer: "https://explorer.ande.network",
  faucet: "https://faucet.ande.network",
  monitoring: "https://grafana.ande.network",
  
  // Token
  nativeCurrency: {
    name: "ANDE",
    symbol: "ANDE",
    decimals: 18,
    precompile: "0x00000000000000000000000000000000000000FD"
  },
  
  // Bloctime & Consensus
  blockTime: 2000, // ms
  consensus: "Evolve Sequencer",
  dataAvailability: "Celestia Mocha-4",
  
  // URLs para agregar red en MetaMask
  addNetworkUrl: "https://www.ande.network/add-network",
  faucetUrl: "https://faucet.ande.network"
};
```

---

## 🚀 PASOS FINALES PARA INTERNET

### 1. Actualizar DNS (AHORA MISMO)
```
Host      Tipo   Valor
──────────────────────────────
www       A      189.28.81.202    ← CAMBIAR de 216.198.79.1
faucet    A      189.28.81.202    ← AGREGAR
```

### 2. Verificar Certificados SSL
```bash
# Verificar expiración
echo | openssl s_client -servername rpc.ande.network -connect rpc.ande.network:443 2>/dev/null | openssl x509 -noout -dates

# Para todos:
for domain in rpc.ande.network ws.ande.network api.ande.network explorer.ande.network faucet.ande.network status.ande.network; do
  echo "=== $domain ==="
  echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -dates
done
```

### 3. Test desde Internet (CRÍTICO)

```bash
# 1. RPC call
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq

# Expected: {"jsonrpc":"2.0","id":1,"result":"0x4f5"}

# 2. Chain ID
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq

# Expected: {"jsonrpc":"2.0","id":1,"result":"0x181e"}

# 3. Gas Price
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}' | jq

# 4. Peer Count
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' | jq
```

### 4. WebSocket Test

```bash
# Instalar wscat si no lo tienes
npm install -g wscat

# Test WebSocket
wscat -c wss://ws.ande.network

# En la terminal wscat:
{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}

# Expected respuesta con número de bloque
```

### 5. Explorer Test
```bash
# Debe cargar sin errores
curl -I https://explorer.ande.network

# Expected: HTTP/1.1 200 OK
```

### 6. Faucet Test
```bash
# Debe responder
curl -I https://faucet.ande.network

# Expected: HTTP/1.1 200 OK
```

---

## 📊 DATOS PARA ACTUALIZAR EN TU WEB

### 1. chainlist.json (para agregar en chainlist.org)

```json
{
  "name": "AndeChain Testnet",
  "chain": "ANDE",
  "icon": "ande",
  "rpc": [
    "https://rpc.ande.network",
    "https://189.28.81.202:8545"
  ],
  "faucets": [
    "https://faucet.ande.network"
  ],
  "nativeCurrency": {
    "name": "ANDE",
    "symbol": "ANDE",
    "decimals": 18
  },
  "infoURL": "https://www.ande.network",
  "shortName": "ande-testnet",
  "chainId": 6174,
  "networkId": 6174,
  "explorers": [
    {
      "name": "AndeChain Explorer",
      "url": "https://explorer.ande.network",
      "standard": "EIP3091"
    }
  ],
  "parent": {
    "type": "L2",
    "chain": "eip155-1",
    "bridges": [
      {
        "url": "https://www.ande.network"
      }
    ]
  }
}
```

### 2. MetaMask Network Config

```javascript
{
  chainId: "0x181E",
  chainName: "AndeChain Testnet",
  nativeCurrency: {
    name: "ANDE",
    symbol: "ANDE",
    decimals: 18
  },
  rpcUrls: ["https://rpc.ande.network"],
  blockExplorerUrls: ["https://explorer.ande.network"],
  webSocketUrls: ["wss://ws.ande.network"]
}
```

---

## ⚠️ PROBLEMAS COMUNES

### "Connection Refused" en RPC

**Causa**: Nginx no está corriendo o puerto 8545 no es accesible

**Solución**:
```bash
# Verificar nginx
docker ps | grep nginx

# Revisar logs
docker logs nginx-proxy | tail -20

# Reiniciar
docker compose restart nginx
```

### "SSL Certificate Error"

**Causa**: Certificado no obtenido o expirado

**Solución**:
```bash
# Obtener certificado
docker compose run --rm certbot certonly --webroot \
  -w /var/www/certbot \
  -d rpc.ande.network \
  --email admin@ande.network \
  --agree-tos

# Renovar todos
docker compose run --rm certbot renew

# Reiniciar nginx
docker compose restart nginx
```

### "Rate Limit Exceeded"

**Causa**: Demasiadas requests en poco tiempo

**Solución**:
- RPC: 100 req/s máximo
- Faucet: 5 req/min máximo
- Esperar o usar fallback endpoint

### DNS no propaga

**Causa**: TTL alto o cache de ISP

**Solución**:
```bash
# Esperar 24-48 horas
# Borrar cache local:

# macOS
dscacheutil -flushcache

# Linux
sudo systemctl restart systemd-resolved

# Windows
ipconfig /flushdns
```

---

## 🎯 RESUMEN DE CAMBIOS NECESARIOS

| Item | Actual | Requerido | Acción |
|------|--------|-----------|--------|
| www DNS | 216.198.79.1 | 189.28.81.202 | ⚠️ ACTUALIZAR |
| faucet DNS | No existe | 189.28.81.202 | ⚠️ CREAR |
| SSL certs | Requerido | Let's Encrypt | ✅ (hacer) |
| CORS | Configurado | Activo | ✅ OK |
| Rate limit | 100 req/s | Activo | ✅ OK |
| Health checks | Sí | Sí | ✅ OK |

---

## 📝 COMANDOS FINALES PARA VALIDAR TODO

```bash
#!/bin/bash

echo "🔍 VALIDACIÓN COMPLETA DE ANDECHAIN"
echo "===================================="
echo ""

# 1. DNS
echo "1️⃣ DNS Resolution:"
for domain in rpc.ande.network ws.ande.network api.ande.network explorer.ande.network faucet.ande.network www.ande.network; do
  ip=$(nslookup $domain | grep "Address:" | tail -1 | awk '{print $2}')
  echo "  $domain -> $ip"
done

echo ""
echo "2️⃣ Services Running:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E 'reth|evolve|blockscout|nginx|faucet'

echo ""
echo "3️⃣ RPC Test:"
curl -s -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq '.result' | xargs printf "  Current Block: %d\n"

echo ""
echo "4️⃣ Chain ID:"
curl -s -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq '.result'

echo ""
echo "5️⃣ Endpoints:"
echo "  RPC:      https://rpc.ande.network"
echo "  WS:       wss://ws.ande.network"
echo "  Explorer: https://explorer.ande.network"
echo "  Faucet:   https://faucet.ande.network"
echo "  API:      https://api.ande.network"
```

---

## ✅ CHECKLIST FINAL

Marca cuando completado:

- [ ] DNS actualizado (www a 189.28.81.202)
- [ ] Subdomain faucet agregado al DNS
- [ ] SSL certificates obtenidos para todos
- [ ] nginx reiniciado
- [ ] RPC test exitoso desde internet
- [ ] WebSocket test exitoso
- [ ] Explorer accesible
- [ ] Faucet respondiendo
- [ ] Rate limiting funcionando
- [ ] CORS configurado
- [ ] Datos actualizados en www.ande.network
- [ ] chainlist.json preparado
- [ ] MetaMask config preparada

---

**Estado**: 🟢 LISTO PARA PRODUCCIÓN (con cambios DNS)

Próximo paso: Actualizar DNS y hacer tests desde internet.
