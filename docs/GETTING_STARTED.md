# 🚀 Guía de Inicio - AndeChain Development

<div align="center">

**Setup Completo para Desarrollo Local**

[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg)](https://www.docker.com/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![Node.js](https://img.shields.io/badge/Node.js-20+-green.svg)](https://nodejs.org/)

[📋 Prerequisites](#prerrequisitos) • [⚡ Quick Start](#inicio-rápido) • [🔧 Manual Setup](#setup-manual) • [🧪 Testing](#testing) • [🐛 Troubleshooting](#troubleshooting)

</div>

---

## 📋 Prerrequisitos

Antes de comenzar, asegúrate de tener instaladas las siguientes herramientas:

### 🔧 Herramientas Requeridas

```bash
# Verificar instalaciones
docker --version          # >= 24.0.0
node --version           # >= 20.0.0
foundryup --version      # Latest
make --version           # Any version
git --version            # >= 2.30
```

### 📦 Instalación de Herramientas

#### Docker & Docker Compose
```bash
# macOS (usando Homebrew)
brew install --cask docker

# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Verificar instalación
docker --version
docker compose version
```

#### Node.js y npm
```bash
# Usando nvm (recomendado)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20

# Verificar instalación
node --version
npm --version
```

#### Foundry
```bash
# Instalar Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verificar instalación
forge --version
cast --version
anvil --version
```

#### Git
```bash
# macOS
brew install git

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install git

# Verificar instalación
git --version
```

## ⚡ Inicio Rápido (Automático)

### 1. Clonar el Repositorio

```bash
# Clonar el repositorio principal
git clone https://github.com/AndeLabs/andechain.git
cd andechain

# O clonar tu fork
git clone https://github.com/TU_USERNAME/andechain.git
cd andechain
```

### 2. Configurar Variables de Entorno

```bash
# Copiar archivo de entorno de ejemplo
cp .env.example .env

# Editar variables necesarias (opcional para desarrollo)
nano .env
```

### 3. Iniciar Ecosistema Completo

```bash
# Este comando iniciará:
# - Infraestructura Docker (Reth + ev-node + Blockscout)
# - Compilación y despliegue de contratos
# - Inicio del relayer
# - Servidor faucet

make start
```

### 4. Verificar Instalación

```bash
# Verificar estado de todos los servicios
make status

# Deberías ver algo como:
# ✅ Docker services: running
# ✅ Contracts: deployed
# ✅ Relayer: running
# ✅ RPC: http://localhost:8545
# ✅ Explorer: http://localhost:4000
```

### 5. Acceder a los Servicios

Una vez completado el setup, puedes acceder a:

| Servicio | URL | Descripción |
|----------|-----|-------------|
| **🌐 RPC Endpoint** | http://localhost:8545 | Ethereum JSON-RPC |
| **🔍 Block Explorer** | http://localhost:4000 | Blockscout UI |
| **💧 Faucet** | http://localhost:3000 | ETH faucet |
| **📊 Local DA** | http://localhost:7980 | Mock Celestia |

## 🔧 Setup Manual (Modo Avanzado)

Si prefieres un control más granular del proceso de instalación:

### Paso 1: Iniciar Infraestructura Blockchain

```bash
cd infra

# Iniciar stack Docker
docker compose up -d --build

# Esperar a que los servicios estén listos (~30 segundos)
docker compose logs -f single-sequencer

# Verificar que el rollup está operativo
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545
```

**Componentes iniciados:**
- **ev-reth-sequencer**: Capa de ejecución EVM
- **single-sequencer**: Productor de bloques
- **local-da**: Mock de Celestia DA
- **blockscout**: Explorador de bloques
- **faucet**: Faucet de desarrollo

### Paso 2: Compilar y Desplegar Contratos

```bash
cd ../contracts

# Compilar contratos
forge build

# Configurar cuenta de desarrollo (usar variables de entorno)
export PRIVATE_KEY=$PRIVATE_KEY_DESARROLLO

# Desplegar ecosistema completo
forge script script/DeployEcosystem.s.sol:DeployEcosystem \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --legacy

# Verificar direcciones desplegadas
cat deployments/localhost.json
```

**Contratos desplegados:**
- **ANDEToken**: Token nativo de gobernanza
- **AndeGovernor**: Sistema de gobernanza
- **MintController**: Control de emisión
- **AndeChainBridge**: Bridge fuente
- **EthereumBridge**: Bridge destino
- **Oráculos**: Sistema de precios P2P

### Paso 3: Configurar y Iniciar Relayer

```bash
cd ../relayer

# Instalar dependencias
npm install

# Configurar variables de entorno
cp .env.example .env

# Editar .env con las direcciones desplegadas
nano .env
```

**Variables de entorno del relayer:**
```bash
# Configuración de redes
BSC_RPC_URL=https://bsc-dataseed.binance.org
AND_CHAIN_RPC_URL=http://localhost:8545

# Clave privada (usar variables de entorno)
PRIVATE_KEY=$PRIVATE_KEY_REAYER

# Direcciones de contratos (actualizar con direcciones desplegadas)
ANDE_BRIDGE_ADDRESS=$ANDE_BRIDGE_ADDRESS
BSC_BRIDGE_ADDRESS=$BSC_BRIDGE_ADDRESS
BLOBSTREAM_ADDRESS=$BLOBSTREAM_ADDRESS

# Configuración de Celestia
CELESTIA_RPC_URL=http://localhost:26657
```

```bash
# Iniciar relayer
npm start
```

### Paso 4: (Opcional) Iniciar Faucet Server

```bash
cd ..

# Iniciar servidor faucet separado
node faucet-server.js
```

## 🧪 Testing y Validación

### Tests de Contratos Inteligentes

```bash
cd contracts

# Ejecutar todos los tests
forge test

# Tests con output detallado
forge test -vvv

# Tests de un contrato específico
forge test --match-path test/unit/ANDEToken.t.sol

# Tests de integración
forge test --match-path test/integration/

# Reporte de consumo de gas
forge test --gas-report

# Cobertura de código
forge coverage
```

### Tests de Integración del Sistema

```bash
# Verificar conectividad RPC
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:8545

# Verificar balance de cuenta de desarrollo
cast balance $TU_DIRECCION_DESARROLLO --rpc-url local

# Interactuar con contratos desplegados
cast call <CONTRACT_ADDRESS> "name()" --rpc-url local
```

### Verificación del Sistema

```bash
# Estado general del sistema
make status

# Verificar logs de servicios específicos
cd infra
docker compose logs -f single-sequencer
docker compose logs -f ev-reth-sequencer

# Verificar endpoints de salud
curl http://localhost:7980/health  # Local DA
curl http://localhost:4000/health  # Blockscout
```

## 🔧 Comandos Útiles de Desarrollo

### Make Commands (Desde raíz de andechain)

```bash
# 🚀 Comandos principales
make start              # Iniciar todo (infra + contracts + relayer)
make stop               # Detener infraestructura
make reset              # Reset completo + clean + start
make status             # Verificar estado de servicios

# 🧪 Testing y calidad
make test               # Ejecutar tests de contratos
make coverage           # Generar reporte de cobertura
make security           # Análisis de seguridad con Slither

# 🚀 Despliegue individual
make deploy-ecosystem   # Desplegar ecosistema de contratos
make relayer-only       # Iniciar solo el relayer
make faucet             # Iniciar faucet server

# 🧹 Mantenimiento
make clean              # Limpiar artifacts de Foundry
make help               # Mostrar todos los comandos disponibles
```

### Comandos de Foundry (Desde contracts/)

```bash
# Compilación
forge build
forge clean

# Testing
forge test
forge test -vvv
forge test --gas-report
forge test --match-test testFunctionName

# Despliegue
forge script script/DeployEcosystem.s.sol:DeployEcosystem \
  --rpc-url local --broadcast --legacy

# Interacción con contratos
cast call <ADDRESS> "functionName()" --rpc-url local
cast send <ADDRESS> "functionName(arg)" <VALUE> --rpc-url local --private-key $PRIVATE_KEY
```

### Comandos Docker (Desde infra/)

```bash
# Gestión de servicios
docker compose up -d --build
docker compose down
docker compose restart <service>
docker compose logs -f <service>

# Estado del sistema
docker compose ps
docker compose top

# Debugging
docker compose exec single-sequencer bash
docker compose exec ev-reth-sequencer bash

# Reset completo (eliminar volúmenes)
docker compose down -v
docker compose up -d --build
```

## 💻 Configuración del Entorno de Desarrollo

### VS Code - Extensiones Recomendadas

```json
{
  "recommendations": [
    "NomicFoundation.hardhat-solidity",
    "juanblanco.solidity",
    "ms-vscode.vscode-json",
    "redhat.vscode-yaml",
    "ms-azuretools.vscode-docker",
    "bradlc.vscode-tailwindcss",
    "esbenp.prettier-vscode"
  ]
}
```

### Configuración de Foundry

**foundry.toml (resumido):**
```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
test = "test"
cache_path = ".cache"

[rpc_endpoints]
local = "http://localhost:8545"
sepolia = "${SEPOLIA_RPC_URL}"

[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
```

### Configuración de Git Hooks

```bash
# Instalar pre-commit hooks (si existen)
npm install -g pre-commit
pre-commit install

# O configurar manualmente en .git/hooks
```

## 🔄 Flujo de Desarrollo Típico

### Desarrollo de Contratos

```bash
# 1. Iterar en contratos
# Editar archivos en src/

# 2. Compilar cambios
forge build

# 3. Ejecutar tests
forge test

# 4. Tests específicos
forge test --match-path test/unit/MiContrato.t.sol

# 5. Verificar consumo de gas
forge test --gas-report

# 6. Desplegar localmente si es necesario
forge script script/DeployEcosystem.s.sol:DeployEcosystem \
  --rpc-url local --broadcast --legacy
```

### Debugging de Contratos

```bash
# Debug con console.log
console.log("Variable value:", variable);

# Debug con traces
forge test --match-test testFunction --debug trace

# Ver eventos emitidos
forge test --match-test testFunction -vvvv
```

### Desarrollo de Infraestructura

```bash
# 1. Modificar configuración Docker
# Editar archivos en infra/

# 2. Reconstruir imágenes
cd infra
docker compose up -d --build

# 3. Verificar logs
docker compose logs -f <service>

# 4. Debug interactivo
docker compose exec <service> bash
```

## 🐛 Troubleshooting Común

### Problemas Frecuentes y Soluciones

#### 1. Docker Services No Inician

**Síntoma:**
```bash
docker compose up -d
# Error: port already in use
```

**Solución:**
```bash
# Verificar puertos en uso
lsof -i :8545
lsof -i :4000

# Matar procesos
kill -9 <PID>

# O reset completo
docker compose down -v
docker compose up -d --build
```

#### 2. Contratos No Despliegan

**Síntoma:**
```bash
forge script ... --broadcast
# Error: RPC not responding
```

**Solución:**
```bash
# Verificar RPC está activo
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

# Si no responde, reiniciar infraestructura
cd infra
docker compose restart single-sequencer

# Esperar 30 segundos y reintentar
```

#### 3. Tests Fallan con "Insufficient Funds"

**Síntoma:**
```bash
forge test
# Error: insufficient funds for gas * price + value
```

**Solución:**
```bash
# Verificar balance de cuenta
cast balance $TU_DIRECCION_DESARROLLO --rpc-url local

# Obtener fondos del faucet
curl http://localhost:3000/fund?address=$TU_DIRECCION_DESARROLLO
```

#### 4. Relayer No Conecta

**Síntoma:**
```bash
cd relayer && npm start
# Error: contract not found
```

**Solución:**
```bash
# Verificar direcciones en .env
cat relayer/.env

# Verificar contratos desplegados
cat contracts/deployments/localhost.json

# Actualizar .env con direcciones correctas
nano relayer/.env
```

#### 5. Problemas de Permiso (Docker)

**Síntoma:**
```bash
docker compose up -d
# Error: permission denied
```

**Solución:**
```bash
# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Hacer logout y login nuevamente
# O usar sudo para comandos docker
sudo docker compose up -d
```

#### 6. Foundry Commands Not Found

**Síntoma:**
```bash
forge --version
# Command not found: forge
```

**Solución:**
```bash
# Reinstalar Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verificar instalación
forge --version

# Si persiste, agregar al PATH
echo 'export PATH="$HOME/.foundry/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 📞 Obtener Ayuda Adicional

1. **📖 Documentación**: Revisa `../docs/ONBOARDING.md`
2. **💬 Discord**: [Join our community](https://discord.gg/andechain)
3. **🐛 Issues**: [Create GitHub Issue](https://github.com/AndeLabs/andechain/issues)
4. **📧 Email**: dev@andechain.org

### 📋 Commands de Verificación

```bash
# Script completo de verificación
echo "🔍 Verificando instalación completa..."

# 1. Verificar herramientas
docker --version || echo "❌ Docker no instalado"
node --version || echo "❌ Node.js no instalado"
forge --version || echo "❌ Foundry no instalado"

# 2. Verificar servicios
curl -s http://localhost:8545 > /dev/null && echo "✅ RPC activo" || echo "❌ RPC inactivo"
curl -s http://localhost:4000 > /dev/null && echo "✅ Blockscout activo" || echo "❌ Blockscout inactivo"

# 3. Verificar contratos
test -f deployments/localhost.json && echo "✅ Contratos desplegados" || echo "❌ Contratos no desplegados"

# 4. Verificar relayer
ps aux | grep -q "relayer" && echo "✅ Relayer activo" || echo "❌ Relayer inactivo"

echo "🎉 Verificación completada"
```

## 🎯 Siguientes Pasos

Una vez que tu entorno esté funcionando:

1. **📖 Explorar la documentación**:
   - [../docs/ONBOARDING.md](./ONBOARDING.md) - Guía completa
   - [../contracts/README.md](../contracts/README.md) - Contratos inteligentes
   - [../relayer/README.md](../relayer/README.md) - Relayer

2. **🧪 Ejecutar tests completos**:
   ```bash
   make test
   make coverage
   ```

3. **💻 Explorar ejemplos**:
   - Interactuar con contratos via cast
   - Crear tus propios scripts de Foundry
   - Experimentar con el sistema de gobernanza

4. **🤝 Contribuir al proyecto**:
   - Lee el [Git Workflow](../docs/GIT_WORKFLOW.md)
   - Crea un fork del repositorio
   - Envía tu primer Pull Request

---

<div align="center">

**🚀 ¡Bienvenido al ecosistema AndeChain!**

[📚 Documentación](./) • [💬 Discord](https://discord.gg/andechain) • [🐙 GitHub](https://github.com/AndeLabs/andechain)

[⬆ Volver arriba](#-guía-de-inicio---andechain-development)

</div>