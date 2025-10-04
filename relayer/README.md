# AndeChain Bridge Relayer

Este servicio es un componente off-chain crítico que escucha los eventos del contrato `AndeBridge` en AndeChain, los publica en la capa de disponibilidad de datos (Celestia), y completa la transacción en la red de destino (Ethereum).

## Guía Rápida

### 1. Instalación

```bash
npm install
```

### 2. Configuración

Crea un archivo `.env` a partir de la plantilla. Este archivo contendrá tus claves privadas y URLs de RPC.

```bash
cp .env.example .env
```

Asegúrate de que las direcciones de los contratos y las URLs en el archivo `.env` sean correctas para tu entorno.

### 3. Ejecución

Para iniciar el servicio del relayer en modo de escucha, ejecuta:

```bash
npm start
```

El relayer se conectará a la RPC de AndeChain y esperará nuevos eventos `BridgeInitiated` para procesarlos.
