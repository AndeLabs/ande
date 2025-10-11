# Khipu: Hoja de Ruta Estratégica para los Hackathons de Mezo e ICP

---

## 🎯 Visión General Estratégica: Construcción en Dos Fases

Nuestra estrategia para abordar los hackathons de Mezo (Octubre) e ICP (Noviembre) se basa en un principio de **construcción incremental y reutilización inteligente**. En lugar de empezar de cero dos veces, construiremos una base sólida en el primer hackathon y la elevaremos al siguiente nivel en el segundo.

*   **Fase 1 (Mezo): Construir la Fortaleza.** Crearemos un Producto Mínimo Viable (MVP) completamente funcional y pulido llamado **Khipu**. Este proyecto se centrará en el ecosistema EVM, que dominamos, para asegurar una entrega de alta calidad y maximizar nuestras posibilidades de ganar.
*   **Fase 2 (ICP): Expandir la Fortaleza.** Tomaremos el proyecto ganador de Mezo y lo mejoraremos con la tecnología de "Chain Fusion" de ICP. Reemplazaremos componentes centralizados o más simples con las soluciones criptográficas avanzadas de ICP, como la custodia nativa de BTC mediante firmas de umbral.

Este enfoque nos permite tener un producto competitivo en ambos eventos, mitigar riesgos y demostrar una visión a largo plazo.

### Cronología Visual de la Estrategia

```
Octubre 2025: Foco en Mezo
├─ Módulo 1: Fundación y Configuración
├─ Módulo 2: Desarrollo de Contratos EVM
├─ Módulo 3: Desarrollo de Frontend
├─ Módulo 4: Pruebas e Integración
└─ Módulo 5: Pulido y Entrega ✅

Noviembre 2025: Foco en ICP
├─ Módulo 1: Inmersión y Setup de ICP
├─ Módulo 2: Desarrollo de Canister de Custodia
├─ Módulo 3: Integración Rollup <-> ICP
└─ Módulo 4: Pruebas y Entrega Final ✅
```

---

## 🏰 Fase 1: Plan de Batalla para el Hackathon de Mezo

**Objetivo:** Construir y presentar un MVP impecable de **Khipu**, una bóveda de rendimiento auto-compuesta para MUSD.

### Módulo 1: Cimientos y Configuración

*   **[ ] Configurar el Repositorio:** Crear un nuevo repositorio para "Khipu" basado en nuestro rollup AndeChain.
*   **[ ] Configurar el Entorno de Contratos:** Inicializar un proyecto con Foundry y configurarlo para que se conecte a la testnet de Mezo.
*   **[ ] Obtener Activos de Prueba:** Conseguir MUSD y tokens de gas necesarios de la testnet de Mezo.
*   **[ ] Desplegar el Rollup Base:** Asegurar que una versión de AndeChain esté operativa en un entorno de prueba para la demo.

### Módulo 2: El Núcleo del Protocolo (Contratos Inteligentes)

*   **[ ] Contrato `KhipuVault.sol` (Bóveda de Colateral):**
    *   Implementar la lógica para `deposit()` y `withdraw()` de colateral (WBTC).
    *   Implementar la lógica para `borrow()` y `repay()` de MUSD.
    *   Asegurar el cálculo correcto del ratio de colateralización y los reverts de seguridad.
    *   Emitir eventos detallados para cada acción (`CollateralDeposited`, `MusdBorrowed`, etc.).

*   **[ ] Contrato `YieldStrategy.sol` (Estrategia de Rendimiento):**
    *   Implementar una única y simple estrategia de rendimiento (ej. depositar MUSD en un pool de préstamos de Mezo).
    *   Crear funciones `invest()` para desplegar los fondos y `harvest()` para recolectar ganancias.

*   **[ ] Contrato `PriceOracle.sol` (Oráculo de Precios):**
    *   Implementar un oráculo simple con un propietario que pueda actualizar el precio del BTC/USD para el MVP.

*   **[ ] Contrato `LiquidationEngine.sol` (Motor de Liquidación):**
    *   Implementar una lógica de liquidación simple donde un liquidador puede repagar deuda a cambio de colateral con descuento.

*   **[ ] Script de Despliegue:**
    *   Crear un script en Foundry para desplegar y configurar todos los contratos de manera automatizada.

### Módulo 3: La Interfaz (Frontend)

*   **[ ] Configuración del Proyecto:** Iniciar un proyecto React/Next.js con `wagmi` y `viem`.
*   **[ ] Componentes de Interacción:** Desarrollar componentes para la conexión de billetera y los formularios de depósito/préstamo.
*   **[ ] Dashboard del Usuario:** Crear una interfaz clara que muestre la posición del usuario, el ratio de colateralización (con un indicador de salud visual) y las ganancias generadas.

### Módulo 4: Pruebas e Integración End-to-End

*   **[ ] Conectar Frontend y Contratos:** Integrar la UI con los contratos desplegados en la testnet.
*   **[ ] Probar el Flujo de Usuario Completo:** Realizar pruebas exhaustivas del ciclo completo: depósito, préstamo, generación de rendimiento, repago y retiro.
*   **[ ] Simular y Probar Liquidaciones:** Asegurarse de que el mecanismo de liquidación funcione como se espera.

### Módulo 5: Seguridad y Pulido

*   **[ ] Revisión de Seguridad:** Auditar internamente los contratos en busca de vulnerabilidades comunes (re-entrada, control de acceso, etc.).
*   **[ ] Mejoras de UI/UX:** Añadir estados de carga, manejo de errores y notificaciones para una experiencia de usuario fluida y profesional. Asegurar el diseño responsivo.

### Módulo 6: Entrega y Presentación

*   **[ ] Documentación (`README.md`):** Crear un `README.md` claro para el proyecto Khipu.
*   **[ ] Video Demo (2-3 minutos):** Producir un video de demostración conciso y potente.
*   **[ ] Pitch Deck:** Preparar una presentación que resuma el problema, la solución y el potencial del proyecto.

---

## 💎 Fase 2: Plan de Evolución para el Hackathon de ICP

**Objetivo:** Evolucionar Khipu, reemplazando su mecanismo de custodia de BTC por la tecnología "Chain Fusion" de ICP para una descentralización y seguridad superiores.

### Arquitectura de la Actualización

```diff
+ ┌─────────────────────────────────┐
+ │  ICP Canister (Rust/Motoko)      │
+ │  - Custodia Nativa de BTC        │
+ │  - Firmas de Umbral (Threshold)  │
+ └────────────┬────────────────────┘
+              │ (Llamadas Seguras)
               │
┌──────────────▼──────────────────┐
│   Khipu en AndeChain     │
│   (Contratos ya existentes)     │
│   - Modificados para verificar   │
│     las firmas del Canister ICP.│
└─────────────────────────────────┘
```

### Módulo 1: Inmersión en el Ecosistema ICP

*   **[ ] Configurar Entorno de Desarrollo:** Instalar `dfx` y configurar un proyecto de ICP.
*   **[ ] Canister Básico:** Desarrollar y desplegar un canister "Hola Mundo" para familiarizarse con el flujo de trabajo.

### Módulo 2: Desarrollo del Canister de Custodia

*   **[ ] Implementar Custodia de BTC:** Crear un canister que pueda generar y gestionar direcciones de Bitcoin de forma nativa.
*   **[ ] Integrar Firmas de Umbral:** Utilizar la funcionalidad de Threshold ECDSA/Schnorr de ICP para permitir que el canister firme transacciones de Bitcoin de manera descentralizada.

### Módulo 3: Puente de Comunicación (Rollup <-> ICP)

*   **[ ] Desarrollar un Módulo de Relay/Escucha:** Crear un servicio que pueda comunicar las solicitudes de nuestro rollup a los canisters de ICP y devolver las respuestas (firmas).

### Módulo 4: Actualización del Protocolo Khipu

*   **[ ] Modificar `KhipuVault.sol`:** Actualizar el contrato para que, en lugar de gestionar colateral en una multisig simple, interactúe con el Canister de ICP para verificar depósitos y autorizar retiros de BTC nativo.

### Módulo 5: Pruebas y Presentación Final

*   **[ ] Probar el Nuevo Flujo:** Realizar pruebas E2E del nuevo sistema de custodia descentralizado.
*   **[ ] Adaptar el Pitch:** Actualizar la presentación y el video demo para destacar la innovación principal: **la eliminación de puentes y la custodia nativa de BTC**, todo orquestado desde nuestro rollup soberano a través de ICP.

---

## 🚀 Próximos Pasos Inmediatos

Para comenzar hoy con la Fase 1:

1.  **[ ] Crear el repositorio para `Khipu`.**
2.  **[ ] Configurar el proyecto de Foundry y la conexión a la testnet de Mezo.**
3.  **[ ] Obtener MUSD y otros tokens de prueba.**
4.  **[ ] Empezar a escribir el esqueleto del contrato `KhipuVault.sol`.**