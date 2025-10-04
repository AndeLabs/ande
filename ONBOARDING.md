# Manual de Incorporación para Ingenieros de AndeChain

## 1. Visión y Potencial del Proyecto (El "Porqué")

Bienvenido a AndeChain. No estamos construyendo una blockchain más; estamos construyendo una solución soberana para la fragmentación financiera de América Latina.

Nuestra visión es crear un ecosistema económico regional que resuelva problemas del mundo real. Para lograrlo, hemos diseñado un sofisticado motor económico implementado sobre una infraestructura tecnológica de vanguardia.

## 2. Arquitectura Técnica (El "Qué")

Hemos construido un **Rollup Soberano EVM sobre Celestia**. Esta arquitectura, centralizada en la carpeta `infra`, nos da soberanía, escalabilidad y acceso al ecosistema de herramientas de Ethereum.

El sistema se compone de las siguientes capas que corren en contenedores Docker:

1.  **Capa de Ejecución (El "Motor"):**
    *   **Servicio Docker:** `ev-reth-sequencer`
    *   **Tecnología:** `Reth` (Cliente de ejecución de Ethereum).
    *   **Función:** Ejecuta la lógica de nuestros Smart Contracts.

2.  **Capa de Secuenciación (El "Director de Orquesta"):**
    *   **Servicio Docker:** `single-sequencer`
    *   **Tecnología:** `Evolve / ev-node`.
    *   **Función:** Ordena las transacciones y crea los bloques.

3.  **Capa de Disponibilidad de Datos (El "Notario Público"):**
    *   **Servicio Docker:** `local-da`
    *   **Tecnología:** Simulador de Celestia.
    *   **Función:** Garantiza que los datos de las transacciones sean públicos y verificables.

## 3. Guía Práctica de Despliegue y Desarrollo (El "Cómo")

### 3.1. Requisitos Previos

1.  **Docker Desktop**: La base que corre toda nuestra infraestructura.
2.  **Foundry**: El kit de herramientas para compilar, probar y desplegar nuestros contratos de Solidity.

### 3.2. Gestión del Entorno Local

La gestión del stack se realiza desde `andechain/infra`. Los comandos principales son:

-   **Levantar el stack (desde cero):**
    ```bash
    cd andechain/infra
    docker compose up -d --build
    ```
-   **Verificar el estado:**
    ```bash
    docker compose ps
    ```
-   **Resetear COMPLETAMENTE el stack (La "Solución Nuclear"):**
    Para borrar la base de datos de la blockchain y empezar de cero, usa el flag `-v`. Este es el comando que usarás el 99% del tiempo para asegurar un estado limpio.
    ```bash
    docker compose down -v
    ```

### 3.3. Puntos de Acceso

*   **RPC Endpoint:** `http://localhost:8545`
*   **Explorador de Bloques:** `http://localhost:4000`

### 3.4. Flujo de Desarrollo de Smart Contracts (Foundry)

El ciclo de vida del desarrollo de contratos se centra en el directorio `andechain/contracts`.

**1. Compilar y Probar:**
```bash
cd andechain/contracts
forge build
forge test
```

**2. Desplegar en la Red Local:**

*   **Paso A: Obtén la Clave Privada.**
    Nuestra configuración actual **fondea automáticamente** la cuenta de desarrollo estándar de Foundry/Anvil. No necesitas buscarla en los logs ni usar el faucet.
    *   **Cuenta:** `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
    *   **Clave Privada:** `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

*   **Paso B: Ejecuta el Script de Despliegue.**
    Usa la clave privada en una variable de entorno y especifica el contrato a ejecutar con `--tc`.
    ```bash
    cd andechain/contracts
    export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    forge script script/DeployBridge.s.sol --tc DeployBridge --rpc-url local --broadcast
    ```

### 3.5. Flujo de Desarrollo del Relayer

El relayer es un servicio off-chain que conecta los puentes. Se gestiona desde `andechain/relayer`.

1.  **Instalar dependencias:**
    ```bash
    cd andechain/relayer
    npm install
    ```
2.  **Configurar:**
    Copia la plantilla de entorno y asegúrate de que las URLs y direcciones son correctas.
    ```bash
    cp .env.example .env
    ```
3.  **Ejecutar el relayer:**
    ```bash
    npm start
    ```

### 3.6. Troubleshooting y Lecciones Críticas de Nuestro Viaje

1.  **CRÍTICO - Error: `insufficient funds` al desplegar:**
    *   **Causa Definitiva:** El nodo `reth` por defecto no fondea ninguna cuenta y el `genesis.json` original es incorrecto.
    *   **Solución Implementada:**
        1.  El archivo `infra/stacks/single-sequencer/docker-compose.da.local.yml` ahora pasa el flag `--dev` al contenedor `ev-reth-sequencer`.
        2.  Se utiliza un `genesis.final.json` que monta directamente en `reth`, asignando un saldo inicial en `aande` a la cuenta de desarrollo `0xf39...`.
    *   **Acción:** Si vuelves a ver este error, la solución es siempre `docker compose down -v` para forzar al sistema a usar la configuración de génesis correcta desde cero.

2.  **Error: `method '...' not found` al llamar a `local-da`:**
    *   **Causa:** El simulador `local-da` tiene una API JSON-RPC no estándar.
    *   **Solución:** El método correcto es `da.Submit` y los parámetros deben ser `[ [array de blobs en base64], gasPrice, namespaceEnBase64 ]`.

3.  **Error: `namespace must be exactly 29 bytes`:**
    *   **Causa:** El namespace de Celestia debe tener una longitud fija de 29 bytes.
    *   **Solución:** Usamos un namespace válido como `0x0000000000000000000000000000000000000000000000000000000001`.

4.  **Error: `Cannot read properties of undefined (reading 'then')` en `ethers`:**
    *   **Causa:** Se está pasando un argumento `undefined` a una función de contrato. Nuestro bug específico fue no extraer los parámetros `indexed` de un evento desde `event.topics`.
    *   **Solución:** Los parámetros de eventos `indexed` se deben leer de `event.topics`, mientras que los no indexados se leen de `event.args`.

## 4. Estructura del Proyecto

```
andechain/
├── infra/                # <-- PUNTO DE ENTRADA PRINCIPAL (Docker)
│   ├── docker-compose.yml  # Orquesta todos los servicios.
│   └── stacks/             # Definiciones de cada servicio.
│
├── contracts/            # Contiene todos los Smart Contracts.
│   ├── src/                # Código fuente de los contratos (.sol).
│   ├── test/               # Pruebas de los contratos (.t.sol).
│   ├── script/             # Scripts de despliegue (.s.sol).
│   ├── foundry.toml        # Configuración de Foundry.
│   └── lib/                # Dependencias (submódulos de Git).
│
├── README.md             # Este documento.
└── ...
```

Este documento debe servir como tu mapa y brújula. ¡Bienvenido a bordo!