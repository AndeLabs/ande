# 🏗️ Infraestructura de AndeChain (Docker)

Este directorio contiene toda la configuración de Docker para levantar un entorno de desarrollo local completo de AndeChain.

## Arquitectura de Servicios

El sistema se orquesta a través del archivo principal `docker-compose.yml`, que a su vez incluye las definiciones de los servicios ubicados en el directorio `stacks/`.

### Servicios Principales

1.  **`ev-reth-sequencer` (`stacks/single-sequencer/`)**
    *   **Imagen:** `ghcr.io/evstack/ev-reth:latest`
    *   **Propósito:** Es el **Motor de Ejecución (EVM)**. Procesa las transacciones, actualiza el estado y expone el endpoint RPC en `http://localhost:8545`.
    *   **Configuración Clave:** Lo ejecutamos con el flag `--dev` para que genere cuentas pre-fondeadas. Además, monta nuestro `genesis.final.json` para asegurar que la moneda nativa y los saldos iniciales sean los correctos para AndeChain.

2.  **`single-sequencer` (`stacks/single-sequencer/`)**
    *   **Imagen:** `ghcr.io/evstack/ev-node-evm-single:main`
    *   **Propósito:** Es el **Secuenciador**. Ordena las transacciones que recibe del motor de ejecución, las empaqueta en bloques y las publica en la capa de disponibilidad de datos.

3.  **`local-da` (`stacks/da-local/`)**
    *   **Imagen:** Construida localmente desde el código fuente en `ev-node/da`.
    *   **Propósito:** Es nuestro **Simulador de Celestia**. Actúa como la capa de **Disponibilidad de Datos (DA)**, recibiendo los bloques del secuenciador y haciéndolos disponibles a través de su propia API en `http://localhost:7980`.

### Servicios de Soporte

*   **`blockscout-` (varios servicios en `stacks/eth-explorer/`):** Un explorador de bloques completo accesible en `http://localhost:4000`.
*   **`eth-faucet` (`stacks/eth-faucet/`):** Un faucet que, aunque está corriendo, **no usamos activamente** porque nuestro `genesis.final.json` ya nos provee de fondos.

## Gestión del Entorno

### Flujo de Trabajo Principal (Recomendado)

La forma recomendada de iniciar y gestionar el ecosistema completo (infraestructura + contratos) es a través de los comandos `make` definidos en el directorio raíz de `andechain/`.

Estos comandos aseguran que todos los servicios se inicien en el orden correcto y que los contratos se desplieguen automáticamente.

```bash
# Navega al directorio raíz de andechain
cd ..

# Inicia la infraestructura, despliega y verifica los contratos
make deploy-ecosystem
make verify-contracts
```

Para más detalles, consulta el archivo `ONBOARDING.md`.

### Comandos de Gestión Manual

Los siguientes comandos `docker compose` son útiles si necesitas gestionar o depurar la capa de infraestructura de forma aislada.

-   **Iniciar o reiniciar el entorno:**
    El uso de `down -v` y `--force-recreate` asegura que la blockchain se cree desde cero, aplicando cualquier cambio en la configuración.
    ```bash
    # Desde andechain/infra/
    docker compose down -v && docker compose up -d --force-recreate
    ```

-   **Ver logs de un servicio específico:**
    Muy útil para depurar. Por ejemplo, para ver los logs del secuenciador:
    ```bash
    docker compose logs -f single-sequencer
    ```

-   **Detener los servicios:**
    ```bash
    docker compose down
    ```