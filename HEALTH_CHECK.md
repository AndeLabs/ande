# Guía de Chequeo de Salud del Proyecto

Esta guía contiene una serie de comandos para realizar una auditoría y verificación completa del estado del proyecto AndeChain.

### 1. Análisis de Contratos: Pruebas, Gas y Cobertura

Estos comandos verifican que la lógica de los contratos sea correcta, miden su costo computacional (gas) y revelan qué partes del código no tienen pruebas.

*Se deben ejecutar desde `andechain/contracts/`.*

```bash
# Entra al directorio de los contratos
cd andechain/contracts

# Ejecuta todas las pruebas, genera un reporte de uso de gas
 forge test --gas-report 
# y muestra el porcentaje de cobertura de las pruebas.
forge coverage
```

### 2. Análisis de Seguridad

Estos comandos buscan vulnerabilidades potenciales en los contratos.

*Se deben ejecutar desde `andechain/contracts/`.*

```bash
# 1. Fuzz Testing
# Ejecuta pruebas de fuzzing. Nota: Esto solo tendrá efecto si
# existen funciones de prueba que acepten argumentos (ej: testFuzz(uint256 amount)).
forge test --fuzz-runs 10000

# 2. Análisis Estático con Slither
# Instala Slither si no lo tienes
pip install slither-analyzer

# Ejecuta Slither
slither .
```



### 3. Verificación de la Infraestructura

Estos comandos levantan y verifican todo el entorno de la blockchain local.

*Se deben ejecutar desde `andechain/infra/`.*

```bash
# Entra al directorio de infraestructura
cd andechain/infra

# Reconstruye y levanta todos los servicios de Docker en segundo plano
docker compose up -d --build

# Verifica que todos los contenedores estén corriendo y saludables
docker compose ps
```

### 4. Prueba de Integración E2E (End-to-End)

Este es el flujo **correcto** para probar la interacción entre los contratos recién desplegados y el relayer.

```bash
# 1. Desplegar los contratos en la red local
cd andechain/contracts
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/DeployBridge.s.sol --tc DeployBridge --rpc-url local --broadcast

# 2. ¡Paso Clave! Anotar las nuevas direcciones de los contratos
# De la salida del comando anterior, copia la nueva dirección del contrato 'AndeBridge'.

# 3. Actualizar la configuración del Relayer
# Abre el archivo 'andechain/relayer/.env' y reemplaza la dirección del
# contrato del bridge con la nueva que acabas de copiar.

# 4. Iniciar el Relayer (solo después de actualizar la config)
cd ../relayer
npm start
```
