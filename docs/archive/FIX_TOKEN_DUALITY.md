# 🔧 FIX: Token Duality Not Working

## 🚨 PROBLEMA DETECTADO

El sistema AndeChain está corriendo pero **Token Duality NO está funcionando**.

### Estado Actual:
- ✅ **ANDE Nativo** funcionando (para gas)
- ❌ **Precompile 0xFD** NO existe
- ⚠️ **ANDE ERC20** deployado pero vacío
- ❌ **NO hay sincronización** entre nativo y ERC20

## 📊 EVIDENCIA

```bash
# Precompile 0xFD
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getCode","params":["0x00000000000000000000000000000000000000FD","latest"],"id":1}' \
  http://localhost:8545

# Resultado: {"result":"0x"}  ← VACÍO ❌
```

```bash
# ANDE ERC20 Contract
cast call 0x5fbdb2315678afecb367f032d93f642f64180aa3 \
  "totalSupply()(uint256)" \
  --rpc-url http://localhost:8545

# Resultado: 0  ← Sin supply ❌
```

## 🎯 CAUSA RAÍZ

El Docker image `ghcr.io/joshstevens19/evolve-reth:latest` **NO incluye** el precompile personalizado de ANDE.

**Necesitas el fork:** https://github.com/AndeLabs/ande-reth

## ✅ SOLUCIÓN PASO A PASO

### Paso 1: Clonar ande-reth con precompile

```bash
cd ~/dev/ande-labs
git clone https://github.com/AndeLabs/ande-reth
cd ande-reth
```

### Paso 2: Verificar implementación del precompile

```bash
# Buscar el precompile ANDE
rg "0xFD" -A 10
rg "ANDE_PRECOMPILE" -A 10

# Debería encontrar algo como:
# crates/primitives/src/revm/config.rs
# pub const ANDE_PRECOMPILE: Address = address!("00000000000000000000000000000000000000FD");
```

### Paso 3: Build ev-reth con Token Duality

```bash
# Build con precompile habilitado
cargo build --release --bin reth \
  --features "ande-precompile,optimism"

# El binario estará en:
# target/release/reth
```

### Paso 4: Crear Docker image

```bash
# Dockerfile personalizado
cat > Dockerfile.ande <<'EOF'
FROM rust:1.75 as builder

WORKDIR /app
COPY . .

RUN cargo build --release --bin reth \
    --features "ande-precompile,optimism"

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/reth /usr/local/bin/

ENTRYPOINT ["reth"]
EOF

# Build
docker build -f Dockerfile.ande -t andelabs/ev-reth:ande-duality .
```

### Paso 5: Actualizar docker-compose

```yaml
# andechain/infra/stacks/single-sequencer/docker-compose.yml

services:
  ev-reth-sequencer:
    # ANTES:
    # image: ghcr.io/joshstevens19/evolve-reth:latest

    # AHORA:
    image: andelabs/ev-reth:ande-duality

    # O build local:
    build:
      context: /path/to/ande-reth
      dockerfile: Dockerfile.ande
```

### Paso 6: Reset y redeploy

```bash
cd ~/dev/ande-labs/andechain

# 1. Detener todo
make stop

# 2. Limpiar completamente
docker compose down -v

# 3. Rebuild con nuevo image
docker compose up -d --build --force-recreate

# 4. Esperar 30 segundos
sleep 30

# 5. Verificar precompile
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getCode","params":["0x00000000000000000000000000000000000000FD","latest"],"id":1}' \
  http://localhost:8545

# Debería devolver bytecode ahora ✅
```

### Paso 7: Redeploy contratos

```bash
cd contracts

export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Deploy ANDE Token con Duality
forge script script/DeployANDEDuality.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --legacy \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

## 🧪 VERIFICACIÓN

### Test 1: Precompile existe

```bash
cast code 0x00000000000000000000000000000000000000FD \
  --rpc-url http://localhost:8545

# Debería devolver bytecode ✅
```

### Test 2: Balance nativo

```bash
cast balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --rpc-url http://localhost:8545

# Resultado: 10000000000000000000000 (10,000 ANDE) ✅
```

### Test 3: Balance ERC20 sincronizado

```bash
cast call $ANDE_ADDRESS "balanceOf(address)(uint256)" \
  0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --rpc-url http://localhost:8545

# Debería ser IGUAL al balance nativo ✅
```

### Test 4: Transfer sincronizado

```bash
# Transfer via ERC20
cast send $ANDE_ADDRESS \
  "transfer(address,uint256)" \
  0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  "1000000000000000000" \
  --private-key $PRIVATE_KEY \
  --rpc-url http://localhost:8545

# Verificar balance nativo se actualizó
cast balance 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  --rpc-url http://localhost:8545

# Debería ser 1 ANDE ✅
```

## 📚 REFERENCIA

### Arquitectura Token Duality

```
┌─────────────────────────────────────────────┐
│  User/DApp                                  │
└─────────────┬───────────────────────────────┘
              │
              ├──────────┬──────────────┐
              │          │              │
         Native TX   ERC20 call    Account
         (transfer)  (.transfer)   Abstraction
              │          │              │
              └────┬─────┴──────────────┘
                   │
                   ▼
      ┌────────────────────────────┐
      │  Precompile 0xFD           │
      │  (ANDE Token Duality)      │
      └────────────┬───────────────┘
                   │
                   ▼
        ┌──────────────────┐
        │ journal.transfer │
        │ (Native Balance) │
        └──────────────────┘
```

### Código Precompile (Pseudo-código)

```rust
// En ev-reth fork
pub fn ande_transfer(
    input: &Bytes,
    gas_limit: u64,
    journal: &mut Journal
) -> PrecompileResult {
    // Decode input
    let (from, to, amount) = decode_transfer(input)?;

    // Verificar balance
    if journal.get_balance(from) < amount {
        return Err(PrecompileError::InsufficientBalance);
    }

    // Actualizar balances nativos
    journal.transfer(from, to, amount)?;

    // Emitir evento ERC20
    emit_transfer_event(from, to, amount);

    Ok((21_000, Bytes::new()))
}
```

## ⚠️ WORKAROUND TEMPORAL

Si NO puedes compilar ande-reth ahora, usa DOS tokens separados:

```bash
# 1. ANDE nativo (para gas) - Ya funciona ✅

# 2. Acuñar ANDE ERC20 (para DeFi)
cast send 0x5fbdb2315678afecb367f032d93f642f64180aa3 \
  "mint(address,uint256)" \
  0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  "10000000000000000000000000" \
  --private-key $PRIVATE_KEY \
  --rpc-url http://localhost:8545

# ⚠️ PROBLEMA: No hay sincronización
# - Gas se paga con ANDE nativo
# - DeFi usa ANDE ERC20
# - Son tokens DIFERENTES
```

## 📞 NEXT STEPS

1. ✅ Contactar con equipo de Evolve (ev-node/ev-reth)
2. ✅ Verificar si ya tienen implementación de precompiles custom
3. ✅ Fork ande-reth y agregar precompile ANDE
4. ✅ Documentar implementación para futuras referencias
5. ✅ Crear tests de integración para Token Duality

## 🔗 RECURSOS

- **ev-reth**: https://github.com/evolve-hack/reth
- **ande-reth fork**: https://github.com/AndeLabs/ande-reth
- **Precompiles Reth**: https://github.com/paradigmxyz/reth/tree/main/crates/precompile
- **Token Duality Docs**: andechain/docs/token-duality/

---

**Status:** 🔴 BLOCKER para funcionalidad completa de ANDE Token Duality
**Prioridad:** 🔥 ALTA
**Estimación:** 2-5 días (compilación + testing)
