# Estrategia de Control de Ramas Git

## 📋 Índice
1. [Estructura de Ramas](#estructura-de-ramas)
2. [Flujo de Trabajo](#flujo-de-trabajo)
3. [Nomenclatura](#nomenclatura)
4. [Comandos Esenciales](#comandos-esenciales)
5. [Mejores Prácticas](#mejores-prácticas)
6. [Resolución de Conflictos](#resolución-de-conflictos)

---

## 🌳 Estructura de Ramas

### Ramas Principales (Permanentes)

#### **`main` (o `master`)**
- **Propósito**: Código en producción
- **Estabilidad**: 100% estable y probado
- **Deploy**: Automático a producción
- **Protección**: Solo merge via Pull Request con aprobación
- **Nunca** hacer commit directo aquí

#### **`develop`**
- **Propósito**: Rama de integración y desarrollo
- **Estabilidad**: Estable pero en desarrollo activo
- **Deploy**: Ambiente de staging/testing
- **Fusiona**: Features completadas antes de ir a main

### Ramas Temporales (Se eliminan después del merge)

#### **`feature/*`**
- **Propósito**: Desarrollo de nuevas funcionalidades
- **Ejemplos**: 
  - `feature/tokenomics-implementation`
  - `feature/user-authentication`
  - `feature/dashboard-ui`
- **Origen**: Se crea desde `develop`
- **Destino**: Se fusiona de vuelta a `develop`
- **Duración**: Días a semanas

#### **`bugfix/*`**
- **Propósito**: Corrección de bugs en desarrollo
- **Ejemplos**: 
  - `bugfix/login-validation`
  - `bugfix/token-calculation`
- **Origen**: Se crea desde `develop`
- **Destino**: Se fusiona a `develop`

#### **`hotfix/*`**
- **Propósito**: Corrección urgente en producción
- **Ejemplos**: 
  - `hotfix/critical-security-patch`
  - `hotfix/payment-gateway-down`
- **Origen**: Se crea desde `main`
- **Destino**: Se fusiona a `main` Y `develop`
- **Prioridad**: ALTA - Deployment inmediato

#### **`release/*`**
- **Propósito**: Preparación de nueva versión
- **Ejemplos**: 
  - `release/v1.2.0`
  - `release/v2.0.0-beta`
- **Origen**: Se crea desde `develop`
- **Destino**: Se fusiona a `main` y `develop`
- **Uso**: Ajustes finales, testing, documentación de versión

---

## 🔄 Flujo de Trabajo

### Escenario 1: Nueva Funcionalidad

```bash
# 1. Actualizar develop
git checkout develop
git pull origin develop

# 2. Crear rama feature
git checkout -b feature/nombre-de-la-feature

# 3. Trabajar y hacer commits
git add .
git commit -m "feat: implement new feature"

# 4. Mantener actualizado (hacer rebase frecuentemente)
git checkout develop
git pull origin develop
git checkout feature/nombre-de-la-feature
git rebase develop

# 5. Cuando termines, push a remoto
git push origin feature/nombre-de-la-feature

# 6. Crear Pull Request en GitHub/GitLab
# develop ← feature/nombre-de-la-feature

# 7. Después del merge, eliminar rama
git checkout develop
git pull origin develop
git branch -d feature/nombre-de-la-feature
git push origin --delete feature/nombre-de-la-feature
```

### Escenario 2: Hotfix Urgente en Producción

```bash
# 1. Crear hotfix desde main
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug

# 2. Corregir el bug
git add .
git commit -m "hotfix: fix critical bug"

# 3. Push y crear PR a main
git push origin hotfix/critical-bug
# Crear PR: main ← hotfix/critical-bug

# 4. IMPORTANTE: También fusionar a develop
git checkout develop
git pull origin develop
git merge hotfix/critical-bug
git push origin develop

# 5. Eliminar rama hotfix
git branch -d hotfix/critical-bug
git push origin --delete hotfix/critical-bug
```

---

## 📝 Nomenclatura

### Nombres de Ramas
```
feature/nombre-descriptivo-en-kebab-case
bugfix/descripcion-del-bug
hotfix/problema-critico
release/v1.2.0
```

### Mensajes de Commit (Conventional Commits)

```bash
# Tipos principales
feat:     Nueva funcionalidad
fix:      Corrección de bug
docs:     Cambios en documentación
style:    Formato, espacios (sin cambio de código)
refactor: Refactorización de código
test:     Agregar o modificar tests
chore:    Tareas de mantenimiento
perf:     Mejoras de performance

# Ejemplos
git commit -m "feat(tokenomics): add staking rewards calculator"
git commit -m "fix(auth): resolve login token expiration issue"
git commit -m "docs(readme): update installation instructions"
```

---

## ✅ Mejores Prácticas

1. **Commits Pequeños y Frecuentes**: Cada commit debe representar un cambio lógico.
2. **Mantén Tus Ramas Actualizadas**: Usa `git pull --rebase origin develop` frecuentemente.
3. **Pull Requests (PR) / Merge Requests (MR)**: Siempre usa PR para fusionar a `main` o `develop`.
4. **Proteger Ramas Principales**: En GitHub/GitLab, configura reglas de protección para `main` y `develop`.
5. **Limpieza Regular**: Borra las ramas locales y remotas que ya han sido fusionadas.

---

## 🔥 Resolución de Conflictos

### Rebase
```bash
git checkout feature/mi-feature
git rebase develop

# Si hay conflictos:
# 1. Editar archivos con conflictos
# 2. Marcar como resueltos
git add archivo-conflicto.js
git rebase --continue

# Si te arrepientes
git rebase --abort
```

### Merge
```bash
git checkout develop
git merge feature/mi-feature

# Si hay conflictos:
# 1. Resolver conflictos en archivos
# 2. Agregar archivos resueltos
git add .
git commit -m "merge: resolve conflicts from feature/mi-feature"
```
