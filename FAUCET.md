# AndeChain Faucet Server

Servidor de faucet para distribuir tokens ANDE de prueba en el entorno de desarrollo local.

## Inicio Rápido

```bash
# Instalar dependencias
npm install

# Iniciar servidor (usa configuración por defecto)
npm start
```

El servidor se iniciará en `http://localhost:8081`

## Configuración

El servidor se puede configurar mediante variables de entorno:

```bash
# .env (opcional)
RPC_URL=http://localhost:8545
FAUCET_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

**Nota**: La private key por defecto es la cuenta pre-financiada de Hardhat/Foundry para desarrollo local.

## API Endpoints

### POST `/`
Solicitar fondos del faucet

**Request:**
```json
{
  "address": "0x..."
}
```

**Response (éxito):**
```json
{
  "success": true,
  "message": "¡10 ANDE enviados exitosamente!",
  "txHash": "0x...",
  "blockNumber": 123,
  "from": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  "to": "0x...",
  "amount": "10.0"
}
```

**Response (cooldown):**
```json
{
  "success": false,
  "message": "Por favor espera 60 segundos antes de solicitar más fondos.",
  "remainingTime": 45
}
```

### GET `/health`
Verificar estado del faucet

**Response:**
```json
{
  "status": "healthy",
  "faucetAddress": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  "balance": "9999.5",
  "blockNumber": "123",
  "chainId": "1234",
  "cooldownTime": "60s",
  "faucetAmount": "10.0"
}
```

### GET `/cooldown/:address`
Verificar tiempo de espera para una dirección

**Response:**
```json
{
  "canRequest": false,
  "remainingTime": 45,
  "lastRequestTime": "2025-01-15T10:30:00.000Z"
}
```

## Características

- ✅ Cooldown de 60 segundos por dirección
- ✅ Validación de direcciones Ethereum
- ✅ Verificación de balance del faucet
- ✅ CORS habilitado para desarrollo
- ✅ Logs detallados de transacciones
- ✅ Health check endpoint

## Integración con Frontend

El frontend de Ande Labs ya está configurado para usar este servidor. Ver `FaucetSection.tsx`:

```typescript
const FAUCET_URL = process.env.NEXT_PUBLIC_FAUCET_URL || 'http://localhost:8081';

const response = await fetch(FAUCET_URL, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ address: userAddress })
});
```

## Troubleshooting

### "Faucet no tiene suficientes fondos"

La cuenta del faucet se ha quedado sin ANDE. Envía más fondos:

```bash
cast send 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --value 1000ether \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://localhost:8545
```

### "Failed to fetch"

El servidor no está corriendo o el frontend no puede conectarse:

1. Verifica que el servidor esté corriendo: `lsof -i :8081`
2. Verifica la URL en el frontend: debe ser `http://localhost:8081`
3. Verifica CORS (ya está habilitado por defecto)

### RPC connection failed

La blockchain local no está corriendo:

```bash
cd andechain
make start  # Inicia toda la infraestructura
```

## Seguridad

⚠️ **IMPORTANTE**: Este servidor es SOLO para desarrollo local.

- NO uses en producción sin implementar:
  - Rate limiting más robusto (por IP, no solo por dirección)
  - Autenticación/CAPTCHA
  - Monitoreo de abuse
  - Limitar cantidad por solicitud
  - Rotación de claves del faucet
  - HTTPS

## Customización

### Cambiar cantidad de ANDE por solicitud

Edita `faucet-server.js`:

```javascript
const FAUCET_AMOUNT = ethers.parseEther('10'); // Cambiar a la cantidad deseada
```

### Cambiar tiempo de cooldown

```javascript
const COOLDOWN_TIME = 60 * 1000; // 60 segundos, ajusta según necesites
```

## Logs

El servidor registra todas las transacciones:

```
🚰 Faucet server running on http://localhost:8081
💧 Faucet amount: 10.0 ANDE
⏱️  Cooldown: 60s
👛 Faucet address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
🔗 RPC: http://localhost:8545
```

## Workflow de Desarrollo

1. **Iniciar blockchain local:**
   ```bash
   cd andechain/infra
   docker compose up -d
   ```

2. **Iniciar faucet:**
   ```bash
   cd andechain
   npm start
   ```

3. **Iniciar frontend:**
   ```bash
   cd ande-frontend
   npm run dev
   ```

4. **Usar faucet:**
   - Navega a http://localhost:9002/dashboard/faucet
   - Ingresa una dirección o usa tu wallet conectada
   - Solicita tokens

## Monitoreo

Verificar transacciones del faucet:

```bash
# Ver balance del faucet
cast balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://localhost:8545

# Ver últimas transacciones
cast block latest --rpc-url http://localhost:8545
```
