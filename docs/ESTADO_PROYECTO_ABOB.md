# 🇧🇴 ANDE LABS - Estado del Proyecto Sistema Stablecoin Boliviano (ABOB)
**Fecha de Actualización:** 7 de Octubre, 2025
**Branch Actual:** `develop`
**Objetivo Principal:** Protocolo de Deuda Colateralizada (CDP) multi-activo para ABOB

---

## 📊 RESUMEN EJECUTIVO

**AndeChain** es un rollup soberano EVM en Celestia diseñado para resolver la fragmentación financiera en América Latina. El componente central es **ABOB (Andean Boliviano)**, un token CDP multi-colateral inspirado en MakerDAO.

### Visión Final del Sistema ABOB 2.0
```
┌─────────────────────────────────────────────────────────┐
│   ABOB 2.0 - Protocolo CDP Multi-Colateral            │
└─────────────────────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
   ┌────▼─────┐    ┌────▼─────┐    ┌────▼─────┐
   │   ABOB   │    │  sABOB   │    │  Bridge  │
   │ (Token)  │    │ (Staked) │    │ (xERC20) │
   └────┬─────┘    └────┬─────┘    └────┬─────┘
        │                │                │
        │                │                │
   Sobre-         Generación       Cross-chain
   colateral      de Yield         Interoperability
   Multi-activo   (ERC-4626)       (Multi-cadena)
```

---

## ✅ QUÉ SE HA HECHO (Implementado y Funcionando)

### 1. Infraestructura Core ✅

**Blockchain Stack Completo:**
- ✅ Rollup EVM soberano sobre Celestia (usando Rollkit)
- ✅ Execution Layer: Reth (EVM execution)
- ✅ Sequencer: ev-node (block production)
- ✅ Data Availability: local-da (mock Celestia para desarrollo)
- ✅ RPC Endpoint: http://localhost:8545
- ✅ Block Explorer: Blockscout en http://localhost:4000
- ✅ ANDE como token nativo para gas

**Ubicación:** `/infra/`
**Estado:** ✅ Operacional - Permite desarrollo local completo

---

### 2. Sistema de Tokens Core ✅

#### A. ANDE Token (`ANDEToken.sol`)
**Ubicación:** `/contracts/src/ANDEToken.sol`
**Estado:** ✅ Implementado y Testeado

**Características:**
- ✅ ERC20 upgradeable (UUPS pattern)
- ✅ ERC20Votes (gobernanza on-chain)
- ✅ ERC20Permit (gasless approvals)
- ✅ Burnable y Pausable
- ✅ Control de roles granular (MINTER_ROLE, BURNER_ROLE, PAUSER_ROLE)
- ✅ Token nativo de gas en AndeChain

**Roles Implementados:**
```solidity
MINTER_ROLE      → MintController (emisión controlada)
BURNER_ROLE      → DualTrackBurnEngine (deflación)
PAUSER_ROLE      → Gobernanza (emergencias)
DEFAULT_ADMIN    → Multi-sig governance
```

---

#### B. ABOB Token (`AbobToken.sol`) - NÚCLEO DEL PROYECTO
**Ubicación:** `/contracts/src/AbobToken.sol`
**Estado:** ✅ Implementado - Sistema CDP Multi-Colateral

**Mecanismo CDP Multi-Colateral:**
```
Usuario deposita colateral → Mint ABOB (deuda)
    ↓
Colateral Aceptado:
├─ USDC (Stablecoin USD) → 150% ratio
├─ wETH (ETH)             → 125% ratio
├─ ANDE (Token nativo)    → 175% ratio
└─ Otros activos aprobados por gobernanza

Sistema de Vaults personales con liquidaciones por subasta holandesa
```

**Funciones Core Implementadas:**
```solidity
// Crear vault y mintear ABOB
depositAndMint(address[] _collaterals, uint256[] _amounts, uint256 _abobToMint)
  → Verifica que colateral sea soportado
  → Valora colateral vía oráculos
  → Verifica ratio de sobre-colateralización
  → Crea/actualiza vault del usuario
  → Acuña ABOB al usuario

// Saldar deuda y recuperar colateral
burnAndWithdraw(uint256 _abobAmount, address[] _collaterals, uint256[] _amounts)
  → Quema ABOB del usuario
  → Verifica health ratio del vault
  → Transfiere colateral solicitado
  → Actualiza vault del usuario
```

**Características de Seguridad:**
- ✅ ReentrancyGuard en todas las funciones de valor
- ✅ Pausable por emergencias
- ✅ Control de roles (GOVERNANCE_ROLE, PAUSER_ROLE)
- ✅ Upgradeable (UUPS) para mejoras futuras
- ✅ Uso de SafeERC20 para transferencias seguras
- ✅ Math.mulDiv para cálculos sin overflow

**Oráculos Integrados:**
- `andePriceFeed` → Precio ANDE/USD
- `abobPriceFeed` → Precio ABOB/BOB (Boliviano)

**Variables de Gobernanza:**
```solidity
collateralSettings → Configuración por tipo de colateral
priceOracle        → Oráculo agregador de precios
liquidationManager → Gestor de subastas holandesas
```

---

#### C. sABOB Token (`sAbobToken.sol`) - Yield-Bearing CDP Vault
**Ubicación:** `/contracts/src/sAbobToken.sol`
**Estado:** ✅ Implementado - ERC-4626 Vault

**Concepto:**
```
Usuario deposita ABOB → Recibe sABOB shares
    ↓
Yield generado por:
├─ Stability fees del CDP system
├─ Liquidation bonuses (excedente de subastas)
├─ Intereses de colateral (ej: ETH staking)
└─ Protocol fees (bridge, etc.)

Contratos con YIELD_DEPOSITOR_ROLE depositan ganancias
→ Aumenta el valor de sABOB shares automáticamente
```

**Funciones Core:**
```solidity
// ERC-4626 standard
deposit(uint256 assets, address receiver)
mint(uint256 shares, address receiver)
withdraw(uint256 assets, address receiver, address owner)
redeem(uint256 shares, address receiver, address owner)

// Custom yield management
depositYield(uint256 amount)  // Solo YIELD_DEPOSITOR_ROLE
```

**Ventaja Clave:**
- Los holders de sABOB ganan yield generado por el sistema CDP
- Compatible con DeFi (puede usarse como colateral en otros protocolos)
- Share del revenue del protocolo ABOB

---

### 3. Sistema de Oráculos ✅

#### A. P2POracleV2 - Oracle Descentralizado
**Ubicación:** `/contracts/src/P2POracleV2.sol`
**Estado:** ✅ Implementado - Stake-Weighted Median Oracle

**Arquitectura:**
```
Reporters staking ANDE tokens
    ↓
Envían precios cada epoch (ej: cada 1 hora)
    ↓
Finalizer (trusted role) calcula mediana ponderada por stake
    ↓
Precio finalizado → usado por contratos (ABOB, AUSD, etc.)
```

**Características:**
- ✅ Reporters deben hacer stake de ANDE para participar
- ✅ Cálculo de mediana ponderada por stake (resistente a outliers)
- ✅ Sistema de epochs para agregación temporal
- ✅ Prevención de double-reporting
- ✅ Slashing implementado para reporters maliciosos
- ✅ Compatible con interfaz IOracle (Chainlink-like)

**Uso en el Ecosistema:**
- Precio USDC/USD → valoración de colateral principal
- Precio wETH/USD → valoración de colateral ETH
- Precio ANDE/USD → valoración de colateral nativo
- Precio ABOB/BOB → vinculación al Boliviano

---

#### B. AndeOracleAggregator
**Ubicación:** `/contracts/src/AndeOracleAggregator.sol`
**Estado:** ✅ Implementado

**Características:**
- Agrega múltiples fuentes de oráculos
- Proporciona resistencia contra fallas de un oracle single-point
- Cálculo de mediana con IQR para detección de anomalías

---

#### C. TrustedRelayerOracle
**Ubicación:** `/contracts/src/TrustedRelayerOracle.sol`
**Estado:** ✅ Implementado

**Uso:** Oracle centralizado para casos de uso específicos o bootstrapping inicial.

---

### 4. Sistema de Liquidación (Subastas Holandesas) ✅
**Ubicación:** `/contracts/src/AuctionManager.sol`
**Estado:** ✅ Implementado

**Función:**
- Gestiona liquidaciones de vaults con health ratio bajo
- Subastas holandesas para venta eficiente de colateral
- Distribución justa de excedentes a dueños de vaults

**Relación con ABOB:**
Protege la solvencia del sistema CDP liquidando posiciones de riesgo cuando el colateral cae por debajo del ratio mínimo.

---

### 5. DualTrackBurnEngine - Mecanismo Deflacionario ✅
**Ubicación:** `/contracts/src/DualTrackBurnEngine.sol`
**Estado:** ✅ Implementado

**Mecanismo:**
```
Real-Time Burns:
├─ % de fees de trading → quemados inmediatamente
├─ % de fees de bridge → quemados inmediatamente
└─ Reduce presión inflacionaria en tiempo real

Quarterly Burns:
├─ Acumulación de revenue en el contrato
└─ Burn masivo trimestral → evento comunitario
```

**Propósito:** Mantener presión deflacionaria en ANDE para contrarrestar emisión.

---

### 6. Tests Implementados ✅

**Ubicación:** `/contracts/test/unit/`

**Tests Completos:**
- ✅ `ANDEToken.t.sol` - Cobertura completa del token ANDE
- ✅ `AbobToken.t.sol` - Tests de sistema CDP multi-colateral
- ✅ `sAbobToken.t.sol` - Tests de ERC-4626 yield vault
- ✅ `P2POracleV2.t.sol` - Tests de oracle descentralizado
- ✅ `AuctionManager.t.sol` - Tests de sistema de liquidación
- ✅ `DualTrackBurnEngine.t.sol` - Tests de mecanismo deflacionario

**Cómo ejecutar:**
```bash
cd contracts
forge test                    # Todos los tests
forge test -vvv              # Verbose output
forge test --gas-report      # Reporte de gas
forge coverage               # Cobertura de código
```

---

## 🚧 QUÉ SE ESTÁ HACIENDO (Work in Progress)

### 1. xERC20 Bridge Implementation (Branch Actual)
**Branch:** `feature/xerc20-implementation`
**Estado:** 🚧 En Desarrollo

**Objetivo:** Implementar puente cross-chain para ABOB usando estándar xERC20 (ERC-7281)

#### Componentes en Desarrollo:

**A. AndeChainBridge Contract** ✅ Implementado (Pendiente Tests)
**Ubicación:** `/contracts/src/bridge/AndeChainBridge.sol`

**Características Implementadas:**
```solidity
// Bridging hacia otra cadena
bridgeTokens(address token, address recipient, uint256 amount, uint256 destinationChain)
  → Burns tokens on source chain
  → Emits event for relayer
  → Respeta rate limits de xERC20

// Recibir tokens desde otra cadena
receiveTokens(address token, address recipient, uint256 amount, ...)
  → Verifica Merkle proof de Celestia Blobstream
  → Previene replay attacks
  → Mints tokens on destination chain

// Escape Hatch - Forced Inclusion
forceTransaction(BridgeTransaction calldata txData, bytes calldata proof)
  → Permite a usuarios forzar transacción si relayer falla
  → Requiere proof de Celestia DA
  → Ventana temporal configurable (forceInclusionPeriod)
```

**Integraciones:**
- ✅ Blobstream verifier para proofs de DA
- ✅ xERC20 interface para rate limits
- ✅ Multi-token support
- ✅ Emergency pause mechanism
- ✅ Ownable para admin functions

**Pendiente:**
- ⏳ Tests completos del bridge
- ⏳ Deployment scripts con configuración real
- ⏳ Integración con Celestia Blobstream mainnet
- ⏳ Relayer off-chain implementation

---

**B. xERC20 Interfaces** ✅ Implementado
**Ubicación:** `/contracts/src/interfaces/`

- ✅ `IXERC20.sol` - Interface para tokens con bridge limits
- ✅ `IXERC20Lockbox.sol` - Interface para native token wrapping

**Capacidades del estándar xERC20:**
```solidity
struct BridgeParameters {
    uint256 timestamp;           // Última actualización
    uint256 ratePerSecond;       // Tasa de replenishment
    uint256 maxLimit;            // Límite máximo acumulable
    uint256 currentLimit;        // Límite actual disponible
}

// Rate limiting por bridge
setLimits(address bridge, uint256 mintingLimit, uint256 burningLimit)

// Mint/Burn controlado
mint(address user, uint256 amount)  // Solo bridges autorizados
burn(address user, uint256 amount)  // Solo bridges autorizados
```

**Ventajas xERC20:**
1. **Control de emisión cross-chain:** Evita infinite minting attacks
2. **Rate limiting:** Previene exploits masivos
3. **Fungibilidad garantizada:** ABOB es el mismo token en todas las cadenas
4. **Compatibilidad multi-bridge:** Soporta LayerZero, Axelar, Wormhole, custom

---

**C. Test en Desarrollo**
**Ubicación:** `/contracts/test/bridge/AndeChainBridge.t.sol`

**Estado:** 🚧 Test básico implementado, necesita expansión

**Casos que deben cubrirse:**
- ✅ Bridging básico (happy path)
- ⏳ Rate limit enforcement
- ⏳ Replay attack prevention
- ⏳ Blobstream proof verification
- ⏳ Force transaction mechanism
- ⏳ Pause/unpause functionality
- ⏳ Multi-destination chain support

---

### 2. Próximos Pasos Inmediatos (Próximas 2 Semanas)

**Prioridad ALTA:**
1. ✅ Completar tests del bridge (AndeChainBridge.t.sol)
2. ⏳ Implementar xERC20 wrapper para ABOB
3. ⏳ Deployment script con configuración de bridges
4. ⏳ Integración con Celestia Blobstream testnet
5. ⏳ Relayer TypeScript básico en `/relayer/`

**Prioridad MEDIA:**
6. ⏳ Auditoría de seguridad interna
7. ⏳ Documentation de flujos de bridging
8. ⏳ Frontend básico para bridge UI

---

## 🔮 QUÉ SE HARÁ (Roadmap Siguiente)

### Q2 2025 - Componentes Core (PRIORIDAD MÁXIMA)

Según `AndeChainPlanMaestro.md`, estos son los componentes NO NEGOCIABLES para V1:

#### 1. Bridge Seguro con xERC20 ✅ En Progreso
**Estado Actual:** 60% completado

**Falta:**
- Implementación completa de xERC20ABOB contract
- Deployment en Ethereum mainnet + AndeChain
- Configuración de rate limits basada en análisis de riesgo
- Auditoría externa por firma tier-1 (OpenZeppelin, Trail of Bits, Consensys)
- Bug bounty de $100k+ en ImmuneFi

**Cadenas Target Iniciales:**
1. Ethereum (settlement layer principal)
2. Arbitrum (L2 para bajar costos)
3. Polygon (comunidad LATAM)

---

#### 2. Escape Hatch Funcional (Soberanía del Usuario) ⏳ Pendiente
**Prioridad:** CRÍTICA

**Arquitectura Recomendada (según Plan Maestro):**
```
Nivel 1 - Normal Withdrawals (Regular):
  → User requests withdrawal
  → Sequencer includes in batch
  → Settlement en Ethereum
  → Tiempo: ~1 hora

Nivel 2 - Forced Inclusion (Sequencer offline/censoring):
  → User publica tx en Celestia con priority flag
  → Sequencer DEBE incluir o pierde stake
  → Tiempo: ~6 horas
  → Implementado parcialmente en forceTransaction()

Nivel 3 - Full Exit (Sistema comprometido):
  → User publica Merkle proof de balance en Ethereum
  → Retiro directo desde bridge contract
  → No depende de sequencer
  → Tiempo: ~7 días
```

**Tareas:**
- [ ] Implementar Merkle tree de estados en bridge
- [ ] Proof generation client-side
- [ ] Emergency withdrawal contract en Ethereum
- [ ] Testing exhaustivo en testnet
- [ ] Documentación clara para usuarios

---

#### 3. Gobernanza Bootstrap ⏳ Pendiente
**Componente:** Dual-Governance System

**Nivel 1 - Optimistic Governance (Decisiones no críticas):**
```solidity
// Propuestas se ejecutan automáticamente tras delay
// Cualquier holder puede vetar con stake suficiente
// Uso: ajuste de fees, distribución de rewards, grants
```

**Nivel 2 - Secured Governance (Decisiones críticas):**
```solidity
// Requiere quórum alto (10%+ del supply votante)
// Timelock obligatorio (7 días mínimo)
// Veto posible por Security Council
// Uso: upgrades, cambios en bridge, security patches
```

**Emergency Council:**
- 5-7 miembros de confianza
- Puede pausar contratos en emergencias
- Límite temporal: pausa máxima 72 horas
- Todas las acciones on-chain y transparentes

**Tareas:**
- [ ] Implementar GovernorBravo con modificaciones
- [ ] Security Council multi-sig en Gnosis Safe
- [ ] Timelock contracts con diferentes delays
- [ ] Delegación líquida (cambiar voto después)
- [ ] Conviction voting (votos ganan peso con tiempo)

---

#### 4. Sequencer Federado (No Descentralizado Día 1) ⏳ Pendiente
**Filosofía:** Progressive Decentralization

**Fase 1 - Federated Sequencing (Q2 2025):**
- 3-5 sequencers operados por equipo + partners confianza
- Rotación cada N bloques
- Multi-sig para configuración
- Slashing por downtime

**Fase 2 - Staked Sequencing (Q3 2025):**
- Anyone puede ser sequencer con stake de stANDE
- Selección ponderada por stake
- Rewards proporcionales a bloques
- Slashing por: bloques inválidos, censura, downtime

**Fase 3 - Espresso Integration (Q4 2025-Q1 2026):**
- Integrar con Espresso Sequencer (shared sequencing)
- Atomic cross-rollup transactions
- MEV minimization
- Decentralización heredada de Espresso

**Tareas Inmediatas:**
- [ ] Setup de 3 sequencer nodes en cloud
- [ ] Monitoring 24/7 con PagerDuty
- [ ] Runbooks de incident response
- [ ] Health check endpoints
- [ ] Failover automático

---

#### 5. Infraestructura Básica ⏳ Parcialmente Completo

**Ya Tenemos:**
- ✅ RPC endpoints locales
- ✅ Blockscout explorer
- ✅ Local DA mock

**Falta para Producción:**
- [ ] RPCs en múltiples regiones (US, EU, LATAM)
  - Quicknode
  - Ankr
  - Nodos propios
- [ ] Blockscout en mainnet con features custom:
  - Vista de batches a Celestia
  - L1 ↔ L2 transaction mapping
  - MEV transparency
- [ ] Monitoring con Prometheus + Grafana
- [ ] Distributed tracing con Tempo/Jaeger
- [ ] Public status page
- [ ] Documentation site
- [ ] Faucet público para testnet

---

### Q3 2025 - Optimización & Crecimiento

#### 1. SDK v1 (Developer Experience)
**Multi-Language SDK:**

**TypeScript (Priority 1):**
```typescript
// Ejemplo de uso futuro
const sdk = new AndeChainSDK({ network: 'mainnet' });

// Bridge abstraction (usuario no elige bridge)
const quote = await sdk.bridge.getQuote({
  from: "ethereum",
  to: "andechain",
  token: "ABOB",
  amount: 1000
});
await sdk.bridge.execute(quote);

// DeFi operations
const bestSwap = await sdk.defi.findBestSwap({
  tokenIn: "USDC",
  tokenOut: "ABOB",
  amount: 1000
});
```

**Python (Priority 2):**
- Backend services
- Data analysis
- Bots de trading

---

#### 2. DeFi Primitives con Hooks
**Concepto:** Uniswap v4-style hooks para extensibilidad

**Tipos de Hooks:**
```solidity
BeforeSwap: Validaciones, rate limiting, KYC
AfterSwap: Rewards, analytics, fees
BeforeAddLiquidity: Verificaciones de balance
AfterRemoveLiquidity: Penalizaciones por early exit
```

**Use Cases:**
- MEV Redistribution: Capturar MEV, redistribuir a LPs
- Dynamic Fees: Ajustar fees según volatilidad
- Just-in-Time Liquidity: Agregar liquidez antes de swaps grandes
- Anti-Sniper: Prevenir bots de frontrunning

---

#### 3. Gauges System (Incentivos Alineados)
**Concepto:** Vote-escrowed tokenomics (estilo Curve/Velodrome)

**Mejoras sobre modelos existentes:**
- Decay de votos (5% por epoch) → previene set-and-forget
- Minimum diversity requirement (ningún pool > 30% rewards)
- Performance multipliers (pools con high volume obtienen boost)
- Cross-chain gauges (futuro: votar por pools en otros rollups Celestia)

**Propósito para ABOB:**
Incentivar liquidez profunda en pools ABOB/USDC, ABOB/BOB, etc.

---

### Q4 2025 - Diferenciación & Escalabilidad

#### 1. Liquid Restaking (Modelo EigenLayer-like)
**Concepto:** rsANDE (restaked ANDE)

**Servicios Asegurables:**
```
Oracle networks → ANDE holders validan price feeds
Bridge validators → Multisig requiere stake
Sequencer sets → Rotación entre stakers
Cross-chain relayers → Mensajes entre rollups
```

**Revenue Distribution:**
- 50% de fees de servicios → rsANDE holders
- 30% de slashing proceeds → rsANDE holders
- 20% recompra de ANDE → price support

**Propósito para ABOB:**
Asegurar los oráculos de precio ABOB/BOB con stake económico real.

---

#### 2. Intent-Based Architecture
**Concepto:** Usuarios expresan intents, solvers compiten por ejecutar

**Ejemplo de Intent:**
```json
{
  "intent": "Comprar ABOB con mis USDC al mejor precio",
  "constraints": {
    "maxSlippage": "0.5%",
    "deadline": "10 minutos"
  }
}
```

**Solver Network:**
- Solvers buscan mejor ruta (DEX, bridge, aggregators)
- Solver con mejor solución gana fee
- Verificadores checkan ejecución
- Slashing si solver no cumple

**Use Cases para ABOB:**
- "Convertir mi salario en USD a ABOB automáticamente"
- "Rebalancear portfolio si exposición a ABOB > 30%"
- "Auto-compound sABOB rewards cada semana"

---

### Q1 2026 - Liderazgo & Innovación

#### 1. L3 Fractal Scaling
**Concepto:** AndeChain como base para L3s especializados

**L3 Types:**
```
High-Frequency L3 (Gaming, DeFi):
  → Block time: 200ms
  → DA: Batch to AndeChain every minute
  → Gas token: ANDE o custom

Privacy L3:
  → ZK-based execution
  → Private transactions con ABOB
  → Proof batching to AndeChain
```

**Economic Model:**
- L3s pagan fees en ANDE a AndeChain
- AndeChain provee DA + sequencing + bridging
- Shared security via restaking

---

#### 2. ZK Migration Path
**Concepto:** Transición de Optimistic a ZK Rollup

**Ventajas para ABOB:**
- Finalidad rápida (~15 minutos vs ~7 días)
- Mejor UX para pagos
- Withdrawals más rápidos del bridge
- Menor dependencia de challenge period

**Tareas:**
- Research de ZK frameworks (Risc Zero, SP1, etc.)
- Proof-of-concept en testnet
- Partnership con ZK proving networks
- Gradual migration sin romper compatibilidad

---

## 🎯 ARQUITECTURA FINAL DEL SISTEMA ABOB

### Diagrama de Flujo Completo

```
┌──────────────────────────────────────────────────────────────┐
│                    USUARIO FINAL (Bolivia)                   │
└────────────┬─────────────────────────────────────────────────┘
             │
             │ Interacción vía:
             │ ├─ Web App (ande-frontend/)
             │ ├─ Mobile App (futuro)
             │ └─ WhatsApp Bot (P2P remittances)
             │
    ┌────────▼───────────┐
    │   AndeChain RPC    │ (RPC Descentralizado con múltiples proveedores)
    └────────┬───────────┘
             │
    ┌────────▼───────────┐
    │  Smart Contracts   │
    │    ABOB CDP System │
    └────────┬───────────┘
             │
      ┌──────┴──────┐
      │             │
┌─────▼─────┐  ┌───▼────┐
│   ABOB    │  │ sABOB  │
│  Token    │  │ Vault  │
│ (Deuda)   │  │ Yield  │
└─────┬─────┘  └───┬────┘
      │            │
      │ Colateral  │ Protocol
      │ Multi-     │ Revenue
      │ Activo     │ (fees, liquidaciones)
      │            │
┌─────▼─────┐  ┌───▼────────┐
│   USDC    │  │  Revenue   │
│ wETH etc. │  │  Sources:  │
└─────┬─────┘  │ - Stability fees │
      │        │ - Liquidation    │
┌─────▼─────┐  │   bonuses        │
│   ANDE    │  │ - Bridge fees    │
│(Native)   │  └──────────────────┘
└─────┬─────┘
      │
      │ Precio
      │ Oracle
      │
┌─────▼──────┐
│ AndeOracle │
│ Aggregator │
└────────────┘
      │
      │ Reporters
      │ Multi-fuente
      │
┌─────▼──────────┐
│  Price Feeds:  │
│ - USDC/USD     │
│ - wETH/USD     │
│ - ANDE/USD     │
│ - ABOB/BOB     │
└────────────────┘
```

---

### Flujo de Uso Real: Remesa Bolivia

**Escenario:** Juan en España envía $500 a su familia en La Paz.

**Flujo Tradicional (Actual):**
```
Juan → Western Union → $500 - $35 fee = $465
→ 7 días de espera
→ Familia recibe ~3200 BOB (tasa de cambio desfavorable)
```

**Flujo con ABOB (Futuro):**
```
1. Juan compra ABOB en España (vía bridge desde Ethereum)
   $500 en USDC → 500 ABOB (tasa ~1:1 con BOB)
   Bridge fee: ~$2

2. ABOB viaja cross-chain instantáneamente
   Ethereum → AndeChain (vía xERC20 bridge)

3. Juan envía ABOB a wallet de su familia
   Fee: <$0.01 (gas en ANDE)

4. Familia en Bolivia:
   Opción A: Mantiene ABOB como stablecoin local
   Opción B: Stake en sABOB para yield (~5-8% APY)
   Opción C: Off-ramp a BOB fiat en ATM local

Total: $500 - $2 = $498 llegó a familia
Tiempo: <5 minutos
```

**Beneficio:** 93% más barato, 2000x más rápido

---

### Casos de Uso Adicionales ABOB

**1. Ahorro con Protección Inflacionaria:**
- Bolivianos depositan BOB fiat → compran ABOB
- ABOB mantiene paridad con BOB pero con respaldo dual
- Stake en sABOB genera yield en dólares
- Protección contra devaluación del BOB

**2. Pagos Comerciales Cross-Border:**
- Exportadores bolivianos cobran en ABOB
- Evitan pérdidas por cambio de divisa
- Settlement instantáneo vs 3-5 días bancarios

**3. DeFi Local:**
- Lending/borrowing en ABOB (tasa local)
- DEX pools ABOB/USDC con liquidez profunda
- Yield farming con rewards en ANDE

**4. Integración con Fintech LATAM:**
- Mercado Pago acepta ABOB
- Nubank integra wallet ABOB
- ATMs locales dispensen ABOB

---

## 📈 MÉTRICAS DE ÉXITO

### Q2 2025 (Launch)
- ✅ Auditorías completadas sin issues críticos
- ✅ $1M+ TVL en bridges
- ✅ 1000+ usuarios activos en primeros 30 días
- ✅ 99.9% uptime de sequencers
- ✅ 0 incidents de seguridad

### Q3 2025 (Crecimiento)
- ✅ $10M+ TVL
- ✅ 10,000+ usuarios activos mensuales
- ✅ 50+ dApps deployed
- ✅ 10 sequencers (5 community-operated)
- ✅ <2 segundos confirmación (preconfs)

### Q4 2025 (Escalabilidad)
- ✅ $50M+ TVL
- ✅ 50,000+ usuarios activos mensuales
- ✅ 100+ dApps activos
- ✅ 20+ sequencers (80% community)
- ✅ 10+ integraciones externas

### Q1 2026 (Liderazgo)
- ✅ Top 3 rollup en Celestia por TVL
- ✅ $100M+ TVL
- ✅ 100,000+ usuarios activos mensuales
- ✅ 200+ dApps
- ✅ 5+ L3s deployados
- ✅ Partnerships con 10+ proyectos tier-1

---

## 🔐 CONSIDERACIONES DE SEGURIDAD

### Críticas para ABOB

**1. Oracle Security (CRÍTICO):**
- ✅ P2POracleV2 con stake-weighted median
- ⏳ Integrar múltiples oráculos (Chainlink, Pyth, UMA)
- ⏳ Circuit breakers si precio diverge >5%
- ⏳ Timelock en cambios de oracle feeds

**2. Collateral Management:**
- ✅ Ratios configurables por gobernanza
- ⏳ Monitoring de health ratio del sistema
- ⏳ Emergency shutdown mechanism
- ⏳ Insurance fund (5-10% treasury)

**3. Bridge Security:**
- ✅ Rate limits en xERC20
- ✅ Replay attack prevention
- ✅ Emergency pause
- ⏳ Auditoría externa tier-1
- ⏳ Bug bounty $1M+ en ImmuneFi
- ⏳ Multi-sig para admin functions

**4. Smart Contract Risks:**
- ✅ All contracts upgradeable (UUPS)
- ✅ ReentrancyGuard en funciones críticas
- ✅ Pausable para emergencias
- ⏳ Formal verification de lógica crítica
- ⏳ Chaos engineering tests
- ⏳ Simulation tests con Foundry

**5. Economic Attacks:**
- ⏳ Análisis game-theoretic de incentivos
- ⏳ Liquidation cascade simulations
- ⏳ Oracle manipulation resistance testing
- ⏳ Flash loan attack vectors analysis

---

## 🚀 PRÓXIMOS PASOS CONCRETOS (Próximas 4 Semanas)

### Semana 1-2: Completar Bridge Infrastructure

**Día 1-3:**
- [ ] Expandir tests de AndeChainBridge.t.sol
  - Rate limit enforcement
  - Blobstream proof verification mock
  - Force transaction scenarios
  - Multi-chain support

**Día 4-7:**
- [ ] Implementar xERC20ABOB.sol
  ```solidity
  contract xERC20ABOB is IXERC20, ERC20Upgradeable {
      mapping(address => Bridge) public bridges;

      function mint(address user, uint256 amount) external {
          // Check caller is authorized bridge
          // Check rate limits
          // Update limits
          // Mint tokens
      }
  }
  ```

**Día 8-10:**
- [ ] Deployment scripts para testnet
  - Deploy xERC20ABOB en Ethereum Sepolia
  - Deploy xERC20ABOB en AndeChain testnet
  - Deploy AndeChainBridge en ambas cadenas
  - Configure bridge limits

**Día 11-14:**
- [ ] Relayer básico en TypeScript
  ```typescript
  // contracts/relayer/src/bridge-relayer.ts
  - Listen events en source chain
  - Query Celestia para Merkle proofs
  - Submit receiveTokens en destination chain
  - Handle retries y error cases
  ```

---

### Semana 3: Integración y Testing

**Día 15-17:**
- [ ] End-to-end bridge testing
  - Bridge ABOB: AndeChain → Ethereum
  - Bridge ABOB: Ethereum → AndeChain
  - Test force transaction mechanism
  - Test con diferentes amounts (rate limits)

**Día 18-21:**
- [ ] Security review interno
  - Code review completo
  - Gas optimization
  - Check for common vulnerabilities (reentrancy, etc.)
  - Preparar para auditoría externa

---

### Semana 4: Documentation & Deployment

**Día 22-24:**
- [ ] Documentation completa
  - Architecture diagrams
  - API reference
  - User guides (cómo hacer bridge)
  - Developer guides (integrar con dApps)

**Día 25-28:**
- [ ] Testnet público deployment
  - Deploy en Sepolia + AndeChain testnet
  - Faucet público para testing
  - Bug bounty inicial ($10k pool)
  - Community testing campaign

---

## 📚 RECURSOS Y REFERENCIAS

### Documentación Técnica Interna
- `CLAUDE.md` - Guía de desarrollo para Claude Code
- `ONBOARDING.md` - Operations manual detallado
- `NATIVE_ANDE_MIGRATION.md` - Guía de ANDE como gas token
- `HEALTH_CHECK.md` - Comandos de verificación
- `GIT_WORKFLOW.md` - Branching strategy
- `AndeChainPlanMaestro.md` - Roadmap estratégico completo

### Estándares y ERCs
- **ERC-7281 (xERC20):** https://ethereum-magicians.org/t/erc-7281-sovereign-bridged-tokens/14979
- **ERC-4626 (Vaults):** https://eips.ethereum.org/EIPS/eip-4626
- **ERC-20 (Tokens):** https://eips.ethereum.org/EIPS/eip-20

### Tecnologías Core
- **Celestia:** https://docs.celestia.org/
- **Rollkit:** https://rollkit.dev/
- **Reth:** https://paradigmxyz.github.io/reth/
- **Foundry:** https://book.getfoundry.sh/

### Inspiración DeFi
- **Curve Finance:** Vote-escrowed tokenomics
- **Velodrome:** Optimized ve(3,3) model
- **Frax Finance:** Fractional-algorithmic stablecoins
- **Liquity:** Immutable stablecoin protocol

---

## 🎯 CONCLUSIÓN

### Estado Actual: SÓLIDO ✅
- Infraestructura blockchain funcionando
- Tokens core implementados y testeados
- Sistema ABOB con colateral dual funcional
- Oráculos descentralizados operativos

### Trabajo Inmediato: BRIDGE 🚧
- xERC20 implementation 60% completo
- 4 semanas para MVP funcional
- Testnet deployment en horizonte

### Visión Clara: STABLECOIN BOLIVIANA 🇧🇴
- ABOB como puente entre cripto y economía real
- sABOB generando yield para ahorradores
- Bridge seguro conectando LATAM con DeFi global
- Sistema sostenible con incentivos alineados

**El proyecto está bien encaminado. El próximo milestone crítico es completar el bridge xERC20 y desplegarlo en testnet público para validación comunitaria.**

---

**Última Actualización:** 6 de Octubre, 2025
**Autor:** Ande Labs Team
**Contacto:** team@andelabs.io
**Estado del Repositorio:** `feature/xerc20-implementation` branch
