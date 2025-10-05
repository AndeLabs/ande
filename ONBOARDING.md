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

### 🚀 Flujo de Desarrollo Unificado (Recomendado)

Esta es la guía de inicio rápido para levantar todo el ecosistema local. Estos comandos deben ejecutarse desde la raíz del directorio `andechain/`.

**Paso 1: Iniciar la Infraestructura Blockchain**

Este comando levanta todos los servicios de backend (Nodo, Sequencer, Explorador de Bloques, etc.) en segundo plano.

```bash
# Desde la raíz de andechain/
cd infra
docker compose up -d --force-recreate
cd ..
```
*Nota: Usa `--force-recreate` para asegurar que los cambios en la configuración de Docker se apliquen. Si necesitas resetear la blockchain por completo, ejecuta `docker compose down -v` antes de este paso.*

**Paso 2: Desplegar y Verificar Contratos**

Estos comandos, definidos en el `Makefile`, compilan, despliegan y verifican todo el ecosistema de contratos inteligentes en la red local.

```bash
# Desde la raíz de andechain/
make deploy-ecosystem
make verify-contracts
```

**Paso 3: Iniciar el Frontend**

Este comando inicia la aplicación web de AndeFrontend.

```bash
# Navega al directorio del frontend
cd ../ande-frontend
npm run dev
```

**Paso 4: Acceder al Ecosistema**

*   **Frontend dApp:** [http://localhost:9002](http://localhost:9002)
*   **Explorador de Bloques (Blockscout):** [http://localhost:4000](http://localhost:4000)

---

### 📜 Guía para el Desarrollador de Smart Contracts

Tu trabajo se centra en el directorio `contracts/`. El **Flujo de Desarrollo Unificado** es la forma recomendada de desplegar, pero para el desarrollo y pruebas iterativas, estos comandos son tu día a día.

**1. Configuración Inicial (Solo una vez):**
```bash
cd contracts
forge install
```

**2. Ciclo de Desarrollo Típico:**
```bash
# Compilar contratos
forge build

# Ejecutar pruebas
forge test

# Obtener cobertura de pruebas
forge coverage
```

### 🌐 Guía para el Operador de Nodo

El **Flujo de Desarrollo Unificado** gestiona el inicio de la infraestructura. Los siguientes comandos son para gestión y troubleshooting.

```bash
# Navega al directorio de infraestructura
cd infra

# Verificar servicios activos
docker compose ps

# Detener todos los servicios
docker compose down

# Resetear la blockchain (borra todos los datos)
docker compose down -v
```

### 🔍 Guía para el Auditor o Explorador

Tu rol es interactuar con la red desplegada para verificar su estado.

*   **RPC Endpoint:** `http://localhost:8545`
*   **Explorador de Bloques:** `http://localhost:4000`
*   **Comandos `cast`:** Usa `cast` de Foundry para interactuar directamente con los contratos desde la línea de comandos. Revisa las direcciones en el `DEPLOYMENT SUMMARY` del comando `make deploy-ecosystem`.
    ```bash
    # Ejemplo: Verificar el balance de ANDE del desplegador
    cast balance --rpc-url http://localhost:8545 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
    ```
