#!/bin/bash

# ============================================================================
# AndeChain - Deployment de Contratos Faltantes para Producción
# ============================================================================
# 
# Este script despliega los 3 contratos críticos faltantes:
# 1. AndeSequencerRegistry (UUPS Upgradeable)
# 2. xANDEToken (UUPS Upgradeable) 
# 3. XERC20Lockbox (Immutable)
#
# Chain ID: 6174 (AndeChain Testnet)
# RPC: https://rpc.ande.network (después de DNS setup)
#      o http://189.28.81.202:8545 (IP directa)
#
# Uso: ./DEPLOY_MISSING_CONTRACTS.sh
# ============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}AndeChain - Deployment de Contratos Faltantes${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"

# Verificar que estamos en el directorio correcto
if [ ! -f "foundry.toml" ]; then
    echo -e "${RED}❌ Error: Ejecuta este script desde /andechain/contracts/${NC}"
    exit 1
fi

# Variables de entorno
export PRIVATE_KEY=${PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}
export RPC_URL=${RPC_URL:-"http://189.28.81.202:8545"}
export CHAIN_ID=6174

# Direcciones de contratos ya desplegados
export ANDE_TOKEN="0x5FC8d32690cc91D4c39d9d3abcBD16989F875707"
export DEPLOYER_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

echo -e "${YELLOW}Configuración:${NC}"
echo "• Chain ID: $CHAIN_ID"
echo "• RPC URL: $RPC_URL"
echo "• ANDE Token: $ANDE_TOKEN"
echo "• Deployer: $DEPLOYER_ADDRESS"
echo ""

# ============================================================================
# VERIFICACIÓN DE CONECTIVIDAD
# ============================================================================

echo -e "${YELLOW}Verificando conectividad RPC...${NC}"
CHAIN_ID_RESPONSE=$(curl -s -X POST $RPC_URL \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq -r '.result')

if [ -z "$CHAIN_ID_RESPONSE" ]; then
    echo -e "${RED}❌ Error: RPC no responde en $RPC_URL${NC}"
    echo -e "${YELLOW}Asegúrate de que el nodo esté corriendo:${NC}"
    echo "  • Verifica: docker ps | grep reth"
    echo "  • O ejecuta: ./deploy-production.sh production"
    exit 1
fi

CHAIN_ID_DEC=$((16#${CHAIN_ID_RESPONSE:2}))
if [ "$CHAIN_ID_DEC" != "$CHAIN_ID" ]; then
    echo -e "${RED}❌ Error: Chain ID incorrecto${NC}"
    echo "  Esperado: $CHAIN_ID"
    echo "  Recibido: $CHAIN_ID_DEC"
    exit 1
fi

echo -e "${GREEN}✓ RPC conectado correctamente (Chain ID: $CHAIN_ID_DEC)${NC}\n"

# ============================================================================
# COMPILACIÓN
# ============================================================================

echo -e "${YELLOW}Compilando contratos...${NC}"
forge build --force > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Compilación exitosa${NC}\n"
else
    echo -e "${RED}❌ Error en compilación${NC}"
    exit 1
fi

# ============================================================================
# DEPLOYMENT 1: AndeSequencerRegistry
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}1/3: Desplegando AndeSequencerRegistry (UUPS)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Paso 1.1: Desplegando Implementation...${NC}"
SEQUENCER_IMPL=$(forge create src/sequencer/AndeSequencerRegistry.sol:AndeSequencerRegistry \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --json | jq -r '.deployedTo')

if [ -z "$SEQUENCER_IMPL" ] || [ "$SEQUENCER_IMPL" == "null" ]; then
    echo -e "${RED}❌ Error desplegando AndeSequencerRegistry implementation${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Implementation desplegado: $SEQUENCER_IMPL${NC}\n"

echo -e "${YELLOW}Paso 1.2: Desplegando Proxy...${NC}"

# Encode initialize call for AndeSequencerRegistry
# initialize(address defaultAdmin, address foundation)
INIT_DATA=$(cast abi-encode "initialize(address,address)" $DEPLOYER_ADDRESS $DEPLOYER_ADDRESS)

SEQUENCER_PROXY=$(forge create lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args $SEQUENCER_IMPL $INIT_DATA \
  --json | jq -r '.deployedTo')

if [ -z "$SEQUENCER_PROXY" ] || [ "$SEQUENCER_PROXY" == "null" ]; then
    echo -e "${RED}❌ Error desplegando AndeSequencerRegistry proxy${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Proxy desplegado: $SEQUENCER_PROXY${NC}\n"

echo -e "${GREEN}✅ AndeSequencerRegistry desplegado exitosamente${NC}"
echo "   Implementation: $SEQUENCER_IMPL"
echo "   Proxy (usar esta): $SEQUENCER_PROXY"
echo ""

# ============================================================================
# DEPLOYMENT 2: xANDEToken
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}2/3: Desplegando xANDEToken (XERC20)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Paso 2.1: Desplegando XERC20 Implementation...${NC}"
XANDE_IMPL=$(forge create src/xERC20/xANDEToken.sol:xANDEToken \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --json | jq -r '.deployedTo')

if [ -z "$XANDE_IMPL" ] || [ "$XANDE_IMPL" == "null" ]; then
    echo -e "${RED}❌ Error desplegando xANDEToken implementation${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Implementation desplegado: $XANDE_IMPL${NC}\n"

echo -e "${YELLOW}Paso 2.2: Desplegando Proxy...${NC}"

# Encode initialize call
INIT_DATA=$(cast abi-encode "initialize(address)" $DEPLOYER_ADDRESS)

XANDE_PROXY=$(forge create lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args $XANDE_IMPL $INIT_DATA \
  --json | jq -r '.deployedTo')

if [ -z "$XANDE_PROXY" ] || [ "$XANDE_PROXY" == "null" ]; then
    echo -e "${RED}❌ Error desplegando xANDEToken proxy${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Proxy desplegado: $XANDE_PROXY${NC}\n"

echo -e "${GREEN}✅ xANDEToken desplegado exitosamente${NC}"
echo "   Implementation: $XANDE_IMPL"
echo "   Proxy (usar esta): $XANDE_PROXY"
echo ""

# ============================================================================
# DEPLOYMENT 3: XERC20Lockbox
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}3/3: Desplegando XERC20Lockbox${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Desplegando XERC20Lockbox...${NC}"
echo "   xANDE Token: $XANDE_PROXY"
echo "   ANDE Token: $ANDE_TOKEN"
echo ""

LOCKBOX=$(forge create src/xERC20/XERC20Lockbox.sol:XERC20Lockbox \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args $XANDE_PROXY $ANDE_TOKEN \
  --json | jq -r '.deployedTo')

if [ -z "$LOCKBOX" ] || [ "$LOCKBOX" == "null" ]; then
    echo -e "${RED}❌ Error desplegando XERC20Lockbox${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Lockbox desplegado: $LOCKBOX${NC}\n"

echo -e "${GREEN}✅ XERC20Lockbox desplegado exitosamente${NC}"
echo "   Address: $LOCKBOX"
echo ""

# ============================================================================
# CONFIGURACIÓN POST-DEPLOYMENT
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Configuración Post-Deployment${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Configurando xANDEToken con Lockbox como minter...${NC}"

# Set lockbox as minter in xANDE
cast send $XANDE_PROXY \
  "setLimits(address,uint256,uint256)" \
  $LOCKBOX \
  115792089237316195423570985008687907853269984665640564039457584007913129639935 \
  115792089237316195423570985008687907853269984665640564039457584007913129639935 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Lockbox configurado como minter en xANDE${NC}\n"
else
    echo -e "${YELLOW}⚠ Warning: No se pudo configurar lockbox (verificar manualmente)${NC}\n"
fi

# ============================================================================
# RESUMEN FINAL
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}DEPLOYMENT COMPLETADO EXITOSAMENTE ✅${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${GREEN}Contratos Desplegados en Chain ID $CHAIN_ID:${NC}\n"

echo "┌─────────────────────────────┬──────────────────────────────────────────────┐"
echo "│ Contrato                    │ Address                                      │"
echo "├─────────────────────────────┼──────────────────────────────────────────────┤"
echo "│ AndeSequencerRegistry       │ $SEQUENCER_PROXY │"
echo "│ xANDEToken                  │ $XANDE_PROXY │"
echo "│ XERC20Lockbox               │ $LOCKBOX │"
echo "└─────────────────────────────┴──────────────────────────────────────────────┘"
echo ""

echo -e "${YELLOW}Contratos Ya Desplegados:${NC}\n"
echo "┌─────────────────────────────┬──────────────────────────────────────────────┐"
echo "│ ANDETokenDuality            │ $ANDE_TOKEN │"
echo "│ AndeNativeStaking           │ 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853 │"
echo "│ AndeGovernor                │ 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e │"
echo "│ AndeTimelockController      │ 0x8A791620dd6260079BF849Dc5567aDC3F2FdC318 │"
echo "└─────────────────────────────┴──────────────────────────────────────────────┘"
echo ""

# ============================================================================
# GUARDAR ADDRESSES
# ============================================================================

ADDRESSES_FILE="deployments/production-addresses-$(date +%Y%m%d-%H%M%S).json"
mkdir -p deployments

cat > $ADDRESSES_FILE << EOF
{
  "network": "AndeChain Testnet",
  "chainId": $CHAIN_ID,
  "rpcUrl": "$RPC_URL",
  "deployedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "contracts": {
    "ANDETokenDuality": "$ANDE_TOKEN",
    "AndeNativeStaking": "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853",
    "AndeGovernor": "0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e",
    "AndeTimelockController": "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318",
    "AndeSequencerRegistry": {
      "proxy": "$SEQUENCER_PROXY",
      "implementation": "$SEQUENCER_IMPL"
    },
    "xANDEToken": {
      "proxy": "$XANDE_PROXY",
      "implementation": "$XANDE_IMPL"
    },
    "XERC20Lockbox": "$LOCKBOX"
  }
}
EOF

echo -e "${GREEN}✓ Addresses guardadas en: $ADDRESSES_FILE${NC}\n"

# ============================================================================
# PRÓXIMOS PASOS
# ============================================================================

echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}PRÓXIMOS PASOS:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}\n"

echo "1. Verificar contratos en Blockscout:"
echo "   • http://189.28.81.202:4000"
echo ""

echo "2. Actualizar frontend con nuevas addresses:"
echo "   • andefrontend/src/contracts/addresses.ts"
echo ""

echo "3. Actualizar .env.production en frontend:"
echo "   NEXT_PUBLIC_SEQUENCER_REGISTRY_ADDRESS=$SEQUENCER_PROXY"
echo "   NEXT_PUBLIC_XANDE_TOKEN_ADDRESS=$XANDE_PROXY"
echo "   NEXT_PUBLIC_XERC20_LOCKBOX_ADDRESS=$LOCKBOX"
echo ""

echo "4. Redeploy frontend en Vercel"
echo ""

echo "5. Testear funcionalidad:"
echo "   • Sequencer registration"
echo "   • xANDE wrapping/unwrapping"
echo "   • Cross-chain bridges"
echo ""

echo -e "${GREEN}🎉 ¡Deployment completado! AndeChain está listo para producción.${NC}\n"
