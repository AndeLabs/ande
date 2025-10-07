# AndeChain Account Abstraction Bundler

Un bundler de Account Abstraction (ERC-4337) optimizado para AndeChain, diseñado para permitir transacciones sin gas y wallets con recuperación social para usuarios bolivianos.

## 🚀 Características

- **Account Abstraction Completa**: Implementación completa de ERC-4337
- **Gasless Transactions**: Patrocinio de gas mediante AndePaymaster
- **Social Recovery**: Wallets con recuperación vía email/guardianes
- **Bundling Inteligente**: Optimización de UserOperations en bundles
- **JSON-RPC API**: Compatible con estándares EIP-4337
- **REST API**: Endpoints adicionales para conveniencia
- **Métricas en Tiempo Real**: Monitoreo completo del sistema
- **Seguridad Robusta**: Rate limiting, CORS, headers de seguridad

## 📋 Requisitos

- Node.js >= 18.0.0
- TypeScript >= 5.0
- Acceso a nodo AndeChain (local o producción)

## 🛠️ Instalación

```bash
# Instalar dependencias
npm install

# Compilar TypeScript
npm run build

# Iniciar en desarrollo
npm run dev
```

## ⚙️ Configuración

### Variables de Entorno

Crea un archivo `.env` con la siguiente configuración:

```bash
# Configuración Obligatoria
RPC_URL=http://localhost:8545
ENTRY_POINT_ADDRESS=0x4337084d9e255ff0702461cf8895ce9e3b5ff108
BENEFICIARY_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# Configuración del Bundler
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
MAX_BUNDLE_SIZE=10
MIN_BUNDLE_SIZE=1
BUNDLE_INTERVAL_MS=5000
GAS_MULTIPLIER=1.1

# Configuración de Gas
MAX_GAS_PRICE=100000000000  # 100 gwei
MIN_PRIORITY_FEE=1000000000 # 1 gwei

# Configuración del Servidor
PORT=3000
LOG_LEVEL=info
CORS_ORIGINS=http://localhost:3000,http://localhost:9002

# Tokens (Producción)
ANDE_TOKEN_ADDRESS=0x...
ABOB_TOKEN_ADDRESS=0x...
```

### Configuración de Desarrollo vs Producción

```typescript
import { createBundler } from './src/index';

// Desarrollo
const devBundler = createBundler('development');

// Producción
const prodBundler = createBundler('production');
```

## 🌐 API Endpoints

### JSON-RPC API

El bundler implementa el estándar EIP-4337:

```bash
# Enviar UserOperation
curl -X POST http://localhost:3000 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "eth_sendUserOperation",
    "params": [userOperation]
  }'

# Estimar gas
curl -X POST http://localhost:3000 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "eth_estimateUserOperationGas",
    "params": [userOperation]
  }'

# Obttener EntryPoint soportado
curl -X POST http://localhost:3000 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "eth_supportedEntryPoints",
    "params": []
  }'
```

### REST API

```bash
# Health Check
curl http://localhost:3000/health

# Métricas
curl http://localhost:3000/metrics

# Enviar UserOperation
curl -X POST http://localhost:3000/sendUserOperation \
  -H "Content-Type: application/json" \
  -d '{"sender": "...", "nonce": 0, ...}'

# Obtener UserOperations pendientes
curl http://localhost:3000/pendingUserOperations

# Estadísticas
curl http://localhost:3000/stats
```

## 🏗️ Arquitectura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend/DApp │────│   Bundler API   │────│  AndeChain RPC  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                       ┌─────────────────┐
                       │      Mempool    │
                       └─────────────────┘
                                │
                       ┌─────────────────┐
                       │  Bundle Builder │
                       └─────────────────┘
                                │
                       ┌─────────────────┐
                       │   EntryPoint    │
                       └─────────────────┘
                                │
                       ┌─────────────────┐
                       │  AndeWallet     │
                       │  AndePaymaster  │
                       └─────────────────┘
```

## 🔄 Flujo de UserOperation

1. **Recepción**: Frontend envía UserOperation al bundler
2. **Validación**: Bundler valida firma, nonce, y límites de gas
3. **Simulación**: Simula ejecución sin afectar el estado
4. **Mempool**: Añade a mempool si es válida
5. **Bundling**: Agrupa con otras UserOperations
6. **Ejecución**: Envía bundle al EntryPoint
7. **Patrocinio**: Paymaster cubre el gas si es necesario
8. **Confirmación**: Notifica resultado al frontend

## 📊 Métricas y Monitoreo

El bundler provee métricas en tiempo real:

```json
{
  "timestamp": 1699123456789,
  "uptime": 3600.5,
  "bundler": {
    "totalBundles": 150,
    "successfulBundles": 145,
    "failedBundles": 5,
    "totalUserOps": 1200,
    "successRate": 0.9667,
    "avgProcessingTime": 2500,
    "avgBundleSize": 8.0,
    "mempoolSize": 25,
    "currentGasPrice": "20000000000"
  },
  "server": {
    "totalRequests": 5000,
    "successfulRequests": 4950,
    "failedRequests": 50
  },
  "system": {
    "uptime": 3600.5,
    "memoryUsage": {...},
    "cpuUsage": {...},
    "requestsPerSecond": 1.39,
    "errorRate": 0.01
  }
}
```

## 🧪 Testing

```bash
# Ejecutar tests
npm test

# Tests con coverage
npm run test:coverage

# Tests de integración
npm run test:integration
```

## 🔧 Desarrollo

### Estructura del Proyecto

```
src/
├── core/
│   └── bundler.ts          # Lógica principal del bundler
├── server/
│   └── index.ts            # Servidor API y JSON-RPC
├── utils/
│   └── logger.ts           # Sistema de logging
├── types/
│   └── index.ts            # Definiciones TypeScript
├── config/
│   └── index.ts            # Configuración
└── index.ts                # Entry point principal
```

### Logging

El bundler usa Winston para logging estructurado:

```typescript
import { getLogger } from './src/utils/logger';

const logger = getLogger();
logger.info('UserOperation received', { userOpHash, sender });
logger.error('Validation failed', error);
```

### Eventos

El bundler emite eventos para monitoreo:

```typescript
bundler.on('userOpAdded', (userOp) => {
  console.log('New UserOperation:', userOp.userOpHash);
});

bundler.on('bundleIncluded', (bundleHash, blockNumber) => {
  console.log('Bundle included:', bundleHash, 'Block:', blockNumber);
});
```

## 🚀 Despliegue

### Desarrollo

```bash
# Iniciar con configuración de desarrollo
npm run dev

# O con variables de entorno específicas
NODE_ENV=development RPC_URL=http://localhost:8545 npm start
```

### Producción

```bash
# Compilar
npm run build

# Iniciar con PM2
pm2 start ecosystem.config.js

# O con Docker
docker build -t andechain-aa-bundler .
docker run -d --env-file .env andechain-aa-bundler
```

### Dockerfile

```dockerfile
FROM node:18-alpine

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

EXPOSE 3000

CMD ["npm", "start"]
```

## 🔍 Troubleshooting

### Problemas Comunes

1. **Mempool llena**: Ajusta `maxSize` en la configuración
2. **Gas price muy alto**: Verifica `maxGasPrice` y `minPriorityFee`
3. **Fallas de validación**: Revisa la configuración del EntryPoint
4. **Conexión RPC**: Verifica que el nodo AndeChain esté accesible

### Debug Mode

```bash
# Habilitar logging verbose
LOG_LEVEL=debug npm start

# Ver mempool actual
curl http://localhost:3000/debug_bundler_dumpMempool

# Forzar bundle inmediato
curl http://localhost:3000/debug_bundler_sendBundleNow
```

## 📚 Referencias

- [EIP-4337: Account Abstraction](https://eips.ethereum.org/EIPS/eip-4337)
- [Account Abstraction Documentation](https://docs.alchemy.com/docs/account-abstraction)
- [AndeChain Documentation](https://docs.andechain.org)

## 🤝 Contribuir

1. Fork del proyecto
2. Crear feature branch
3. Commit con mensaje descriptivo
4. Push a la branch
5. Crear Pull Request

## 📄 Licencia

MIT License - ver [LICENSE](LICENSE) para detalles.

## 🆘 Soporte

- Issues: [GitHub Issues](https://github.com/ande-labs/aa-bundler/issues)
- Discord: [Ande Labs Discord](https://discord.gg/andechain)
- Email: support@andechain.org