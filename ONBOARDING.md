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

**Paso 3: Añade tu Llave Privada**

⚠️ **ACCIÓN MANUAL REQUERIDA:**

Necesitas una cuenta de Ethereum con su llave privada. Esta cuenta será fondeada en el génesis y la usarás para interactuar con la red.

1.  Abre el archivo `infra/.env` que acabas de crear.
2.  Añade la siguiente línea al final, reemplazando `0x...` con tu llave privada:
    ```
    PRIVATE_KEY=0x...
    ```

**Importante:** Para que las herramientas de Hardhat y Ethers.js funcionen, **DEBES incluir el prefijo `0x`** en tu llave privada.

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

La interacción y prueba de los smart contracts se realiza a través de un servicio de Docker controlado desde el directorio `infra`. Esto garantiza un entorno consistente y reproducible para todos los desarrolladores.

#### **Paso 1: Preparar el Entorno de Contratos (Solo la primera vez)**

Antes de poder ejecutar pruebas o scripts, necesitas que `npm` instale las dependencias de los contratos. Esto creará el archivo `package-lock.json` necesario para las builds de Docker.

```bash
# Navega al directorio de los contratos
cd andechain/contracts

# Instala las dependencias
npm install

# Regresa al directorio de infraestructura
cd ../infra
```

#### **Paso 2: Interactuar con los Contratos desde la Carpeta `infra`**

Todos los comandos para compilar, probar o interactuar con los contratos se ejecutan desde el directorio `andechain/infra`.

-   **Ejecutar todas las pruebas:**
    El comando más común. Reconstruye el entorno si es necesario y corre toda la suite de tests.
    ```bash
    docker compose run --build contracts npm test
    ```

-   **Ejecutar un archivo de prueba específico:**
    Útil para centrarse en un solo test.
    ```bash
    docker compose run --build contracts npm exec -- hardhat test test/mi-prueba.ts --network localhost
    ```

-   **Compilar los contratos:**
    ```bash
    docker compose run --build contracts npm run compile
    ```

-   **Abrir una terminal dentro del contenedor:**
    Para ejecutar comandos ad-hoc o depurar.
    ```bash
    docker compose run contracts /bin/sh
    ```

-   **Desplegar a la red local (usando Hardhat Ignition):**
    *Nota: El plugin de Ignition fue deshabilitado temporalmente. Se debe resolver el conflicto de dependencias antes de usar este comando.*
    ```bash
    docker compose run --build contracts npm exec -- hardhat ignition deploy ignition/modules/MiModulo.ts --network localhost
    ```

### 3.5.2. Flujo de Desarrollo Avanzado: Contratos Actualizables

A medida que el proyecto madura, utilizamos patrones de contratos actualizables (upgradeable) para permitir la mejora de la lógica de negocio sin migrar datos. Esto introduce dependencias y consideraciones específicas.

**Dependencias Clave:**

Para trabajar con contratos actualizables, el entorno de `contracts` necesita dos paquetes principales de OpenZeppelin:

1.  `@openzeppelin/contracts-upgradeable`: Proporciona las implementaciones base de contratos como `ERC20Upgradeable` que están diseñadas para ser usadas detrás de un proxy.
2.  `@openzeppelin/hardhat-upgrades`: Es el plugin de Hardhat que nos da las herramientas para desplegar y gestionar los proxies (ej. `upgrades.deployProxy`).

Estas dependencias ya están incluidas en `andechain/contracts/package.json`.

**Lecciones Aprendidas en la Configuración:**

-   **Conflicto de Herencia con `nonces`:** Al combinar `ERC20PermitUpgradeable` y `ERC20VotesUpgradeable`, ambos contratos definen una función `nonces`. Solidity requiere que anulemos (override) explícitamente esta función en nuestro contrato final (`ANDEToken.sol`) para resolver la ambigüedad.
-   **Pruebas con Proxies:** Las pruebas para contratos actualizables son ligeramente diferentes. En lugar de desplegar el contrato directamente, se utiliza `upgrades.deployProxy()` para simular el entorno de producción real, que incluye el contrato de implementación y el proxy.

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
