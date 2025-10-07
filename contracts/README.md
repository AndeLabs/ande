# Smart Contracts - AndeChain Tokenomics

<div align="center">

**Sistema de Contratos Inteligentes para AndeChain**

[![Solidity](https://img.shields.io/badge/Solidity-0.8.25-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-4.x-4B7EBC.svg)](https://openzeppelin.com/)
[![Tests](https://img.shields.io/badge/Tests-11%2F11%20Passing-success.svg)](./test/ABOB.t.sol)
[![ABOB](https://img.shields.io/badge/ABOB-Production%20Ready-brightgreen.svg)](./ABOB_PRODUCTION_READY.md)

[📖 Architecture](#arquitectura-de-contratos) • [🔨 Development](#desarrollo) • [🧪 Testing](#testing) • [🚀 Deployment](#despliegue) • [📄 ABOB Report](./ABOB_PRODUCTION_READY.md)

</div>

---

## 🎯 Visión General

Este directorio contiene el sistema completo de contratos inteligentes de AndeChain, con énfasis en **ABOB**, un sistema de **Collateralized Debt Position (CDP)** multi-colateral listo para producción.

### ⭐ ABOB - Production Ready

**Status:** ✅ **Ready for Security Audit & Testnet Deployment**
**Test Coverage:** 11/11 (100%)
**Last Updated:** 2025-10-07

ABOB es un sistema CDP que permite a los usuarios depositar colateral aprobado (USDC, WETH, ANDE) y acuñar ABOB (Boliviano tokenizado) contra él.

**Características Principales:**
- 🏦 **Multi-Collateral CDP**: Soporte para USDC, WETH, ANDE
- 🔐 **Sobre-colateralización**: Ratio mínimo 150%
- 📊 **Oracle Descentralizado**: Precio mediano de múltiples fuentes
- ⚡ **Liquidaciones Automáticas**: Threshold de 125%
- 🔧 **Normalización de Decimales**: Soporte para tokens con diferentes decimales
- 🌉 **xERC20 Ready**: Preparado para bridges cross-chain

👉 **[Ver Reporte Completo de Producción](./ABOB_PRODUCTION_READY.md)**

### 💡 Características del Ecosistema Completo

- **🏛️ Gobernanza Vote-Escrowed**: Sistema veANDE con lock hasta 4 años
- **🔒 Seguridad Multi-capa**: Patrones UUPS, AccessControl, pausabilidad
- **⚡ Optimización Gas-Eficiente**: Análisis continuo de consumo
- **🌉 Bridges xERC20**: Estándar industry para cross-chain
- **📊 Oráculos P2P**: Sistema descentralizado de precios
- **⚖️ CDP System**: Colateralización multi-activo para ABOB

## 🏗️ Arquitectura de Contratos

### 📋 Estructura de Directorios

```
contracts/
├── 📁 src/                          # 🔨 Código fuente principal
│   ├── 📁 tokens/                   # 🪙 Tokens del ecosistema
│   │   ├── 📄 ANDEToken.sol         # 🔥 Token nativo + gobernanza
│   │   ├── 📄 AbobToken.sol         # 🇧🇴 Boliviano tokenizado (CDP)
│   │   └── 📄 sAbobToken.sol        # 💰 ABOB staked con yield
│   │
│   ├── 📁 governance/               # 🏛️ Sistema de gobernanza
│   │   ├── 📄 AndeGovernor.sol      # 🗳️ Contrato de gobernador
│   │   ├── 📄 AndeTimelockController.sol # ⏰ Control de tiempo
│   │   └── 📄 MintController.sol    # 🏭 Control de emisión
│   │
│   ├── 📁 bridge/                   # 🌉 Infraestructura de puentes
│   │   ├── 📄 AndeChainBridge.sol   # 🔄 Bridge fuente
│   │   ├── 📄 EthereumBridge.sol    # 🎯 Bridge destino
│   │   └── 📄 IBlobstream.sol       # 🔗 Interface Celestia
│   │
│   ├── 📁 oracle/                   # 📊 Sistema de oráculos
│   │   ├── 📄 P2POracle.sol         # 👥 Oráculo P2P
│   │   ├── 📄 AndeOracleAggregator.sol # 📈 Agregador de precios
│   │   └── 📄 TrustedRelayerOracle.sol # 🔐 Oráculo confiable
│   │
│   ├── 📁 gauges/                   # 📊 Sistema de gauges (veANDE)
│   │   ├── 📄 VotingEscrow.sol      # 🗳️ veANDE vote-escrow
│   │   ├── 📄 GaugeController.sol   # 📊 Controlador de gauges
│   │   └── 📄 LiquidityGaugeV1.sol  # 💰 Gauge de liquidez

│   ├── 📁 burn/                     # 🔥 Mecanismos de deflación
│   │   └── 📄 DualTrackBurnEngine.sol # 🔥 Quema dual
│   │
│   ├── 📁 xERC20/                   # 🔐 Estándar xERC20
│   │   ├── 📄 XERC20Lockbox.sol     # 📦 Gestión de liquidez
│   │   └── 📄 IXERC20.sol           # 📄 Interface estándar
│   │
│   ├── 📁 security/                 # 🛡️ Utilidades de seguridad
│   │   └── 📄 Utils.sol             # 🔧 Funciones helper
│   │
│   ├── 📁 mocks/                    # 🧪 Contratos de prueba
│   │   ├── 📄 MockERC20.sol         # 🪙 Token ERC20 mock
│   │   └── 📄 MockOracle.sol        # 📊 Oráculo mock
│   │
│   └── 📄 Counter.sol               # 🔢 Contrato simple para testing
│
├── 📁 test/                         # 🧪 Suite de tests
│   ├── 📁 unit/                     # 🔬 Tests unitarios
│   ├── 📁 integration/              # 🔗 Tests de integración
│   └── 📁 fuzz/                     # 🎲 Tests de fuzzing
│
├── 📁 script/                       # 🚀 Scripts de despliegue
│   ├── 📄 DeployEcosystem.s.sol    # 🌍 Despliegue completo
│   ├── 📄 DeployBridge.s.sol        # 🌉 Despliegue de bridges
│   └── 📄 DeployOracle.s.sol        # 📊 Despliegue de oráculos
│
├── 📁 lib/                          # 📚 Bibliotecas externas
├── 📄 foundry.toml                  # ⚙️ Configuración de Foundry
└── 📄 package.json                  # 📦 Metadatos del proyecto
```

## 🪙 Sistema de Tokens

### 🔥 ANDEToken - Token Nativo de Gobernanza

**Contrato**: `src/tokens/ANDEToken.sol`

```solidity
// ERC20Votes + Gobernanza + Gas Nativo
contract ANDEToken is
    ERC20VotesUpgradeable,      // Voting power
    AccessControlUpgradeable,   // Role-based access
    UUPSUpgradeable,           // Upgradeability
    PausableUpgradeable,       // Emergency pause
    ERC20BurnableUpgradeable   // Deflationary mechanism
```

**Características Principales:**
- **🏛️ Voting Power**: Implementa EIP-6372 para votación on-chain
- **🔑 Role Management**: MINTER_ROLE, BURNER_ROLE, PAUSER_ROLE
- **⬆️ UUPS Upgradeable**: Actualizaciones sin migración
- **⏸️ Pausable**: Protección de emergencia
- **🔥 Burnable**: Mecanismos deflacionarios

**Roles y Permisos:**
```solidity
MINTER_ROLE    // MintController - control de emisión
BURNER_ROLE    // DualTrackBurnEngine - quema de tokens
PAUSER_ROLE    // Admin - emergencias
DEFAULT_ADMIN_ROLE  // Gobernanza - actualizaciones
```

### 🏦 CDP System - Multi-Collateral Vaults

**Contrato**: `src/tokens/AbobToken.sol`

**Características:**
- **🎯 Multi-Colateral**: USDC, wETH, ANDE y otros activos
- **⚖️ Sobre-colateralización**: Ratios mínimos configurables
- **📊 Oracle-Based**: Valoración vía oráculos descentralizados
- **🔨 Liquidation System**: Subastas holandesas automáticas

### 🇧🇴 ABOB - Boliviano Tokenizado

**Contrato**: `src/tokens/AbobToken.sol`

**Características:**
- **🎯 1:1 BOB Peg**: Vinculado 1:1 con Boliviano
- **🏦 CDP System**: Emitido contra colateral depositado
- **📈 Yield Generation**: Yield vía sABOB y fees del protocolo
- **🔄 Bridge Support**: Compatible con xERC20

### 💰 sAbobToken - Staked ABOB con Yield

**Contrato**: `src/tokens/sAbobToken.sol`

**Características:**
- **🔄 Auto-compounding**: Yield compounding automático
- **📊 APR Dinámico**: Basado en utilidades del protocolo
- **⏰ Unstaking Period**: Período de cooldown de 7 días
- **🎯 Rewards Distribution**: Distribución de fees staking

## 🏛️ Sistema de Gobernanza

### 🗳️ AndeGovernor - Contrato Principal de Gobernanza

**Contrato**: `src/governance/AndeGovernor.sol`

**Parámetros de Gobernanza:**
- **📊 Quorum**: 4% del supply total de veANDE
- **⏰ Voting Delay**: 1 bloque (1 segundo en AndeChain)
- **🗳️ Voting Period**: 7200 bloques (~2 horas)
- **📋 Proposal Threshold**: 0.1% del supply de veANDE
- **⏰ Timelock**: 48 horas para ejecución

### 🏭 MintController - Control de Emisión ANDE

**Contrato**: `src/governance/MintController.sol`

**Límites de Seguridad:**
```solidity
uint256 public constant HARD_CAP = 1_000_000_000e18;      // 1B ANDE
uint256 public constant ANNUAL_LIMIT = 50_000_000e18;    // 50M ANDE/año
uint256 public constant SUPERMAJORITY = 66;              // 66% aprobación
uint256 public constant VOTING_PERIOD = 7 days;          // 7 días votación
```

## 🌉 Sistema de Bridges

### 🔄 AndeChainBridge - Bridge Fuente

**Contrato**: `src/bridge/AndeChainBridge.sol`

**Flow de Lock:**
1. **📝 Usuario llama** `lockTokens(amount, destination)`
2. **🔒 Tokens transferidos** al contrato del bridge
3. **⚡ Evento emitido** `BridgeInitiated`
4. **📊 Datos enviados** a Celestia DA
5. **🔄 Relayer monitorea** y procesa

### 🎯 BSCBridge - Bridge Destino

**Contrato**: `src/bridge/BSCBridge.sol`

**Flow de Mint:**
1. **📊 Relayer verifica** DA proof de Celestia
2. **🔍 Validación de** transacción original
3. **🪙 Mint de tokens** en Binance Smart Chain
4. **✅ Confirmación** al usuario

### 📦 XERC20Lockbox - Gestión de Liquidez

**Contrato**: `src/xERC20/XERC20Lockbox.sol`

**Características:**
- **🔄 Liquidity Management**: Gestión de liquidity pools
- **📊 Rate Limiting**: Límites de transferencia
- **🔒 Security**: Múltiples capas de seguridad
- **⚡ Efficiency**: Optimizado para alto throughput

## 📊 Sistema de Oráculos

### 👥 P2POracle - Oráculo P2P

**Contrato**: `src/oracle/P2POracle.sol`

**Pairs Soportados:**
- BOB/USD (Boliviano)
- CLP/USD (Peso Chileno)
- PEN/USD (Sol Peruano)
- ARS/USD (Peso Argentino)
- EUR/USD (Euro)
- BTC/USD (Bitcoin)

### 📈 AndeOracleAggregator - Agregador Principal

**Contrato**: `src/oracle/AndeOracleAggregator.sol`

**Sources de Precios:**
1. **👥 P2POracle**: Tasas P2P reales
2. **🔗 Chainlink**: Precios de referencia
3. **🔐 TrustedRelayerOracle**: Fuentes confiables
4. **📊 Band Protocol**: Datos de mercado

## ⚖️ Motor de Estabilidad

### 🗳️ veANDE System - Vote-Escrowed Governance

**Contrato**: `src/gauges/VotingEscrow.sol`

**Funciones:**
- **🔒 Token Locking**: Lock de ANDE hasta 4 años
- **📊 Voting Power**: Poder basado en cantidad y tiempo
- **📈 Decay Linear**: Decaimiento lineal del poder
- **🎯 Gauge Voting**: Votación por distribuciones de rewards

### 🔥 DualTrackBurnEngine - Quema Dual

**Contrato**: `src/burn/DualTrackBurnEngine.sol`

**Mecanismos de Quema:**
1. **⚡ Real-time Burn**: Quema inmediata de fees
2. **📅 Quarterly Burn**: Quema trimestral de excedentes
3. **📊 Burn Ratio**: Porcentaje dinámico basado en métricas
4. **🔄 Buyback & Burn**: Compra y quema de tokens

## 🔨 Desarrollo

### 🔧 Configuración del Entorno

```bash
# Instalar Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Instalar dependencias
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
forge install foundry-rs/forge-std
```

### 🧪 Testing

#### Tests Unitarios

```bash
# Ejecutar todos los tests
forge test

# Tests específicos
forge test --match-test testMintWithGovernance
forge test --match-path test/unit/ANDEToken.t.sol

# Verbose output
forge test -vvv

# Gas reporting
forge test --gas-report
```

#### Tests de Integración

```bash
# Tests de bridges
forge test --match-path test/integration/bridge/

# Tests de gobernanza
forge test --match-path test/integration/governance/

# Tests de oráculos
forge test --match-path test/integration/oracle/
```

#### Fuzzing

```bash
# Fuzz testing con 10,000 runs
forge test --fuzz-runs 10000

# Fuzz testing específico
forge test --match-test testFuzzMint --fuzz-runs 50000
```

### 📊 Cobertura de Código

```bash
# Generar reporte de cobertura
forge coverage

# Reporte detallado
forge coverage --report lcov
```

**Métricas Objetivo:**
- **📊 Coverage**: >85%
- **🧪 Branch Coverage**: >80%
- **⚡ Gas Optimization**: <5% variación

## 🚀 Deployment

### 🔧 Configuración de Despliegue

**Variables de Entorno:**
```bash
# Development
export PRIVATE_KEY=TU_CLAVE_PRIVADA_DESARROLLO
export RPC_URL=http://localhost:8545

# Production (BSC)
export PRIVATE_KEY=TU_CLAVE_PRIVADA_PRODUCCION
export RPC_URL=https://bsc-dataseed.binance.org
export BSCSCAN_API_KEY=TU_API_KEY
```

### 📜 Scripts de Despliegue

#### 1. Despliegue Completo del Ecosistema

```bash
# Desplegar todo (tokens, gobernanza, bridges, oráculos)
forge script script/DeployEcosystem.s.sol:DeployEcosystem \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --legacy
```

#### 2. Despliegue de Bridges

```bash
# Solo bridges (AndeChain -> BSC)
forge script script/DeployBridge.s.sol:DeployBridge \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

### 📍 Direcciones de Despliegue

**Development (localhost:8545):**
Las direcciones de contratos se guardan automáticamente en `deployments/localhost.json` después del despliegue. Estas direcciones son dinámicas y cambiarán en cada despliegue local.

**Production:**
Las direcciones de contratos en mainnet/testnet serán consistentes y publicadas en la documentación oficial del proyecto.

## 🔒 Seguridad

### 🛡️ Análisis Estático

```bash
# Análisis con Slither
slither src/ --filter medium

# Análisis completo
slither src/ --filter low,medium,high,critical

# Reporte HTML
slither src/ --html slither-report.html
```

### 🔍 Mejores Prácticas de Seguridad

1. **✅ Input Validation**: Validar todos los inputs
2. **🔄 Checks-Effects-Interactions**: Prevenir reentrancy
3. **⚡ Gas Optimization**: Análisis continuo de consumo
4. **🔒 Access Control**: Roles granulares con OpenZeppelin
5. **⏸️ Pausability**: Mecanismos de emergencia
6. **🔄 Upgradability**: UUPS upgrade pattern
7. **📊 Event Logging**: Transparencia completa

## 🔗 Interactuando con Contratos Usando `cast`

`cast` es una herramienta poderosa para interactuar con los contratos desplegados desde la línea de comandos.

-   **Leer un valor:**
    ```bash
    # Llama a la función `name()` de un contrato ERC20
    cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "name()" --rpc-url local
    ```

-   **Enviar una transacción:**
    ```bash
    # Llama a la función `approve()` de un ERC20
    cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "approve(address,uint256)" <SPENDER> <AMOUNT> --rpc-url local --private-key $PRIVATE_KEY
    ```

-   **Consultar balance:**
    ```bash
    # Balance de tokens de una dirección
    cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "balanceOf(address)" <ADDRESS> --rpc-url local
    ```

-   **Verificar allowance:**
    ```bash
    # Verificar allowance aprobado
    cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "allowance(address,address)" <OWNER> <SPENDER> --rpc-url local
    ```

## 📊 Métricas y Optimización

### ⚡ Consumo de Gas

**Métricas Objetivo:**
- **🪙 Mint**: <50,000 gas
- **🔄 Transfer**: <30,000 gas
- **🗳️ Vote**: <80,000 gas
- **🌉 Bridge Lock**: <100,000 gas
- **📊 Oracle Update**: <60,000 gas

### 📈 Optimizaciones Implementadas

1. **🔢 Packing de Variables**: Optimización de storage
2. **📦 Batching**: Múltiples operaciones en single tx
3. **🔄 Events instead of Returns**: Ahorro de gas
4. **📊 Lazy Evaluation**: Computación solo cuando es necesario
5. **🔍 Precomputed Constants**: Constantes pre-calculadas

## 🔗 Interfaces y Estándares

### 📄 Interfaces Principales

```solidity
// Interface para gobernanza
interface IGovernance {
    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) external returns (uint256);
    function castVote(uint256 proposalId, uint8 support) external;
}

// Interface para oráculos
interface IOracle {
    function getPrice(string calldata pair) external view returns (uint256);
    function updatePrice(string calldata pair, uint256 price) external;
}

// Interface para bridges
interface IBridge {
    function lockTokens(uint256 amount, address destination) external;
    function mintTokens(address recipient, uint256 amount, bytes calldata proof) external;
}
```

### 📋 Estándares Implementados

- **🪙 ERC20**: Token estándar
- **🗳️ ERC20Votes**: Poder de voto on-chain
- **📝 ERC712**: Signed approvals (EIP-2612)
- **🔐 ERC1820**: Registry de interfaces
- **🌉 xERC20**: Cross-chain token estándar

---

<div align="center">

**🔨 Construyendo la infraestructura DeFi de América Latina**

[⬆ Volver arriba](#smart-contracts---andechain-tokenomics-v30)

</div>