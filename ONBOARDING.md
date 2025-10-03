# Manual de Incorporación para Ingenieros de AndeChain

## 1. Visión y Potencial del Proyecto (El "Porqué")

Bienvenido a AndeChain. No estamos construyendo una blockchain más; estamos construyendo una solución soberana para la fragmentación financiera de América Latina.

Nuestra visión, detallada en `planande.md`, es crear un ecosistema económico regional que comienza en Bolivia y se expande. El objetivo es resolver problemas del mundo real como la evasión de controles de capital, las remesas lentas y costosas, y la protección contra la inflación. Para lograrlo, hemos diseñado un sofisticado motor económico, **Tokenomics V3.0**, implementado sobre una infraestructura tecnológica de vanguardia.

## 2. Arquitectura Técnica (El "Qué")

Hemos construido una **Base Sólida Extendida** que consiste en un **Rollup Soberano EVM sobre Celestia**. Esta arquitectura, definida en `andechain/infra`, nos da lo mejor de dos mundos: la soberanía y escalabilidad de un rollup modular, y el acceso al gigantesco ecosistema de herramientas y desarrolladores de Ethereum (EVM).

El sistema se compone de tres capas principales que corren en contenedores Docker:

1.  **Capa de Ejecución (El "Motor"):**
    *   **Tecnología:** `Reth` (Cliente de ejecución de Ethereum de alto rendimiento).
    *   **Función:** Ejecuta la lógica de nuestros Smart Contracts escritos en Solidity. Es el corazón que procesa las transacciones.

2.  **Capa de Secuenciación (El "Director de Orquesta"):**
    *   **Tecnología:** `Evolve / ev-node` (basado en Rollkit).
    *   **Función:** Ordena las transacciones, crea los bloques y los envía a la capa de ejecución y a la de disponibilidad de datos. Es el cerebro que dirige el rollup.

3.  **Capa de Disponibilidad de Datos (El "Notario Público"):**
    *   **Tecnología:** `local-da` (simulador de Celestia para desarrollo local).
    *   **Función:** Garantiza que los datos de las transacciones sean públicos y verificables, asegurando la transparencia y seguridad del rollup.

Además, la base incluye un **Explorador de Bloques** (Blockscout) y un **Faucet**, herramientas esenciales para un ciclo de desarrollo eficiente.

## 3. Guía Práctica de Despliegue y Desarrollo (El "Cómo")

Esta sección es la guía paso a paso para levantar y trabajar con el proyecto.

### 3.1. Requisitos Previos

1.  **Docker Desktop**: Es la "fábrica de maquetas" que corre nuestros contenedores. Asegúrate de que esté instalado y en ejecución en su versión más reciente.
    *   **Descarga aquí**: [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)
2.  **Node.js y npm**: Necesarios para gestionar las dependencias de los contratos. `npm` viene incluido con Node.js.

### 3.2. Configuración Inicial (UNA SOLA VEZ)

(Los pasos de clonación y configuración inicial del `.env` no cambian)

### 3.3. Uso Diario del Entorno

(La gestión del stack de Docker con `up`, `down`, `ps` no cambia)

### 3.4. Puntos de Acceso y Herramientas

*   **RPC Endpoint (para desarrolladores):** `http://localhost:8545`
*   **Explorador de Bloques:** `http://localhost:4000`
*   **Faucet:** `http://localhost:8081`

### 3.5. Flujo de Desarrollo de Smart Contracts

Esta sección ha sido reescrita para reflejar las mejores prácticas que descubrimos durante nuestro ciclo de securitización.

#### **La Estrategia de Pruebas Correcta: La Pirámide de Testing**

Para un desarrollo rápido y fiable, separamos nuestras pruebas en dos niveles:

**Nivel 1: Tests Unitarios y de Integración (El 99% del tiempo)**
- **Propósito**: Probar la lógica de cada contrato de forma rápida y aislada.
- **Entorno**: **Red de memoria de Hardhat**. Es instantánea, limpia en cada ejecución y nos permite controlar el tiempo.
- **Comando Estándar** (desde `andechain/infra`):
  ```bash
  docker compose run --build contracts npm test
  ```

**Nivel 2: Tests End-to-End (E2E)**
- **Propósito**: Probar el flujo completo del sistema en un entorno idéntico a producción.
- **Entorno**: Nuestro **Rollup local** (`ev-reth-sequencer`).
- **Comando E2E** (desde `andechain/infra`):
  ```bash
  docker compose run --build contracts npm test -- --network localhost
  ```

#### **Configuración de Tests Unitarios (Estándar del Proyecto)**

TODAS las suites de tests unitarios (`*.test.ts`) deben usar `ethers.getSigners()` para obtener cuentas de prueba con fondos. Este es el patrón canónico para la red de memoria de Hardhat.

**Ejemplo de `beforeEach` Estándar:**
```typescript
    let owner: HardhatEthersSigner, user1: HardhatEthersSigner;

    beforeEach(async function() {
        [owner, user1] = await ethers.getSigners();

        // ... Aquí va la lógica de despliegue de tus contratos ...
        const MyContractFactory = await ethers.getContractFactory("MyContract", owner);
        const myContract = await upgrades.deployProxy(MyContractFactory, [/* args */]);
        await myContract.waitForDeployment();
    });
```

#### **Lecciones Críticas de Nuestro Viaje de Securización**

1.  **Dependencias de OpenZeppelin v5+**: La estructura de los paquetes cambió. Las **Interfaces** (`IVotes`) y **Librerías** (`SafeERC20`, `ECDSA`) se importan desde `@openzeppelin/contracts`, mientras que las **Implementaciones Actualizables** (`ERC20Upgradeable`) vienen de `@openzeppelin/contracts-upgradeable`.

2.  **Contratos Actualizables y `constructors`**: Los contratos que usan el patrón de proxy actualizable **NO DEBEN tener un `constructor`**. Toda la lógica de inicialización debe ir en una función `initializer`.

3.  **Herencia en Solidity (`virtual` / `override`)**: Para sobreescribir una función de un contrato padre, la función original **DEBE** estar marcada como `virtual`. La función hija debe usar `override`.

4.  **Manejo de Errores de Acceso**: Las versiones recientes de OpenZeppelin emiten `Custom Errors` (ej. `AccessControlUnauthorizedAccount`) en lugar de `reason strings`. Los tests deben esperar estos errores específicos con `revertedWithCustomError`.

5.  **El Entorno es Frágil (La "Solución Nuclear")**: Si te encuentras con errores extraños que no tienen sentido (como `function selector not recognized` a pesar de que la función existe), es muy probable que la caché de Hardhat esté corrupta. La solución más rápida y fiable es purgar el entorno y reinstalar.
    *   **Comando Mágico**: `rm -rf artifacts cache typechain-types node_modules/.cache && npm install`

6.  **La Brecha entre Desarrollo y Producción**: Un prototipo funcional no es un producto final. Nuestro `P2POracleV2` es el ejemplo perfecto:
    *   **Para Desarrollo**: Lo hicimos funcionar devolviendo el último precio reportado para agilizar las pruebas.
    *   **Para Producción**: Lo robustecimos para que solo devuelva un precio finalizado tras un consenso de mediana ponderada por stake. Esta distinción es **crítica** para la seguridad.

7.  **Los Decimales No Mienten**: El bug más difícil de rastrear que encontramos se debió a un manejo incorrecto de decimales entre el `MockOracle` (8 decimales) y el `AusdToken` (que esperaba 18). En DeFi, un error de decimales es un error de millones de dólares. Siempre valida y normaliza.

#### **Comandos de Desarrollo**

Siempre desde la carpeta `andechain/infra`:

-   **Ejecutar TODOS los tests unitarios (Recomendado):**
    ```bash
    docker compose run --build contracts npm test
    ```

-   **Ejecutar un archivo de prueba específico:**
    ```bash
    docker compose run --build contracts npm exec -- hardhat test test/veANDE.test.ts
    ```

### 3.6. Verificación del Entorno E2E (Health Check)

Para verificar que tu stack de Docker y la conexión con el rollup `localhost` funcionan correctamente, puedes ejecutar un test E2E específico como `verify-gas-token.ts`. Este test **SÍ USA** el patrón de crear billeteras manualmente desde el `.env`, porque necesita probar una cuenta específica que fue fondeada en el génesis de tu rollup.

```bash
# Desde andechain/infra
docker compose run --build contracts npm exec -- hardhat test test/verify-gas-token.ts --network localhost
```

El éxito de este test confirma que tu entorno E2E está listo.

## 4. Automatización con GitHub Actions (El "Guardián de la Calidad")

(Sin cambios en esta sección)

## 5. Próximos Pasos

(Sin cambios en esta sección)

Este documento debe servir como tu mapa y brújula. ¡Bienvenido a bordo!