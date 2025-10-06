# AndeChain - Sovereign EVM Rollup Infrastructure

<div align="center">

**Blockchain Infrastructure for Latin America**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Built with Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.25-blue.svg)](https://soliditylang.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg)](https://www.docker.com/)

[📚 Documentation](./docs/) • [🐙 GitHub](https://github.com/AndeLabs/andechain) • [💬 Discord](https://discord.gg/andechain)

</div>

---

## 🎯 ¿Qué es AndeChain?

### 🌟 Una Blockchain Soberana para América Latina

<div align="center">

**AndeChain es una rollup EVM soberana construida sobre Celestia**, diseñada específicamente para resolver los problemas financieros de América Latina.

</div>

### 🏗️ ¿Cómo Funciona Nuestra Rollup?

```
📱 Usuarios y Apps         🔗 Conectan a           🚀 AndeChain Rollup
┌─────────────────┐   RPC   ┌─────────────────┐   ┌─────────────────┐
│   DApps         │◄──────►│  AndeChain RPC  │◄──────►│   EVM Engine    │
│   Wallets       │        │  (localhost)    │        │   (Reth)        │
│   DeFi Protos   │        └─────────────────┘        └─────────────────┘
└─────────────────┘                                         │
                                                                │
📦 Bloques Producidos                                       📊
┌─────────────────┐   Verifies   ┌─────────────────┐   Data Availability
│  Sequencer      │◄─────────────┤   Consensus     │◄───────────────────────► Celestia
│  (ev-node)      │   Bloques    │   Layer        │      Blobstream        │
└─────────────────┘              └─────────────────┘  (Mock/Prod DA Layer)
```

### 💡 ¿Por Qué Celestia Data Availability?

<div align="center">

**🔗 Celestia nos permite ser verdaderamente soberanos**

</div>

| ✅ **Beneficio** | 📖 **Explicación** |
|:---------------:|:------------------|
| **🆓 Independencia** | No dependemos de Ethereum L1 para seguridad |
| **⚡ Baja Latencia** | Bloques rápidos optimizados para América Latina |
| **💸 Costos Bajos** | Fees predecibles y accesibles |
| **🌐 Escalabilidad** | Capacidad ilimitada de transacciones |
| **🏛️ Soberanía** | Control total de la infraestructura |

### 🌍 El Problema que Resolvemos

<div align="center">

**💰 67% de latinoamericanos sin acceso bancario**

**💸 $100B+ en remesas con comisiones del 6-8%**

**📊 Inflación de dos dígitos en múltiples economías**

</div>

### ✅ Nuestra Solución

| 🎯 **Característica** | 🌟 **Impacto** |
|:-------------------:|:------------:|
| **🪙 ANDE Token** | Gas nativo para soberanía económica |
| **🇧🇴 Stablecoins Locales** | ABOB (Boliviano) y más monedas regionales |
| **🌉 Puentes a BSC** | Conectividad con el ecosistema más usado en LATAM |
| **📊 Oráculos P2P** | Tasas de cambio justas y descentralizadas |
| **🏛️ Gobernanza veANDE** | Democracia on-chain para decisiones estratégicas |

---

## 👥 Secciones por Audiencia

### 🌟 Para el Público General

<div align="center">

**🚀 ¿Quieres usar AndeChain?**

</div>

#### 🎮 ¿Qué Puedo Hacer en AndeChain?

| 💸 **Enviar Dinero** | 🏦 **Acceso Financiero** | 🛍️ **Comercio Local** |
|:-------------------:|:----------------------:|:-------------------:|
| Remesas sin comisiones | Prestamos DeFi | Comercio con stablecoins locales |
| Pagos transfronterizos | Staking y yields | Mercado P2P regional |
| Cambios de moneda | Seguros digitales | NFTs y arte digital |

#### 📱 Cómo Empezar

1. **🔗 Conectar tu Wallet**: MetaMask, Trust Wallet, etc.
2. **💰 Obtener ANDE**: Faucet gratuito o comprar en exchanges
3. **🌉 Bridge desde BSC**: Traer tus tokens de Binance Smart Chain
4. **🎯 Usar DApps**: Explorar aplicaciones financieras

#### 💡 Casos de Uso Reales

- **👨‍💻 Freelancer**: Recibir pagos de clientes internacionales sin bancos
- **👩‍🌾 Emprendedora**: Acceder a préstamos para su negocio
- **👨‍👩‍👧 Familias**: Enviar remesas con costo casi nulo
- **🏪 Comercios**: Aceptar pagos digitales sin volatilidad

---

### 👨‍💻 Para Developers

<div align="center">

**🔨 Construye el futuro financiero de América Latina**

</div>

#### 🚀 Quick Start

```bash
# 1. Clonar y setup
git clone https://github.com/AndeLabs/andechain.git
cd andechain
make start

# 2. Conectar al RPC
RPC_URL: http://localhost:8545
Chain ID: 31337

# 3. Obtener tokens de prueba
curl http://localhost:3000/fund?address=TU_DIRECCION
```

#### 🛠️ Herramientas Disponibles

| 🛠️ **Herramienta** | 📋 **Uso** | 🔗 **Link** |
|:-----------------:|:----------:|:-----------:|
| **📜 Smart Contracts** | Tokens, gobernanza, bridges | [Ver contratos](./contracts/README.md) |
| **🌉 Bridge SDK** | Conectar BSC ↔ AndeChain | [Documentación](./docs/BRIDGE_SDK.md) |
| **📊 Oracle API** | Precios P2P en tiempo real | [API Docs](./docs/ORACLE_API.md) |
| **🔧 Node SDK** | Interactuar con la rollup | [SDK Guide](./docs/NODE_SDK.md) |

#### 🎯 Ecosistema de Contratos

```solidity
// Ejemplo: Token con Gobernanza
contract MiToken is ERC20VotesUpgradeable {
    // Soporte nativo para voting
    function lockForVoting(uint256 amount) external {
        _lock(msg.sender, amount);
        _transfer(msg.sender, address(this), amount);
    }
}
```

#### 📚 Recursos para Developers

- **📖 [Documentación Técnica](./docs/)**
- **🧪 [Test Suite](./contracts/test/)**
- **🎯 [Examples & Templates](./examples/)**
- **💬 [Developer Discord](https://discord.gg/andechain)**

---

### 🔧 Para Operadores de Red

<div align="center">

**🏛️ Sé parte de la infraestructura soberana**

</div>

#### 🏗️ Tipos de Operadores

| 🔧 **Rol** | 🎯 **Responsabilidad** | 💰 **Incentivos** |
|:----------:|:---------------------:|:---------------:|
| **🔑 Sequencer** | Producir bloques y ordenar txs | Fees de transacción |
| **📊 Relayer** | Mantener bridges funcionando | Comisiones de bridge |
| **🔍 Validador** | Verificar integridad de DA | Staking rewards |
| **🏛️ Noder** | Mantener RPC público | Donaciones y fees |

#### 🚀 Requisitos Mínimos

| 📋 **Componente** | 💻 **Mínimo** | ☁️ **Recomendado** |
|:----------------:|:------------:|:----------------:|
| **CPU** | 4 cores | 8 cores |
| **RAM** | 8GB | 16GB |
| **Storage** | 500GB SSD | 1TB NVMe SSD |
| **Network** | 100 Mbps | 1 Gbps simétrica |

#### 🔐 Setup de Sequencer

```bash
# 1. Instalar dependencias
sudo apt update && sudo apt install docker-compose

# 2. Clonar repositorio
git clone https://github.com/AndeLabs/andechain.git
cd andechain/infra

# 3. Configurar nodo
cp .env.sequencer.example .env
# Editar .env con tu configuración

# 4. Iniciar nodo
docker compose -f sequencer.yml up -d
```

#### 📊 Monitoreo y Salud

| 📈 **Métrica** | 🎯 **Target** | 🔍 **Cómo Monitorear** |
|:--------------:|:------------:|:---------------------:|
| **Uptime** | 99.9% | Prometheus + Grafana |
| **Latencia** | <100ms | Ping RPC endpoint |
| **Sync** | Latest block | eth_blockNumber |
| **DA Health** | Connected | Celestia RPC status |

#### 💰 Incentivos y Recompensas

| 🏆 **Nivel** | 📊 **Performance** | 💰 **Rewards** |
|:------------:|:-----------------:|:-------------:|
| **🥇 Elite** | 99.9% uptime | +20% bonus |
| **🥈 Estándar** | 99% uptime | Base rewards |
| **🥉 Básico** | 95% uptime | -10% penalty |

---

## 🏗️ Arquitectura Técnica

### 📋 Estructura del Proyecto

```
andechain/
├── 📁 contracts/                    # 🔨 Smart Contracts (Foundry)
│   ├── 📁 src/                      # 📄 Código fuente
│   │   ├── 📁 tokens/               # 🪙 Tokens (ANDE, ABOB, AUSD)
│   │   ├── 📁 governance/           # 🏛️ Gobernanza (Governor, Timelock)
│   │   ├── 📁 bridge/               # 🌉 Bridges (AndeChain ↔ BSC)
│   │   ├── 📁 oracle/               # 📊 Oráculos P2P
│   │   └── 📁 stability/            # ⚖️ Motor de estabilidad
│   ├── 📁 test/                     # 🧪 Tests
│   └── 📁 script/                   # 🚀 Scripts de deploy
│
├── 📁 infra/                        # 🐳 Infraestructura (Docker)
│   ├── 📁 stacks/                   # ⚙️ Configuraciones
│   └── 🐳 docker-compose.yml        # 🎼 Orquestación
│
├── 📁 relayer/                      # 🔄 Bridge relayer (TypeScript)
├── 📁 docs/                         # 📚 Documentación
├── 📄 Makefile                      # 🛠️ Comandos automatizados
└── 📄 CLAUDE.md                     # 🤖 Guía para IA
```

### 🔧 Componentes Principales

#### 💰 Tokenomics V3.0

| Contrato | Token | Propósito | Características Clave |
|----------|-------|-----------|----------------------|
| `ANDEToken.sol` | **ANDE** | Governance + Gas Nativo | ERC20Votes, Burnable, Pausable, UUPS |
| `VeANDE.sol` | **veANDE** | Vote-Escrowed | Lock hasta 4 años, poder boosteado |
| `AusdToken.sol` | **AUSD** | Stablecoin Algorítmica | Collateralizado, rebase mechanism |
| `AbobToken.sol` | **ABOB** | Boliviano Tokenizado | Pegged a BOB, 1:1 backing |
| `sAbobToken.sol` | **sABOB** | Staked ABOB | Yield compounding, rewards |

#### 🏛️ Sistema de Gobernanza

**Contratos Principales:**
- **`AndeGovernor.sol`**: Gobernanza on-chain para propuestas y votación
- **`AndeTimelockController.sol`**: Ejecución retardada de propuestas (48h)
- **`MintController.sol`**: Control de emisión con límites de seguridad:
  - Hard cap: 1B ANDE
  - Límite anual: 50M ANDE
  - Supermajority requerida: 66%

#### 🌉 Bridge Infrastructure

**Arquitectura de Puentes:**
```
Source Chain (AndeChain)        Destination Chain (BSC)
       │                                │
AndeBridge.sol                BSCBridge.sol
       │                                │
   Lock Tokens                     Mint Tokens
       │                                │
   Emit Events                    Verify DA Proofs
       │                                │
   └───────► Blobstream ◄───────────────┘
               (Celestia DA)
```

#### 📊 Oracle Network

**Sistema Multi-Oracle:**
- **P2POracleV2**: Tasas P2P reales de usuarios
- **AndeOracleAggregator**: Agregador de múltiples fuentes
- **TrustedRelayerOracle**: Oráculo centralizado para casos específicos

**Tipos de Precios Soportados:**
- BOB/USD (Boliviano)
- CLP/USD (Peso Chileno)
- PEN/USD (Sol Peruano)
- ARS/USD (Peso Argentino)
- EUR/USD (Euro)
- BTC/USD (Bitcoin)

---

## 🚀 Guía de Inicio Rápido

### 📋 Prerrequisitos

Asegúrate de tener instalado:

```bash
# Verificar instalaciones
docker --version          # >= 24.0.0
node --version           # >= 20.0.0
foundryup --version      # Latest
make --version           # Any version
```

### ⚡ Inicio Automático (Recomendado)

```bash
# Clonar el repositorio
git clone https://github.com/AndeLabs/andechain.git
cd andechain

# Iniciar ecosistema completo
make start

# Verificar estado
make status
```

### 🔧 Desarrollo Manual

#### 1. Iniciar Infraestructura

```bash
cd infra
docker compose up -d --build

# Verificar rollup está operativo
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545
```

#### 2. Desplegar Contratos

```bash
cd ../contracts
forge build

# Configurar cuenta (usar variables de entorno)
export PRIVATE_KEY=$PRIVATE_KEY_DESARROLLO

# Desplegar ecosistema
forge script script/DeployEcosystem.s.sol:DeployEcosystem \
  --rpc-url http://localhost:8545 \
  --broadcast --legacy
```

#### 3. Iniciar Relayer

```bash
cd ../relayer
npm install
cp .env.example .env
# Editar .env con direcciones desplegadas
npm start
```

### 🖥️ Acceso a Servicios

| Servicio | URL | Descripción |
|----------|-----|-------------|
| **RPC Endpoint** | http://localhost:8545 | Ethereum JSON-RPC |
| **Block Explorer** | http://localhost:4000 | Blockscout |
| **Faucet** | http://localhost:3000 | ETH faucet |
| **Local DA** | http://localhost:7980 | Mock Celestia |

---

## 🛠️ Comandos de Desarrollo

### 🎯 Make Commands (Principal)

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

### 🔨 Contratos (Foundry)

```bash
cd contracts

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
```

### 🐳 Infraestructura (Docker)

```bash
cd infra

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
```

---

## 📚 Documentación Completa

### 🎯 Guías Esenciales

| Documento | Audiencia | Descripción |
|-----------|-----------|-------------|
| [🚀 Getting Started](./docs/GETTING_STARTED.md) | 👨‍💻 Developers | Guía completa de instalación y configuración |
| [🏗️ Architecture Overview](./docs/ONBOARDING.md) | 🔧 Technical | Arquitectura detallada del sistema |
| [🔨 Smart Contracts](./contracts/README.md) | ⚡ Blockchain | Documentación de contratos inteligentes |
| [🌉 Bridge System](./docs/BRIDGE_GUIDE.md) | 💰 DeFi | Guía del sistema de puentes |
| [📊 Oracle Network](./docs/ORACLE_GUIDE.md) | 📈 Data Feeds | Configuración de oráculos |

### 🔗 Documentación por Componente

- **📋 Blockchain**: [contracts/README.md](./contracts/README.md)
- **🔄 Relayer**: [relayer/README.md](./relayer/README.md)
- **🌱 Filosofía**: [GEMINI.md](./GEMINI.md)
- **🔄 Git Workflow**: [docs/GIT_WORKFLOW.md](./docs/GIT_WORKFLOW.md)

---

## 🛠️ Stack Tecnológico

### ⚡ Layer Blockchain

| Componente | Tecnología | Versión | Propósito |
|------------|------------|---------|-----------|
| Smart Contracts | Solidity | 0.8.25 | Lógica de negocio |
| Development | Foundry | Latest | Testing, deploy, dev |
| Execution Layer | Reth | Latest | EVM execution |
| Sequencer | ev-node | Latest | Block production |
| Data Availability | Celestia | Mocha-4 | DA layer |
| Block Explorer | Blockscout | 6.10.0 | Blockchain explorer |

### 🔧 Infrastructure

- **🐳 Docker** - Containerización y orquestación
- **🚀 GitHub Actions** - CI/CD automation
- **🛡️ Slither** - Security analysis
- **📊 Codecov** - Coverage tracking

---

## 🔐 Cuentas y Claves

### 💰 Cuenta de Desarrollo (Local)

Para desarrollo local, puedes usar las cuentas prefinanciadas que proporciona Anvil (Foundry) o configurar tu propia cuenta en el archivo `.env`.

**⚠️ IMPORTANTE**: Nunca commiteas claves privadas al repositorio. Usa variables de entorno para claves y configuraciones sensibles.

### 📍 Direcciones de Contratos

Después de `make deploy-ecosystem`, las direcciones de los contratos se guardarán en `contracts/deployments/localhost.json`. Estas direcciones cambiarán en cada despliegue local.

**Nota:** Para entornos de testnet/mainnet, las direcciones serán consistentes y publicadas en la documentación oficial.

---

## 🔄 Flujo de Transacciones Cross-Chain

```
1. Usuario inicia bridge desde AndeChain hacia BSC
   └─ AndeBridge.lockTokens()

2. Tokens bloqueados y evento emitido
   └─ BridgeInitiated(address, amount, destination)

3. Relayer detecta evento
   └─ Escucha en AndeChain RPC

4. Relayer crea prueba DA en Celestia
   └─ SubmitData(blob)

5. Relayer prueba en Binance Smart Chain
   └─ BSCBridge.verifyAndMint()

6. Tokens minteados en BSC
   └─ Usuario recibe tokens en BSC
```

---

## 🔧 Configuración y Variables de Entorno

### 📄 Variables de Entorno (Relayer)

```bash
# .env file para el relayer
BSC_RPC_URL=https://bsc-dataseed.binance.org
AND_CHAIN_RPC_URL=http://localhost:8545
PRIVATE_KEY=Tu clave privada aquí
ANDE_BRIDGE_ADDRESS=Dirección del bridge en AndeChain
BSC_BRIDGE_ADDRESS=Dirección del bridge en BSC
BLOBSTREAM_ADDRESS=Dirección del contrato de Celestia
```

### ⚙️ Configuración de Foundry

```toml
# foundry.toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
test = "test"
cache_path = ".cache"

[rpc_endpoints]
local = "http://localhost:8545"
bsc = "https://bsc-dataseed.binance.org"
bsc_testnet = "https://data-seed-prebsc-1-s1.binance.org:8545"

[etherscan]
bsc = { key = "${BSCSCAN_API_KEY}" }
bsc_testnet = { key = "${BSCSCAN_API_KEY}" }
```

---

## 🤝 Contribuir al Proyecto

### 🔄 Flujo de Trabajo

1. **🍴 Fork** el repositorio
2. **🌿 Crear branch** desde `develop`
3. **💻 Desarrollar** con commits convencionales
4. **🧪 Testing** completo obligatorio
5. **📤 Push** y crear PR a `develop`

### 📝 Estándar de Commits

```bash
feat(contracts): agregar nueva funcionalidad de bridge
fix(relayer): corregir manejo de eventos de mint
docs(readme): actualizar guía de instalación
test(contracts): agregar tests para MintController
refactor(oracle): optimizar lógica de agregación
chore(infra): actualizar versiones de Docker
```

### 🔍 Requisitos para PRs

- ✅ Tests pasando (`make test`)
- ✅ Cobertura >80% (`make coverage`)
- ✅ Sin alertas de seguridad (`make security`)
- ✅ Código documentado con NatSpec
- ✅ Commits convencionales
- ✅ Builds exitosos en CI/CD

---

## 🐛 Troubleshooting Común

### 🔧 Problemas Frecuentes

**1. Rollup no inicia:**
```bash
# Verificar logs
docker compose logs -f single-sequencer

# Reset completo
docker compose down -v
docker compose up -d --build
```

**2. Contratos no despliegan:**
```bash
# Verificar RPC está activo
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

# Verificar PRIVATE_KEY configurada
echo $PRIVATE_KEY
```

**3. Tests fallan:**
```bash
# Limpiar cache
forge clean
forge build

# Reinstalar foundry
foundryup
```

**4. Relayer no conecta:**
```bash
# Verificar variables de entorno
cat relayer/.env

# Verificar direcciones de contratos
cat deployments/localhost.json
```

### 📞 Obtener Ayuda

- **📖 Documentación**: Revisa `docs/ONBOARDING.md`
- **💬 Discord**: [Join our community](https://discord.gg/andechain)
- **🐛 Issues**: [Create GitHub Issue](https://github.com/AndeLabs/andechain/issues)
- **📧 Email**: dev@andechain.org

---

## 📜 Licencia

Este proyecto está licenciado bajo **MIT License**. Ver [LICENSE](./LICENSE) para detalles completos.

## 🔗 Enlaces y Recursos

### 📚 Documentación Técnica

- **📖 Smart Contracts**: [contracts/README.md](./contracts/README.md)
- **🔄 Relayer**: [relayer/README.md](./relayer/README.md)
- **🏗️ Arquitectura**: [docs/ONBOARDING.md](./docs/ONBOARDING.md)
- **🔍 Salud del Sistema**: [docs/HEALTH_CHECK.md](./docs/HEALTH_CHECK.md)

### 🛠️ Herramientas y Tecnologías

- **🔨 Foundry**: [Documentation](https://book.getfoundry.sh/)
- **🐳 Docker**: [Documentation](https://docs.docker.com/)
- **⚡ Reth**: [GitHub](https://github.com/paradigmxyz/reth)
- **🔗 ev-node**: [Documentation](https://docs.evolve.zone/)
- **🌐 Celestia**: [Documentation](https://docs.celestia.org/)
- **🛡️ OpenZeppelin**: [Contracts](https://docs.openzeppelin.com/contracts/)

### 🌐 Comunidad

- **🐦 Twitter**: [@AndeChain](https://twitter.com/andechain)
- **💬 Discord**: [Join Community](https://discord.gg/andechain)
- **🐙 GitHub**: [AndeLabs/andechain](https://github.com/AndeLabs/andechain)
- **📧 Contacto**: dev@andechain.org

---

<div align="center">

**🚀 Construyendo la infraestructura financiera soberana de América Latina**

[⬆ Volver arriba](#andechain---sovereign-evm-rollup-infrastructure)

</div>