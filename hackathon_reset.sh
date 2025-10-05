#!/bin/bash
# ============================================
# AndeChain - Reset y Setup Completo para Hackathon
# ============================================
# Un solo comando para resetear, desplegar y configurar todo

set -e  # Salir si hay errores

echo "════════════════════════════════════════════════════════"
echo "  🚀 AndeChain - Setup Completo para Hackathon"
echo "════════════════════════════════════════════════════════"
echo ""

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Reset completo
echo -e "${BLUE}[1/5] 🧹 Limpiando sistema...${NC}"
make reset
echo ""

# 2. Iniciar infraestructura
echo -e "${BLUE}[2/5] 🐳 Iniciando infraestructura Docker...${NC}"
cd infra
docker compose up -d --build
cd ..
echo ""

# 3. Esperar a que la blockchain esté lista
echo -e "${BLUE}[3/5] ⏳ Esperando 30 segundos para que la blockchain esté lista...${NC}"
sleep 30
echo ""

# 4. Desplegar contratos y actualizar direcciones
echo -e "${BLUE}[4/5] 📜 Desplegando contratos y actualizando direcciones...${NC}"
DEPLOY_LOG="/tmp/deploy_output.log"
make deploy-ecosystem 2>&1 | tee "$DEPLOY_LOG"

# Extraer direcciones
ANDE_TOKEN=$(grep "ANDE Token:" "$DEPLOY_LOG" | grep -v "aUSD" | awk '{print $NF}')
AUSD_TOKEN=$(grep "aUSD Token:" "$DEPLOY_LOG" | awk '{print $NF}')
ABOB_TOKEN=$(grep "ABOB Token:" "$DEPLOY_LOG" | awk '{print $NF}')
SABOB_TOKEN=$(grep "sABOB Token:" "$DEPLOY_LOG" | awk '{print $NF}')
VEANDE=$(grep "VeANDE:" "$DEPLOY_LOG" | awk '{print $NF}')
MINT_CONTROLLER=$(grep "MintController:" "$DEPLOY_LOG" | awk '{print $NF}')
BURN_ENGINE=$(grep "BurnEngine:" "$DEPLOY_LOG" | awk '{print $NF}')
STABILITY_ENGINE=$(grep "StabilityEngine:" "$DEPLOY_LOG" | awk '{print $NF}')
ANDE_BRIDGE=$(grep "AndeBridge:" "$DEPLOY_LOG" | awk '{print $NF}')
ETH_BRIDGE=$(grep "EthereumBridge:" "$DEPLOY_LOG" | awk '{print $NF}')
MOCK_USDC=$(grep "MockUSDC:" "$DEPLOY_LOG" | awk '{print $NF}')

# Crear set_addresses.sh
cat > set_addresses.sh << EOF
#!/bin/bash
# Generado automáticamente: $(date)
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export DEPLOYER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export ANDE_TOKEN=$ANDE_TOKEN
export AUSD_TOKEN=$AUSD_TOKEN
export ABOB_TOKEN=$ABOB_TOKEN
export SABOB_TOKEN=$SABOB_TOKEN
export VEANDE=$VEANDE
export MINT_CONTROLLER=$MINT_CONTROLLER
export BURN_ENGINE=$BURN_ENGINE
export STABILITY_ENGINE=$STABILITY_ENGINE
export ANDE_BRIDGE=$ANDE_BRIDGE
export ETH_BRIDGE=$ETH_BRIDGE
export MOCK_USDC=$MOCK_USDC

echo "✅ Variables configuradas - Usa: source set_addresses.sh"
EOF

chmod +x set_addresses.sh
echo ""

# 5. Verificar que todo funciona
echo -e "${BLUE}[5/5] ✅ Verificando instalación...${NC}"
source set_addresses.sh

# Verificar RPC
BLOCK_NUMBER=$(cast block-number --rpc-url http://localhost:8545)
echo -e "${GREEN}✓ RPC funcionando - Bloque actual: $BLOCK_NUMBER${NC}"

# Verificar contratos
ANDE_NAME=$(cast call $ANDE_TOKEN "name()(string)" --rpc-url http://localhost:8545)
AUSD_NAME=$(cast call $AUSD_TOKEN "name()(string)" --rpc-url http://localhost:8545)
echo -e "${GREEN}✓ Contratos desplegados correctamente${NC}"
echo -e "${GREEN}  - ANDE Token: $ANDE_NAME${NC}"
echo -e "${GREEN}  - aUSD Token: $AUSD_NAME${NC}"

echo ""
echo "════════════════════════════════════════════════════════"
echo -e "${GREEN}✅ ¡Setup completo!${NC}"
echo "════════════════════════════════════════════════════════"
echo ""
echo "📋 DIRECCIONES DE CONTRATOS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ANDE Token:       $ANDE_TOKEN"
echo "  aUSD Token:       $AUSD_TOKEN"
echo "  ABOB Token:       $ABOB_TOKEN"
echo "  sABOB Token:      $SABOB_TOKEN"
echo "  VeANDE:           $VEANDE"
echo "  StabilityEngine:  $STABILITY_ENGINE"
echo "  AndeBridge:       $ANDE_BRIDGE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 SERVICIOS DISPONIBLES:"
echo "  • RPC:        http://localhost:8545"
echo "  • Blockscout: http://localhost:4000"
echo "  • Frontend:   http://localhost:9002 (si está corriendo)"
echo ""
echo "📝 PRÓXIMOS PASOS:"
echo "  1. Cargar variables: ${YELLOW}source set_addresses.sh${NC}"
echo "  2. Verificar token:  ${YELLOW}cast call \$ANDE_TOKEN 'name()(string)' --rpc-url http://localhost:8545${NC}"
echo "  3. Ver demo:         ${YELLOW}cat HACKATHON_DEMO.md${NC}"
echo ""
echo "🎉 ¡Listo para demostrar en el hackathon!"
echo ""
