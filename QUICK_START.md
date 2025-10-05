# 🚀 AndeChain - Guía de Inicio Rápido

Esta guía te ayudará a levantar todo el ecosistema AndeChain en minutos.

## 📋 Requisitos Previos

- Docker Desktop instalado y corriendo
- Foundry instalado (`curl -L https://foundry.paradigm.xyz | bash && foundryup`)
- Node.js 18+ (para el relayer y frontend)

## ⚡ Inicio Rápido (Un Solo Comando)

```bash
cd andechain
make start
```

Este comando automáticamente:
1. ✅ Levanta toda la infraestructura Docker (blockchain + explorer)
2. ✅ Compila y despliega todos los contratos
3. ✅ Muestra las URLs de acceso y direcciones de contratos

## 🎯 Comandos Principales

### Iniciar el Entorno

```bash
make start          # Inicia TODO (recomendado)
```

### Detener Servicios

```bash
make stop           # Detiene la infraestructura (mantiene datos)
```

### Reset Completo

```bash
make reset          # Borra TODO y reinicia desde cero
```

**⚠️ Cuándo usar `make reset`:**
- Cuando cambias el archivo genesis
- Cuando quieres empezar con blockchain limpia
- Cuando hay errores extraños de estado

### Testing y Desarrollo

```bash
make test           # Ejecuta todos los tests
make coverage       # Reporte de cobertura
make security       # Análisis de seguridad (Slither)
make gas            # Reporte de gas
```

### Deploy Manual (Avanzado)

```bash
# Solo si la infraestructura ya está corriendo
make deploy-only          # Deploy básico (puentes)
make deploy-ecosystem     # Deploy completo (todo el ecosistema)
```

## 🌐 URLs de Acceso

Una vez que ejecutes `make start`, tendrás acceso a:

| Servicio | URL | Descripción |
|----------|-----|-------------|
| **RPC Endpoint** | `http://localhost:8545` | Punto de conexión JSON-RPC |
| **Block Explorer** | `http://localhost:4000` | Blockscout (indexador y verificador) |
| **Faucet** | `http://localhost:8081` | Faucet para obtener tokens de prueba |
| **Frontend** | `http://localhost:9002` | Aplicación web Next.js |

## 🔑 Cuenta de Desarrollo Pre-financiada

```
Address:     0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

**⚠️ ADVERTENCIA:** Esta cuenta es **SOLO PARA DESARROLLO LOCAL**. Nunca uses esta clave privada en producción.

## 📦 Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────┐
│                    Frontend                          │
│              (Next.js - Port 9002)                   │
└────────────────────┬────────────────────────────────┘
                     │
                     ↓ (wagmi/viem)
┌─────────────────────────────────────────────────────┐
│              RPC Endpoint (Port 8545)                │
│                  ev-reth-sequencer                   │
└────────────────────┬────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────┐
│            Block Production & Ordering               │
│                 single-sequencer                     │
└────────────────────┬────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────┐
│              Data Availability Layer                 │
│            local-da (mock Celestia)                  │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│              Block Explorer (Port 4000)              │
│    Blockscout - Indexa y verifica contratos          │
└─────────────────────────────────────────────────────┘
```

## 🔍 Verificación de Contratos

**Los contratos se verifican AUTOMÁTICAMENTE** cuando:
1. Son desplegados en la red
2. Blockscout indexa el bloque correspondiente

Puedes ver el estado de verificación en: http://localhost:4000

### Verificación Manual (si es necesario)

```bash
forge verify-contract <ADDRESS> <CONTRACT> \
  --verifier blockscout \
  --verifier-url http://localhost:4000/api \
  --chain-id 1234
```

## 🛠️ Troubleshooting

### "RPC no responde"

```bash
# Verifica que los contenedores estén corriendo
cd infra
docker compose ps

# Verifica logs del sequencer
docker compose logs -f ev-reth-sequencer
```

### "Contracts no se despliegan"

```bash
# 1. Asegúrate de que el RPC esté activo
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

# 2. Si está activo, intenta deploy manual
cd contracts
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/DeployEcosystem.s.sol --rpc-url local --broadcast --legacy -vvv
```

### "El sistema está lento"

```bash
# Reset completo
make reset

# Reinicia Docker Desktop
# Luego:
make start
```

### "Puerto 8545 ya está en uso"

```bash
# Encuentra qué proceso lo está usando
lsof -i :8545

# Detén los contenedores existentes
cd infra
docker compose down
```

## 📁 Estructura de Archivos Importantes

```
andechain/
├── Makefile                    # Comandos principales
├── scripts/
│   └── start-all.sh           # Script principal de inicio
├── contracts/
│   ├── src/                   # Contratos Solidity
│   ├── script/                # Scripts de deploy
│   │   └── DeployEcosystem.s.sol  # Deploy completo
│   ├── test/                  # Tests
│   └── broadcast/             # Registros de deployment
│       └── DeployEcosystem.s.sol/
│           └── 1234/
│               └── run-latest.json  # Direcciones desplegadas
├── infra/
│   └── docker-compose.yml     # Definición de servicios
└── relayer/
    └── src/                   # Relayer TypeScript
```

## 🔄 Flujo de Trabajo Típico

### 1. Primera Vez

```bash
# Clonar y entrar al directorio
git clone <repo>
cd andechain

# Iniciar todo
make start
```

### 2. Desarrollo Diario

```bash
# Iniciar servicios (si están detenidos)
make start

# Hacer cambios en contratos...

# Ejecutar tests
make test

# Si los tests pasan, redesplegar
cd contracts
forge script script/DeployEcosystem.s.sol --rpc-url local --broadcast --legacy
```

### 3. Cambios en Génesis o Configuración

```bash
# Reset completo necesario
make reset

# Editar genesis.json o configuración...

# Reiniciar
make start
```

## 🎓 Recursos Adicionales

- [CLAUDE.md](./CLAUDE.md) - Instrucciones completas del proyecto
- [ONBOARDING.md](./ONBOARDING.md) - Guía detallada de operaciones
- [GEMINI.md](../GEMINI.md) - Filosofía de desarrollo
- [Foundry Book](https://book.getfoundry.sh/) - Documentación de Foundry
- [Blockscout Docs](https://docs.blockscout.com/) - Documentación del explorador

## ❓ FAQ

**Q: ¿Necesito reiniciar la infraestructura cuando cambio contratos?**
A: No, solo redesplegar con `forge script`.

**Q: ¿Cómo veo las direcciones de los contratos desplegados?**
A: En `contracts/broadcast/DeployEcosystem.s.sol/1234/run-latest.json`

**Q: ¿Por qué Chain ID 1234?**
A: Es el chain ID configurado para desarrollo local.

**Q: ¿Cómo conecto MetaMask?**
A:
1. Agregar red custom en MetaMask
2. Chain ID: `1234`
3. RPC URL: `http://localhost:8545`
4. Currency: `AETH`
5. Importar cuenta con la private key de desarrollo

---

**¿Problemas?** Revisa [ONBOARDING.md](./ONBOARDING.md) o abre un issue en GitHub.
