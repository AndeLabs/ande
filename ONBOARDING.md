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

### 3.2. Entorno Local

La gestión del stack se realiza desde `andechain/infra`. Los comandos principales son:

-   **Levantar el stack:**
    ```bash
    cd andechain/infra
    docker compose up -d --build
    ```
-   **Verificar el estado:**
    ```bash
    docker compose ps
    ```
-   **Detener el stack:**
    ```bash
    docker compose down
    ```

### 3.3. Puntos de Acceso

*   **RPC Endpoint:** `http://localhost:8545`
*   **Explorador de Bloques:** `http://localhost:4000`
*   **Faucet:** `http://localhost:8081`

### 3.4. Flujo de Desarrollo de Smart Contracts (Foundry)

El ciclo de vida del desarrollo de contratos se centra en el directorio `andechain/contracts`.

**1. Instalar Dependencias:**
Foundry gestiona las dependencias (ej. OpenZeppelin) como submódulos de Git.
```bash
cd andechain/contracts
forge install
```

**2. Compilar:**
```bash
forge build
```

**3. Probar:**
Las pruebas se escriben en Solidity (`*.t.sol`) y son extremadamente rápidas.
```bash
forge test
```

**4. Desplegar:**
Los despliegues se realizan mediante scripts de Solidity.
```bash
forge script script/MiScript.s.sol --rpc-url http://localhost:8545 --broadcast
```

### 3.5. Lecciones Críticas de Nuestro Viaje de Desarrollo

1.  **Dependencias de OpenZeppelin v5+**: La estructura de los paquetes cambió. Las **Interfaces** (`IVotes`) y **Librerías** (`SafeERC20`) se importan desde `@openzeppelin/contracts`, mientras que las **Implementaciones Actualizables** (`ERC20Upgradeable`) vienen de `@openzeppelin/contracts-upgradeable`.

2.  **Contratos Actualizables y `constructors`**: Los contratos que usan el patrón de proxy actualizable **NO DEBEN tener un `constructor`**. Toda la lógica de inicialización debe ir en una función `initializer`.

3.  **Herencia en Solidity (`virtual` / `override`)**: Para sobreescribir una función de un contrato padre, la función original **DEBE** estar marcada como `virtual`. La función hija debe usar `override`.

4.  **Manejo de Errores de Acceso**: Las versiones recientes de OpenZeppelin emiten `Custom Errors` (ej. `AccessControlUnauthorizedAccount`) en lugar de `reason strings`. Los tests en Foundry deben esperar estos errores específicos con `vm.expectRevert(abi.encodeWithSelector(MyContract.MyCustomError.selector, ...))`.

5.  **El Entorno es Frágil (La "Solución Nuclear")**: Si te encuentras con errores extraños, es probable que la caché de Foundry esté corrupta. La solución más rápida es purgarla: `forge clean` seguido de `forge build`.

6.  **Los Decimales No Mienten**: Un bug muy difícil de rastrear que encontramos se debió a un manejo incorrecto de decimales entre un oráculo y un token. En DeFi, un error de decimales es un error de millones de dólares. Siempre valida y normaliza.

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