# AndeChain - Manual de Operaciones y Guía de Inicio

<div align="center">

**Tu fuente central de verdad para el desarrollo, despliegue y mantenimiento del ecosistema AndeChain.**

[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg)](https://www.docker.com/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![Node.js](https://img.shields.io/badge/Node.js-20+-green.svg)](https://nodejs.org/)

</div>

---

## 🎯 Introducción

Bienvenido a AndeChain. Esta guía es el manual de operaciones definitivo para cualquier desarrollador que trabaje en el ecosistema. Cubre todo, desde la configuración inicial y el flujo de trabajo de desarrollo hasta los estándares de codificación, la arquitectura de componentes clave y la solución de problemas comunes.

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

---

## 🚀 Guía de Inicio Rápido

Esta sección te guiará para tener un entorno de desarrollo local completo y funcional.

### ✅ Prerrequisitos

Asegúrate de tener instaladas las siguientes herramientas:

| Herramienta | Versión Mínima | Comando de Verificación |
| :--- | :--- | :--- |
| Docker | `24.0.0` | `docker --version` |
| Node.js | `20.0.0` | `node --version` |
| Foundry | (última) | `foundryup --version` |
| Git | `2.30` | `git --version` |
| Make | (cualquiera) | `make --version` |

Si te falta alguna, consulta la [guía de instalación de herramientas detallada](#-instalación-de-herramientas).

### ⚡ Instalación Automática (Recomendado)

El siguiente método utiliza `make` para orquestar todo el proceso de forma automática.

**1. Clonar el Repositorio**
```bash
git clone https://github.com/AndeLabs/andechain.git
cd andechain
```

**2. Configurar Variables de Entorno**
```bash
# Copia el archivo de ejemplo. No se requieren cambios para el setup básico.
cp infra/.env.example infra/.env
```

**3. Iniciar el Ecosistema Completo**
```bash
# Este comando mágico hará todo por ti:
# 1. Construirá y ejecutará la infraestructura Docker (EVM, Sequencer, DA, Blockscout).
# 2. Compilará y desplegará todos los contratos inteligentes.
# 3. Iniciará el servicio del relayer.
make start
```

### ✅ Verificación y Acceso a Servicios

Después de ejecutar `make start`, verifica que todo funcione correctamente:

```bash
make status
```

Deberías ver una salida similar a esta, confirmando que todos los servicios están activos:
```
✅ Docker services: running
✅ Contracts: deployed
✅ Relayer: running
✅ RPC: http://localhost:8545
✅ Explorer: http://localhost:4000
```

Ahora puedes acceder a los servicios locales:

| Servicio | URL | Descripción |
| :--- | :--- | :--- |
| **🌐 RPC Endpoint** | `http://localhost:8545` | Ethereum JSON-RPC para interactuar con la red. |
| **🔍 Block Explorer** | `http://localhost:4000` | Interfaz de Blockscout para explorar bloques y transacciones. |
| **💧 Faucet** | `http://localhost:3000` | Faucet para obtener ETH de desarrollo. |
| **📊 Local DA** | `http://localhost:7980` | Mock de Celestia para la disponibilidad de datos. |

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

### Principales Comandos `make` (desde la raíz de `andechain/`)

| Comando | Propósito |
| :--- | :--- |
| `make start` | **El más importante.** Inicia todo el entorno de desarrollo local. |
| `make stop` | Detiene la infraestructura Docker. |
| `make reset` | **Destructivo.** Detiene y elimina los volúmenes de Docker para un reinicio limpio. |
| `make status` | Muestra el estado actual de todos los servicios. |
| `make test` | Ejecuta la suite completa de tests para los contratos. |
| `make coverage` | Genera un reporte de cobertura de los tests. |
| `make security` | Ejecuta un análisis de seguridad estático con Slither. |
| `make deploy-ecosystem` | Despliega los contratos en la red local (usado por `make start`). |
| `make clean` | Limpia los artefactos de compilación de Foundry. |

### Comandos Útiles de `foundry` (desde `contracts/`)

*   **Compilar**: `forge build`
*   **Testear**: `forge test -vvv` (con más verbosidad)
*   **Reporte de Gas**: `forge test --gas-report`
*   **Interactuar (Llamada)**: `cast call <ADDRESS> "functionName()" --rpc-url local`
*   **Interactuar (Transacción)**: `cast send <ADDRESS> "functionName(arg)" --private-key $PRIVATE_KEY --rpc-url local`

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
    docker compose logs -f ev-reth-sequencer

    # Reinicia el servicio
    docker compose restart ev-reth-sequencer single-sequencer
    ```

---
<div align="center">

**🚀 ¡Feliz desarrollo en AndeChain!**

</div>
