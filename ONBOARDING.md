# Manual de Operaciones de AndeChain

## 1. Visión del Proyecto (El "Porqué")

Bienvenido a AndeChain. No estamos construyendo una blockchain más; estamos construyendo una solución soberana para la fragmentación financiera de América Latina. Nuestra visión es crear un ecosistema económico regional que resuelva problemas del mundo real, implementado sobre una infraestructura tecnológica de vanguardia.

## 2. Anatomía del Proyecto (El "Qué")

Esta sección detalla la estructura de directorios y el propósito de cada componente clave.

```
andechain/
├── infra/                # <-- GESTIÓN DEL ENTORNO BLOCKCHAIN
│   ├── docker-compose.yml  # Orquesta todos los servicios (DA, Sequencer, EVM).
│   ├── stacks/             # Definiciones de cada servicio individual.
│   │   ├── da-local/       # Contiene la configuración del Data Availability local.
│   │   ├── single-sequencer/ # Contiene la lógica del Sequencer y el nodo EVM.
│   │   │   ├── genesis.final.json # ¡CLAVE! Nuestro génesis modificado que pre-funda cuentas.
│   │   │   └── entrypoint.sequencer.sh # Script que inicia y parchea el génesis.
│   │   └── ...
│   └── .env                # Variables de entorno para el stack.
│
├── contracts/            # <-- DESARROLLO DE SMART CONTRACTS (FOUNDRY)
│   ├── src/                # Código fuente de los contratos (.sol).
│   ├── test/               # Pruebas unitarias de los contratos (.t.sol).
│   ├── script/             # Scripts de despliegue (.s.sol).
│   ├── foundry.toml        # Archivo de configuración principal de Foundry.
│   └── lib/                # Dependencias (ej. OpenZeppelin).
│
├── relayer/              # <-- SERVICIO OFF-CHAIN PARA EL BRIDGE
│   ├── src/                # Código fuente del relayer en TypeScript.
│   │   ├── listeners/      # Escucha eventos on-chain.
│   │   ├── processors/     # Procesa datos y genera pruebas.
│   │   └── submitters/     # Envía transacciones a Celestia y Ethereum.
│   ├── package.json        # Dependencias de Node.js.
│   ├── .env.example        # Plantilla de variables de entorno para el relayer.
│   └── tsconfig.json       # Configuración de TypeScript.
│
└── ONBOARDING.md         # Este documento.
```

---

## 3. Guías por Rol

A continuación se presentan guías específicas según tu rol en el proyecto.

### 📜 Guía para el Desarrollador de Smart Contracts

Tu trabajo se centra en el directorio `contracts/`.

**1. Configuración Inicial (Solo una vez):**
Instala las dependencias de Foundry.
```bash
cd andechain/contracts
forge install
```

**2. Ciclo de Desarrollo Típico:**

*   **Compilar:** Verifica que no haya errores de sintaxis.
    ```bash
    forge build
    ```
*   **Probar:** Ejecuta todas las pruebas unitarias.
    ```bash
    forge test
    ```

**3. Desplegar y Probar en la Red Local:**

*   **Asegúrate de que el entorno esté corriendo.** (Ver la guía del Operador de Nodo).

*   **Obtén la Clave Privada de Desarrollo:** Nuestra red local pre-funda la siguiente cuenta con `aande` para pagar el gas. No necesitas un faucet.
    *   **Clave Privada:** `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

*   **Ejecuta tu Script de Despliegue:**
    ```bash
    # Navega al directorio de contratos
    cd andechain/contracts

    # Exporta la clave privada
    export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

    # Ejecuta el script especificando el contrato con --tc
    forge script script/DeployBridge.s.sol --tc DeployBridge --rpc-url local --broadcast
    ```

### 🌐 Guía para el Operador de Nodo y Relayer

Tu trabajo se centra en los directorios `infra/` y `relayer/`.

**1. Levantar el Entorno Blockchain Completo:**
Este comando construye las imágenes de Docker si no existen y levanta todos los servicios (DA, Sequencer, EVM, Explorador, etc.).
```bash
cd andechain/infra
docker compose up -d --build
```

**2. Gestionar el Ciclo de Vida del Entorno:**

*   **Verificar Servicios Activos:**
    ```bash
    docker compose ps
    ```
*   **Resetear la Blockchain (Comando más común):**
    Para empezar desde cero, borrando todos los datos de la cadena, usa el flag `-v`. Esto es esencial para aplicar cambios en el `genesis.json`.
    ```bash
    docker compose down -v
    ```

**3. Ejecutar el Servicio de Relayer:**

*   **Instalación (Solo una vez):**
    ```bash
    cd andechain/relayer
    npm install
    ```
*   **Configuración (Solo una vez):**
    Crea tu archivo de configuración local a partir de la plantilla.
    ```bash
    cp .env.example .env
    ```
    *Nota: Asegúrate de que las variables en `.env` (especialmente las direcciones de los contratos) coincidan con las desplegadas en tu red local.*

*   **Iniciar el Relayer:**
    Este comando inicia el servicio, que se quedará escuchando eventos de la blockchain en la misma terminal.
    ```bash
    npm start
    ```

### 🔍 Guía para el Auditor o Explorador

Tu rol es interactuar con la red desplegada para verificar su estado y comportamiento.

**1. Puntos de Acceso:**

*   **RPC Endpoint (para `cast` o dApps):** `http://localhost:8545`
*   **Explorador de Bloques:** Abre `http://localhost:4000` en tu navegador para ver transacciones y bloques en tiempo real.

**2. Comandos Útiles con `cast` (de Foundry):**
Estos comandos se ejecutan desde cualquier terminal, ya que `cast` suele estar en tu PATH.

*   **Verificar el Saldo de una Cuenta:**
    ```bash
    cast balance --rpc-url http://localhost:8545 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
    ```

*   **Llamar a una Función de Solo Lectura (`view`):**
    Por ejemplo, para ver la aprobación de un token ERC20.
    ```bash
    # cast call <DIRECCION_CONTRATO> "<FIRMA_FUNCION>" <ARGUMENTOS...>
    cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "allowance(address,address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
    ```

*   **Enviar una Transacción (como la de `approve`):**
    ```bash
    cast send <DIRECCION_CONTRATO> "<FIRMA_FUNCION>" <ARGUMENTOS...> --rpc-url local --private-key <TU_CLAVE>
    ```
