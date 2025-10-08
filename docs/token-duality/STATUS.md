# Token Duality - Estado del Proyecto

**Última actualización:** 2025-10-07
**Rama actual:** `feature/token-duality-poc`
**Estado:** 📝 Planificación Completada → 🚀 Listo para Implementación

---

## ✅ Completado

### Fase de Planificación
- [x] **Análisis de arquitectura actual**
  - Revisión de ANDEToken.sol y dependencias
  - Identificación de WAndeVault.sol para deprecación
  - Análisis de tests existentes

- [x] **Especificación técnica**
  - Diseño del precompile (dirección 0x...fd)
  - Definición de interfaz y validaciones
  - Arquitectura de integración con ANDEToken.sol

- [x] **Plan de implementación completo**
  - 7 fases detalladas (docs/token-duality/IMPLEMENTATION_PLAN.md)
  - Checklist de seguridad
  - Plan de testing
  - Estrategia de migración de WANDE

- [x] **Organización de repositorio**
  - Rama `feature/token-duality-poc` creada desde `develop`
  - Documentación estructurada en `docs/token-duality/`
  - Referencias añadidas en ROADMAP_CONCEPTUAL.md

### Documentación Creada
- [x] `docs/token-duality/README.md` - Overview y navegación
- [x] `docs/token-duality/IMPLEMENTATION_PLAN.md` - Plan detallado de 7 fases
- [x] `docs/token-duality/QUICK_START.md` - Guía rápida para desarrolladores
- [x] `docs/token-duality/STATUS.md` - Este archivo

---

## 🚧 En Progreso

**Ninguna tarea actualmente en progreso.**

Siguiente paso: Ejecutar Fase 1 del plan de implementación.

---

## ⏳ Pendiente (Por Orden de Prioridad)

### Fase 1: Fork y Setup de ev-reth
- [ ] Forkear https://github.com/evstack/ev-reth en cuenta ande-labs
- [ ] Clonar fork localmente
- [ ] Configurar upstream remote
- [ ] Crear rama `feature/ande-precompile`
- [ ] Explorar estructura del proyecto

**Responsable sugerido:** Ingeniero con experiencia en Rust
**Tiempo estimado:** 1 hora

### Fase 2: Modificación del Precompile en revm
- [ ] Localizar archivo `crates/revm/src/precompile.rs`
- [ ] Añadir constantes de dirección (ANDETOKEN_ADDRESS, CELO_TRANSFER_PRECOMPILE)
- [ ] Implementar función `celo_transfer()`
- [ ] Registrar precompile en `berlin_precompiles()`
- [ ] Compilar y verificar (`cargo build -p revm --release`)

**Responsable sugerido:** Ingeniero con experiencia en Rust + EVM
**Tiempo estimado:** 4-8 horas

### Fase 3: Compilación de Ande-Reth
- [ ] Compilar binario completo (`cargo build --release`)
- [ ] Crear Dockerfile optimizado
- [ ] Build imagen Docker (`andelabs/ande-reth:token-duality-v1`)
- [ ] (Opcional) Push a GitHub Container Registry

**Responsable sugerido:** DevOps / Ingeniero de Infraestructura
**Tiempo estimado:** 2-4 horas (primera compilación puede tardar)

### Fase 4: Modificación de ANDEToken.sol
- [ ] Backup de contrato original
- [ ] Override `balanceOf()` para leer `address.balance`
- [ ] Override `_update()` para llamar al precompile
- [ ] Implementar función `migrateToNative()` (temporal)
- [ ] Verificar compilación (`forge build`)

**Responsable sugerido:** Ingeniero de Smart Contracts
**Tiempo estimado:** 3-6 horas

### Fase 5: Testing Completo
- [ ] Crear `test/unit/TokenDuality.t.sol`
- [ ] Implementar tests core de Token Duality
- [ ] Implementar tests de compatibilidad ERC-20
- [ ] Implementar tests de gobernanza (voting)
- [ ] Implementar tests de seguridad (pause, permisos)
- [ ] Ejecutar tests contra nodo local con Ande-Reth

**Responsable sugerido:** Ingeniero de Smart Contracts + QA
**Tiempo estimado:** 6-12 horas

### Fase 6: Integración con Infraestructura
- [ ] Modificar `infra/stacks/single-sequencer/docker-compose.da.local.yml`
- [ ] Actualizar imagen de `ev-reth-sequencer` a custom
- [ ] Actualizar `genesis.final.json` con dirección de ANDEToken
- [ ] Verificar deployment end-to-end
- [ ] Realizar pruebas de integración completas

**Responsable sugerido:** DevOps + Ingeniero de Infraestructura
**Tiempo estimado:** 4-8 horas

### Fase 7: Deprecación de WANDE
- [ ] Marcar `WAndeVault.sol` con `@custom:deprecated`
- [ ] Crear `docs/token-duality/WANDE_MIGRATION_GUIDE.md`
- [ ] Actualizar `contracts/README.md`
- [ ] Comunicar cambios al equipo y usuarios

**Responsable sugerido:** Technical Writer + Product Manager
**Tiempo estimado:** 2-4 horas

---

## 📊 Progreso General

```
Fase de Planificación:  ████████████████████ 100% ✅
Fase 1 (Fork ev-reth):  ░░░░░░░░░░░░░░░░░░░░   0%
Fase 2 (Precompile):    ░░░░░░░░░░░░░░░░░░░░   0%
Fase 3 (Compilación):   ░░░░░░░░░░░░░░░░░░░░   0%
Fase 4 (ANDEToken.sol): ░░░░░░░░░░░░░░░░░░░░   0%
Fase 5 (Testing):       ░░░░░░░░░░░░░░░░░░░░   0%
Fase 6 (Integración):   ░░░░░░░░░░░░░░░░░░░░   0%
Fase 7 (Deprecación):   ░░░░░░░░░░░░░░░░░░░░   0%

TOTAL:                  ██░░░░░░░░░░░░░░░░░░  12.5%
```

---

## 🎯 Próximos Pasos Inmediatos

### Para Comenzar la Implementación

1. **Asignar Fase 1 a un desarrollador Rust**
   ```bash
   # Desarrollador debe ejecutar:
   # 1. Fork de ev-reth en GitHub
   # 2. git clone https://github.com/ande-labs/ev-reth.git
   # 3. cd ev-reth && git checkout -b feature/ande-precompile
   ```

2. **Revisar documentación técnica**
   - Leer `docs/token-duality/IMPLEMENTATION_PLAN.md` (Fase 2)
   - Estudiar código de ejemplo del precompile
   - Familiarizarse con estructura de revm

3. **Setup de entorno de desarrollo Rust**
   ```bash
   # Verificar instalaciones
   rustc --version  # >= 1.75.0
   cargo --version
   ```

### Recursos de Referencia

- **Celo Fee Abstraction (inspiración):** https://github.com/celo-org/celo-proposals/blob/master/CIPs/cip-0064.md
- **revm Precompiles:** https://github.com/bluealloy/revm/tree/main/crates/precompile
- **ev-reth Upstream:** https://github.com/evstack/ev-reth

---

## 📝 Notas Importantes

### Consideraciones de Seguridad

⚠️ **CRÍTICO:** Antes de deployment en mainnet:
- [ ] Auditoría de código Rust (precompile)
- [ ] Auditoría de smart contracts (ANDEToken.sol)
- [ ] Bug bounty en testnet (mínimo 1 mes)
- [ ] Load testing
- [ ] Plan de rollback documentado

### Dependencias Externas

- **ev-reth upstream:** Monitorear releases para mantener fork actualizado
- **revm version:** Verificar compatibilidad con versión usada por ev-reth

### Decisiones Pendientes

- [ ] **Dirección final de ANDEToken:** Actualizar `ANDETOKEN_ADDRESS` en precompile después de deployment
- [ ] **Registry de Docker:** ¿GitHub Container Registry o Docker Hub?
- [ ] **Timeline de deprecación de WANDE:** Definir fechas específicas

---

## 📞 Puntos de Contacto

- **Lead Técnico:** dev@andelabs.io
- **Seguridad:** security@andelabs.io
- **Preguntas sobre roadmap:** strategy@andelabs.io

---

## 🔄 Historial de Cambios

### 2025-10-07
- ✅ Completada fase de planificación
- ✅ Documentación estructurada creada
- ✅ Rama `feature/token-duality-poc` establecida
- ✅ Referencias añadidas en ROADMAP_CONCEPTUAL.md
- 📌 **Estado:** Listo para comenzar Fase 1 (implementación)

---

**Siguiente Actualización:** Cuando se complete Fase 1 (Fork de ev-reth)

**Para actualizar este archivo:**
```bash
git checkout feature/token-duality-poc
# Editar docs/token-duality/STATUS.md
git add docs/token-duality/STATUS.md
git commit -m "docs(token-duality): update STATUS.md with progress"
```
