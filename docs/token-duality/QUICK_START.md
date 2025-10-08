# Token Duality - Guía de Inicio Rápido

**Para:** Desarrolladores que implementarán Token Duality
**Tiempo estimado:** 5 minutos de lectura

---

## 🎯 ¿Qué es Token Duality?

ANDE funcionará como:
- **Gas token nativo** (para pagar fees)
- **Token ERC-20** (para usar en dApps)

**Un solo token, dos funciones.** No más WANDE.

---

## 📍 Dónde Estamos

```
FASE ACTUAL: Preparación inicial
RAMA: feature/token-duality-poc
ESTADO: PoC - Diseño completado
```

---

## 🚀 Pasos Siguientes (Para el Equipo)

### 1. Fork de ev-reth (Prioridad: ALTA)

```bash
# En GitHub
# Ir a: https://github.com/evstack/ev-reth
# Click en "Fork" → Crear en ande-labs

# Luego clonar
cd ~/dev/ande-labs
git clone https://github.com/ande-labs/ev-reth.git
cd ev-reth
git remote add upstream https://github.com/evstack/ev-reth.git
git checkout -b feature/ande-precompile
```

### 2. Localizar Archivo de Precompiles

```bash
cd ~/dev/ande-labs/ev-reth

# Buscar archivo de precompiles
find . -name "precompile.rs" -o -name "precompiles.rs"

# Ruta esperada:
# ./crates/revm/src/precompile.rs
# O:
# ./crates/precompile/src/lib.rs
```

### 3. Implementar Precompile

Seguir la **Fase 2** del [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md):

**Archivos a modificar:**
- `crates/revm/src/precompile.rs`

**Código a añadir:**
```rust
// 1. Constantes
const ANDETOKEN_ADDRESS: Address = address!("1000000000000000000000000000000000000001");
const CELO_TRANSFER_PRECOMPILE: Address = address!("00000000000000000000000000000000000000fd");

// 2. Función celo_transfer()
pub fn celo_transfer(input: &Bytes, gas_limit: u64, context: &mut EvmContext) -> PrecompileResult {
    // Ver implementación completa en IMPLEMENTATION_PLAN.md Paso 2.4
}

// 3. Registrar en berlin_precompiles()
precompiles.insert(CELO_TRANSFER_PRECOMPILE, Precompile::Standard(celo_transfer));
```

### 4. Compilar Ande-Reth

```bash
cd ~/dev/ande-labs/ev-reth

# Compilar binario
cargo build --release

# Compilar imagen Docker
docker build -t andelabs/ande-reth:token-duality-v1 .
```

### 5. Modificar ANDEToken.sol

En `andechain/contracts/src/ANDEToken.sol`:

```solidity
// Override balanceOf
function balanceOf(address account) public view override returns (uint256) {
    return account.balance;  // Lee balance nativo
}

// Override _update
function _update(address from, address to, uint256 value) internal override {
    _transferVotingUnits(from, to, value);

    (bool success,) = NATIVE_TRANSFER_PRECOMPILE.call(
        abi.encode(from, to, value)
    );
    require(success, "native transfer failed");

    emit Transfer(from, to, value);
}
```

### 6. Crear Tests

Ver plantilla completa en [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) Fase 5.

```bash
cd ~/dev/ande-labs/andechain/contracts

# Crear archivo de test
# test/unit/TokenDuality.t.sol

# Ejecutar tests (requiere Ande-Reth corriendo)
forge test --match-path test/unit/TokenDuality.t.sol --rpc-url http://localhost:8545 -vvv
```

---

## ⚠️ Puntos Críticos de Seguridad

1. **Dirección de ANDEToken debe coincidir**
   - Hardcodeada en precompile: `ANDETOKEN_ADDRESS`
   - Debe ser la dirección real del proxy después de deployment

2. **Solo ANDEToken puede llamar al precompile**
   - Validación en Rust: `if context.caller != ANDETOKEN_ADDRESS`
   - Previene uso no autorizado

3. **Transferencias son atómicas**
   - `journaled_state` garantiza atomicidad
   - Rollback automático si falla

4. **Gas metering es crítico**
   - Cobrar `BASE_GAS_COST = 9000` gas
   - Prevenir DoS

---

## 📚 Documentación Completa

- **Plan completo:** [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)
- **Arquitectura:** [../ROADMAP_CONCEPTUAL.md](../ROADMAP_CONCEPTUAL.md)
- **Git workflow:** [../GIT_WORKFLOW.md](../GIT_WORKFLOW.md)

---

## 🆘 Troubleshooting Común

### Error: "unauthorized caller"
**Causa:** Dirección de ANDEToken no coincide
**Solución:** Verificar `ANDETOKEN_ADDRESS` en `precompile.rs`

### Error: "precompile not found"
**Causa:** Imagen Docker no actualizada
**Solución:**
```bash
docker compose down -v
docker compose up -d --force-recreate
```

### Compilación de Rust falla
**Causa:** Dependencias faltantes
**Solución:**
```bash
apt-get install libclang-dev libssl-dev
```

---

## 🎓 Recursos de Aprendizaje

- **Celo Fee Abstraction:** https://github.com/celo-org/celo-proposals/blob/master/CIPs/cip-0064.md
- **EVM Precompiles:** https://www.evm.codes/precompiled
- **revm Codebase:** https://github.com/bluealloy/revm

---

## ✅ Checklist de Implementación

```
Fase 1: Fork y Setup
[ ] ev-reth forkeado
[ ] Rama feature/ande-precompile creada
[ ] Estructura del proyecto explorada

Fase 2: Precompile
[ ] Archivo precompile.rs localizado
[ ] Constantes añadidas
[ ] Función celo_transfer() implementada
[ ] Precompile registrado

Fase 3: Compilación
[ ] Binario compilado (cargo build --release)
[ ] Imagen Docker creada

Fase 4: ANDEToken.sol
[ ] balanceOf() modificado
[ ] _update() modificado
[ ] Funcionalidad de votes mantenida

Fase 5: Testing
[ ] Suite de tests creada
[ ] Tests pasando

Fase 6: Integración
[ ] docker-compose.yml actualizado
[ ] genesis.json actualizado
[ ] Deployment end-to-end exitoso

Fase 7: Deprecación
[ ] WAndeVault marcado como @deprecated
[ ] Guía de migración creada
```

---

**¿Siguiente paso?** → Ejecutar Fase 1: Fork de ev-reth

**¿Dudas?** → Revisar [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) o contactar al equipo
