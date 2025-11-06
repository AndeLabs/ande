# AndeChain Testnet - External Deployment Guide

## 🎯 OBJETIVO
Desplegar contratos inteligentes de AndeChain desde una PC externa usando la RPC abierta al mundo.

## 📋 REQUISITOS

### En tu PC (Windows/Mac/Linux)
1. **Foundry instalado**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   forge --version  # Debe mostrar 1.4.3+
   ```

2. **Git instalado**
   ```bash
   git --version  # Debe mostrar 2.x+
   ```

3. **Node.js (opcional, para herramientas auxiliares)**
   ```bash
   node --version  # Debe mostrar v18+
   ```

## 🔐 CREDENCIALES Y CONFIGURACIÓN

### Servidor AndeChain (Información Pública)
- **IP Pública**: `189.28.81.202`
- **Chain ID**: `6174` (0x181e)
- **RPC Endpoint**: `http://189.28.81.202:8545`
- **WebSocket**: `ws://189.28.81.202:8546`
- **Block Explorer API**: `http://189.28.81.202:4000/api/v2`
- **Monitoreo**: `http://189.28.81.202:3000` (Grafana)

### Cuenta de Deployment (Genesis Account - SOLO TESTNET)
```
Address:     0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Private Key: ac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f20f10b5a234e983
Network:     AndeChain Testnet (Chain ID: 6174)
Balance:     ∞ (Genesis allocation)
```

⚠️ **IMPORTANTE**: Esta es la cuenta de Foundry estándar para testing. 
- ✅ Usar SOLO en testnet
- ❌ NUNCA usar en mainnet
- ❌ Esta clave ya está publicada (no usar con fondos reales)

## 📦 PASO 1: Clonar y Configurar Repositorio

```bash
# 1. Clonar el repositorio AndeChain
git clone https://github.com/AndeLabs/ande.git
cd ande/contracts

# 2. Instalar dependencias (toma ~5 minutos)
forge install

# 3. Listar dependencias instaladas
ls -la lib/
# Debe mostrar:
# - openzeppelin-contracts/ (v5.1.0)
# - openzeppelin-contracts-upgradeable/ (v5.1.0)
# - solady/ (latest)
# - forge-std/ (latest)
```

## 🧪 PASO 2: Verificar Conexión a la Red

```bash
# Test 1: Verificar que el RPC responde
curl -X POST http://189.28.81.202:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Respuesta esperada:
# {"jsonrpc":"2.0","id":1,"result":"0x181e"}

# Test 2: Obtener el bloque actual
curl -X POST http://189.28.81.202:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Respuesta esperada: Un número en hexadecimal, ej: "0x2a1"

# Test 3: Verificar saldo de la cuenta de deployment
curl -X POST http://189.28.81.202:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"eth_getBalance",
    "params":["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","latest"],
    "id":1
  }'

# Respuesta esperada: Un balance muy alto en hex (ej: "0x3635c9adc5dea00000")
```

## 🔧 PASO 3: Compilar Contratos

```bash
cd ande/contracts

# Compilar todos los contratos
forge build

# Salida esperada:
# Compiling 193 files with Solc 0.8.25
# Solc 0.8.25 finished in X.XXs
# [SUCCESS] Compiling complete

# Si hay errores, son errores de compilación que deben arreglarse
# (No debería haber si clonaste desde repo actualizado)
```

## 🚀 PASO 4: Desplegar Contratos Core

### Opción A: Deployment Manual (Recomendado para Debugging)

```bash
# 1. Establecer la clave privada como variable de entorno
export PRIVATE_KEY=ac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f20f10b5a234e983

# 2. Hacer un dry run (sin broadcast)
forge script script/DeployCore.s.sol \
  --rpc-url http://189.28.81.202:8545 \
  --private-key $PRIVATE_KEY \
  -vvv

# 3. Si todo parece bien, hacer el deployment real
forge script script/DeployCore.s.sol \
  --rpc-url http://189.28.81.202:8545 \
  --private-key $PRIVATE_KEY \
  --broadcast \
  -vvv
```

### Opción B: Deployment con Verificación

```bash
# Guardar la salida en un archivo para referencia
forge script script/DeployCore.s.sol \
  --rpc-url http://189.28.81.202:8545 \
  --private-key $PRIVATE_KEY \
  --broadcast \
  -vvv \
  > deployment_output.txt 2>&1

# Ver el resultado
cat deployment_output.txt | grep -E "ANDE|Staking|Governor|Timelock"
```

## 📊 PASO 5: Verificar Deployment

```bash
# Los contratos se habrán desplegado en direcciones específicas.
# La salida del script mostrará algo como:

# [CONTRACTS] Contract Addresses:
#   ANDE Implementation: 0x...
#   ANDE Proxy: 0x...
#   Staking Implementation: 0x...
#   Staking Proxy: 0x...
#   Timelock Implementation: 0x...
#   Timelock Proxy: 0x...
#   Governor Implementation: 0x...
#   Governor Proxy: 0x...

# Verificar en Blockscout (API)
ANDE_ADDRESS="0x..." # Reemplazar con la dirección del proxy

curl http://189.28.81.202:4000/api/v2/addresses/$ANDE_ADDRESS

# Debería retornar información del contrato
```

## 🧮 OTROS DEPLOYMENTS DISPONIBLES

### DeployANDETokenDuality (Token Duality)
```bash
forge script script/DeployANDETokenDuality.s.sol \
  --rpc-url http://189.28.81.202:8545 \
  --private-key $PRIVATE_KEY \
  --broadcast -vvv
```

### DeployStaking (Sistema de Staking)
```bash
forge script script/DeployStaking.s.sol \
  --rpc-url http://189.28.81.202:8545 \
  --private-key $PRIVATE_KEY \
  --broadcast -vvv
```

### DeployGovernance (Sistema de Gobernanza)
```bash
forge script script/DeployGovernance.s.sol \
  --rpc-url http://189.28.81.202:8545 \
  --private-key $PRIVATE_KEY \
  --broadcast -vvv
```

## 🧪 PASO 6: Interactuar con Contratos Desplegados

```bash
# Ejemplo: Llamar función balanceOf del token ANDE
TOKEN_ADDRESS="0x..."  # Tu dirección del contrato ANDE

# Obtener el saldo de una cuenta
curl -X POST http://189.28.81.202:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "eth_call",
    "params": [{
      "to": "'$TOKEN_ADDRESS'",
      "data": "0x70a08231000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cffb92266"
    }, "latest"],
    "id": 1
  }'

# O usando cast (parte de Foundry)
cast call $TOKEN_ADDRESS "balanceOf(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --rpc-url http://189.28.81.202:8545
```

## 📝 DOCUMENTACIÓN ÚTIL

### Archivos Importantes en el Repositorio
- **Contratos Core**: `ande/contracts/src/`
  - `ANDETokenDuality.sol` - Token ANDE con dualidad nativa/ERC20
  - `staking/AndeNativeStaking.sol` - Sistema de staking
  - `governance/AndeGovernor.sol` - Gobernanza on-chain
  - `governance/AndeTimelockController.sol` - Timelock para propuestas

- **Scripts de Deployment**: `ande/contracts/script/`
  - `DeployCore.s.sol` - Deployment de todos los contratos core
  - `DeployStaking.s.sol` - Solo sistema de staking
  - `DeployGovernance.s.sol` - Solo gobernanza

- **Configuración de Red**: `ande/`
  - `chainlist.json` - Configuración para directorios de redes
  - `metamask-config.json` - Configuración para MetaMask

## ✅ CHECKLIST DE VERIFICACIÓN POST-DEPLOYMENT

- [ ] Todos los contratos compilaron sin errores
- [ ] Dry run completó sin errores
- [ ] Broadcast completó exitosamente
- [ ] Las direcciones de contratos se guardaron en archivo
- [ ] Verificaste en Blockscout API que los contratos existen
- [ ] Probaste llamar una función de lectura (balanceOf, etc)
- [ ] Documentaste todas las direcciones de contrato

## 🐛 TROUBLESHOOTING

### Error: "RPC connection refused"
```
Solución: Verifica que puedas hacer ping al servidor
ping 189.28.81.202

Si no responde, el servidor podría estar offline o el firewall bloqueado.
```

### Error: "Account nonce too high"
```
Solución: El nonce está desincronizado. Intenta de nuevo:
forge script ... --broadcast --resume
```

### Error: "Insufficient balance"
```
Solución: La cuenta no tiene fondos. Usa la cuenta de genesis:
0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

### Compilación lenta
```
Solución: Si toma más de 5 minutos, intenta:
forge cache clean
forge build --force
```

## 📞 SOPORTE

Si encuentras problemas:

1. **Verificar logs del servidor**:
   ```bash
   curl http://189.28.81.202:3000  # Grafana (ver logs)
   ```

2. **Revisar el Blockscout API**:
   ```bash
   curl http://189.28.81.202:4000/api/v2/stats
   ```

3. **Verificar RPC está respondiendo**:
   ```bash
   curl -X POST http://189.28.81.202:8545 \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}'
   ```

---
**Versión**: v1.0  
**Fecha**: 2025-11-06  
**Servidor**: AndeChain Testnet (Chain ID 6174)
