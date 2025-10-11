# Bridge Escape Hatches - Security Documentation

## Overview

Los "escape hatches" (mecanismos de escape) del bridge AndeChain son características de seguridad críticas que permiten a los usuarios retirar sus fondos incluso si el relayer o el sequencer fallan. Estos mecanismos aseguran que los usuarios nunca queden atrapados con sus tokens en el bridge.

## 🛡️ Mecanismos de Escape Disponibles

### 1. `forceTransaction()` - Forzado por Tiempo

**Propósito**: Permite a los usuarios forzar el procesamiento de transacciones si el relayer no las procesa dentro del período de tiempo definido.

**Cuándo usar**: Cuando el relayer está funcionando mal o está offline por un período prolongado.

**Requisitos**:
- ✅ Prueba válida de Celestia Blobstream
- ✅ Período de fuerza transcurrido (default: configurable)
- ✅ Transacción no procesada previamente

**Flow**:
```solidity
// 1. Usuario espera el período de fuerza (ej. 24 horas)
// 2. Prepara prueba de inclusión en DA layer
// 3. Llama a forceTransaction()
function forceTransaction(
    BridgeTransaction calldata txData,
    bytes calldata proof
) external nonReentrant whenNotPaused
```

### 2. `emergencyWithdraw()` - Retiro de Emergencia

**Propósito**: Permite retiros inmediatos cuando el sistema está en modo de emergencia.

**Cuándo usar**: Durante crisis del sistema (sequencer caído, bugs críticos, etc.)

**Requisitos**:
- ✅ Modo de emergencia activado por el owner
- ✅ Prueba válida de Celestia Blobstream
- ✅ Usuario no ha reclamado esta transacción previamente

**Flow**:
```solidity
// 1. Owner activa modo de emergencia
// 2. Usuario prueba su transacción original
// 3. Retira fondos inmediatamente
function emergencyWithdraw(
    address token,
    address recipient,
    uint256 amount,
    bytes32 sourceTxHash,
    bytes calldata proof
) external nonReentrant
```

### 3. `toggleEmergencyMode()` - Control de Emergencia

**Propósito**: Permite al owner activar/desactivar el modo de emergencia.

**Cuándo usar**: Solo en situaciones extremas que justifiquen retiros inmediatos.

**Requisitos**:
- ✅ Rol de owner
- ✅ Justificación documentada

**Flow**:
```solidity
function toggleEmergencyMode(string calldata reason) external onlyOwner
```

## 🔧 Configuración de Parámetros

### Períodos de Tiempo

| Parámetro | Default | Rango Recomendado | Descripción |
|-----------|---------|-------------------|-------------|
| `forceInclusionPeriod` | 24 horas | 1-168 horas | Tiempo para forzar transacción |
| `emergencyGracePeriod` | 24 horas | 1-72 horas | Ventana de emergencia |

### Parámetros de Seguridad

| Parámetro | Default | Máximo | Descripción |
|-----------|---------|---------|-------------|
| `minConfirmations` | 3 | 10 | Confirmaciones requeridas |
| `forceInclusionPeriod` | 24h | 168h | Período máximo de fuerza |

## 📊 Escenarios de Uso

### Escenario 1: Relayer Offline

```
1. Usuario puentea 1000 USDC de Ethereum → AndeChain
2. Relayer está offline y no procesa la transacción
3. Después de 24 horas, usuario puede usar forceTransaction()
4. Usuario prueba que la transacción fue incluida en Celestia
5. Bridge mintea 1000 USDC en AndeChain
```

### Escenario 2: Bug Crítico del Sistema

```
1. Se descubre un bug crítico en el bridge
2. Owner activa modo de emergencia con toggleEmergencyMode()
3. Todos los usuarios pueden usar emergencyWithdraw() inmediatamente
4. Los usuarios prueban sus transacciones originales
5. Fondos recuperados sin esperar períodos de tiempo
```

### Escenario 3: Sequencer Caído

```
1. El sequencer de AndeChain está caído
2. Las transacciones no pueden ser procesadas normalmente
3. Owner activa modo de emergencia
4. Usuarios usan emergencyWithdraw() para recuperar fondos
5. Sistema protegido contra pérdida de fondos
```

## 🛡️ Protecciones Anti-Abuso

### 1. Replay Protection

- Cada transacción tiene un hash único
- Los usuarios solo pueden reclamar cada transacción una vez
- Mapeo `emergencyClaims[user][txHash]` previene dobles reclamos

### 2. Proof Verification

- Todas las reclamaciones requieren prueba válida de Celestia
- Verificación de inclusion en DA layer
- Mínimo de confirmaciones requeridas

### 3. Time-Based Controls

- Períodos de tiempo configurables
- Modo de emergencia solo puede ser activado por owner
- Eventos on-chain para todas las acciones de emergencia

### 4. Access Controls

- Solo owner puede activar modo de emergencia
- Solo owner puede configurar parámetros de tiempo
- Funciones pausables para detener operaciones si es necesario

## 📋 Monitoreo y Alertas

### Eventos Críticos

```solidity
event EmergencyModeToggled(bool enabled, address indexed triggeredBy, string reason);
event EmergencyWithdrawal(address indexed user, address indexed token, uint256 amount, bytes32 indexed sourceTxHash);
event TokensReceived(address indexed token, address indexed recipient, uint256 amount, uint256 sourceChain, bytes32 indexed sourceTxHash);
```

### Métricas a Monitorear

1. **Transacciones Pendientes**: Número de transacciones no procesadas
2. **Tiempo Promedio de Procesamiento**: Latencia del relayer
3. **Activaciones de Emergencia**: Frecuencia de uso de escape hatches
4. **Proof Failures**: Tasa de fallos de verificación

### Sistema de Alertas Recomendado

```yaml
alerts:
  - name: High Pending Transactions
    condition: pending_transactions > 100
    action: notify_admins

  - name: Emergency Mode Activated
    condition: emergency_mode == true
    action: critical_alert

  - name: Force Transaction Usage
    condition: force_transactions_hourly > 10
    action: investigate_relayer_health
```

## 🔍 Procedimientos de Testing

### Testing de Force Transaction

```javascript
// 1. Simular bridge operation
await bridge.bridgeTokens(token, user, amount, destinationChain);

// 2. Esperar período de fuerza (en test: vm.warp)
await vm.warp(block.timestamp + forcePeriod + 1);

// 3. Preparar datos de transacción
const txData = {
    token: tokenAddress,
    recipient: userAddress,
    amount: bridgeAmount,
    sourceChain: 1,
    sourceTxHash: txHash,
    blockTimestamp: blockTimestamp
};

// 4. Ejecutar force transaction
await bridge.forceTransaction(txData, proof);
```

### Testing de Emergency Mode

```javascript
// 1. Activar modo de emergencia
await bridge.connect(owner).toggleEmergencyMode("Test emergency");

// 2. Verificar estado
const isEmergency = await bridge.emergencyMode();
expect(isEmergency).to.be.true;

// 3. Probar emergency withdrawal
await bridge.connect(user).emergencyWithdraw(
    token,
    recipient,
    amount,
    sourceTxHash,
    proof
);
```

## 📚 Mejores Prácticas

### Para Desarrolladores

1. **Siempre probar escape hatches** en cada deploy
2. **Configurar períodos razonables** (no muy cortos, no muy largos)
3. **Monitorear eventos de emergencia** en producción
4. **Tener plan de respuesta** para activaciones de emergencia

### Para Operations

1. **Investigar causas** antes de activar emergencia
2. **Documentar todas** las activaciones de emergencia
3. **Comunicar claramente** a los usuarios durante emergencias
4. **Tener procedimientos** para degradación graceful

### Para Usuarios

1. **Guardar transaction hashes** de todas las operaciones de bridge
2. **Conocer los períodos de fuerza** para sus tokens
3. **Monitorear estado del bridge** antes de operaciones grandes
4. **Tener plan de respaldo** para recuperar fondos

## 🚨 Procedimientos de Respuesta

### Activación de Emergencia - Checklist

- [ ] Verificar que no hay alternativas disponibles
- [ ] Documentar causa raíz del problema
- [ ] Preparar comunicación para usuarios
- [ ] Activar modo de emergencia con justificación clara
- [ ] Monitorear retiros de emergencia
- [ ] Investigar actividad sospechosa
- [ ] Planificar desactivación cuando sea seguro

### Post-Emergencia

1. **Root cause analysis** del incidente
2. **Mejorar sistemas** para prevenir recurrencia
3. **Actualizar documentación** y procedimientos
4. **Comunicar mejoras** a la comunidad

## 🔗 Recursos Adicionales

- [Contrato del Bridge](../src/bridge/AndeChainBridge.sol)
- [Scripts de Testing](../script/TestBridgeEscapeHatches.s.sol)
- [Documentación Celestia DA](https://docs.celestia.org/)
- [Estándar xERC20](https://github.com/erc-x/ERC-X)

---

**⚠️ Importante**: Los escape hatches son medidas de seguridad de última instancia. Su uso indica problemas sistémicos que deben ser investigados y resueltos rápidamente.