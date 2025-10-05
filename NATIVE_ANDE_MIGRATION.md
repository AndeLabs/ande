# Migración a ANDE como Token Nativo de Gas

## 🎯 Objetivo

Convertir ANDE en el token nativo de AndeChain para pagos de gas, haciendo la chain verdaderamente soberana.

## 📋 Cambios Realizados

### 1. Genesis Configuration

**Archivo**: `infra/stacks/single-sequencer/genesis.json`

**Cambios**:
- ✅ Aumentado balance inicial de cuentas pre-funded a 100,000 ANDE
- ✅ `0x95c8f96C7F012e422fB089619223315C25fB8857`: 100,000 ANDE
- ✅ `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`: 100,000 ANDE (dev account)

**Balance en hex**: `0x52B7D2DCC80CD2E4000000` = 100,000 * 10^18 wei

## 🚀 Proceso de Migración

### Paso 1: Resetear la Chain (CRÍTICO)

Los cambios en genesis requieren reset completo:

```bash
cd andechain/infra
docker compose down -v  # -v es CRÍTICO para borrar volúmenes
```

### Paso 2: Reiniciar Infrastructure

```bash
docker compose up -d --build
```

### Paso 3: Verificar Token Nativo

```bash
# Verificar balance de ANDE nativo (dev account)
cast balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://localhost:8545

# Debería mostrar: 100000000000000000000000 (100,000 ANDE)
```

### Paso 4: Actualizar Deployment Scripts

Los scripts de deployment ahora usarán ANDE para gas:

```bash
cd ../contracts

# Deploy usando ANDE como gas token
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/DeployBridge.s.sol --tc DeployBridge --rpc-url local --broadcast
```

### Paso 5: Actualizar Configuración de Gas Prices

Los usuarios ahora pagarán gas en ANDE:

```bash
# Ejemplo de transacción con ANDE como gas
cast send <CONTRACT_ADDRESS> "function()" \
  --rpc-url http://localhost:8545 \
  --private-key $PRIVATE_KEY \
  --gas-price 1000000000  # En ANDE (1 Gwei)
```

## 📊 Tokenomics Nativa

### Distribución Inicial en Genesis

| Cuenta | Balance | Propósito |
|--------|---------|-----------|
| `0x95c8f96C7F012e422fB089619223315C25fB8857` | 100,000 ANDE | Sequencer/Validator |
| `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | 100,000 ANDE | Dev/Testing |

**Total Supply Inicial**: 200,000 ANDE

### Gas Economics

- **Gas Token**: ANDE nativo
- **Base Fee**: 1 Gwei (configurable)
- **Gas Limit**: 120,000,000,000 (0x1c9c38000)

### Mecánicas de Deflación

Con ANDE como gas token, el **DualTrackBurnEngine** se vuelve más poderoso:

1. **Real-time Burn**: Cada transacción quema una fracción del gas
2. **Quarterly Burn**: Burn periódico de acumulación
3. **Fee Market**: EIP-1559 style con base fee que se quema

## ⚙️ Configuración Avanzada

### Ajustar Gas Prices (Opcional)

Si necesitas ajustar el precio base del gas:

```bash
# Modificar baseFeePerGas en genesis.json
# Valor actual: 0x3b9aca00 = 1 Gwei
# Ejemplo para 0.5 Gwei: 0x1dcd6500
```

### Multi-Currency Support (Futuro)

Para permitir pago de gas con otros tokens (AUSD, ABOB):

1. Implementar meta-transactions con relayer
2. El relayer paga gas en ANDE
3. El usuario paga al relayer en token alternativo

## 🔒 Seguridad

### Consideraciones

1. **Supply Monitoring**: Track total ANDE supply para evitar inflación no controlada
2. **Burn Tracking**: Monitor ANDE quemado vs emitido
3. **Genesis Accounts**: Las cuentas pre-funded deben ser multisig en producción

### Auditoría Recomendada

Antes de mainnet:

```bash
# Verificar supply inicial
cast call <ANDE_TOKEN_ADDRESS> "totalSupply()" --rpc-url http://localhost:8545

# Verificar burn engine está activo
cast call <BURN_ENGINE_ADDRESS> "isActive()" --rpc-url http://localhost:8545
```

## 🧪 Testing

### Test de Gas Payment

```solidity
// Test en Foundry
function testGasPaymentInANDE() public {
    uint256 balanceBefore = address(this).balance; // Balance en ANDE

    // Ejecutar transacción
    vm.prank(user);
    andeToken.transfer(recipient, 100 ether);

    uint256 balanceAfter = address(this).balance;
    uint256 gasPaid = balanceBefore - balanceAfter;

    assertTrue(gasPaid > 0, "Gas should be paid in ANDE");
}
```

### Verificar Burn Mechanism

```bash
# Monitorear burns en tiempo real
cast logs --address <BURN_ENGINE_ADDRESS> --from-block latest --rpc-url http://localhost:8545
```

## 📝 Próximos Pasos

### Inmediato
- [x] Actualizar genesis con ANDE nativo
- [ ] Resetear infrastructure
- [ ] Re-deploy contracts
- [ ] Actualizar tests para usar ANDE como gas

### Corto Plazo
- [ ] Implementar dashboard de gas analytics
- [ ] Configurar gas price oracle
- [ ] Documentar best practices para usuarios

### Largo Plazo
- [ ] Meta-transactions para pago con AUSD/ABOB
- [ ] Dynamic gas pricing basado en congestión
- [ ] Gas refunds para operaciones beneficiosas (ej: agregar liquidez)

## ⚠️ Warnings

**IMPORTANTE**: Este cambio requiere **reset completo** de la chain:

```bash
# ESTO BORRARÁ TODOS LOS DATOS
docker compose down -v
```

Solo ejecutar cuando:
- ✅ Tienes backup de contratos importantes
- ✅ Estás en entorno de desarrollo
- ✅ Has comunicado el downtime al equipo

## 🔗 Referencias

- [Evolve Documentation](https://docs.evolve.zone/)
- [EIP-1559](https://eips.ethereum.org/EIPS/eip-1559) - Fee Market
- [Genesis Configuration Guide](https://geth.ethereum.org/docs/fundamentals/private-network#the-genesis-file)
- [GEMINI.md](../GEMINI.md) - Development Philosophy

---

**Autor**: AndeChain Development Team
**Fecha**: 2025-10-05
**Estado**: ✅ Implementado en desarrollo, pendiente para producción
