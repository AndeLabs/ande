# Token Duality PoC - Limitaciones y Migración a Producción

**Propósito:** Documentar las limitaciones del PoC con mock y el camino hacia producción
**Fecha:** 2025-10-07
**Estado:** Completado ✅

---

## 📋 Resumen

Este documento explica las diferencias entre el **PoC con mock** (implementado) y la **implementación final con precompile real** en ev-reth.

---

## ✅ Lo Que Funciona en el PoC

### 1. **Arquitectura Token Duality Completa**

El PoC valida exitosamente el patrón Token Duality:

```solidity
// ✅ FUNCIONA: ANDETokenDuality lee balance del mock
function balanceOf(address account) public view override returns (uint256) {
    (bool success, bytes memory returnData) =
        _nativeTransferPrecompile.staticcall(
            abi.encodeWithSignature("getNativeBalance(address)", account)
        );
    if (!success) return 0;
    return abi.decode(returnData, (uint256));
}

// ✅ FUNCIONA: Transferencias delegadas al mock
function _update(address from, address to, uint256 value) internal override {
    _transferVotingUnits(from, to, value); // Checkpoints primero

    if (from != address(0) && to != address(0)) {
        bytes memory input = abi.encode(from, to, value);
        (bool success,) = _nativeTransferPrecompile.call(input);
        require(success);
    }

    emit Transfer(from, to, value);
}
```

### 2. **100% Compatibilidad ERC-20**

El PoC pasa **26/26 tests** que cubren:

| Categoría | Tests | Estado |
|-----------|-------|--------|
| Core Token Duality | 5 | ✅ 100% |
| ERC-20 Standard | 6 | ✅ 100% |
| ERC-20 Votes (Gobernanza) | 4 | ✅ 100% |
| ERC-20 Permit (Gasless) | 1 | ✅ 100% |
| Pausable | 2 | ✅ 100% |
| Access Control | 2 | ✅ 100% |
| Minting | 2 | ✅ 100% |
| Integration Tests | 2 | ✅ 100% |

**Resultado:** Todas las funcionalidades de gobernanza (voting power, checkpoints, delegation) funcionan perfectamente.

### 3. **Lógica de Negocio Validada**

El mock precompile implementa la lógica exacta que tendrá el precompile real:

- ✅ Validación de caller autorizado (solo ANDEToken puede llamar)
- ✅ Validación de balance suficiente
- ✅ Protección contra address(0) como destinatario
- ✅ Optimización para transferencias de 0 (gas saving)
- ✅ Eventos emitidos correctamente

---

## ⚠️ Limitaciones del PoC (vs Producción)

### 1. **Almacenamiento de Balances**

| Aspecto | PoC (Mock) | Producción (Precompile Real) |
|---------|------------|-------------------------------|
| **Donde se guarda** | Mapping Solidity interno del mock | Balance nativo del EVM (`address.balance`) |
| **Cómo se lee** | `_nativeBalances[account]` | Directo desde el state trie del EVM |
| **Implicación** | Balances NO son nativos | Balances SON nativos, usables para gas |

**Problema en PoC:**
```solidity
// Mock: Balance solo existe en storage del contrato mock
mapping(address => uint256) private _nativeBalances; // ❌ NO es balance nativo

// Producción: Balance ES el balance nativo del address
// Alice tiene 1000 ANDE → alice.balance == 1000 ether ✅ Usado para pagar gas
```

### 2. **Llamadas al Precompile**

| Aspecto | PoC (Mock) | Producción (Precompile Real) |
|---------|------------|-------------------------------|
| **Dirección** | Contrato deploye normal (Ej: `0x5991A2dF...`) | Dirección fija del precompile (`0x...fd`) |
| **Tipo de llamada** | External call a contrato Solidity | Llamada a código nativo de Rust en revm |
| **Costo de gas** | ~27k gas (CALL + Solidity logic) | ~2-5k gas (código nativo optimizado) |

**Diferencia de Gas:**
```solidity
// Mock: ~27,665 gas para transfer
NativeTransferPrecompileMock::fallback() → _executeTransfer()

// Producción: ~2,500 gas estimado (similar a ECRECOVER precompile)
Precompile::execute() → directamente modifica state en Rust
```

### 3. **Mint y Burn**

| Operación | PoC (Mock) | Producción (Precompile Real) |
|-----------|------------|-------------------------------|
| **Mint** | Llama `depositNativeBalance()` para simular aumento de supply | Precompile incrementa supply total y asigna balance nativo real |
| **Burn** | Requeriría función `withdrawNativeBalance()` | Precompile decrementa supply total y quema balance nativo |

**Código en PoC:**
```solidity
function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    // PoC: Depositar en mock primero
    (bool success,) = _nativeTransferPrecompile.call(
        abi.encodeWithSignature("depositNativeBalance(address,uint256)", to, amount)
    );
    require(success);

    _update(address(0), to, amount); // No llama al precompile para minting
}
```

**Código en Producción:**
```solidity
function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    // Producción: Precompile tiene función especial para minting
    (bool success,) = _nativeTransferPrecompile.call(
        abi.encodeWithSignature("mintNative(address,uint256)", to, amount)
    );
    require(success);

    _update(address(0), to, amount); // Solo para eventos y checkpoints
}
```

### 4. **Interoperabilidad con Gas**

| Escenario | PoC (Mock) | Producción (Precompile Real) |
|-----------|------------|-------------------------------|
| **Pagar gas con ANDE** | ❌ Imposible (balance no es nativo) | ✅ Funciona automáticamente |
| **Recibir ANDE como gas refund** | ❌ No aplicable | ✅ Funciona automáticamente |
| **Balance usado en `msg.value`** | ❌ Separado | ✅ Mismo balance |

**Ejemplo que NO funciona en PoC:**
```solidity
// Alice tiene 1000 ANDE en el mock
// Intenta enviar transacción con gas

// ❌ PoC: Falla porque alice.balance (nativo) = 0
//         alice tiene ANDE solo en el mock

// ✅ Producción: Funciona porque alice.balance (nativo) = 1000 ANDE
//                puede pagar ~21,000 gas = 0.000021 ANDE
```

---

## 🔄 Migración: PoC → Producción

### Fase 1: Implementar Precompile Real (ev-reth)

**Archivo:** `~/dev/ande-labs/ev-reth/crates/evolve-ev-reth/src/precompile_ande.rs`

```rust
use revm::precompile::{Precompile, PrecompileError, PrecompileResult};
use revm::primitives::{Address, Bytes, U256};

/// Dirección del precompile ANDE Transfer
pub const ANDE_TRANSFER_PRECOMPILE: Address = address!("00000000000000000000000000000000000000fd");

/// Dirección autorizada del contrato ANDEToken
const ANDE_TOKEN_ADDRESS: Address = address!("..."); // Desde genesis o config

pub fn ande_native_transfer(
    input: &Bytes,
    gas_limit: u64,
    context: &mut InnerEvmContext
) -> PrecompileResult {
    // 1. Validar caller
    if context.env.tx.caller != ANDE_TOKEN_ADDRESS {
        return Err(PrecompileError::Other("Unauthorized caller".into()));
    }

    // 2. Decodificar input (96 bytes: from, to, value)
    if input.len() != 96 {
        return Err(PrecompileError::Other("Invalid input length".into()));
    }

    let from = Address::from_slice(&input[12..32]);
    let to = Address::from_slice(&input[44..64]);
    let value = U256::from_be_slice(&input[64..96]);

    // 3. Validaciones
    if to == Address::ZERO {
        return Err(PrecompileError::Other("Transfer to zero address".into()));
    }

    // 4. Ejecutar transferencia nativa
    let from_balance = context.journaled_state.load_account(from, &mut context.db)?
        .info.balance;

    if from_balance < value {
        return Err(PrecompileError::Other("Insufficient balance".into()));
    }

    // Modificar balances directamente en el state
    context.journaled_state.transfer(&from, &to, value, &mut context.db)?;

    // 5. Retornar éxito
    Ok((3000, Bytes::from(vec![0u8; 32]))) // 3000 gas usado
}
```

**Registrar precompile:**
```rust
// En evolve-ev-reth/src/lib.rs o similar
pub fn register_ande_precompiles(precompiles: &mut BTreeMap<Address, Precompile>) {
    precompiles.insert(
        ANDE_TRANSFER_PRECOMPILE,
        Precompile::Standard(ande_native_transfer)
    );
}
```

### Fase 2: Actualizar ANDETokenDuality.sol

**Cambios mínimos:**

1. **Constructor/Initializer:**
```solidity
// ANTES (PoC):
function initialize(address defaultAdmin, address minter, address precompile) public initializer {
    // precompile = dirección del mock deploye

// DESPUÉS (Producción):
function initialize(address defaultAdmin, address minter) public initializer {
    address precompile = 0x00000000000000000000000000000000000000fd; // Hardcoded
```

2. **Función mint() - Agregar mintNative():**
```solidity
// Producción: Usar función mintNative del precompile
function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    (bool success,) = _nativeTransferPrecompile.call(
        abi.encodeWithSignature("mintNative(address,uint256)", to, amount)
    );
    require(success, "Failed to mint native balance");

    _update(address(0), to, amount);
}
```

3. **Opcional: Burn function:**
```solidity
function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
    (bool success,) = _nativeTransferPrecompile.call(
        abi.encodeWithSignature("burnNative(address,uint256)", from, amount)
    );
    require(success, "Failed to burn native balance");

    _update(from, address(0), amount);
}
```

### Fase 3: Genesis Configuration

**Archivo:** `andechain/infra/stacks/single-sequencer/genesis.json`

```json
{
  "alloc": {
    "0x...": {
      "balance": "1000000000000000000000000",
      "nonce": "0",
      "code": "..." // Bytecode de ANDETokenDuality proxy
    }
  },
  "config": {
    "chainId": 31337,
    "andeTokenAddress": "0x..." // Address del ANDEToken proxy
  }
}
```

**CRÍTICO:** La dirección del ANDEToken proxy debe estar hardcodeada en el precompile para validación.

### Fase 4: Testing Completo

**Test end-to-end:**

```bash
# 1. Compilar ande-reth con precompile
cd ~/dev/ande-labs/ev-reth
cargo build --release
docker build -t andelabs/ande-reth:token-duality-prod .

# 2. Actualizar docker-compose en andechain
cd ~/dev/ande-labs/andechain/infra
# Editar docker-compose.yml: image: andelabs/ande-reth:token-duality-prod

# 3. Reset completo y redeploy
docker compose down -v
docker compose up -d

# 4. Deploy ANDEToken (producción)
cd ../contracts
forge script script/DeployANDETokenDuality.s.sol --rpc-url local --broadcast

# 5. Ejecutar tests
forge test --match-path test/unit/TokenDuality.t.sol --rpc-url http://localhost:8545

# 6. TEST CRÍTICO: Verificar que balance nativo funciona para gas
cast send <RECIPIENT> --value 1ether --from <ALICE> --private-key <ALICE_KEY>
# ✅ Debe descontar gas del balance de ANDE de Alice
```

---

## 📊 Comparación de Características

| Característica | PoC (Mock) | Producción (Precompile) |
|----------------|-----------|--------------------------|
| **Balance storage** | Storage del mock | Balance nativo EVM |
| **Pagar gas con ANDE** | ❌ No | ✅ Sí |
| **ERC-20 compliant** | ✅ Sí | ✅ Sí |
| **ERC-20 Votes** | ✅ Sí | ✅ Sí |
| **ERC-20 Permit** | ✅ Sí | ✅ Sí |
| **Pausable** | ✅ Sí | ✅ Sí |
| **Gas por transfer** | ~67k gas | ~40k gas (estimado) |
| **Minting** | Via depositNativeBalance() | Via precompile nativo |
| **Burning** | No implementado | Via precompile nativo |
| **Validación de seguridad** | ✅ Sí | ✅ Sí |

---

## ✅ Checklist de Migración

### Pre-requisitos

- [ ] Precompile implementado en ev-reth
- [ ] ande-reth compilado y dockerizado
- [ ] Genesis actualizado con dirección de ANDEToken
- [ ] ANDETokenDuality.sol actualizado para producción

### Testing

- [ ] Tests unitarios pasando en local
- [ ] Test de pago de gas con ANDE
- [ ] Test de mint/burn nativos
- [ ] Test de integración completo
- [ ] Stress test con múltiples transfers

### Deployment

- [ ] Imagen de ande-reth publicada en registry
- [ ] docker-compose.yml actualizado
- [ ] Genesis desplegado en testnet
- [ ] ANDEToken deploye en testnet
- [ ] Verificación en Blockscout

### Documentación

- [ ] Actualizar docs/token-duality/IMPLEMENTATION_PLAN.md
- [ ] Crear guía de usuario para ANDE nativo
- [ ] Documentar diferencias de gas consumption
- [ ] Actualizar CHANGELOG

---

## 🎯 Conclusión del PoC

### ✅ Logros

1. **Arquitectura Validada:** El patrón Token Duality funciona perfectamente
2. **Tests Completos:** 26/26 tests pasando, cubriendo todas las funcionalidades ERC-20
3. **Gobernanza Funcional:** Vote escrow, delegation, y checkpoints operativos
4. **Código Listo:** Solo cambios menores necesarios para producción

### ⏭️ Próximos Pasos

1. **Implementar precompile real** en `~/dev/ande-labs/ev-reth`
2. **Compilar y dockerizar** ande-reth
3. **Testing end-to-end** con precompile real
4. **Deploy en testnet** para validación externa
5. **Auditoría de seguridad** antes de mainnet

**Tiempo estimado para migración:** 15-25 horas (basado en plan original)

---

**Última actualización:** 2025-10-07
**Mantenido por:** Ande Labs Development Team
