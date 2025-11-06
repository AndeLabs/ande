# 🚀 DEPLOYMENT DE CONTRATOS - AndeChain

Guía completa para desplegar contratos en AndeChain desde cualquier máquina (WSL, otra PC, etc).

---

## 📋 REQUISITOS PREVIOS

### 1. Tener acceso al servidor
```bash
# SSH al servidor (WSL en Windows)
ssh sator@192.168.0.8 -p 2222 -t "wsl.exe"

# O si estás en la misma máquina:
wsl
```

### 2. Foundry instalado
```bash
# Verificar instalación
forge --version
cast --version

# Si no está instalado:
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 3. Ubicarte en el directorio correcto
```bash
cd andelabs/ande/contracts

# Verificar que estás en el lugar correcto
pwd
ls -la
```

---

## ✅ PASO 1: VERIFICAR QUE LA CHAIN ESTÁ CORRIENDO

```bash
# Verificar Chain ID (debe ser 6174 = 0x181e)
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Expected: {"jsonrpc":"2.0","id":1,"result":"0x181e"}

# Verificar block number (que está produciendo bloques)
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Verificar balance del deployer (genesis account)
cast balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --rpc-url http://localhost:8545
```

**Si hay problemas aquí → DETENTE y reporta el error**

---

## 🔨 PASO 2: COMPILAR CONTRATOS

```bash
# Limpiar builds previos
forge clean

# Compilar todos los contratos
forge build --force

# Expected output: "Compiler run successful!"
```

---

## 📦 PASO 3: DEPLOYMENT - ANDE TOKEN DUALITY

```bash
forge script script/DeployANDETokenDuality.s.sol:DeployANDETokenDuality \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast \
  -vvvv
```

### Verificar el deployment

```bash
# Ver el broadcast
cat broadcast/DeployANDETokenDuality.s.sol/6174/run-latest.json | jq

# Extraer address del contrato
export ANDE_TOKEN_ADDRESS=$(cat broadcast/DeployANDETokenDuality.s.sol/6174/run-latest.json | jq -r '.transactions[0].contractAddress')
echo "ANDE Token: $ANDE_TOKEN_ADDRESS"

# Verificar que funciona
cast call $ANDE_TOKEN_ADDRESS "name()(string)" --rpc-url http://localhost:8545
```

---

## 🏛️ PASO 4: DEPLOYMENT - STAKING

```bash
forge script script/DeployStaking.s.sol:DeployStakingLocal \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast \
  -vvvv
```

---

## 🏛️ PASO 5: DEPLOYMENT - GOVERNANCE

```bash
forge script script/DeployGovernance.s.sol:DeployGovernanceLocal \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast \
  -vvvv
```

---

## 📄 PASO 6: GUARDAR ADDRESSES

```bash
# Crear JSON con todas las addresses
cat > deployed-contracts.json << JSONEOF
{
  "chainId": 6174,
  "chainName": "AndeChain Testnet",
  "contracts": {
    "ANDETokenDuality": "$ANDE_TOKEN_ADDRESS",
    "AndeNativeStaking": "$STAKING_ADDRESS",
    "AndeGovernor": "$GOVERNOR_ADDRESS"
  }
}
JSONEOF
```

---

## 🌐 DEPLOYMENT DESDE OTRA PC

### Usando RPC público (después de configurar DNS):
```bash
forge script script/Deploy.s.sol \
  --rpc-url https://rpc.ande.network \
  --private-key YOUR_PRIVATE_KEY \
  --broadcast
```

### Usando IP directa:
```bash
forge script script/Deploy.s.sol \
  --rpc-url http://189.28.81.202:8545 \
  --private-key YOUR_PRIVATE_KEY \
  --broadcast
```

---

## ⚠️ TROUBLESHOOTING

### Error: "Connection refused"
```bash
# Verificar chain corriendo
curl http://localhost:8545
docker ps | grep reth
```

### Error: "Insufficient funds"
```bash
# Fondear wallet
cast send YOUR_ADDRESS --value 100ether \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

---

## 📝 CHECKLIST

- [ ] Chain corriendo (RPC responde)
- [ ] Balance del deployer > 0
- [ ] Contratos compilan sin errores
- [ ] Token deployado y verificado
- [ ] Staking deployado
- [ ] Governance deployado
- [ ] Addresses guardadas en JSON
- [ ] Verificar en explorer

---

**¿Problemas? Copia el error completo y el comando ejecutado.**
