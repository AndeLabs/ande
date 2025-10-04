# 🏔️ AndeChain - Un Rollup Soberano para LATAM

## 🌟 Visión

AndeChain es una blockchain soberana regional que inicia en Bolivia y se expande, construida como un **Rollup EVM sobre Celestia**. Nuestra misión es resolver la fragmentación financiera de América Latina a través de un sistema económico robusto y una infraestructura tecnológica de vanguardia.

Para una inmersión profunda en la visión y el modelo económico, consulta el documento de visión del proyecto.

## 🏗️ Arquitectura Técnica

Nuestro stack tecnológico está completamente contenedorizado con Docker y se gestiona desde el directorio `/infra`. Se compone de las siguientes capas principales:

1.  **Capa de Ejecución (El "Motor"):**
    *   **Servicio Docker:** `ev-reth-sequencer`
    *   **Tecnología:** `Reth` (Cliente de ejecución de Ethereum de alto rendimiento).
    *   **Función:** Ejecuta la lógica de nuestros Smart Contracts escritos en Solidity.

2.  **Capa de Secuenciación (El "Director de Orquesta"):**
    *   **Servicio Docker:** `single-sequencer`
    *   **Tecnología:** `Evolve / ev-node` (basado en Rollkit).
    *   **Función:** Ordena las transacciones, crea los bloques y los publica.

3.  **Capa de Disponibilidad de Datos (El "Notario Público"):**
    *   **Servicio Docker:** `local-da`
    *   **Tecnología:** Simulador de Celestia para desarrollo local.
    *   **Función:** Garantiza que los datos de las transacciones sean públicos y verificables.

El stack también incluye un **Explorador de Bloques** (`http://localhost:4000`) y un **Faucet** (`http://localhost:8081`) para un ciclo de desarrollo completo.

## 🚀 Guía de Inicio Rápido (Desarrollo Local)

**Requisitos:**
- Docker Desktop
- Foundry (Kit de herramientas para desarrollo en Solidity)

**Pasos:**

1.  **Navega al directorio de infraestructura:**
    ```bash
    cd andechain/infra
    ```

2.  **Configura el entorno:**
    Copia el archivo de ejemplo para crear tu configuración local. Para el desarrollo inicial, los valores por defecto son suficientes.
    ```bash
    cp .env.example .env
    ```

3.  **Lanza el Stack:**
    Este comando levantará todos los servicios en segundo plano.
    ```bash
    docker compose up -d --build
    ```
    ¡Y listo! Tu rollup soberano local estará funcionando en `http://localhost:8545`.

## 🛠️ Flujo de Desarrollo de Contratos (Foundry)

Todo el desarrollo de smart contracts se realiza en el directorio `andechain/contracts` usando **Foundry**.

1.  **Navega al directorio de contratos:**
    ```bash
    cd andechain/contracts
    ```

2.  **Instala Dependencias:**
    ```bash
    forge install
    ```

3.  **Compila los Contratos:**
    ```bash
    forge build
    ```

4.  **Ejecuta las Pruebas:**
    ```bash
    forge test
    ```

5.  **Despliega un Script:**
    ```bash
    forge script script/Counter.s.sol --rpc-url http://localhost:8545 --broadcast
    ```

## 📚 Documentación Adicional

Para una inmersión más profunda, consulta las siguientes guías dentro de este directorio (`andechain`):

-   **[GUIA_DESPLIEGUE_LOCAL.md](./GUIA_DESPLIEGUE_LOCAL.md)**: Guía detallada del entorno local.
-   **[ONBOARDING.md](./ONBOARDING.md)**: Manual de incorporación para nuevos ingenieros, con lecciones aprendidas y patrones de diseño.
-   **[GIT_WORKFLOW.md](./GIT_WORKFLOW.md)**: Nuestras convenciones y estrategia de ramas para contribuir al proyecto.