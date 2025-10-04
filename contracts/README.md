# 🏗️ Arquitectura de Smart Contracts de AndeChain

Este directorio contiene todo el código de Solidity para el ecosistema de AndeChain, gestionado con [Foundry](https://book.getfoundry.sh/).

##  Anatomía de los Contratos

-   `src/`: Contiene el código fuente de todos los contratos desplegables.
    -   `tokens/`: Contratos de los tokens del ecosistema (`ANDEToken`, `AusdToken`, `AbobToken`).
    -   `bridge/`: Los contratos `AndeBridge` y `EthereumBridge` que conforman el puente.
    -   `gov/`: Contratos relacionados a la gobernanza (`veANDE`, `MintController`).
    -   `oracles/`: Contratos de oráculos, como el `P2POracleV2`.
    -   `mocks/`: Contratos de prueba para simular componentes en el entorno local.
-   `test/`: Pruebas unitarias y de integración para cada contrato.
-   `script/`: Scripts para automatizar despliegues y interacciones.
-   `foundry.toml`: Archivo de configuración principal de Foundry.

## Contratos Principales

| Contrato | Propósito |
| :--- | :--- |
| `ANDEToken.sol` | Implementación del token nativo $ANDE (ERC20, Votes). |
| `veANDE.sol` | Contrato de *Vote Escrow* para bloquear $ANDE y obtener poder de voto. |
| `MintController.sol` | Gobierna la emisión de nuevos tokens $ANDE. |
| `AndeBridge.sol` | Contrato de origen del puente. Bloquea tokens y emite eventos. |
| `EthereumBridge.sol` | Contrato de destino del puente. Verifica pruebas de DA y libera fondos. |

## Flujo de Desarrollo

El ciclo de vida completo se gestiona con `forge`.

1.  **Compilar:**
    ```bash
    forge build
    ```

2.  **Probar:**
    Ejecuta todas las pruebas. Para ejecutar un solo archivo, usa `forge test --match-path test/MiPrueba.t.sol`.
    ```bash
    forge test
    ```

3.  **Ver Cobertura de Pruebas:**
    Genera un reporte de qué líneas de código están cubiertas por las pruebas.
    ```bash
    forge coverage
    ```

4.  **Desplegar:**
    Usa el perfil `local` definido en `foundry.toml`.
    ```bash
    export PRIVATE_KEY=<TU_CLAVE_PRIVADA>
    forge script script/DeployBridge.s.sol --tc DeployBridge --rpc-url local --broadcast
    ```

## Interactuando con Contratos Usando `cast`

`cast` es una herramienta poderosa para interactuar con los contratos desplegados desde la línea de comandos.

-   **Leer un valor:**
    ```bash
    # Llama a la función `name()` de un contrato ERC20
    cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "name()" --rpc-url local
    ```

-   **Enviar una transacción:**
    ```bash
    # Llama a la función `approve()` de un ERC20
    cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "approve(address,uint256)" <SPENDER> <AMOUNT> --rpc-url local --private-key $PRIVATE_KEY
    ```