# P2P Oracle Setup Guide

## Overview

El sistema de oráculo P2P de AndeChain permite a los reporteros staking tokens ANDE para enviar precios de USD/BOB de forma descentralizada. Este documento explica cómo configurar y operar el sistema.

## Arquitectura

```
Reporter(s) → P2POracle.sol → AndeOracleAggregator.sol → DApps
```

1. **P2POracle.sol**: Recibe precios de reporteros con stake, calcula mediana ponderada
2. **AndeOracleAggregator.sol**: Interfaz compatible con Chainlink para DApps

## Flujo de Operación

### 1. Registro de Reporteros

Los reporteros deben:
- Tener tokens ANDE para el stake mínimo
- Registrarse en P2POracle.sol
- Enviar precios periódicamente cada epoch

### 2. Reporte de Precios

- Cada epoch (1 hora configurable), los reporteros envían precios
- El sistema calcula la mediana ponderada por stake
- Un finalizador autorizado cierra el epoch

### 3. Consumo de Datos

Las DApps consultan AndeOracleAggregator.sol para obtener el precio final

## Setup para Desarrollo

### 1. Iniciar Stack Local

```bash
cd andechain
make start
```

### 2. Desplegar Contratos

```bash
cd contracts
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/DeployAndTestP2POracle.s.sol --tc DeployAndTestP2POracle --rpc-url local --broadcast --legacy
```

### 3. Configurar Variables de Entorno

```bash
# En el relayer/
cp .env.example .env

# Configurar:
P2P_ORACLE_ADDRESS=0x... # dirección del P2POracle desplegado
RELAYER_PRIVATE_KEY=0x... # clave privada del reporter
RPC_URL=http://localhost:8545
```

## Operación de Reporteros

### Herramientas Disponibles

#### 1. Script Oracle Reporter

```bash
cd relayer
node scripts/oracle-reporter.mjs <comando>
```

**Comandos disponibles:**

```bash
# Ver ayuda
node scripts/oracle-reporter.mjs help

# Registrarse como reporter (requiere stake mínimo)
node scripts/oracle-reporter.mjs register

# Ver estado del reporter
node scripts/oracle-reporter.mjs status

# Reportar precio (obtenido de APIs automáticamente)
node scripts/oracle-reporter.mjs report

# Reportar precio manual
node scripts/oracle-reporter.mjs report 6.91

# Aumentar stake
node scripts/oracle-reporter.mjs stake 1000

# Disminuir stake
node scripts/oracle-reporter.mjs unstake 100
```

#### 2. Script Legacy (automático)

```bash
node scripts/report-price.mjs
```

Obtiene automáticamente precios de DolarAPI y CriptoYa, calcula mediana y envía.

### Proceso de Reporter

#### Paso 1: Registro

```bash
node scripts/oracle-reporter.mjs register
```

- Staking mínimo requerido (configurable, default: 100 ANDE)
- Necesitas aprobar tokens ANDE primero

#### Paso 2: Reporte Periódico

```bash
# Opción A: Automático (recomendado)
node scripts/oracle-reporter.mjs report

# Opción B: Manual
node scripts/oracle-reporter.mjs report 6.91
```

Los reportes deben enviarse:
- Cada epoch (configurable, default: 1 hora)
- Solo una vez por epoch por reporter

#### Paso 3: Monitoreo

```bash
# Ver tu estado
node scripts/oracle-reporter.mjs status
```

## Configuración para Producción

### 1. Stake Mínimo

El administrador del oráculo configura:

```solidity
// En initialize()
minStake = 1000 * 1e18; // 1000 ANDE
reportEpochDuration = 3600; // 1 hora
```

### 2. Roles y Permisos

- **DEFAULT_ADMIN_ROLE**: Configuración general
- **FINALIZER_ROLE**: Finalizar epochs
- **SLASHER_ROLE**: Penalizar reporteros

### 3. Automatización

Para producción, configurar:

```bash
# Crontab para reporte automático cada hora
0 * * * * cd /path/to/relayer && node scripts/oracle-reporter.mjs report
```

## Integración con DApps

### Ejemplo en Solidity

```solidity
import {AndeOracleAggregator} from "./AndeOracleAggregator.sol";

contract MyDApp {
    AndeOracleAggregator public oracle;

    constructor(address _oracle) {
        oracle = AndeOracleAggregator(_oracle);
    }

    function getBOBUSDPrice() external view returns (uint256) {
        (, int256 price,,, ) = oracle.latestRoundData();
        return uint256(price);
    }
}
```

### Ejemplo en JavaScript (Frontend)

```javascript
import { ethers } from 'ethers';

const ORACLE_ADDRESS = '0x...'; // dirección del AndeOracleAggregator
const ORACLE_ABI = [
    'function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80)',
    'function decimals() external view returns (uint8)'
];

async function getPrice() {
    const provider = new ethers.JsonRpcProvider('http://localhost:8545');
    const oracle = new ethers.Contract(ORACLE_ADDRESS, ORACLE_ABI, provider);

    const [, price, , ,] = await oracle.latestRoundData();
    const decimals = await oracle.decimals();

    // Convertir de precio de 1 BOB en USD a USD/BOB
    const bobUsdPrice = (1e18 * 1e18) / price;

    return bobUsdPrice / 10**decimals;
}
```

## Seguridad

### Para Reporteros

1. **Proteger claves privadas**: Nunca exponer private keys
2. **Validar precios**: Usar múltiples fuentes
3. **Monitorear stakes**: Ajustar según necesidad
4. **Regularidad**: Reportar consistentemente cada epoch

### Para Administradores

1. **Configurar slasher**: Tener mecanismo para penalizar mal comportamiento
2. **Monitorear participación**: Asegurar suficientes reporteros activos
3. **Validar datos**: Verificar que los precios sean razonables
4. **Gobernanza**: Establecer reglas claras para el sistema

## Troubleshooting

### Problemas Comunes

#### 1. "Already reported this epoch"
- Solo puedes reportar una vez por epoch
- Espera al siguiente epoch para reportar nuevamente

#### 2. "Not enough reports to finalize"
- Se necesita un mínimo de reporteros para finalizar
- Incentivar a más reporteros a participar

#### 3. "Not a registered reporter"
- Debes registrarte primero con `register()`
- Asegurar tener suficiente stake de ANDE

#### 4. "Cannot withdraw below minimum stake"
- Debes mantener siempre el stake mínimo
- Usa `unregister()` para retirar todo

### Logs y Monitoreo

```bash
# Ver logs del contrato
cast logs --address <P2POracle_ADDRESS> --from-block <block> --rpc-url local

# Ver eventos de reportes
cast logs --address <P2POracle_ADDRESS> --event "PriceReported(uint256,address,uint256)" --rpc-url local
```

## Recursos

- [Documentación de Contratos](../contracts/src/)
- [APIs de Precios](#)
- [Herramientas de Desarrollo](../scripts/)

## Soporte

Para problemas técnicos:
1. Revisar logs del contrato
2. Verificar configuración de red
3. Contactar al equipo de Ande Labs