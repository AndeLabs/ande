# 🗺️ Roadmap de Desarrollo - AndeChain

> **Versión:** 1.0
> **Fecha:** 2025-10-04
> **Estado del Proyecto:** Desarrollo Activo

---

## 📊 Estado Actual

### Métricas Clave
```
✅ Tests Passing:        102/102 (100%)
📊 Cobertura Global:     54.42% lines, 35.27% branches
🎯 Target Producción:    >80% lines, >70% branches
⏱️  Suite Execution:     ~150ms (excelente)
```

### Contratos por Estado

#### 🟢 Producción-Ready (>80% coverage)
- **AbobToken** - 98.51% lines, 85.71% branches
- **P2POracleV2** - 85.90% lines, 71.43% branches
- **MintController** - 87.57% lines, 55.32% branches (branches necesitan mejora)
- **AndeBridge** - 100% lines, 100% branches
- **EthereumBridge** - 100% lines, 62.50% branches
- **DualTrackBurnEngine** - 95.83% lines, 50% branches

#### 🟡 Requiere Mejoras (40-80% coverage)
- **VeANDE** - 61.79% lines, 37.93% branches
- **AusdToken** - 87.30% lines, 7.69% branches ⚠️
- **ANDEToken** - 70.83% lines

#### 🔴 Sin Coverage (0%)
- **StabilityEngine** ❌
- **TrustedRelayerOracle** ❌
- **AndeOracleAggregator** ❌
- **sAbobToken** ❌

---

## 🎯 Objetivos por Timeline

### Sprint 1 (Semana 1-2) - CRÍTICO
**Objetivo:** Implementar tests para contratos con 0% coverage

#### StabilityEngine.sol
**Esfuerzo:** 3-4 días
**Tests a Implementar:** 20-25

**Prioridad Alta:**
- [ ] Deployment y inicialización (3 tests)
- [ ] Collateral rebalancing logic (5 tests)
- [ ] Price deviation detection (4 tests)
- [ ] Emergency stability mechanisms (4 tests)
- [ ] Collateral ratio adjustments (4 tests)

**Prioridad Media:**
- [ ] Multiple collateral scenarios (3 tests)
- [ ] Edge cases de límites (3 tests)
- [ ] Access control (2 tests)

**Tests Críticos Sugeridos:**
```solidity
test_Rebalance_WhenPriceDips()
test_Rebalance_WhenPriceSpikes()
test_Fail_Rebalance_InsufficientCollateral()
test_EmergencyStabilization_ActivatesCorrectly()
test_CollateralRatio_UpdatesWithPriceChanges()
```

**Criterio de Éxito:** >70% branches

---

#### TrustedRelayerOracle.sol
**Esfuerzo:** 4-5 días
**Tests a Implementar:** 25-30

**Prioridad Alta:**
- [ ] Deployment y configuración (3 tests)
- [ ] Data submission by trusted relayers (5 tests)
- [ ] Data verification mechanisms (6 tests)
- [ ] Fallback scenarios (4 tests)
- [ ] Relayer management (add/remove) (4 tests)

**Prioridad Media:**
- [ ] Multiple data sources aggregation (4 tests)
- [ ] Stale data detection (3 tests)
- [ ] Access control exhaustivo (3 tests)

**Tests Críticos Sugeridos:**
```solidity
test_SubmitData_ValidRelayer()
test_Fail_SubmitData_UntrustedRelayer()
test_Aggregation_MultipleRelayers()
test_Fallback_WhenNoDataAvailable()
test_StaleData_Rejected()
test_AddRelayer_OnlyGovernance()
test_RemoveRelayer_OnlyGovernance()
```

**Criterio de Éxito:** >75% branches

---

### Sprint 2 (Semana 3-4) - IMPORTANTE
**Objetivo:** Completar cobertura de contratos restantes y mejorar branches

#### AusdToken.sol - Mejorar Branches
**Esfuerzo:** 2-3 días
**Tests a Agregar:** 15-20

**Problema Actual:** Solo 7.69% branches cubiertos (1/13)

**Tests Necesarios:**
- [ ] Rebalancing con múltiples colaterales (6 tests)
- [ ] Cambios de collateral ratio (4 tests)
- [ ] Deposit con diferentes collateral types (3 tests)
- [ ] Withdraw scenarios complejos (3 tests)
- [ ] Emergency pause/unpause flows (3 tests)

**Criterio de Éxito:** >70% branches (de 7.69%)

---

#### AndeOracleAggregator.sol
**Esfuerzo:** 2-3 días
**Tests a Implementar:** 15-20

**Prioridad Alta:**
- [ ] Price aggregation logic (5 tests)
- [ ] Multiple oracle sources (4 tests)
- [ ] Outlier detection (3 tests)
- [ ] Weighted averages (3 tests)

**Prioridad Media:**
- [ ] Oracle source management (3 tests)
- [ ] Fallback mechanisms (2 tests)
- [ ] Edge cases de precios (2 tests)

**Criterio de Éxito:** >70% branches

---

#### sAbobToken.sol
**Esfuerzo:** 1-2 días
**Tests a Implementar:** 8-10

**Tests Necesarios:**
- [ ] Deployment y setup (2 tests)
- [ ] Staking ABOB (2 tests)
- [ ] Unstaking ABOB (2 tests)
- [ ] Rewards distribution (2 tests)
- [ ] Access control (2 tests)

**Criterio de Éxito:** >80% branches (es un contrato pequeño)

---

### Sprint 3 (Semana 5-6) - OPTIMIZACIÓN
**Objetivo:** Mejorar branches de contratos buenos y agregar tests avanzados

#### VeANDE.sol - Mejorar Coverage
**Esfuerzo:** 2-3 días
**Tests a Agregar:** 10-15

**Objetivo:** 37.93% branches → >70%

**Tests Faltantes:**
- [ ] Lock extension scenarios (3 tests)
- [ ] Early withdrawal attempts (3 tests)
- [ ] Delegation edge cases (3 tests)
- [ ] Voting power calculation en diferentes periodos (3 tests)
- [ ] Multiple locks per user (2 tests)

---

#### MintController.sol - Alcanzar 70% Branches
**Esfuerzo:** 2-3 días
**Tests a Agregar:** 10-15

**Objetivo:** 55.32% branches → >70%

**Tests Faltantes:**
- [ ] Proposal state edge cases (4 tests)
- [ ] Timelock boundary conditions (3 tests)
- [ ] Voting power edge cases (3 tests)
- [ ] Complex proposal lifecycle scenarios (3 tests)

---

#### DualTrackBurnEngine.sol - Mejorar Branches
**Esfuerzo:** 1 día
**Tests a Agregar:** 5-8

**Objetivo:** 50% branches → >70%

**Tests Faltantes:**
- [ ] Scheduled burn tracking (3 tests)
- [ ] Impulsive burn limits (2 tests)
- [ ] Burn history tracking (2 tests)

---

### Sprint 4 (Semana 7-8) - AVANZADO
**Objetivo:** Implementar tests avanzados e invariants

#### Invariant Tests
**Esfuerzo:** 3-4 días

**MintController Invariants:**
```solidity
invariant_totalMinted_never_exceeds_hardCap()
invariant_mintedThisYear_never_exceeds_annualLimit()
invariant_proposalCount_always_increases()
invariant_executed_proposals_have_correct_state()
```

**VeANDE Invariants:**
```solidity
invariant_totalLocked_equals_sum_of_locks()
invariant_voting_power_never_exceeds_locked_amount()
invariant_unlock_time_always_in_future()
```

**AbobToken Invariants:**
```solidity
invariant_collateral_value_backs_supply()
invariant_collateral_ratio_within_bounds()
```

**Esfuerzo Total:** ~20 invariant tests

---

#### Integration Tests
**Esfuerzo:** 4-5 días

**Flujos End-to-End:**
- [ ] Bridge completo: Ethereum → AndeChain → Ethereum (3 tests)
- [ ] Governance: Propuesta → Votación → Ejecución → Mint (4 tests)
- [ ] Stablecoin: Mint ABOB → Trade → Redeem (3 tests)
- [ ] Oracle: Price update → Trigger rebalance → Stabilize (3 tests)
- [ ] Emergency: Oracle fails → Fallback → Recovery (3 tests)

**Esfuerzo Total:** ~16 integration tests

---

### Sprint 5 (Semana 9-10) - OPTIMIZACIÓN Y AUDITORÍA
**Objetivo:** Gas optimization, security audit prep

#### Gas Optimization
**Esfuerzo:** 2-3 días

- [ ] Generate gas report for all contracts
- [ ] Create gas snapshots with `forge snapshot`
- [ ] Identify expensive operations
- [ ] Optimize storage layouts
- [ ] Optimize loops and iterations
- [ ] Document gas costs for critical functions

**Deliverables:**
- Gas report completo
- Benchmarks de funciones críticas
- Optimizaciones implementadas (si factible)

---

#### Security Audit Preparation
**Esfuerzo:** 3-4 días

**Checklist Pre-Auditoría:**
- [ ] Ejecutar Slither y documentar findings
- [ ] Ejecutar Mythril (symbolic execution)
- [ ] Ejecutar Echidna (fuzzing avanzado)
- [ ] Review manual de código crítico
- [ ] Documentar todos los hallazgos
- [ ] Corregir issues de severidad media/alta
- [ ] Preparar documentation pack para auditores

**Herramientas a Usar:**
```bash
slither . --print human-summary
slither . --detect reentrancy-eth
mythril analyze contracts/src/MintController.sol
echidna-test . --contract MintController --config echidna.yaml
```

---

## 📊 Milestones y Métricas

### Milestone 1: Tests Básicos Completos
**Timeline:** Semana 4
**Criterios:**
- ✅ Todos los contratos con >0% coverage
- ✅ Contratos críticos con >60% branches
- ✅ >150 tests totales
- ✅ Suite ejecuta en <300ms

### Milestone 2: Coverage Objetivo Alcanzado
**Timeline:** Semana 6
**Criterios:**
- ✅ Cobertura global >70% branches
- ✅ Todos los contratos críticos >75% branches
- ✅ >200 tests totales
- ✅ 0 tests flaky

### Milestone 3: Tests Avanzados
**Timeline:** Semana 8
**Criterios:**
- ✅ >15 invariant tests
- ✅ >15 integration tests
- ✅ Fuzzing en todos los contratos críticos
- ✅ Gas benchmarks documentados

### Milestone 4: Audit-Ready
**Timeline:** Semana 10
**Criterios:**
- ✅ Cobertura global >80% branches
- ✅ Slither findings resueltos
- ✅ Security documentation completa
- ✅ Test suite robusta (>250 tests)

---

## 🔄 Proceso de Desarrollo

### Workflow para Nuevos Tests

1. **Planificación:**
   ```bash
   # Identificar contrato objetivo
   forge coverage --match-contract TargetContract

   # Analizar branches no cubiertos
   forge coverage --report lcov
   # Abrir en editor de coverage para identificar gaps
   ```

2. **Implementación:**
   ```solidity
   // 1. Deployment tests
   // 2. Happy path tests
   // 3. Edge cases tests
   // 4. Failure tests (reverts)
   // 5. Access control tests
   // 6. Fuzzing tests
   ```

3. **Validación:**
   ```bash
   # Ejecutar tests
   forge test --match-contract TargetContractTest

   # Verificar coverage
   forge coverage --match-contract TargetContract

   # Gas report
   forge test --gas-report --match-contract TargetContract
   ```

4. **Review:**
   - Code review por par
   - Verificar que tests son mantenibles
   - Documentar casos especiales
   - Commit con mensaje descriptivo

---

## 📋 Checklist de Calidad por Contrato

Para cada contrato, verificar:

### Tests Básicos
- [ ] Deployment test (roles, parámetros iniciales)
- [ ] Happy path para cada función pública
- [ ] Revert tests para todas las validaciones
- [ ] Access control para funciones protegidas
- [ ] Event emission tests
- [ ] State transition tests

### Tests Avanzados
- [ ] Edge cases (boundary values)
- [ ] Fuzzing tests (al menos 1 por función crítica)
- [ ] Integration con otros contratos
- [ ] Reentrancy tests (si aplica)
- [ ] Gas optimization tests

### Documentación
- [ ] Nombres descriptivos de tests
- [ ] Comentarios explicando estrategia
- [ ] README con instrucciones de ejecución
- [ ] Casos especiales documentados

---

## 🚨 Risk Mitigation

### Riesgos Identificados

**1. Contratos con 0% Coverage**
- **Riesgo:** Vulnerabilidades no detectadas
- **Mitigación:** Sprint 1 enfocado 100% en estos contratos
- **Owner:** Tech Lead
- **Deadline:** Semana 2

**2. AusdToken Branches Muy Bajas (7.69%)**
- **Riesgo:** Lógica de rebalancing no testeada
- **Mitigación:** Sprint 2 prioriza este contrato
- **Owner:** Smart Contract Dev
- **Deadline:** Semana 4

**3. Falta de Integration Tests**
- **Riesgo:** Bugs en interacciones entre contratos
- **Mitigación:** Sprint 4 dedicado a integration tests
- **Owner:** QA Lead
- **Deadline:** Semana 8

**4. Sin Auditoría Externa**
- **Riesgo:** Vulnerabilidades complejas no detectadas
- **Mitigación:** Preparar para auditoría en Sprint 5
- **Owner:** Security Specialist
- **Deadline:** Semana 10

---

## 📊 KPIs y Tracking

### Métricas Semanales
```
Semana 1:  Target: 4 contratos nuevos con tests
Semana 2:  Target: AusdToken >50% branches
Semana 3:  Target: Cobertura global >60%
Semana 4:  Target: Todos contratos >50% branches
Semana 5:  Target: Contratos críticos >70% branches
Semana 6:  Target: Cobertura global >70%
Semana 7:  Target: 15 invariant tests
Semana 8:  Target: 15 integration tests
Semana 9:  Target: Gas optimization completo
Semana 10: Target: Audit-ready checklist 100%
```

### Dashboard de Progreso
Actualizar semanalmente:
```markdown
## Week X Progress
- Tests Added: XX
- Coverage Change: XX% → XX%
- Blockers: [list]
- Next Week Focus: [description]
```

---

## 🎓 Recursos y Referencias

### Tutoriales
- [Foundry Testing Best Practices](https://book.getfoundry.sh/forge/tests)
- [Invariant Testing Guide](https://book.getfoundry.sh/forge/invariant-testing)
- [Fuzzing in Foundry](https://book.getfoundry.sh/forge/fuzz-testing)

### Herramientas
- **Forge:** Testing framework
- **Slither:** Static analysis
- **Mythril:** Symbolic execution
- **Echidna:** Advanced fuzzing
- **Manticore:** Symbolic execution avanzado

### Estándares
- [OpenZeppelin Security](https://docs.openzeppelin.com/contracts/4.x/api/security)
- [Trail of Bits Best Practices](https://github.com/crytic/building-secure-contracts)
- [ConsenSys Smart Contract Best Practices](https://consensys.github.io/smart-contract-best-practices/)

---

## 🤝 Team y Responsabilidades

### Roles Sugeridos

**Tech Lead**
- Oversee testing strategy
- Review critical tests
- Approve security fixes

**Smart Contract Developers (2-3)**
- Implement tests según roadmap
- Fix bugs encontrados
- Document edge cases

**QA Engineer**
- Design integration tests
- Execute full test suite
- Report issues

**Security Specialist**
- Run security tools
- Analyze findings
- Recommend fixes

---

## 📞 Support y Comunicación

### Daily Standups
- Progreso del día anterior
- Plan del día actual
- Blockers identificados

### Weekly Reviews
- Coverage report
- Blockers resolution
- Next week planning

### Bi-Weekly Retrospective
- What went well
- What can improve
- Action items

---

## ✅ Definition of Done

Un contrato se considera "Done" cuando:

- [ ] Coverage >75% lines
- [ ] Coverage >70% branches
- [ ] Todos los happy paths testeados
- [ ] Todos los failure paths testeados
- [ ] Al menos 1 fuzz test
- [ ] Access control testeado
- [ ] Events testeados
- [ ] Gas report generado
- [ ] Documentation actualizada
- [ ] Code reviewed
- [ ] Slither no reporta issues nuevos

---

**Última actualización:** 2025-10-04
**Versión:** 1.0
**Próxima revisión:** Cada viernes
