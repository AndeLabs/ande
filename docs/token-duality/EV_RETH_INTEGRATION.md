# Integración con Ande-Reth (Fork Personalizado de ev-reth)

**Propósito:** Documento de integración entre andechain y el fork personalizado de ev-reth
**Fecha:** 2025-10-07
**Estado:** En Desarrollo

---

## 📋 Resumen

Para implementar Token Duality, AndeChain utiliza un **fork personalizado de ev-reth** que incluye un precompile adicional. Este documento explica la relación entre ambos repositorios y cómo gestionarla.

---

## 🏗️ Arquitectura de Repositorios

```
~/dev/ande-labs/
│
├── andechain/                      # Repositorio PRINCIPAL
│   ├── contracts/                  # Smart contracts (Solidity)
│   │   └── src/ANDEToken.sol      # Usa precompile 0x...fd
│   ├── infra/                      # Infraestructura Docker
│   │   └── docker-compose.yml     # Referencia imagen de ande-reth
│   ├── relayer/                    # Bridge relayer (TypeScript)
│   └── docs/
│       └── token-duality/         # Este documento
│
└── ev-reth/                        # Repositorio SEPARADO
    ├── crates/                     # Código Rust de ev-reth
    ├── Dockerfile                  # Construye imagen personalizada
    └── ANDE_README.md             # Documentación del fork
```

### ¿Por Qué Repositorios Separados?

| Aspecto | Razón |
|---------|-------|
| **Ciclos de Release** | ev-reth se actualiza menos frecuentemente |
| **Responsabilidades** | ev-reth es infraestructura; andechain es aplicación |
| **Mantenimiento** | Más fácil sincronizar con upstream (evstack/ev-reth) |
| **Reutilización** | ande-reth puede usarse en otros proyectos de Ande Labs |
| **CI/CD** | Pipelines independientes para compilar/testear |

---

## 🔗 Punto de Integración: Imagen Docker

La integración entre repositorios se realiza **vía imagen Docker**:

```yaml
# andechain/infra/stacks/single-sequencer/docker-compose.da.local.yml

services:
  ev-reth-sequencer:
    # ANTES (upstream vanilla):
    # image: ghcr.io/evstack/ev-reth:latest

    # DESPUÉS (fork personalizado):
    image: ghcr.io/ande-labs/ande-reth:token-duality-v1

    # ... resto de configuración sin cambios
```

---

## 🚀 Flujo de Desarrollo

### Escenario 1: Desarrollo de Smart Contracts (Común)

**No necesitas tocar ev-reth.**

```bash
cd ~/dev/ande-labs/andechain

# 1. Modificar ANDEToken.sol
vim contracts/src/ANDEToken.sol

# 2. Compilar
cd contracts && forge build

# 3. Ejecutar tests (usa imagen Docker de ande-reth)
cd ../infra
docker compose up -d
cd ../contracts
forge test --rpc-url http://localhost:8545

# 4. Deploy
forge script script/DeployEcosystem.s.sol --rpc-url local --broadcast
```

### Escenario 2: Modificar Precompile (Raro)

**Solo si necesitas cambiar la lógica del precompile.**

```bash
# 1. Ir al repo de ev-reth
cd ~/dev/ande-labs/ev-reth
git checkout feature/ande-precompile

# 2. Modificar precompile (TBD: ubicación exacta)
vim crates/.../precompile.rs

# 3. Compilar binario
cargo build --release  # ~30-60 min primera vez

# 4. Crear imagen Docker local
docker build -t andelabs/ande-reth:local .

# 5. Actualizar docker-compose en andechain
cd ../andechain/infra/stacks/single-sequencer
# Editar docker-compose.da.local.yml:
# image: andelabs/ande-reth:local

# 6. Reiniciar infraestructura
docker compose down -v
docker compose up -d

# 7. Verificar que funciona
docker compose logs -f ev-reth-sequencer

# 8. Si funciona, publicar imagen
cd ~/dev/ande-labs/ev-reth
docker tag andelabs/ande-reth:local ghcr.io/ande-labs/ande-reth:token-duality-v2
docker push ghcr.io/ande-labs/ande-reth:token-duality-v2

# 9. Actualizar docker-compose en andechain con nueva versión
```

---

## 📦 Gestión de Versiones

### Versionado de ande-reth

```
ghcr.io/ande-labs/ande-reth:
  - latest                    # Última versión estable
  - token-duality-v1         # Primera versión con precompile
  - token-duality-v2         # Mejoras al precompile
  - main                      # Branch principal (puede ser inestable)
```

### Sincronización con andechain

**Archivo:** `andechain/infra/.env`

```bash
# Versión de ande-reth a usar
ANDE_RETH_VERSION=token-duality-v1

# O para desarrollo:
# ANDE_RETH_VERSION=local
```

**Archivo:** `andechain/infra/stacks/single-sequencer/docker-compose.da.local.yml`

```yaml
services:
  ev-reth-sequencer:
    image: ghcr.io/ande-labs/ande-reth:${ANDE_RETH_VERSION:-token-duality-v1}
```

---

## 🔄 Actualizaciones de Upstream

### Cuando evstack/ev-reth Release Nueva Versión

```bash
cd ~/dev/ande-labs/ev-reth

# 1. Actualizar desde upstream
git fetch upstream
git checkout main
git merge upstream/main

# 2. Re-aplicar nuestros cambios
git checkout feature/ande-precompile
git rebase main

# 3. Resolver conflictos (si los hay)
# ... editar archivos en conflicto ...
git add .
git rebase --continue

# 4. Recompilar y probar
cargo build --release
docker build -t andelabs/ande-reth:test .

# 5. Verificar en andechain
cd ../andechain/infra
# Usar imagen de test
# ... tests ...

# 6. Si funciona, publicar nueva versión
cd ~/dev/ande-labs/ev-reth
docker tag andelabs/ande-reth:test ghcr.io/ande-labs/ande-reth:token-duality-v3
docker push ghcr.io/ande-labs/ande-reth:token-duality-v3

# 7. Actualizar andechain para usar nueva versión
cd ../andechain
# Actualizar ANDE_RETH_VERSION en .env o docker-compose.yml
git commit -m "chore(infra): upgrade ande-reth to v3"
```

---

## 🧪 Testing de Integración

### Test 1: Verificar que Precompile Está Disponible

```bash
cd ~/dev/ande-labs/andechain/infra
docker compose up -d

# Verificar logs del sequencer
docker compose logs -f ev-reth-sequencer | grep -i precompile

# Intentar llamar al precompile (debería fallar con "unauthorized")
cast call 0x00000000000000000000000000000000000000fd \
  "test()" \
  --rpc-url http://localhost:8545
```

### Test 2: ANDEToken Funciona con Precompile

```bash
cd ~/dev/ande-labs/andechain/contracts

# Deploy ANDEToken
forge script script/DeployEcosystem.s.sol --rpc-url local --broadcast --legacy

# Ejecutar tests de Token Duality
forge test --match-path test/unit/TokenDuality.t.sol \
  --rpc-url http://localhost:8545 \
  -vvv
```

### Test 3: End-to-End

```bash
# Ver docs/token-duality/TESTING_GUIDE.md (por crear)
```

---

## 📝 Checklist de Integración

Cuando se modifica ev-reth:

- [ ] Cambios compilados sin errores
- [ ] Imagen Docker creada exitosamente
- [ ] Imagen probada localmente en andechain
- [ ] Tests de contracts pasando
- [ ] Performance sin degradación
- [ ] Logs sin errores/warnings
- [ ] Imagen publicada en registry
- [ ] docker-compose.yml actualizado en andechain
- [ ] Documentación actualizada
- [ ] Changelog actualizado en ambos repos

---

## ⚠️ Troubleshooting Común

### Error: "Precompile not found"

**Causa:** Imagen Docker no actualizada o precompile no registrado

**Solución:**
```bash
# Verificar versión de imagen
docker compose ps | grep ev-reth-sequencer

# Forzar pull de imagen actualizada
docker compose pull ev-reth-sequencer

# Reiniciar
docker compose down -v
docker compose up -d
```

### Error: "Unauthorized caller"

**Causa:** Dirección de ANDEToken no coincide con la hardcodeada en precompile

**Solución:**
```bash
# 1. Obtener dirección real de ANDEToken
cast call <PROXY_ADDRESS> "implementation()" --rpc-url http://localhost:8545

# 2. Verificar que coincide con ANDETOKEN_ADDRESS en precompile
# (Si no, recompilar ev-reth con dirección correcta)
```

### Compilación de ev-reth Falla

**Causa:** Dependencias de Rust faltantes

**Solución:**
```bash
cd ~/dev/ande-labs/ev-reth

# Instalar dependencias del sistema
# macOS:
brew install openssl@3

# Linux:
sudo apt-get install libssl-dev pkg-config

# Limpiar y recompilar
cargo clean
cargo build --release
```

---

## 📞 Soporte

### Para Issues de ev-reth
- **Repo:** https://github.com/ande-labs/ev-reth/issues
- **Email:** dev@andelabs.io

### Para Issues de Integración
- **Repo:** https://github.com/ande-labs/andechain/issues
- **Discord:** #dev-support en Discord de AndeChain

---

## 🔗 Referencias

- **ev-reth upstream:** https://github.com/evstack/ev-reth
- **reth documentation:** https://paradigmxyz.github.io/reth/
- **Token Duality Plan:** [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)
- **Quick Start:** [QUICK_START.md](./QUICK_START.md)

---

**Última actualización:** 2025-10-07
**Mantenido por:** Ande Labs DevOps Team
