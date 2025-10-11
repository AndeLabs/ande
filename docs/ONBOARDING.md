# AndeChain - Manual de Operaciones y Guía de Inicio

<div align="center">

**Tu fuente central de verdad para el desarrollo, despliegue y mantenimiento del ecosistema AndeChain.**

[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg)](https://www.docker.com/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![Node.js](https://img.shields.io/badge/Node.js-20+-green.svg)](https://nodejs.org/)

</div>

---

## 🎯 Introducción

Bienvenido a **AndeChain**, una sovereign EVM rollup en Celestia para Latinoamérica. Esta guía es el manual de operaciones definitivo para cualquier desarrollador que trabaje en el ecosistema.

### 💰 ANDE Token Duality - Característica Principal

AndeChain implementa un sistema económico único llamado **ANDE Token Duality** donde el token ANDE funciona simultáneamente como:

1. **Token Nativo de Gas**: Para pagar transacciones en la red (como ETH en Ethereum)
2. **Token ERC-20 Gobernanza**: Para staking, voting y DeFi (como UNI en Uniswap)

**Dirección del Precompile ANDE**: `0x00000000000000000000000000000000000000FD`

Esta dualidad permite:
- ✅ Soberanía económica completa
- ✅ Experiencia DeFi nativa
- ✅ Gobernanza on-chain
- ✅ Integración perfecta con ecosistemas existentes

Esta guía cubre todo, desde la configuración inicial hasta el despliegue, testing y solución de problemas, incluyendo cómo interactuar con este innovador sistema de doble token.

> **📢 Estado Actual**: AndeChain está 100% operativa con configuración estandarizada. El problema del single-sequencer ha sido resuelto actualizando los flags de configuración de `--rollkit.*` a `--evnode.*`.

---

## 📜 Índice

1.  [Guía de Inicio Rápido](#-guía-de-inicio-rápido)
    *   [Prerrequisitos](#-prerrequisitos)
    *   [Instalación Automática](#-instalación-automática-recomendado)
    *   [Setup Manual](#-setup-manual-avanzado)
    *   [Verificación y Acceso a Servicios](#-verificación-y-acceso-a-servicios)
2.  [Control de Versiones y Flujo de Trabajo](#-control-de-versiones-y-flujo-de-trabajo)
    *   [Estructura de Ramas](#-estructura-de-ramas)
    *   [Flujo de Trabajo Típico](#-flujo-de-trabajo-típico)
    *   [Estándar de Commits](#-estándar-de-commits)
3.  [Comandos y Herramientas](#-comandos-y-herramientas)
    *   [Comandos `make`](#-comandos-make)
    *   [Comandos `foundry`](#-comandos-foundry)
    *   [Comandos `docker`](#-comandos-docker)
4.  [Arquitectura y Componentes](#-arquitectura-y-componentes)
    *   [Oráculo P2P](#-oráculo-p2p)
5.  [Testing y Calidad](#-testing-y-calidad)
6.  [Solución de Problemas](#-solución-de-problemas)
7.  [Compatibilidad y Versiones](#-compatibilidad-y-versiones)
    *   [Versiones de Componentes Críticos](#-versiones-de-componentes-críticos)
    *   [Flags de Configuración](#-flags-de-configuración-referencia-rápida)
    *   [Actualizaciones y Mantenimiento](#-actualizaciones-y-mantenimiento)
    *   [Problemas Comunes de Compatibilidad](#-problemas-comunes-de-compatibilidad)

---

## 🚀 Guía de Inicio Rápido

Esta sección te guiará para tener un entorno de desarrollo local completo y funcional con **ANDE Token Duality**.

### ✅ Prerrequisitos

Asegúrate de tener instaladas las siguientes herramientas:

| Herramienta | Versión Mínima | Comando de Verificación |
| :--- | :--- | :--- |
| Docker | `24.0.0` | `docker --version` |
| Docker Compose | `2.0.0` | `docker compose version` |
| Foundry | (última) | `foundryup --version` |
| Git | `2.30` | `git --version` |
| Make | (cualquiera) | `make --version` |

Si te falta alguna, consulta la [guía de instalación de herramientas detallada](#-instalación-de-herramientas).

### 🔥 Instalación Automática COMPLETA (Recomendado)

**🎯 Único comando para todo el ecosistema AndeChain:**

**1. Clonar el Repositorio**
```bash
git clone https://github.com/AndeLabs/andechain.git
cd andechain
```

**2. Iniciar AndeChain Completa**
```bash
# 🔥 COMANDO COMPLETO AUTOMATIZADO - Todo en Uno
make full-start
```

**Este comando mágico hará todo por ti:**
1. ✅ **Verifica requisitos** (Docker, Foundry, etc.)
2. ✅ **Configura entorno** (.env variables)
3. ✅ **Construye ev-reth con ANDE Token Duality** (clone desde GitHub)
4. ✅ **Inicia infraestructura Docker** (ev-reth-sequencer, single-sequencer, local-da)
5. ✅ **Espera estabilización** (60 segundos)
6. ✅ **Verifica salud del sistema** (RPC + containers)
7. ✅ **Despliega contrato ANDE Token** automáticamente

### ✅ Verificación y Acceso a Servicios

Después de ejecutar `make full-start`, verifica que todo funcione correctamente:

```bash
make health
```

Deberías ver una salida similar a esta:
```
🏥 Verificando salud de AndeChain...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Estado de servicios:
NAME                STATUS          PORTS
ev-reth-sequencer   Up (healthy)    8545->8545, 9001->9001
local-da            Up              7980->7980
single-sequencer    Up              26660->26660

🔗 Conectividad RPC:
Chain ID: 0x4d2

📦 Último bloque:
Block: 0xXXX

💰 Saldo ANDE de precompile:
ANDE Balance: 0xXXXX wei
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Ahora puedes acceder a los servicios locales:

| Servicio | URL | Descripción |
| :--- | :--- | :--- |
| **🌐 RPC Endpoint** | `http://localhost:8545` | ANDE Chain RPC con ANDE Token Duality |
| **📍 ANDE Precompile** | `0x00000000000000000000000000000000000000FD` | Dirección del precompile ANDE nativo |
| **📊 Local DA** | `http://localhost:7980` | Mock de Celestia para disponibilidad de datos |
| **📈 Métricas** | `http://localhost:9001` | Métricas de ev-reth (requiere configuración) |

### 🔧 Configuración Estándar Docker

**Importante:** AndeChain usa configuración Docker estandarizada:

```bash
# Archivo único de configuración
infra/stacks/single-sequencer/docker-compose.yml

# Makefile actualizado para usar el nombre estándar
make start    # usa docker-compose.yml (no .ande.yml)
make health   # usa docker-compose.yml
make stop     # usa docker-compose.yml
```

**Nota histórica:** Antes existía `docker-compose.ande.yml` pero fue unificado a `docker-compose.yml` para evitar confusiones.

### 🔧 Setup Manual (Avanzado)

Para un control granular, sigue estos pasos:

**1. Iniciar Infraestructura Blockchain**
```bash
cd infra
docker compose up -d --build
# Espera ~30 segundos y verifica que el RPC responde:
curl -X POST -H "Content-Type: application/json" --data '''{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}''' http://localhost:8545
```

**2. Desplegar Contratos**
```bash
cd ../contracts
# Asegúrate de que la clave privada de desarrollo esté disponible como variable de entorno
export PRIVATE_KEY=$PRIVATE_KEY_DESARROLLO
forge script script/DeployEcosystem.s.sol:DeployEcosystem --rpc-url http://localhost:8545 --broadcast --legacy
```

**3. Iniciar el Relayer**
```bash
cd ../relayer
npm install
cp .env.example .env
# Edita .env con las direcciones de los contratos recién desplegados
npm start
```

---

## 🌿 Control de Versiones y Flujo de Trabajo

Seguimos una estrategia basada en Git Flow para mantener el repositorio organizado y el código de producción estable.

### 🌳 Estructura de Ramas

*   **`main`**: Rama de producción. 100% estable. Solo se fusiona desde `release/*` o `hotfix/*`.
*   **`develop`**: Rama principal de integración. Aquí es donde converge todo el desarrollo activo.
*   **`feature/*`**: Para nuevas funcionalidades. Nacen de `develop` y se fusionan de nuevo en `develop`.
    *   *Ejemplo*: `feature/nuevo-sistema-de-votacion`
*   **`bugfix/*`**: Para corregir bugs no críticos encontrados en `develop`.
    *   *Ejemplo*: `bugfix/error-calculo-recompensas`
*   **`hotfix/*`**: Para correcciones urgentes en `main` (producción). Nacen de `main` y se fusionan tanto a `main` como a `develop`.
    *   *Ejemplo*: `hotfix/vulnerabilidad-critica-en-contrato`
*   **`release/*`**: Para preparar un nuevo lanzamiento a producción. Nacen de `develop` y se fusionan a `main` y `develop`.
    *   *Ejemplo*: `release/v2.1.0`

### 🔄 Flujo de Trabajo Típico

**Desarrollo de una Nueva Funcionalidad:**

1.  **Sincronizar `develop`**:
    ```bash
    git checkout develop
    git pull origin develop
    ```
2.  **Crear tu rama `feature`**:
    ```bash
    git checkout -b feature/mi-nueva-funcionalidad
    ```
3.  **Trabajar y hacer commits**: Realiza commits pequeños y atómicos.
    ```bash
    git add .
    git commit -m "feat(modulo): agregar nueva capacidad"
    ```
4.  **Mantener la rama actualizada**: Haz rebase con `develop` periódicamente para evitar conflictos grandes al final.
    ```bash
    git fetch origin
    git rebase origin/develop
    ```
5.  **Publicar y crear Pull Request**:
    ```bash
    git push origin feature/mi-nueva-funcionalidad
    ```
    Luego, abre un Pull Request en GitHub de `feature/mi-nueva-funcionalidad` hacia `develop`.

### ✍️ Estándar de Commits

**Es obligatorio usar Conventional Commits.** Esto nos permite generar changelogs automáticamente y mantener un historial limpio.

**Formato**: `tipo(alcance): descripción corta en imperativo`

*   **`feat`**: Una nueva funcionalidad.
*   **`fix`**: Una corrección de bug.
*   **`docs`**: Cambios en la documentación.
*   **`style`**: Cambios de formato, sin afectar la lógica.
*   **`refactor`**: Refactorización de código.
*   **`test`**: Añadir o corregir tests.
*   **`chore`**: Tareas de mantenimiento (actualizar dependencias, etc.).

**Ejemplos**:
```
feat(oracle): añadir endpoint para consultar la mediana de precios
fix(governance): corregir error de redondeo en conteo de votos
docs(onboarding): actualizar la sección de prerrequisitos
```

---

## 🛠️ Comandos y Herramientas

La orquestación del proyecto se centraliza en `Makefiles` para simplificar las tareas comunes.

### 🔥 Comandos `make` Principales (desde la raíz de `andechain/`)

| Comando | Propósito | Cuándo Usar |
| :--- | :--- | :--- |
| **`make full-start`** | **🔥 COMANDO COMPLETO AUTOMATIZADO** - Todo en uno | **Primera vez o reinicio completo** |
| `make start` | Inicia infraestructura (requiere ev-reth construido) | Desarrollo diario |
| `make stop` | Detiene la infraestructura Docker | Finalizar sesión |
| `make health` | Verificación completa del sistema | Diagnóstico |
| `make info` | Información detallada del sistema | Debugging |
| `make reset` | **⚠️ Destructivo** - Reset completo con volúmenes | Problemas serios |
| `make deploy-ecosystem` | Muestra scripts de despliegue disponibles | Desarrollo de contratos |
| `make redeploy-token` | Fuerza redeploy de ANDE Token con nueva dirección | Testing |
| `make test` | Ejecuta tests de contratos | Desarrollo |
| `make coverage` | Genera reporte de cobertura de tests | Calidad |
| `make security` | Análisis de seguridad con Slither | Auditoría |
| `make build-ev-reth` | Construye ev-reth con ANDE Token Duality | Mantenimiento |
| `make clean` | Limpia artefactos de compilación | Mantenimiento |

### 🎯 Comandos Esenciales para el Día a Día

```bash
# Inicio rápido (después de primer full-start)
make start && make health

# Ciclo de desarrollo típico
make test          # Probar cambios
make stop          # Finalizar día
```

### 📋 Comandos de Verificación

```bash
# Salud completa del sistema
make health

# Información detallada
make info

# Verificación silenciosa (para scripts)
make health-quiet
```

### 🎯 Comandos Útiles de `foundry` (desde `contracts/`)

*   **Compilar**: `forge build`
*   **Testear**: `forge test -vvv` (con más verbosidad)
*   **Reporte de Gas**: `forge test --gas-report`
*   **Interactuar (Llamada)**: `cast call <ADDRESS> "functionName()" --rpc-url http://localhost:8545`
*   **Interactuar (Transacción)**: `cast send <ADDRESS> "functionName(arg)" --private-key $PRIVATE_KEY --rpc-url http://localhost:8545`
*   **Verificar balance**: `cast balance <ADDRESS> --rpc-url http://localhost:8545`
*   **Verificar bloque**: `cast block-number --rpc-url http://localhost:8545`

### 💰 ANDE Token Duality - Comandos Especiales

**Precompile ANDE Nativo:**
```bash
# Verificar balance del precompile ANDE
cast balance 0x00000000000000000000000000000000000000FD --rpc-url http://localhost:8545

# Enviar tokens ANDE nativos al precompile
cast send 0x00000000000000000000000000000000000000FD \
  --value 1000000000000000000 \
  --rpc-url http://localhost:8545 \
  --private-key $PRIVATE_KEY
```

**Contrato ANDE ERC-20:**
```bash
# Verificar nombre y símbolo (si está deployed)
cast call <ANDE_CONTRACT_ADDRESS> "name()" --rpc-url http://localhost:8545
cast call <ANDE_CONTRACT_ADDRESS> "symbol()" --rpc-url http://localhost:8545

# Verificar balance ERC-20
cast call <ANDE_CONTRACT_ADDRESS> "balanceOf(address)" <ADDRESS> --rpc-url http://localhost:8545
```

### Comandos Útiles de `docker` (desde `infra/`)

*   **Ver logs**: `docker compose logs -f <nombre-del-servicio>` (ej: `ev-reth-sequencer`)
*   **Reiniciar un servicio**: `docker compose restart <nombre-del-servicio>`
*   **Acceder a un contenedor**: `docker compose exec <nombre-del-servicio> bash`

---

## 🏛️ Arquitectura y Componentes

### Oráculo P2P

El sistema de oráculo P2P es un componente crucial que permite a las DApps de AndeChain acceder a precios del mundo real (ej: USD/BOB) de forma descentralizada.

*   **Arquitectura**:
    *   **Reporteros**: Actores que hacen stake de tokens ANDE para poder enviar datos de precios.
    *   **`P2POracle.sol`**: Contrato que recibe los precios de los reporteros, valida su stake y calcula una mediana ponderada para asegurar la calidad del dato.
    *   **`AndeOracleAggregator.sol`**: Contrato que expone los datos de precios de una manera estandarizada (compatible con la interfaz de Chainlink), facilitando la integración con otras DApps.

*   **Operación para Reporteros**:
    1.  **Registro**: Un reportero debe registrarse en `P2POracle.sol` y hacer stake de la cantidad mínima de ANDE requerida.
    2.  **Reporte**: Periódicamente (cada "epoch"), el reportero envía el precio observado.
    3.  **Automatización**: Existe un script en `relayer/scripts/oracle-reporter.mjs` que facilita estas operaciones.

    ```bash
    # Desde la carpeta relayer/
    # Registrarse como reportero
    node scripts/oracle-reporter.mjs register

    # Reportar el precio actual (lo obtiene de APIs externas)
    node scripts/oracle-reporter.mjs report
    ```

---

## 🧪 Testing y Calidad

La calidad y seguridad del código son primordiales.

*   **Tests Unitarios y de Integración**:
    ```bash
    # Ejecutar todos los tests
    make test

    # Ejecutar tests de un archivo específico
    forge test --match-path test/unit/ANDEToken.t.sol
    ```
*   **Cobertura de Código**:
    ```bash
    # Generar y ver el reporte de cobertura
    make coverage
    ```
*   **Análisis de Gas**:
    ```bash
    # Ver el consumo de gas de las funciones
    forge test --gas-report
    ```
*   **Análisis de Seguridad**:
    ```bash
    # Ejecutar Slither para detectar vulnerabilidades comunes
    make security
    ```

---

## 🐛 Solución de Problemas

### Error: Puerto ya en uso (`Port already in use`)
*   **Causa**: Otro proceso está usando un puerto que Docker necesita (ej: 8545, 4000).
*   **Solución**: Encuentra y detén el proceso (`lsof -i :<puerto>`) o reinicia tu máquina. Como último recurso, `make reset` puede ayudar.

### Error: Fondos insuficientes (`Insufficient funds`)
*   **Causa**: La cuenta que estás usando para desplegar o testear no tiene ETH de desarrollo.
*   **Solución**: Usa el faucet en `http://localhost:3000` para enviar fondos a tu dirección.

### Error: El Relayer no conecta (`Contract not found`)
*   **Causa**: Las direcciones de los contratos en el archivo `.env` del relayer son incorrectas o no están actualizadas.
*   **Solución**: Copia las direcciones del archivo `contracts/deployments/localhost.json` y pégalas en `relayer/.env`.

### El RPC no responde
*   **Causa**: El contenedor `ev-reth-sequencer` o `single-sequencer` puede haberse detenido o no iniciado correctamente.
*   **Solución**:
    ```bash
    # Revisa los logs
    cd infra
    docker compose -f stacks/single-sequencer/docker-compose.yml logs -f ev-reth-sequencer
    docker compose -f stacks/single-sequencer/docker-compose.yml logs -f single-sequencer

    # Reinicia el servicio
    docker compose -f stacks/single-sequencer/docker-compose.yml restart ev-reth-sequencer single-sequencer

    # Verificación manual del RPC
    curl -X POST -H "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
      http://localhost:8545
    ```

### ⚠️ Single-Sequencer reiniciándose continuamente
*   **Causa**: Flags de configuración obsoletos en `evm-single`.
*   **Explicación**: La versión actual de `evm-single` cambió los prefijos de flags de `--rollkit.*` a `--evnode.*`.
*   **Síntomas**: El contenedor `single-sequencer` muestra estado "Restarting" y logs muestran "context canceled".
*   **Solución**: La configuración ya está actualizada en el repositorio. Si persiste:
    ```bash
    # Reiniciar solo el sequencer
    cd infra
    docker compose -f stacks/single-sequencer/docker-compose.yml restart single-sequencer

    # Si continúa, hacer reset completo
    cd ..
    make reset
    make full-start
    ```
*   **Nota importante**: Este problema **no está relacionado con las modificaciones de ev-reth para ANDE Token Duality**. Es puramente un cambio de API del sequencer.

### 🔧 Errores de nonce en transacciones
*   **Causa**: Conflicto de nonce cuando hay transacciones pendientes en el mempool.
*   **Solución**:
    ```bash
    # Verificar nonce actual
    cast nonce 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://localhost:8545

    # Usar nonce específico en transacción
    cast send <ADDRESS> --value <AMOUNT> \
      --nonce <NONCE_NUMBER> \
      --rpc-url http://localhost:8545 \
      --private-key $PRIVATE_KEY
    ```

### 📝 Error: `unexpected argument '--nonce'` en forge script
*   **Causa**: Versión de Foundry que ya no soporta el argumento `--nonce`.
*   **Solución**: Usar comandos make que manejan esto automáticamente:
    ```bash
    # En lugar de forge script manual, usar:
    make deploy-ecosystem  # Muestra opciones disponibles

    # O deploy manual sin nonce:
    cd contracts
    forge script script/DeploySimple.s.sol --rpc-url http://localhost:8545 --broadcast --legacy --private-key $PRIVATE_KEY
    ```

---

## 🔧 Compatibilidad y Versiones

### 📦 Versiones de Componentes Críticos

AndeChain depende de varias versiones específicas de componentes. Es importante conocer las compatibilidades:

#### **ev-reth (Custom Build)**
- **Repositorio**: https://github.com/AndeLabs/ande-reth
- **Función**: EVM execution layer con ANDE Token Duality
- **Construcción**: Automática vía `make build-ev-reth` o `make full-start`
- **Compatibilidad**: Totalmente compatible con versiones actuales de ev-node

#### **ev-node / evm-single**
- **Imagen**: `ghcr.io/evstack/ev-node-evm-single:main`
- **Función**: Block production y sequencing
- **API Changes**: Los flags cambiaron de `--rollkit.*` a `--evnode.*`
- **Configuración**: Actualizada automáticamente en este repositorio

#### **Flags de Configuración (Referencia Rápida)**

| Componente | Flag Antiguo | Flag Nuevo | Uso |
|:---|:---|:---|:---|
| RPC Address | `--rollkit.rpc.address` | `--evnode.rpc.address` | Configurar RPC del sequencer |
| P2P Listen | `--rollkit.p2p.listen_address` | `--evnode.p2p.listen_address` | Configurar P2P |
| DA Address | `--rollkit.da.address` | `--evnode.da.address` | Conectar a DA layer |
| Aggregator | `--rollkit.node.aggregator` | `--evnode.node.aggregator` | Modo agregador |
| Block Time | `--rollkit.node.block_time` | `--evnode.node.block_time` | Tiempo entre bloques |

### 🔄 Actualizaciones y Mantenimiento

#### **Actualizar ev-reth**
```bash
# Reconstruir ev-reth con últimos cambios
make build-ev-reth

# Reiniciar solo el componente ev-reth
cd infra
docker compose -f stacks/single-sequencer/docker-compose.yml restart ev-reth-sequencer
```

#### **Verificar Compatibilidad**
```bash
# Verificar versión de ev-reth
make info

# Verificar salud general
make health
```

### ⚠️ Problemas Comunes de Compatibilidad

1. **"context canceled" en logs de sequencer**
   - Generalmente causado por flags incorrectos
   - Solución: Verificar que todos los flags usen el prefijo `--evnode.*`

2. **Contenedores que no inician**
   - Verificar que las imágenes sean compatibles
   - Revisar logs específicos del contenedor

3. **Transacciones que no se procesan**
   - Puede ser por incompatibilidad entre ev-reth y ev-node
   - Generalmente resuelto con reinicio completo: `make reset && make full-start`

---

## 🎉 Resumen del Estado Actual

AndeChain está **lista para producción** con:

### ✅ **Componentes Operativos**
- **ev-reth ANDE**: Custom build con ANDE Token Duality funcionando
- **Single-Sequencer**: Configurado y estable (flags `--evnode.*` actualizados)
- **Local DA**: Mock de Celestia para data availability
- **ANDE Token Duality**: Precompile en `0x00..FD` + contrato ERC-20

### ✅ **Configuración Estandarizada**
- **Docker**: Unificado a `docker-compose.yml` estándar
- **Makefile**: Actualizado con comandos `make full-start`
- **Documentación**: Completamente sincronizada

### ✅ **Herramientas Disponibles**
- **make full-start**: Inicio completo automatizado
- **make health**: Verificación de sistema
- **make deploy-ecosystem**: Despliegue de contratos
- **Transacciones**: Funcionando correctamente

### 🔧 **Próximos Pasos Recomendados**
1. **Desarrollo**: Usar `make start && make health` para desarrollo diario
2. **Testing**: Ejecutar `make test` para validar cambios
3. **Producción**: Considerar migrar `local-da` a Celestia mainnet

---
<div align="center">

**🚀 ¡AndeChain está lista para desarrollo y producción!**

*Estado: ✅ Sistema operacional | Configuración: ✅ Estandarizada | ANDE Token Duality: ✅ Funcional*

</div>
