# Token Duality - Documentación del Proyecto

**Estado:** 🚧 En Desarrollo (PoC)
**Rama:** `feature/token-duality-poc`
**Alineación:** FASE 0 del [ROADMAP_CONCEPTUAL.md](../ROADMAP_CONCEPTUAL.md)

---

## 📚 Documentación Disponible

### 1. [Plan de Implementación](./IMPLEMENTATION_PLAN.md)
**Documento principal** con el plan completo de 7 fases:
- Fase 1: Fork y setup de ev-reth
- Fase 2: Modificación del precompile en revm
- Fase 3: Compilación de Ande-Reth
- Fase 4: Modificación de ANDEToken.sol
- Fase 5: Testing completo
- Fase 6: Integración con infraestructura
- Fase 7: Deprecación de WANDE

### 2. [Especificación Técnica](./TECHNICAL_SPEC.md)
Detalles técnicos del precompile y arquitectura:
- Dirección del precompile: `0x00...fd`
- Interfaz del precompile
- Modificaciones a ANDEToken.sol
- Flujos de transferencia

### 3. [Guía de Testing](./TESTING_GUIDE.md)
Instrucciones para ejecutar tests:
- Unit tests del precompile (Rust)
- Integration tests de contratos (Solidity)
- End-to-end tests

### 4. [Guía de Migración WANDE](./WANDE_MIGRATION.md)
Para usuarios con WANDE existente:
- Timeline de deprecación
- Pasos para unwrap
- FAQ

---

## 🎯 Objetivo

Transformar ANDE en un **token dual** que funcione simultáneamente como:
1. ✅ Token nativo para pagar gas fees
2. ✅ Token ERC-20 estándar para dApps

**Beneficio clave:** Eliminar la necesidad de WANDE (Wrapped ANDE)

---

## 🏗️ Arquitectura en Resumen

```
Usuario/DApp
    ↓
ANDEToken.sol (Proxy)
    ↓ balanceOf() → lee address.balance
    ↓ transfer() → llama precompile
    ↓
Precompile (0x...fd en ev-reth)
    ↓ Valida caller == ANDEToken
    ↓ Ejecuta transferencia nativa
    ↓
EVM State (balance nativo)
```

---

## 📋 Estado Actual del Proyecto

### ✅ Completado
- [x] Análisis de arquitectura actual
- [x] Especificación técnica del precompile
- [x] Plan de implementación completo
- [x] Rama feature creada

### 🚧 En Progreso
- [ ] Fork de ev-reth
- [ ] Implementación del precompile en revm

### ⏳ Pendiente
- [ ] Compilación de Ande-Reth
- [ ] Modificación de ANDEToken.sol
- [ ] Suite de tests
- [ ] Integración con infraestructura
- [ ] Deprecación de WANDE

---

## 🚀 Inicio Rápido

### Para Desarrolladores

```bash
# 1. Cambiar a la rama del feature
git checkout feature/token-duality-poc

# 2. Leer el plan de implementación
cat docs/token-duality/IMPLEMENTATION_PLAN.md

# 3. Seguir las fases del plan
# Actualmente: Fase 1 - Fork de ev-reth
```

### Para Revisores

1. Revisar [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)
2. Verificar alineación con [ROADMAP_CONCEPTUAL.md](../ROADMAP_CONCEPTUAL.md)
3. Evaluar riesgos en sección "Riesgos y Mitigación"
4. Revisar checklist de seguridad

---

## 🔗 Enlaces Importantes

- **Roadmap Conceptual:** [../ROADMAP_CONCEPTUAL.md](../ROADMAP_CONCEPTUAL.md)
- **Arquitectura ABOB:** [../ABOB_TECHNICAL_ARCHITECTURE.md](../ABOB_TECHNICAL_ARCHITECTURE.md)
- **Git Workflow:** [../GIT_WORKFLOW.md](../GIT_WORKFLOW.md)
- **ev-reth upstream:** https://github.com/evstack/ev-reth
- **revm upstream:** https://github.com/bluealloy/revm

---

## 📞 Contacto

- **Team Lead:** dev@andelabs.io
- **Security:** security@andelabs.io
- **Discord:** https://discord.gg/andechain

---

## 📝 Licencia

Este proyecto es parte de AndeChain y sigue la misma licencia MIT del proyecto principal.
