# ¿QUÉ PUEDES HACER DESDE OTRA PC?

## 🚀 OPERACIONES QUE PUEDES HACER REMOTAMENTE

### 1. DEPLOYMENT DE CONTRATOS (Principal)
✅ **SÍ, HACER DESDE OTRA PC**
- Compilar contratos (con Foundry local)
- Hacer dry runs sin broadcast
- Ejecutar scripts de deployment
- Broadcast de transacciones
- Verificar contratos en Blockscout

```bash
forge script script/DeployCore.s.sol \
  --rpc-url http://189.28.81.202:8545 \
  --private-key $PRIVATE_KEY \
  --broadcast -vvv
```

### 2. TESTING DE CONTRATOS
✅ **SÍ, HACER DESDE OTRA PC**
- Tests unitarios locales
- Tests de integración contra la red
- Fuzzing con Foundry
- Debugging de transacciones fallidas

```bash
# Test local (sin red)
forge test

# Test contra la red testnet
forge test --rpc-url http://189.28.81.202:8545

# Con más verbosidad
forge test -vvv --rpc-url http://189.28.81.202:8545
```

### 3. INTERACCIÓN CON CONTRATOS
✅ **SÍ, HACER DESDE OTRA PC**
- Leer estado (balances, configuraciones)
- Ejecutar funciones públicas
- Enviar transacciones
- Monitorear eventos

```bash
# Leer balance
cast call 0xANDE_ADDRESS "balanceOf(address)" 0xTU_ADDRESS \
  --rpc-url http://189.28.81.202:8545

# Enviar transacción
cast send 0xANDE_ADDRESS "transfer(address,uint256)" 0xRECIPIENT 100 \
  --rpc-url http://189.28.81.202:8545 \
  --private-key $PRIVATE_KEY

# Ver logs de una transacción
cast tx 0xTX_HASH --rpc-url http://189.28.81.202:8545
```

### 4. AUDITORÍA Y ANÁLISIS
✅ **SÍ, HACER DESDE OTRA PC**
- Verificar direcciones de contratos
- Analizar bytecode
- Verificar implementaciones
- Comparar abis

```bash
# Obtener bytecode de un contrato
cast code 0xCONTRACT_ADDRESS --rpc-url http://189.28.81.202:8545

# Ver detalles del contrato en Blockscout
curl http://189.28.81.202:4000/api/v2/addresses/0xCONTRACT_ADDRESS

# Listar transacciones de una dirección
curl "http://189.28.81.202:4000/api/v2/addresses/0xADDRESS/transactions"
```

### 5. MONITORING Y OBSERVABILIDAD
✅ **SÍ, HACER DESDE OTRA PC**
- Ver estado de la red
- Monitorear bloques
- Seguir transacciones
- Analizar gas

```bash
# Obtener estadísticas de la red
curl http://189.28.81.202:4000/api/v2/stats

# Último bloque
curl http://189.28.81.202:4000/api/v2/blocks?type=JSON

# Ver transacciones recientes
curl http://189.28.81.202:4000/api/v2/transactions

# Acceder a Grafana (monitoreo en tiempo real)
# Abre: http://189.28.81.202:3000
# Login: admin / andechain-admin-2025
```

### 6. DESARROLLO DE dAPPS
✅ **SÍ, HACER DESDE OTRA PC**
- Crear aplicaciones web que usen AndeChain
- Escribir backends que llamen al RPC
- Integrar con MetaMask
- Hacer querying de datos

```bash
# Ejemplo: JavaScript/Web3.js
const web3 = new Web3('http://189.28.81.202:8545');
const balance = await web3.eth.getBalance('0xf39Fd...');
console.log(balance);

# Ejemplo: Python/Web3.py
from web3 import Web3
w3 = Web3(Web3.HTTPProvider('http://189.28.81.202:8545'))
balance = w3.eth.get_balance('0xf39Fd...')
print(balance)
```

---

## 📊 INFORMACIÓN QUE NECESITAS

### Del Servidor (Ya Disponible)
```
RPC URL:              http://189.28.81.202:8545
Chain ID:             6174 (0x181e)
Block Explorer:       http://189.28.81.202:4000/api/v2
Monitoreo:            http://189.28.81.202:3000 (Grafana)
WebSocket:            ws://189.28.81.202:8546
Status Health:        http://189.28.81.202/health
```

### De tu Cuenta
```
Address:              0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Private Key:          ac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f20f10b5a234e983
Network:              AndeChain Testnet
Balance:              Unlimited (genesis)
```

### De los Contratos (Después de Deployment)
Guardar en archivo:
```
ANDE Token:           0x...
ANDE Staking:         0x...
AndeGovernor:         0x...
AndeTimelock:         0x...
```

---

## 🔄 WORKFLOW TÍPICO DESDE OTRA PC

### 1. Preparación
```bash
# 1. Instalar Foundry
curl -L https://foundry.paradigm.xyz | bash

# 2. Clonar repos
git clone https://github.com/AndeLabs/ande.git
git clone https://github.com/AndeLabs/ande-reth.git

# 3. Instalar dependencias
cd ande/contracts && forge install
```

### 2. Testing Local
```bash
# Tests unitarios
forge test -vvv

# Análisis de seguridad
forge test --coverage
```

### 3. Deployment
```bash
# Dry run
forge script script/DeployCore.s.sol \
  --rpc-url http://189.28.81.202:8545 \
  --private-key $PRIVATE_KEY

# Broadcast real
forge script script/DeployCore.s.sol \
  --rpc-url http://189.28.81.202:8545 \
  --private-key $PRIVATE_KEY \
  --broadcast -vvv > deployment.log

# Guardar las direcciones
grep "0x" deployment.log | grep -E "Proxy|Implementation" > contract_addresses.txt
```

### 4. Verificación
```bash
# Verificar que existen los contratos
cast code 0xANDE_PROXY_ADDRESS --rpc-url http://189.28.81.202:8545

# Llamar una función de prueba
cast call 0xANDE_PROXY_ADDRESS "name()" --rpc-url http://189.28.81.202:8545
```

### 5. Documentación
```bash
# Crear archivo de referencia
cat > DEPLOYMENT_SUMMARY.md << EOL
# AndeChain Deployment

**Fecha**: $(date)
**Chain ID**: 6174
**Network**: AndeChain Testnet
**Deployer**: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

## Contratos Desplegados

- ANDE Token Proxy: 0x...
- ANDE Token Implementation: 0x...
- Staking Proxy: 0x...
- Governor Proxy: 0x...
- Timelock Proxy: 0x...

## Transacciones

- Deployment TX: 0x...
- Block: 12345
- Gas Used: XXXX

EOL
```

---

## 🚫 LO QUE NO DEBES HACER DESDE OTRA PC

### ❌ No editar archivos de configuración del servidor
- No modificar docker-compose.yml
- No cambiar nginx.conf
- No editar genesis.json
- No cambiar variables de entorno

**Razón**: Afectaría el servidor running

### ❌ No hacer cambios en infraestructura
- No reiniciar servicios
- No actualizar ev-reth sin sincronizar
- No cambiar cadenas de bloques
- No purgar bases de datos

**Razón**: Causaría downtime

### ❌ No usar cuentas diferentes sin permiso
- No crear nuevas cuentas
- No pedir fondos a otras direcciones
- No usar testnet como si fuera mainnet

**Razón**: Podrían causar conflictos

---

## 📋 TAREAS PARA CUANDO VUELVAS AL SERVIDOR

1. **Actualizar Versiones**
   - Sincronizar ev-reth con cambios
   - Actualizar Celestia light node
   - Revisar actualizaciones de dependencias

2. **Integración de Contratos**
   - Registrar direcciones en sistema
   - Configurar faucet con el token ANDE
   - Actualizar chainlist.json con direcciones

3. **Testing en Producción**
   - Hacer transacciones reales
   - Probar staking
   - Probar gobernanza

4. **Documentación**
   - Actualizar README con direcciones
   - Crear guías de usuario
   - Documentar API de contratos

5. **Monitoreo**
   - Configurar alertas en Grafana
   - Revisar logs
   - Verificar rendimiento

---

## 💡 TIPS DE SEGURIDAD

1. **Nunca guardes private keys en archivos públicos**
   ```bash
   export PRIVATE_KEY=...  # En memoria, no en archivos
   ```

2. **Usa testnet para experimentos**
   ```bash
   # OK en testnet
   --rpc-url http://189.28.81.202:8545
   
   # NO en mainnet sin verificar 100 veces
   ```

3. **Verifica direcciones dos veces**
   ```bash
   # Antes de enviar dinero
   echo $CONTRACT_ADDRESS  # Confirma visualmente
   ```

4. **Guarda registros de deployment**
   ```bash
   forge script ... > deployment_$(date +%Y%m%d).log
   ```

5. **Mantén un changelog**
   ```bash
   # Documenta qué se hizo, cuándo y por qué
   git log --oneline
   ```

---

**Estado del Sistema**: ✅ Listo para deployment
**RPC Pública**: ✅ Accesible desde cualquier PC
**Requisitos**: Foundry + Git + 20 minutos de tu tiempo

¡Buen deployment! 🚀
