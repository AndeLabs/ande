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

**Paso 1: Clona el Repositorio**

Obtén el código del proyecto desde nuestro repositorio de GitHub.

```bash
# Reemplaza la URL por la del repositorio final
git clone https://github.com/ande-labs/andechain.git
cd andechain
```

**Paso 2: Configura la Infraestructura**

Navega a la carpeta de infraestructura, que será tu centro de operaciones principal.

```bash
cd andechain/infra
```

Copia los archivos de ejemplo de configuración para crear tus archivos locales.

```bash
# Copia la configuración general
cp .env.example .env

# Copia la configuración del Faucet
cp stacks/eth-faucet/.env.example stacks/eth-faucet/.env
```

**Paso 3: Añade tus Llaves Privadas**

⚠️ **ACCIÓN MANUAL REQUERIDA:**

Para poder ejecutar las pruebas de forma robusta, necesitas un total de tres cuentas de desarrollo (owner, user1, user2). Abre el archivo `infra/.env` y añade las tres llaves privadas. La primera (`PRIVATE_KEY`) será fondeada en el génesis de la blockchain.

```env
# Llave para la cuenta principal (owner), fondeada en el génesis.
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Llaves adicionales para cuentas de prueba (user1, user2).
PRIVATE_KEY_USER1=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
PRIVATE_KEY_USER2=0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
```

**Importante:** Para que las herramientas de Hardhat y Ethers.js funcionen, **DEBES incluir el prefijo `0x`** en tus llaves privadas.

**Paso 4: Lanza el Stack**

Desde el directorio `andechain/infra`, este único comando levantará todos los servicios en segundo plano.

```bash
docker compose up -d --build
```
¡Listo! Después de unos minutos, toda la pila de AndeChain estará funcionando.

### 3.3. Uso Diario del Entorno

Desde el directorio `andechain/infra`:

-   **Verificar el estado:** `docker compose ps`
-   **Iniciar el entorno:** `docker compose up -d`
-   **Detener el entorno:** `docker compose down`
-   **Ver logs de un servicio:** `docker compose logs -f single-sequencer`

### 3.4. Puntos de Acceso y Herramientas

*   **RPC Endpoint (para desarrolladores):** `http://localhost:8545`
*   **Explorador de Bloques:** `http://localhost:4000`
*   **Faucet:** `http://localhost:8081`

### 3.5. Flujo de Desarrollo de Smart Contracts

La interacción y prueba de los smart contracts se realiza a través de un servicio de Docker controlado desde el directorio `infra`. Esto garantiza un entorno consistente y reproducible.

#### **Lección Aprendida Crítica: El Entorno de Pruebas**

Tras una extensa depuración, hemos descubierto una **incompatibilidad fundamental** entre el plugin `@openzeppelin/hardhat-upgrades` y nuestro entorno de pruebas (`--network localhost` que corre sobre `ev-reth-sequencer`).

- **El Problema:** El plugin interfiere con la función `ethers.getSigners()`, causando que las pruebas fallen de formas impredecibles al no poder obtener las cuentas del nodo.
- **La Solución (Estándar del Proyecto):** Para evitar este problema, **TODAS las pruebas deben seguir el patrón de creación manual de billeteras**. En lugar de usar `ethers.getSigners()`, se deben inicializar las billeteras directamente desde las llaves privadas definidas en el archivo `.env`.

Este método es más robusto y nos independiza de la incompatibilidad del plugin.

#### **Lección Aprendida Crítica #2: El Entorno de Pruebas Correcto**

Inicialmente, se intentó ejecutar las pruebas unitarias y de integración directamente contra el stack de Docker de nuestra red soberana (`--network localhost`). Sin embargo, este enfoque demostró ser **frágil e inestable**, resultando en errores esporádicos y fallos difíciles de depurar relacionados con la finalización de transacciones y la compatibilidad del entorno.

- **El Problema:** La red `ev-reth-sequencer` tiene su propio tiempo de bloque y particularidades que no son ideales para la ejecución rápida y determinista de cientos de pruebas unitarias.
- **La Solución (Nuevo Estándar del Proyecto):**
    1.  **Pruebas Unitarias y de Integración:** Se deben ejecutar utilizando la **red en memoria de Hardhat**. Es el estándar de la industria, es increíblemente rápida y proporciona un entorno limpio y predecible para cada ejecución de prueba. Para forzar este comportamiento, hemos comentado la configuración de `localhost` en `hardhat.config.ts`.
    2.  **Pruebas End-to-End (E2E):** Las pruebas contra la red soberana real (`localhost`) se deben reservar para un conjunto separado de pruebas E2E, que se enfocarán en verificar la integración completa del sistema, no la lógica de un solo contrato.

Este enfoque nos da lo mejor de ambos mundos: velocidad y fiabilidad para el desarrollo diario, y una verificación completa del sistema antes de un despliegue.

#### **Lección Aprendida Crítica #3: Rutas de Importación en OpenZeppelin v5+**

Durante la implementación del `DualTrackBurnEngine`, nos encontramos con errores de compilación `HH404: File not found` a pesar de que las rutas de importación parecían correctas. La investigación reveló un cambio importante en la estructura de los paquetes de OpenZeppelin a partir de la versión 5.

- **El Problema:** Las versiones anteriores de OpenZeppelin proporcionaban variantes "actualizables" de las interfaces y librerías (ej. `IERC20Upgradeable.sol`, `SafeERC20Upgradeable.sol`) dentro del paquete `@openzeppelin/contracts-upgradeable`.
- **La Solución (Estándar v5+):** A partir de la v5, esta duplicación se ha eliminado. Al interactuar con contratos actualizables, se deben importar las interfaces y librerías estándar directamente desde el paquete `@openzeppelin/contracts`. El sistema de Hardhat y OpenZeppelin se encarga de enlazar correctamente la implementación actualizable.

**Ejemplo Práctico:**

```solidity
// INCORRECTO (para v5+)
// import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

// CORRECTO (para v5+)
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
```

Este conocimiento es crucial para evitar errores de compilación y entender la estructura moderna de los contratos de OpenZeppelin.

#### **Paso 1: Preparar el Entorno de Contratos (Solo la primera vez)**

Este paso no cambia. Asegúrate de tener las dependencias instaladas.

```bash
# Navega al directorio de los contratos
cd andechain/contracts

# Instala las dependencias
npm install

# Regresa al directorio de infraestructura
cd ../infra
```

#### **Paso 2: Escribir Pruebas (El Método Correcto)**

Todas las nuevas suites de pruebas (`*.test.ts`) deben usar el siguiente bloque de configuración en su `beforeEach` para ser compatibles con nuestro entorno.

**Ejemplo de `beforeEach` Estándar:**
```typescript
    let owner: ethers.Wallet, user1: ethers.Wallet, user2: ethers.Wallet;

    beforeEach(async function() {
        const provider = ethers.provider;
        // Crear billeteras desde las llaves privadas del .env
        owner = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
        user1 = new ethers.Wallet(process.env.PRIVATE_KEY_USER1!, provider);
        user2 = new ethers.Wallet(process.env.PRIVATE_KEY_USER2!, provider);

        // Fondear cuentas de prueba con gas desde la cuenta owner (fondeada en génesis)
        await (await owner.sendTransaction({ to: user1.address, value: ethers.parseEther("1.0") })).wait();
        await (await owner.sendTransaction({ to: user2.address, value: ethers.parseEther("1.0") })).wait();

        // ... Aquí va la lógica de despliegue de tus contratos ...
        // const MyContractFactory = await ethers.getContractFactory("MyContract", owner);
        // const myContract = await upgrades.deployProxy(MyContractFactory, [/* args */]);
        // await myContract.waitForDeployment();
    });
```

#### **Paso 3: Interactuar con los Contratos desde la Carpeta `infra`**

Para asegurar que las pruebas se ejecuten en un entorno estable, hemos modificado `docker-compose.yml` para que el servicio `contracts` dependa explícitamente de `ev-reth-sequencer`. Asimismo, el `hardhat.config.ts` ha sido simplificado.

-   **Ejecutar TODAS las pruebas (Recomendado):**
    Este comando ejecuta todas las suites de pruebas contra nuestra red de desarrollo local.
    ```bash
    docker compose run --build contracts npm test -- --network localhost
    ```

-   **Ejecutar un archivo de prueba específico:**
    ```bash
    docker compose run --build contracts npm exec -- hardhat test test/veANDE.test.ts --network localhost
    ```

-   **Compilar y otros comandos:**
    Estos comandos no cambian.
    ```bash
    docker compose run --build contracts npm run compile
    docker compose run contracts /bin/sh
    ```

### 3.5.2. Flujo de Desarrollo Avanzado: Contratos Actualizables

A medida que el proyecto madura, utilizamos patrones de contratos actualizables (upgradeable) para permitir la mejora de la lógica de negocio sin migrar datos. Esto se gestiona con el plugin `@openzeppelin/hardhat-upgrades`.

**Lecciones Aprendidas en la Configuración:**

-   **Conflicto de Herencia con `nonces`:** Al combinar `ERC20PermitUpgradeable` y `ERC20VotesUpgradeable`, ambos contratos definen una función `nonces`. Solidity requiere que anulemos (override) explícitamente esta función en nuestro contrato final (`ANDEToken.sol`) para resolver la ambigüedad.
-   **Incompatibilidad con el Entorno de Pruebas `localhost`:** Como se detalló en la sección anterior, el uso de `upgrades.deployProxy()` junto con nuestro nodo de desarrollo `ev-reth-sequencer` rompe la funcionalidad de `ethers.getSigners()`. Por esta razón, **es mandatorio usar el patrón de creación manual de billeteras** para todas las pruebas que involucren contratos actualizables.

### 3.6. Verificación del Entorno (Health Check)

Después de levantar el stack de Docker, es una excelente práctica realizar una verificación para asegurar que todos los componentes se comunican correctamente.

El test `verify-gas-token.ts` es perfecto para esto, ya que utiliza el método de conexión directa (creando un `provider` y `wallet` manualmente) que hemos establecido como el estándar. Su ejecución exitosa confirma que:
- La conexión entre el entorno de pruebas y el nodo RPC es correcta.
- Las variables de entorno (como tu `PRIVATE_KEY`) se están cargando adecuadamente.
- El fondeo de cuentas en el génesis funciona.

Para ejecutar esta verificación, navega al directorio `andechain/infra` y corre:

```bash
docker compose run --build contracts npm exec -- hardhat test test/verify-gas-token.ts --network localhost
```

Si este test pasa, tu entorno de desarrollo local está 100% operativo para empezar a construir, teniendo en cuenta las consideraciones sobre la estrategia de pruebas ya mencionadas.

Si este test pasa, tu entorno de desarrollo local está 100% operativo y listo para que empieces a construir.

## 4. Automatización con GitHub Actions (El "Guardián de la Calidad")

(La sección de CI/CD permanece igual que en la versión anterior del ONBOARDING.md)

Hemos integrado un pipeline de CI/CD en `.github/workflows/ci-cd.yml` que automatiza la calidad y seguridad en cada cambio. Este es nuestro guardián.

### ¿Cómo nos Ayuda?

1.  **Calidad del Código (`lint`):** En cada Pull Request, revisa automáticamente que el código de Solidity cumpla con las mejores prácticas y el formato estándar usando `solhint` y `prettier`.
2.  **Pruebas Automáticas (`test`):** Ejecuta toda nuestra suite de pruebas de los smart contracts con `npm test`.
3.  **Verificación de Compilación (`build`):** Asegura que los contratos siempre compilen correctamente.
4.  **Escaneo de Seguridad (`security`):** Utiliza `Trivy` para escanear el repositorio en busca de vulnerabilidades.
5.  **Asistentes de IA (`documentation` y `ai-review`):** Automatiza la generación de documentación y las revisiones de código en Pull Requests.

## 5. Próximos Pasos

Nuestra infraestructura está lista, probada, versionada y documentada. El siguiente paso es construir el motor económico de la cadena, basado en nuestra arquitectura **Tokenomics V3.0**. La implementación se divide en los siguientes módulos de contratos inteligentes:

1.  **`ANDEToken.sol`:**
    *   ✅ **Implementado y Probado:** El contrato ERC-20 actualizable que servirá como token nativo ya está implementado.
    *   ✅ **Funcionalidad Base:** Incluye roles de acceso (`MINTER_ROLE`) y la funcionalidad `ERC20Votes` para la gobernanza.
    *   **Siguiente Paso:** Integrar con los demás contratos del motor económico.

2.  **`veANDE.sol`:**
    *   Implementar la lógica de vote-escrow, permitiendo a los usuarios bloquear `ANDE` por hasta 4 años.
    *   Desarrollar el cálculo de poder de voto que decrece linealmente con el tiempo.
    *   Incluir el sistema de `Gauge Voting` para que la comunidad dirija los incentivos.

3.  **`DualTrackBurnEngine.sol`:**
    *   Implementar la lógica para la quema en tiempo real de una porción de las tarifas de transacción (Track 1).
    *   Desarrollar la funcionalidad para las quemas trimestrales programadas basadas en las ganancias del protocolo (Track 2).

4.  **`MintController.sol`:**
    *   Implementar las barreras de seguridad críticas: límite máximo de suministro (hard cap) y límite de emisión anual.
    *   Crear el sistema de propuestas y votación por supermayoría para autorizar cualquier nueva emisión de tokens.

5.  **Pruebas y Simulación:**
    *   Escribir suites de pruebas unitarias y de integración exhaustivas para todos los nuevos contratos.
    *   Desarrollar simulaciones para modelar la economía bajo diferentes escenarios y validar la sostenibilidad del modelo.

Este documento debe servir como tu mapa y brújula. ¡Bienvenido a bordo!
