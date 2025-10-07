# Token Duality - Plan de Implementación Completo

**Versión:** 1.0
**Fecha:** 2025-10-07
**Estado:** Propuesta - En Revisión
**Autor:** Ande Labs Development Team

---

## 📋 Índice

1. [Visión General](#visión-general)
2. [Prerequisitos](#prerequisitos)
3. [Fase 1: Fork y Setup de ev-reth](#fase-1-fork-y-setup-de-ev-reth)
4. [Fase 2: Modificación del Precompile en revm](#fase-2-modificación-del-precompile-en-revm)
5. [Fase 3: Compilación de Ande-Reth](#fase-3-compilación-de-ande-reth)
6. [Fase 4: Modificación de ANDEToken.sol](#fase-4-modificación-de-andetokensol)
7. [Fase 5: Testing Completo](#fase-5-testing-completo)
8. [Fase 6: Integración con Infraestructura](#fase-6-integración-con-infraestructura)
9. [Fase 7: Deprecación de WANDE](#fase-7-deprecación-de-wande)
10. [Anexos](#anexos)

---

## 🎯 Visión General

### Objetivo

Implementar **Token Duality** para que ANDE funcione simultáneamente como:
- ✅ Token nativo para pagar gas fees
- ✅ Token ERC-20 estándar para interactuar con dApps

### Beneficios

```
┌────────────────────────────────────────────────┐
│  ANTES (Situación Actual)                      │
├────────────────────────────────────────────────┤
│  Usuario tiene:                                │
│  ├─ ANDE nativo (para gas)                    │
│  └─ WANDE (wrapped, para DeFi)                │
│                                                │
│  Problemas:                                    │
│  ├─ Confusión (dos tokens "iguales")          │
│  ├─ Transacciones extra (wrap/unwrap)         │
│  ├─ Gas adicional                             │
│  └─ Fragmentación de liquidez                 │
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│  DESPUÉS (Con Token Duality)                   │
├────────────────────────────────────────────────┤
│  Usuario tiene:                                │
│  └─ ANDE (un solo token)                      │
│                                                │
│  Ventajas:                                     │
│  ├─ UX simplificada                           │
│  ├─ Sin wrap/unwrap                           │
│  ├─ Ahorro de gas                             │
│  ├─ Liquidez unificada                        │
│  └─ Compatibilidad total con ERC-20           │
└────────────────────────────────────────────────┘
```

### Arquitectura Técnica

```
┌─────────────────────────────────────────────────────┐
│                  Usuario / DApp                     │
└──────────────────────┬──────────────────────────────┘
                       │
                       │ Llama a transfer()
                       ▼
         ┌─────────────────────────────┐
         │   ANDEToken.sol (Proxy)     │
         │   ┌───────────────────────┐ │
         │   │ Interfaz ERC-20       │ │
         │   │ - transfer()          │ │
         │   │ - balanceOf()         │ │ ← Lee address.balance
         │   │ - approve()           │ │
         │   └───────────┬───────────┘ │
         └───────────────┼─────────────┘
                         │
                         │ Llama al precompile
                         ▼
            ┌────────────────────────────┐
            │  Precompile 0x...fd        │
            │  (en ev-reth / revm)       │
            │  ┌──────────────────────┐  │
            │  │ Función:             │  │
            │  │ celo_transfer()      │  │
            │  │                      │  │
            │  │ Valida:              │  │
            │  │ - caller autorizado  │  │
            │  │ - balance suficiente │  │
            │  │                      │  │
            │  │ Ejecuta:             │  │
            │  │ - from.balance -= X  │  │ ← Modifica balance NATIVO
            │  │ - to.balance += X    │  │
            │  └──────────────────────┘  │
            └────────────────────────────┘
```

---

## ✅ Prerequisitos

### Conocimientos Requeridos

- [ ] **Rust** (intermedio): Para modificar revm
- [ ] **Solidity** (avanzado): Para modificar ANDEToken.sol
- [ ] **Docker** (básico): Para compilar y deployar imágenes
- [ ] **Git** (intermedio): Para manejar forks y branches

### Herramientas Necesarias

```bash
# Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup default stable

# Foundry (para tests de Solidity)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Docker (para compilar ev-reth)
# Instalar desde: https://docs.docker.com/get-docker/

# Verificar instalaciones
rustc --version    # >= 1.75.0
cargo --version
forge --version
docker --version
```

### Repositorios a Forkear

1. **ev-reth**: https://github.com/evstack/ev-reth
2. **revm** (dependency dentro de ev-reth): https://github.com/bluealloy/revm

---

## 🚀 Fase 1: Fork y Setup de ev-reth

### Paso 1.1: Forkear ev-reth

```bash
# 1. Fork en GitHub
# Ir a: https://github.com/evstack/ev-reth
# Click en "Fork" → Crear fork en cuenta de Ande Labs

# 2. Clonar el fork
cd ~/dev/ande-labs
git clone https://github.com/ande-labs/ev-reth.git
cd ev-reth

# 3. Agregar upstream para futuras actualizaciones
git remote add upstream https://github.com/evstack/ev-reth.git
git fetch upstream

# 4. Crear rama de desarrollo
git checkout -b feature/token-duality-poc
```

### Paso 1.2: Entender la Estructura de ev-reth

```bash
# Explorar estructura
tree -L 2 -d

# Estructura esperada:
# ev-reth/
# ├── crates/
# │   ├── revm/           ← AQUÍ modificaremos
# │   ├── primitives/
# │   ├── node/
# │   └── ...
# ├── Cargo.toml
# ├── Dockerfile          ← AQUÍ compilaremos imagen
# └── ...
```

### Paso 1.3: Verificar Dependencia de revm

```bash
# Ver versión de revm usada
cd ~/dev/ande-labs/ev-reth
cat Cargo.toml | grep -A 5 "revm"

# Ejemplo de salida esperada:
# [dependencies]
# revm = { version = "3.5.0", features = ["..."] }
# O podría estar como submodule
```

**IMPORTANTE:** Si `revm` está como dependencia externa (crates.io), necesitamos:
1. Forkear revm también
2. Modificar `Cargo.toml` de ev-reth para apuntar a nuestro fork

```toml
# En ev-reth/Cargo.toml
[dependencies]
revm = { git = "https://github.com/ande-labs/revm.git", branch = "ande-precompile" }
```

---

## 🔧 Fase 2: Modificación del Precompile en revm

### Paso 2.1: Localizar el Archivo de Precompiles

```bash
# Buscar archivo de precompiles
cd ~/dev/ande-labs/ev-reth
find . -name "precompile.rs" -o -name "precompiles.rs"

# Ruta esperada:
# ./crates/revm/src/precompile.rs
# O:
# ./crates/precompile/src/lib.rs
```

### Paso 2.2: Analizar el Código Existente

```bash
# Abrir el archivo encontrado
code ./crates/revm/src/precompile.rs

# Buscar patrones clave:
# - Definiciones de direcciones de precompiles (address!("0x01"), etc)
# - Función berlin_precompiles() o similar
# - Registro de precompiles en BTreeMap<Address, Precompile>
```

### Paso 2.3: Añadir Constantes de Dirección

**Archivo:** `crates/revm/src/precompile.rs` (inicio del archivo)

```rust
// ==========================================
// ANDE LABS - Token Duality Precompile
// ==========================================

use revm_primitives::{address, Address, Bytes, Precompile, PrecompileResult,
                      PrecompileOutput, PrecompileError, B256, U256};

/// Dirección del contrato ANDEToken desplegado
/// NOTA: Esta dirección debe actualizarse después del deployment real
/// Actualmente apunta a la dirección esperada del proxy de ANDEToken
const ANDETOKEN_ADDRESS: Address = address!("1000000000000000000000000000000000000001");

/// Dirección del precompile de transferencia nativa de ANDE
/// Inspirado en Celo's native transfer precompile
const CELO_TRANSFER_PRECOMPILE: Address = address!("00000000000000000000000000000000000000fd");

// ==========================================
```

**⚠️ IMPORTANTE:** La dirección `ANDETOKEN_ADDRESS` debe ser actualizada con la dirección real del proxy de ANDEToken después del deployment.

### Paso 2.4: Implementar la Función del Precompile

**Archivo:** `crates/revm/src/precompile.rs` (después de las constantes)

```rust
/// Implementación del precompile de transferencia nativa para ANDE
///
/// Este precompile permite al contrato ANDEToken ejecutar transferencias
/// de balance nativo (gas token) directamente en el estado de la EVM.
///
/// # Seguridad
/// - Solo puede ser llamado por el contrato ANDEToken autorizado
/// - Valida todos los inputs antes de ejecutar la transferencia
/// - Maneja correctamente casos de balance insuficiente
///
/// # Parámetros de Input (ABI encoded)
/// - `from`: Address - Cuenta origen de la transferencia
/// - `to`: Address - Cuenta destino de la transferencia
/// - `value`: uint256 - Cantidad a transferir (en wei)
///
/// # Gas Cost
/// - BASE: 9000 gas (equivalente a transferencia nativa estándar)
///
/// # Returns
/// - `true` (encoded como bytes32) si la transferencia fue exitosa
/// - Revierte con error descriptivo en caso de fallo
pub fn celo_transfer(input: &Bytes, gas_limit: u64, context: &mut EvmContext) -> PrecompileResult {
    // --- 1. GAS COSTING ---
    const BASE_GAS_COST: u64 = 9000;

    if gas_limit < BASE_GAS_COST {
        return Err(PrecompileError::OutOfGas);
    }

    // --- 2. VERIFICACIÓN DE AUTORIZACIÓN ---
    // CRÍTICO: Solo el contrato ANDEToken puede llamar este precompile
    if context.caller != ANDETOKEN_ADDRESS {
        return Err(PrecompileError::Custom(
            "celo_transfer: unauthorized caller - only ANDEToken contract allowed".into()
        ));
    }

    // --- 3. DECODIFICACIÓN DE PARÁMETROS ---
    // Input esperado: 96 bytes = 32 bytes (from) + 32 bytes (to) + 32 bytes (value)
    // Nota: Los primeros 12 bytes de cada address son padding (0x00)
    if input.len() != 96 {
        return Err(PrecompileError::Custom(
            format!("celo_transfer: invalid input length {} (expected 96)", input.len())
        ));
    }

    // Decodificar addresses (últimos 20 bytes de cada slot de 32 bytes)
    let from = Address(B256::from_slice(&input[0..32]));
    let to = Address(B256::from_slice(&input[32..64]));

    // Decodificar value como U256 big-endian
    let value = U256::from_be_bytes(
        input[64..96].try_into()
            .map_err(|_| PrecompileError::Custom("celo_transfer: failed to decode value".into()))?
    );

    // --- 4. VALIDACIONES DE NEGOCIO ---

    // Prevenir transferencias a dirección cero (potencial pérdida de fondos)
    if to == Address::ZERO {
        return Err(PrecompileError::Custom(
            "celo_transfer: cannot transfer to zero address".into()
        ));
    }

    // Prevenir transferencias de cantidad cero (no hace nada, ahorra gas)
    if value == U256::ZERO {
        // Retornar éxito sin modificar estado
        return Ok(PrecompileOutput::new(
            BASE_GAS_COST,
            Bytes::from(vec![0u8; 31, 1u8])  // true en bytes32
        ));
    }

    // --- 5. EJECUCIÓN DE LA TRANSFERENCIA NATIVA ---

    // Cargar cuenta origen (from)
    let (from_account, _) = context.journaled_state
        .load_account(from, &mut context.db)
        .map_err(|e| PrecompileError::Custom(
            format!("celo_transfer: failed to load from account: {:?}", e)
        ))?;

    // Verificar balance suficiente
    if from_account.info.balance < value {
        return Err(PrecompileError::Custom(
            format!(
                "celo_transfer: insufficient balance (has: {}, needs: {})",
                from_account.info.balance,
                value
            )
        ));
    }

    // Ejecutar deducción de balance (origen)
    // Nota: Esta operación es atómica dentro del journaled_state
    from_account.info.balance -= value;

    // Cargar cuenta destino (to)
    // Si la cuenta no existe, load_account la crea automáticamente
    let (to_account, _) = context.journaled_state
        .load_account(to, &mut context.db)
        .map_err(|e| PrecompileError::Custom(
            format!("celo_transfer: failed to load to account: {:?}", e)
        ))?;

    // Ejecutar incremento de balance (destino)
    // Verificación de overflow (extremadamente improbable pero crítico)
    to_account.info.balance = to_account.info.balance
        .checked_add(value)
        .ok_or(PrecompileError::Custom(
            "celo_transfer: balance overflow on recipient account".into()
        ))?;

    // --- 6. RETORNO EXITOSO ---
    // Retornar true (encoded como bytes32) para cumplir con ABI
    Ok(PrecompileOutput::new(
        BASE_GAS_COST,
        Bytes::from(vec![
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
        ])  // bytes32(uint256(1)) = true
    ))
}
```

### Paso 2.5: Registrar el Precompile en el Conjunto Activo

**Archivo:** `crates/revm/src/precompile.rs` (dentro de la función de inicialización)

```rust
/// Retorna el conjunto de precompiles para el hard fork de Berlin
/// (o el hard fork base que esté usando ev-reth)
pub fn berlin_precompiles() -> &'static Precompiles {
    static PRECOMPILES: OnceLock<Precompiles> = OnceLock::new();
    PRECOMPILES.get_or_init(|| {
        let mut precompiles = BTreeMap::new();

        // Precompiles estándar de Ethereum
        precompiles.insert(address!("0000000000000000000000000000000000000001"), Precompile::new_ecrecover());
        precompiles.insert(address!("0000000000000000000000000000000000000002"), Precompile::new_sha256());
        precompiles.insert(address!("0000000000000000000000000000000000000003"), Precompile::new_ripemd160());
        precompiles.insert(address!("0000000000000000000000000000000000000004"), Precompile::new_identity());
        precompiles.insert(address!("0000000000000000000000000000000000000005"), Precompile::new_modexp());
        precompiles.insert(address!("0000000000000000000000000000000000000006"), Precompile::new_bn128_add());
        precompiles.insert(address!("0000000000000000000000000000000000000007"), Precompile::new_bn128_mul());
        precompiles.insert(address!("0000000000000000000000000000000000000008"), Precompile::new_bn128_pair());
        precompiles.insert(address!("0000000000000000000000000000000000000009"), Precompile::new_blake2f());

        // ========================================
        // ANDE LABS - Registro del Token Duality Precompile
        // ========================================
        precompiles.insert(
            CELO_TRANSFER_PRECOMPILE,
            Precompile::Standard(celo_transfer)
        );
        // ========================================

        precompiles
    })
}
```

**Nota:** La sintaxis exacta puede variar dependiendo de la versión de revm. Si `Precompile::Standard` no existe, usar:
- `Precompile::Custom(Box::new(celo_transfer))`
- O el constructor equivalente que use el codebase

### Paso 2.6: Verificar Compilación

```bash
cd ~/dev/ande-labs/ev-reth

# Compilar solo el crate de revm para verificar sintaxis
cargo build -p revm --release

# Si hay errores, revisar:
# - Imports correctos de revm_primitives
# - Sintaxis de Precompile (Standard vs Custom)
# - Compatibilidad con versión de revm
```

---

## 🏗️ Fase 3: Compilación de Ande-Reth

### Paso 3.1: Compilar el Binario Completo

```bash
cd ~/dev/ande-labs/ev-reth

# Compilación en modo release (optimizado)
# ADVERTENCIA: Puede tardar 30-60 minutos en la primera compilación
cargo build --release

# El binario resultante estará en:
# target/release/ev-reth
```

**Optimizaciones de compilación (opcional):**

```bash
# Para compilación más rápida en desarrollo (menos optimizado)
cargo build

# Para compilación con perfil optimizado custom
# Editar Cargo.toml y añadir:
[profile.release]
lto = true
codegen-units = 1
opt-level = 3
```

### Paso 3.2: Compilar Imagen Docker

**Archivo:** `Dockerfile` (en la raíz de ev-reth)

```dockerfile
# Multi-stage build para optimizar tamaño de imagen

# Stage 1: Builder
FROM rust:1.75-slim as builder

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    build-essential \
    libclang-dev \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copiar código fuente
WORKDIR /app
COPY . .

# Compilar en release
RUN cargo build --release

# Stage 2: Runtime
FROM ubuntu:22.04

# Instalar solo dependencias de runtime
RUN apt-get update && apt-get install -y \
    libssl3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copiar binario compilado desde builder
COPY --from=builder /app/target/release/ev-reth /usr/local/bin/ev-reth

# Crear usuario no-root para seguridad
RUN useradd -m -u 1000 reth && \
    mkdir -p /root/reth /root/logs && \
    chown -R reth:reth /root

USER reth

# Exponer puertos
EXPOSE 8545 8551 9001

ENTRYPOINT ["ev-reth"]
```

**Compilar la imagen:**

```bash
cd ~/dev/ande-labs/ev-reth

# Build con tag específico
docker build -t andelabs/ande-reth:token-duality-v1 .

# Verificar que la imagen se creó
docker images | grep ande-reth

# Salida esperada:
# andelabs/ande-reth   token-duality-v1   <IMAGE_ID>   <SIZE>   <TIME>
```

### Paso 3.3: Push a Registry (Opcional)

```bash
# Si se usa GitHub Container Registry
echo $GITHUB_PAT | docker login ghcr.io -u USERNAME --password-stdin

# Tag para registry
docker tag andelabs/ande-reth:token-duality-v1 ghcr.io/ande-labs/ande-reth:token-duality-v1

# Push
docker push ghcr.io/ande-labs/ande-reth:token-duality-v1
```

---

## 📝 Fase 4: Modificación de ANDEToken.sol

### Paso 4.1: Backup del Contrato Original

```bash
cd ~/dev/ande-labs/andechain/contracts

# Crear backup
cp src/ANDEToken.sol src/ANDEToken.sol.backup

# Crear rama de feature
git checkout develop
git pull origin develop
git checkout -b feature/token-duality-andetoken
```

### Paso 4.2: Modificar el Contrato

**Archivo:** `contracts/src/ANDEToken.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20VotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {ERC20BurnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title ANDEToken with Token Duality
 * @author Ande Labs
 * @notice Token nativo de AndeChain con funcionalidad dual:
 *         - Gas token nativo de la red
 *         - Token ERC-20 estándar para dApps
 *
 * @dev Esta implementación utiliza un precompile personalizado (0x...fd) para
 *      delegar las transferencias de balance nativo, eliminando la necesidad
 *      de un "Wrapped ANDE" (WANDE).
 *
 *      Características principales:
 *      - balanceOf() lee el balance nativo (address.balance)
 *      - _update() delega transferencias al precompile
 *      - Mantiene funcionalidad completa de ERC20Votes, Permit, Pausable
 *      - Compatible 100% con estándar ERC-20
 */
contract ANDEToken is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable
{
    // ========================================
    // CONSTANTES
    // ========================================

    /// @notice Rol para acuñar nuevos tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Rol para quemar tokens
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Rol para pausar/reanudar transferencias
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Dirección del precompile de transferencia nativa
    /// @dev Esta dirección DEBE coincidir con CELO_TRANSFER_PRECOMPILE en ev-reth
    address private constant NATIVE_TRANSFER_PRECOMPILE =
        address(0x00000000000000000000000000000000000000fd);

    // ========================================
    // EVENTOS
    // ========================================

    /// @notice Emitido cuando se migra un balance de storage a nativo
    event BalanceMigrated(address indexed account, uint256 amount);

    // ========================================
    // INICIALIZACIÓN
    // ========================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Inicializa el contrato (patrón proxy UUPS)
     * @param defaultAdmin Dirección con rol de administrador
     * @param minter Dirección con permiso para acuñar (MintController)
     */
    function initialize(address defaultAdmin, address minter) public initializer {
        __ERC20_init("ANDE Token", "ANDE");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ERC20Permit_init("ANDE Token");
        __ERC20Votes_init();
        __ERC20Burnable_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(PAUSER_ROLE, defaultAdmin);
    }

    // ========================================
    // FUNCIONES OVERRIDDEN - TOKEN DUALITY
    // ========================================

    /**
     * @notice Retorna el balance de ANDE de una cuenta
     * @dev MODIFICADO: Lee del balance nativo en lugar de storage
     * @param account Dirección a consultar
     * @return Balance en wei
     */
    function balanceOf(address account)
        public
        view
        override(ERC20Upgradeable)
        returns (uint256)
    {
        // Balance nativo = balance del gas token de la red
        return account.balance;
    }

    /**
     * @notice Hook interno para transferencias, acuñaciones y quemas
     * @dev MODIFICADO: Delega actualizaciones de balance al precompile
     *
     *      Orden de operaciones:
     *      1. Actualizar checkpoints de votación (ERC20Votes)
     *      2. Ejecutar transferencia nativa vía precompile
     *      3. Emitir evento Transfer (compatibilidad ERC-20)
     *
     * @param from Dirección origen (address(0) para mint)
     * @param to Dirección destino (address(0) para burn)
     * @param value Cantidad a transferir
     */
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        // PASO 1: Actualizar checkpoints de votación
        // Esto debe hacerse ANTES de modificar balances para mantener
        // consistencia en el histórico de poder de voto
        _transferVotingUnits(from, to, value);

        // PASO 2: Ejecutar transferencia nativa vía precompile
        // El precompile valida:
        // - Caller == address(this)
        // - Balance suficiente
        // - Destinatario != address(0)
        (bool success, bytes memory returnData) = NATIVE_TRANSFER_PRECOMPILE.call(
            abi.encode(from, to, value)
        );

        if (!success) {
            // Decodificar mensaje de error del precompile
            string memory errorMsg = "ANDEToken: native transfer failed";
            if (returnData.length > 0) {
                assembly {
                    let returnDataSize := mload(returnData)
                    revert(add(32, returnData), returnDataSize)
                }
            }
            revert(errorMsg);
        }

        // PASO 3: Emitir evento Transfer
        // Requerido por estándar ERC-20 para compatibilidad con indexers y explorers
        emit Transfer(from, to, value);
    }

    /**
     * @notice Retorna el supply total de ANDE
     * @dev MODIFICADO: Calcula basado en balance del contrato
     *
     *      NOTA: En una implementación completa, esto debería rastrear
     *      el supply total en una variable de estado separada para
     *      mayor precisión. Por ahora, retornamos el balance del contrato.
     *
     * @return Supply total en wei
     */
    function totalSupply()
        public
        view
        override(ERC20Upgradeable)
        returns (uint256)
    {
        // TODO: Implementar tracking preciso de supply total
        // Por ahora, retornar balance del contrato
        return address(this).balance;
    }

    // ========================================
    // FUNCIONES ADMINISTRATIVAS
    // ========================================

    /**
     * @notice Pausa todas las transferencias de tokens
     * @dev Solo callable por PAUSER_ROLE
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Reanuda las transferencias de tokens
     * @dev Solo callable por PAUSER_ROLE
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Acuña nuevos tokens ANDE
     * @dev Solo callable por MINTER_ROLE (MintController)
     * @param to Dirección que recibirá los tokens
     * @param amount Cantidad a acuñar
     */
    function mint(address to, uint256 amount)
        public
        onlyRole(MINTER_ROLE)
        whenNotPaused
    {
        _mint(to, amount);
    }

    // ========================================
    // FUNCIONES INTERNAS
    // ========================================

    /**
     * @dev Autoriza upgrades del contrato (patrón UUPS)
     * @param newImplementation Dirección de la nueva implementación
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // Validación adicional: verificar que nueva implementación sea válida
        // (opcional, añadir checks específicos si es necesario)
    }

    /**
     * @dev Override para compatibilidad entre ERC20Permit y ERC20Votes
     */
    function nonces(address owner)
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    // ========================================
    // MIGRACIÓN (TEMPORAL)
    // ========================================

    /**
     * @notice Migra balances de storage antiguo a balance nativo
     * @dev FUNCIÓN TEMPORAL - Solo para migración inicial
     *      Será removida en futuras versiones
     *
     * @param users Array de direcciones a migrar
     */
    function migrateToNative(address[] calldata users)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];

            // Obtener balance del storage antiguo
            // NOTA: Esto asume que _balances todavía existe en el storage
            // En la práctica, este valor será 0 después de la migración completa
            uint256 storageBalance = _balances[user];

            if (storageBalance > 0) {
                // Limpiar storage antiguo
                _balances[user] = 0;

                // Transferir al balance nativo
                _update(address(0), user, storageBalance);

                emit BalanceMigrated(user, storageBalance);
            }
        }
    }
}
```

### Paso 4.3: Compilar y Verificar

```bash
cd ~/dev/ande-labs/andechain/contracts

# Compilar contratos
forge build

# Verificar warnings/errors
# Debería compilar sin errores
```

---

## 🧪 Fase 5: Testing Completo

### Paso 5.1: Crear Suite de Tests

**Archivo:** `contracts/test/unit/TokenDuality.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {ANDEToken} from "../../src/ANDEToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title TokenDualityTest
 * @notice Tests completos para verificar funcionalidad de Token Duality
 *
 * REQUISITO CRÍTICO: Estos tests deben ejecutarse con ev-reth que tenga
 * el precompile de transferencia nativa implementado (dirección 0x...fd)
 */
contract TokenDualityTest is Test {
    ANDEToken public ande;

    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function setUp() public {
        // Deploy ANDEToken con proxy
        ANDEToken implementation = new ANDEToken();
        bytes memory data = abi.encodeWithSelector(
            ANDEToken.initialize.selector,
            owner,
            owner  // owner también es minter para tests
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        ande = ANDEToken(address(proxy));

        // Mint inicial para Alice
        vm.prank(owner);
        ande.mint(alice, 1000 ether);
    }

    // ========================================
    // TESTS CORE - Token Duality
    // ========================================

    function test_BalanceOfReadsNativeBalance() public view {
        // balanceOf() debe retornar el mismo valor que address.balance
        assertEq(ande.balanceOf(alice), alice.balance);
    }

    function test_TransferModifiesNativeBalance() public {
        uint256 aliceBalanceBefore = alice.balance;
        uint256 bobBalanceBefore = bob.balance;
        uint256 transferAmount = 100 ether;

        vm.prank(alice);
        ande.transfer(bob, transferAmount);

        // Verificar que balances nativos cambiaron
        assertEq(alice.balance, aliceBalanceBefore - transferAmount);
        assertEq(bob.balance, bobBalanceBefore + transferAmount);
    }

    function test_TransferEmitsEvent() public {
        vm.prank(alice);

        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, bob, 50 ether);

        ande.transfer(bob, 50 ether);
    }

    function test_GasPaymentDeductsFromSameBalance() public {
        uint256 balanceBefore = alice.balance;
        uint256 transferAmount = 100 ether;

        vm.prank(alice);
        vm.txGasPrice(10 gwei);

        ande.transfer(bob, transferAmount);

        // El balance debe reflejar: transfer + gas fees
        uint256 balanceAfter = alice.balance;

        // Balance debe ser menor que (before - transfer) debido al gas
        assertTrue(balanceAfter < balanceBefore - transferAmount);
    }

    // ========================================
    // TESTS - ERC20 Standard Compliance
    // ========================================

    function test_ApproveAndTransferFrom() public {
        uint256 approvalAmount = 500 ether;
        uint256 transferAmount = 100 ether;

        // Alice aprueba a owner
        vm.prank(alice);
        ande.approve(owner, approvalAmount);

        assertEq(ande.allowance(alice, owner), approvalAmount);

        // Owner transfiere de Alice a Bob
        vm.prank(owner);
        ande.transferFrom(alice, bob, transferAmount);

        // Verificar balances nativos
        assertEq(alice.balance, 900 ether);
        assertEq(bob.balance, transferAmount);

        // Verificar allowance decrementado
        assertEq(ande.allowance(alice, owner), approvalAmount - transferAmount);
    }

    function test_TransferFromInsufficientAllowance() public {
        vm.prank(owner);
        vm.expectRevert();  // ERC20: insufficient allowance
        ande.transferFrom(alice, bob, 100 ether);
    }

    function test_TransferInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert();  // Precompile: insufficient balance
        ande.transfer(bob, 2000 ether);  // Alice solo tiene 1000
    }

    // ========================================
    // TESTS - ERC20Votes (Gobernanza)
    // ========================================

    function test_VotingPowerUpdatesOnTransfer() public {
        // Alice se delega a sí misma
        vm.prank(alice);
        ande.delegate(alice);

        uint256 votesBefore = ande.getVotes(alice);
        assertEq(votesBefore, 1000 ether);

        // Alice transfiere a Bob
        vm.prank(alice);
        ande.transfer(bob, 300 ether);

        // Votos de Alice deben disminuir
        uint256 votesAfter = ande.getVotes(alice);
        assertEq(votesAfter, 700 ether);

        // Bob aún no tiene votos (no se ha delegado)
        assertEq(ande.getVotes(bob), 0);

        // Bob se delega a sí mismo
        vm.prank(bob);
        ande.delegate(bob);

        // Ahora Bob tiene votos
        assertEq(ande.getVotes(bob), 300 ether);
    }

    function test_DelegationToOtherAddress() public {
        // Alice delega a Bob
        vm.prank(alice);
        ande.delegate(bob);

        // Bob tiene el poder de voto de Alice
        assertEq(ande.getVotes(bob), 1000 ether);
        assertEq(ande.getVotes(alice), 0);
    }

    // ========================================
    // TESTS - Pausable
    // ========================================

    function test_PauseBlocksTransfers() public {
        vm.prank(owner);
        ande.pause();

        vm.prank(alice);
        vm.expectRevert();  // Pausable: paused
        ande.transfer(bob, 100 ether);
    }

    function test_UnpauseAllowsTransfers() public {
        vm.prank(owner);
        ande.pause();

        vm.prank(owner);
        ande.unpause();

        // Ahora debe funcionar
        vm.prank(alice);
        ande.transfer(bob, 100 ether);

        assertEq(bob.balance, 100 ether);
    }

    // ========================================
    // TESTS - Minting
    // ========================================

    function test_MintIncreasesNativeBalance() public {
        uint256 bobBalanceBefore = bob.balance;
        uint256 mintAmount = 500 ether;

        vm.prank(owner);
        ande.mint(bob, mintAmount);

        assertEq(bob.balance, bobBalanceBefore + mintAmount);
        assertEq(ande.balanceOf(bob), bob.balance);
    }

    // ========================================
    // TESTS - ERC20Permit (Gasless Approvals)
    // ========================================

    function test_PermitApproval() public {
        uint256 privateKey = 0xA11CE;
        address alicePermit = vm.addr(privateKey);

        // Mint para alice
        vm.prank(owner);
        ande.mint(alicePermit, 1000 ether);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = ande.nonces(alicePermit);

        // Crear firma de permit
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                ande.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        alicePermit,
                        owner,
                        500 ether,
                        nonce,
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // Ejecutar permit
        ande.permit(alicePermit, owner, 500 ether, deadline, v, r, s);

        // Verificar approval
        assertEq(ande.allowance(alicePermit, owner), 500 ether);
    }

    // ========================================
    // EVENTS
    // ========================================

    event Transfer(address indexed from, address indexed to, uint256 value);
}
```

### Paso 5.2: Ejecutar Tests

**IMPORTANTE:** Estos tests requieren ejecutarse contra un nodo con el precompile implementado.

```bash
cd ~/dev/ande-labs/andechain/contracts

# Opción 1: Tests contra fork de mainnet (simula precompile)
# NOTA: Esto NO funcionará completamente sin el precompile real

# Opción 2: Tests contra nodo local con Ande-Reth
# 1. Iniciar infraestructura con nueva imagen
cd ../infra
# Modificar docker-compose.yml para usar andelabs/ande-reth:token-duality-v1
docker compose up -d

# 2. Esperar que nodo esté listo
sleep 30

# 3. Ejecutar tests
cd ../contracts
forge test --match-path test/unit/TokenDuality.t.sol --rpc-url http://localhost:8545 -vvv
```

---

## 🔗 Fase 6: Integración con Infraestructura

### Paso 6.1: Modificar docker-compose.yml

**Archivo:** `andechain/infra/stacks/single-sequencer/docker-compose.da.local.yml`

```yaml
services:
  # ... (otros servicios sin cambios)

  ev-reth-sequencer:
    container_name: ev-reth-sequencer
    # CAMBIO CRÍTICO: Usar nuestra imagen custom en lugar de la oficial
    # image: ghcr.io/evstack/ev-reth:latest  ← ANTES
    image: andelabs/ande-reth:token-duality-v1  # ← DESPUÉS

    # O si se publicó en GitHub Container Registry:
    # image: ghcr.io/ande-labs/ande-reth:token-duality-v1

    depends_on:
      jwt-init-sequencer:
        condition: service_completed_successfully
    # ... (resto de configuración sin cambios)
```

### Paso 6.2: Actualizar Genesis para ANDEToken

**Archivo:** `andechain/infra/stacks/single-sequencer/genesis.final.json`

Asegurarse de que la dirección de ANDEToken tenga código (será el proxy):

```json
{
  "config": {
    "chainId": 123456,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0
  },
  "alloc": {
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266": {
      "balance": "0x21e19e0c9bab2400000"
    },
    "0x1000000000000000000000000000000000000001": {
      "code": "0x...",  // Bytecode del proxy de ANDEToken
      "storage": {
        "0x0": "0x..."  // Slots de storage iniciales
      },
      "balance": "0x0"
    }
  },
  "coinbase": "0x0000000000000000000000000000000000000000",
  "difficulty": "0x1",
  "extraData": "0x",
  "gasLimit": "0x1c9c380",
  "nonce": "0x0000000000000042",
  "mixhash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "timestamp": "0x00"
}
```

**NOTA:** La dirección `0x1000...0001` es la que debe estar hardcodeada en `ANDETOKEN_ADDRESS` del precompile.

### Paso 6.3: Desplegar y Verificar

```bash
cd ~/dev/ande-labs/andechain/infra

# Limpiar estado anterior
docker compose down -v

# Iniciar con nueva imagen
docker compose up -d --force-recreate

# Verificar logs
docker compose logs -f ev-reth-sequencer

# Esperar a que nodo esté listo
sleep 30

# Verificar RPC
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

# Verificar que precompile está disponible
# (intentar llamar directamente fallará por autorización, pero confirma que existe)
```

---

## 🗑️ Fase 7: Deprecación de WANDE

### Paso 7.1: Marcar WAndeVault como Deprecated

**Archivo:** `contracts/src/vaults/WAndeVault.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title WAndeVault (Wrapped ANDE Vault)
 * @author Gemini
 *
 * @custom:deprecated
 * ⚠️ ESTE CONTRATO ESTÁ OBSOLETO ⚠️
 *
 * Con la implementación de Token Duality, ANDE ahora funciona nativamente
 * como token ERC-20 sin necesidad de wrapping. Este contrato se mantiene
 * únicamente para compatibilidad temporal con integraciones existentes.
 *
 * RECOMENDACIÓN: Migrar a usar ANDEToken directamente.
 *
 * TIMELINE DE DEPRECACIÓN:
 * - Q1 2025: Marcado como deprecated
 * - Q2 2025: Deshabilitado para nuevos depósitos
 * - Q3 2025: Período de gracia para unwrap
 * - Q4 2025: Eliminación completa del codebase
 *
 * Para migrar: Llamar a redeem() para convertir vaANDE de vuelta a ANDE.
 */
contract WAndeVault is ERC4626 {
    /**
     * @notice Constructs the WAndeVault
     * @param _asset The address of the underlying ANDEToken (ERC-20)
     */
    constructor(IERC20 _asset) ERC20("Vault ANDE", "vaANDE") ERC4626(_asset) {}
}
```

### Paso 7.2: Crear Plan de Migración para Usuarios

**Archivo:** `docs/WANDE_MIGRATION_GUIDE.md`

```markdown
# Guía de Migración: WANDE → ANDE (Token Duality)

## ¿Qué está pasando?

AndeChain ha implementado **Token Duality**, permitiendo que ANDE funcione
simultáneamente como gas token nativo y token ERC-20 estándar.

Esto **elimina la necesidad de WANDE** (Wrapped ANDE).

## ¿Qué debo hacer?

Si tienes vaANDE (shares de WAndeVault):

1. Ve a la dApp de AndeChain
2. Navega a "Unwrap ANDE"
3. Ingresa la cantidad de vaANDE
4. Click en "Redeem" (unwrap)
5. Recibirás ANDE nativo directamente

## Timeline

- **Ahora - Junio 2025:** WAndeVault sigue funcionando normalmente
- **Julio 2025:** Se deshabilitan nuevos depósitos en WAndeVault
- **Julio - Sept 2025:** Período de gracia para unwrap
- **Octubre 2025:** WAndeVault se elimina del código

## ¿Qué pasa si no hago nada?

Tienes hasta **Septiembre 2025** para unwrap. Después de esa fecha,
se implementará un mecanismo de rescate de emergencia.

## Soporte

- Discord: https://discord.gg/andechain
- Email: support@andelabs.io
```

### Paso 7.3: Actualizar README y Documentación

**Archivo:** `contracts/README.md`

Añadir sección prominente:

```markdown
## ⚠️ Cambios Importantes: Token Duality

**ANDE ahora es un token dual** (nativo + ERC-20) sin necesidad de wrapping.

### Contratos Obsoletos

Los siguientes contratos están marcados como deprecated:

- ❌ `WAndeVault.sol` - Ya no necesitas "wrapped ANDE"
- ❌ `DeployWAndeVault.s.sol` - Script de deployment obsoleto

### Migración

Si usabas WANDE en tus contratos:

**Antes:**
```solidity
import {WAndeVault} from "./vaults/WAndeVault.sol";

// Wrap ANDE
ande.approve(address(vault), amount);
vault.deposit(amount, recipient);
```

**Ahora:**
```solidity
import {ANDEToken} from "./ANDEToken.sol";

// Usar ANDE directamente - no se necesita wrap
ande.transfer(recipient, amount);
```

Consulta [WANDE_MIGRATION_GUIDE.md](../docs/WANDE_MIGRATION_GUIDE.md) para más detalles.
```

---

## 📎 Anexos

### Anexo A: Comandos de Verificación Rápida

```bash
# Verificar que precompile está en la imagen
docker run --rm andelabs/ande-reth:token-duality-v1 --version

# Verificar dirección de ANDEToken en genesis
cat andechain/infra/stacks/single-sequencer/genesis.final.json | jq '.alloc["0x1000000000000000000000000000000000000001"]'

# Verificar que nodo está corriendo
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq

# Verificar balance de cuenta de desarrollo
cast balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://localhost:8545
```

### Anexo B: Troubleshooting Común

| Problema | Causa Probable | Solución |
|----------|----------------|----------|
| Tests fallan con "unauthorized caller" | Dirección de ANDEToken no coincide con constante en revm | Verificar `ANDETOKEN_ADDRESS` en `precompile.rs` |
| Docker build falla en compilación | Dependencias de Rust faltantes | Instalar `libclang-dev` y `libssl-dev` |
| Precompile no se encuentra | Imagen de Docker no actualizada | `docker compose down -v` y `docker compose up -d --force-recreate` |
| Balance no se actualiza | Precompile no registrado correctamente | Verificar registro en `berlin_precompiles()` |

### Anexo C: Checklist Pre-Deployment Mainnet

- [ ] Auditoría de seguridad del código Rust completada
- [ ] Auditoría de smart contracts completada
- [ ] Bug bounty en testnet pública (mínimo 1 mes)
- [ ] Tests E2E pasando 100%
- [ ] Load testing realizado (simular tráfico alto)
- [ ] Plan de rollback documentado
- [ ] Monitoreo 24/7 configurado (Grafana/Prometheus)
- [ ] Documentación para usuarios finalizada
- [ ] Plan de comunicación ejecutado
- [ ] Multisig configurada para upgrades
- [ ] Circuit breakers testeados (función pause)

---

**Documento vivo** - Se actualizará durante la implementación.

**Próximo paso:** Ejecutar Fase 1 - Fork de ev-reth
