#!/bin/bash
# ============================================
# Script Automático para Actualizar Direcciones
# ============================================
# Extrae las direcciones del último despliegue y actualiza set_addresses.sh

DEPLOY_LOG="/tmp/deploy_output.log"
ADDRESSES_FILE="set_addresses.sh"

echo "🔍 Extrayendo direcciones del último despliegue..."

# Ejecutar despliegue y guardar output
make deploy-ecosystem 2>&1 | tee "$DEPLOY_LOG"

# Extraer direcciones del log
ANDE_TOKEN=$(grep "ANDE Token:" "$DEPLOY_LOG" | awk '{print $NF}')
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

# Crear nuevo archivo set_addresses.sh
cat > "$ADDRESSES_FILE" << EOF
#!/bin/bash
# ============================================
# AndeChain - Variables de Entorno
# ============================================
# Generado automáticamente: $(date)

export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export DEPLOYER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# Core Tokens
export ANDE_TOKEN=$ANDE_TOKEN
export AUSD_TOKEN=$AUSD_TOKEN
export ABOB_TOKEN=$ABOB_TOKEN
export SABOB_TOKEN=$SABOB_TOKEN

# Governance
export VEANDE=$VEANDE
export MINT_CONTROLLER=$MINT_CONTROLLER
export BURN_ENGINE=$BURN_ENGINE

# Stability
export STABILITY_ENGINE=$STABILITY_ENGINE

# Bridge
export ANDE_BRIDGE=$ANDE_BRIDGE
export ETH_BRIDGE=$ETH_BRIDGE

# Mocks
export MOCK_USDC=$MOCK_USDC

echo "✅ Variables de entorno configuradas para AndeChain"
echo ""
echo "CORE TOKENS:"
echo "  🔹 ANDE Token:    \$ANDE_TOKEN"
echo "  🔹 aUSD Token:    \$AUSD_TOKEN"
echo "  🔹 ABOB Token:    \$ABOB_TOKEN"
echo "  🔹 sABOB Token:   \$SABOB_TOKEN"
echo ""
echo "GOVERNANCE:"
echo "  🔹 VeANDE:        \$VEANDE"
echo "  🔹 MintController: \$MINT_CONTROLLER"
echo ""
echo "STABILITY:"
echo "  🔹 StabilityEngine: \$STABILITY_ENGINE"
echo ""
echo "BRIDGE:"
echo "  🔹 AndeBridge:    \$ANDE_BRIDGE"
echo "  🔹 EthBridge:     \$ETH_BRIDGE"
echo ""
echo "Uso: source set_addresses.sh"
EOF

chmod +x "$ADDRESSES_FILE"

echo ""
echo "✅ Archivo $ADDRESSES_FILE actualizado correctamente"
echo ""
echo "📋 Direcciones extraídas:"
echo "  ANDE Token:     $ANDE_TOKEN"
echo "  aUSD Token:     $AUSD_TOKEN"
echo "  ABOB Token:     $ABOB_TOKEN"
echo "  sABOB Token:    $SABOB_TOKEN"
echo ""
echo "🚀 Para usar estas variables, ejecuta:"
echo "   source set_addresses.sh"
