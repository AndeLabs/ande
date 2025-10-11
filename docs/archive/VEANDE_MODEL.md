# veANDE Model - Vote-Escrowed ANDE Documentation

## Overview

El modelo veANDE (vote-escrowed ANDE) es un sistema de gobernanza diseñado para alinear incentivos a largo plazo. Los usuarios lockean tokens ANDE para recibir veANDE, que da poder de voto y beneficios en el ecosistema.

## 🏗️ Arquitectura del Sistema

```
ANDE Token
    ↓ (lock)
VotingEscrow (veANDE)
    ↓ (voting power)
┌─────────────────┬─────────────────┬─────────────────┐
│   Governor      │ GaugeController │  Protocol Fees  │
│ (Proposals)     │ (Gauge Weights) │  (Boosts)       │
└─────────────────┴─────────────────┴─────────────────┘
```

## 📊 Componentes Principales

### 1. ANDE Token (Base Token)
- **Propósito**: Token nativo de gas y gobernanza de AndeChain
- **Supply**: 100M tokens (configurable)
- **Usos**: Gas, staking, gobernanza, colateral

### 2. VotingEscrow (veANDE)
- **Propósito**: Lock de tokens ANDE para obtener poder de voto
- **Duración máxima**: 4 años
- **Decaimiento**: Lineal over time
- **No transferible**: Solo el propietario puede usar

### 3. GaugeController
- **Propósito**: Distribución de emisiones a gauges
- **Votación**: veANDE holders votan por gauges
- **Pesos**: Determinan la distribución de recompensas

### 4. Governor
- **Propósito**: Gobernanza on-chain del protocolo
- **Cuórum**: 4% de veANDE supply
- **Período de votación**: 1 semana
- **Timelock**: 2 días de delay

### 5. AndeTimelockController
- **Propósito**: Ejecución segura de propuestas
- **Delay**: 2 días para ejecución
- **Roles**: Proposer, Executor, Admin

## 🔢 Mecánicas de veANDE

### Cálculo de Poder de Voto

El poder de voto se calcula basado en:
- **Cantidad de ANDE lockeada**
- **Duración del lock**
- **Tiempo restante**

```
veANDE = ANDE_amount × (lock_duration / MAX_DURATION) × (time_remaining / lock_duration)
```

**Ejemplos con 1000 ANDE:**

| Duración del Lock | Poder Inicial | Poder después de 1 año |
|-------------------|---------------|------------------------|
| 4 años (max) | 1000 veANDE | 750 veANDE |
| 2 años | 500 veANDE | 250 veANDE |
| 1 año | 250 veANDE | 0 veANDE |
| 6 meses | ~123 veANDE | 0 veANDE |

### Tipos de Deposites

1. **Create Lock**: Nuevo lock con cantidad y duración
2. **Increase Amount**: Aumentar cantidad en lock existente
3. **Increase Time**: Extender duración del lock
4. **Deposit For**: Lock para otra dirección

## 🗳️ Sistema de Gobernanza

### Proceso de Propuesta

```
1. Crear Lock de ANDE → Obtener veANDE
2. Esperar Voting Delay (2 semanas)
3. Crear Propuesta (requiere 1000 veANDE)
4. Período de Votación (1 semana)
5. Conteo de Votos
6. Timelock (2 días)
7. Ejecución
```

### Parámetros de Gobernanza

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| Cuórum | 4% de veANDE supply | Mínimo para que una propuesta sea válida |
| Voting Period | 45760 blocks (~1 semana) | Duración de la votación |
| Voting Delay | 40320 blocks (~2 semanas) | Delay entre creación y votación |
| Proposal Threshold | 1000 veANDE | Mínimo para crear propuesta |
| Timelock Delay | 2 días | Período antes de ejecución |

### Tipos de Propuestas

1. **Parameter Changes**: Modificar parámetros del protocolo
2. **Token Mints**: Aumentar supply de tokens
3. **Role Management**: Cambiar roles en contratos
4. **Contract Upgrades**: Actualizar contratos proxy
5. **Treasury Management**: Usar fondos del tesoro

## 🎯 Gauge System

### Tipos de Gauges

1. **Liquidity Gauges**: Proveedores de liquidez
2. **Staking Gauges**: Staking de tokens nativos
3. **Protocol Gauges**: Usos específicos del protocolo

### Proceso de Votación de Gauges

```
1. Lock ANDE → Obtener veANDE
2. Votar por gauges (pesos de 0-10000 basis points)
3. Los pesos determinan distribución de emisiones
4. Las recompensas se distribuyen semanalmente
```

### Cálculo de Pesos

```
Gauge Weight = Σ(User_veANDE × User_Vote_Percentage) / Total_veANDE
```

**Ejemplo:**
- Usuario A: 10000 veANDE, vota 100% Gauge X
- Usuario B: 2500 veANDE, vota 100% Gauge Y
- Usuario C: 2500 veANDE, vota 60% Gauge X, 40% Gauge Y

**Resultado:**
- Gauge X: (10000 + 1500) / 15000 = 76.7%
- Gauge Y: (2500 + 1000) / 15000 = 23.3%

## 💰 Incentivos y Beneficios

### 1. Poder de Voto
- **Protocol Governance**: Votar en propuestas del protocolo
- **Gauge Weights**: Decidir distribución de recompensas
- **Parameter Changes**: Influenciar parámetros del sistema

### 2. Boosts de Recompensas
- **Liquidity Mining**: Mayor share en pools de liquidez
- **Protocol Fees**: Share de fees generados
- **Airdrops**: Prioridad en futuros airdrops

### 3. Descuentos y Beneficios
- **Trading Fees**: Descuentos en trading
- **Platform Features**: Acceso a características premium
- **Early Access**: Primera acceso a nuevos productos

## 📈 Estrategias Óptimas

### Para Maximizar Poder de Voto

1. **Lock Máximo (4 años)**: 100% de poder
2. **Lock Grande**: Más ANDE = más poder
3. **Lock Temprano**: Aprovechar decaimiento
4. **No Withdrawals**: Evitar pérdida de poder

### Para Maximizar Recompensas

1. **Votar Estratégicamente**: Gauges con mejor APY
2. **Comprobar Pesos**: Gauges con menos competencia
3. **Staking Adicional**: Combinar con otros staking
4. **Participación Activa**: Votar en cada período

## ⚠️ Riesgos y Consideraciones

### 1. Riesgo de Lock
- **Capital Locked**: Tokens no disponibles durante lock
- **Oportunidad Cost**: No puede vender durante lock
- **Decaimiento**: Poder disminuye over time

### 2. Riesgo de Gobernanza
- **Centralización**: Grandes holders pueden dominar
- **Apático Voter**: Baja participación
- **Proposals Maliciosas**: Riesgo de ataques

### 3. Riesgo de Sistema
- **Contract Bugs**: Riesgo en contratos complejos
- **Oracle Issues**: Dependencia de oráculos
- **Market Risk**: Valor de ANDE puede fluctuar

## 🛠️ Integración Técnica

### Smart Contracts

```solidity
// Lock ANDE for 4 years
ANDE.approve(address(votingEscrow), 1000e18);
votingEscrow.create_lock(1000e18, block.timestamp + 4 * 365 days);

// Vote for gauge
gaugeController.vote_for_gauge_weights(gaugeAddress, 10000); // 100%

// Create proposal
address[] memory targets = [targetContract];
uint256[] memory values = [0];
bytes[] memory calldatas = [abi.encodeWithSelector(...)];
string memory description = "Proposal Description";

governor.propose(targets, values, calldatas, description);
```

### Frontend Integration

```javascript
// Get veANDE balance
const veBalance = await votingEscrow.balanceOf(userAddress);

// Get voting power
const votingPower = await votingEscrow.getVotes(userAddress);

// Vote for gauge
await gaugeController.vote_for_gauge_weights(gaugeAddress, 10000);

// Check proposal state
const state = await governor.state(proposalId);
```

## 📊 Métricas y Monitoreo

### Métricas Clave

1. **veANDE Supply**: Total de tokens lockeados
2. **Average Lock Time**: Duración promedio de locks
3. **Participation Rate**: Porcentaje de veANDE que vota
4. **Proposal Success Rate**: Tasa de propuestas exitosas
5. **Gauge Distribution**: Distribución de pesos en gauges

### Dashboard Recomendado

```typescript
interface VeANDEReport {
  totalSupply: string;
  averageLockTime: number;
  participationRate: number;
  activeProposals: number;
  topGauges: GaugeWeight[];
}

interface GaugeWeight {
  address: string;
  weight: number;
  apy: number;
}
```

## 🚀 Roadmap

### Fase 1: Implementación Básica
- [x] VotingEscrow contract
- [x] GaugeController contract
- [x] Governor implementation
- [x] Timelock integration

### Fase 2: Gauges de Liquidez
- [ ] LiquidityGauge deployment
- [ ] Farming contracts
- [ ] Reward distribution
- [ ] APY optimization

### Fase 3: Integración con Protocolo
- [ ] CDP gauge integration
- [ ] Bridge gauge integration
- [ ] Fee sharing mechanism
- [ ] Boost calculations

### Fase 4: Mejora de Gobernanza
- [ ] Delegate voting
- [ ] Multi-sig integration
- [ ] Proposal templates
- [ ] Automated execution

## 🔗 Recursos Adicionales

- [Curve veCRV Documentation](https://docs.curve.fi/curve-dao/vecrv)
- [OpenZeppelin Governor](https://docs.openzeppelin.com/contracts/4.x/governance)
- [Smart Contract Best Practices](https://docs.openzeppelin.com/contracts/4.x/security)
- [Governance Patterns](https://github.com/pcaversaccio/greeter)

---

**⚡ Nota**: El modelo veANDE está diseñado para incentivar la participación a largo plazo y la gobernanza descentralizada del protocolo AndeChain.