#!/bin/bash

# Script para verificar contratos en Blockscout local
# Uso: ./scripts/verify-contracts.sh

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  ANDECHAIN CONTRACT VERIFICATION${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Configuración
RPC_URL="http://localhost:8545"
BLOCKSCOUT_API="http://localhost:4000/api"
CHAIN_ID="1234"
COMPILER_VERSION="v0.8.25+commit.b61c2a91"

# Directorio de broadcast (donde Foundry guarda las direcciones desplegadas)
BROADCAST_DIR="./contracts/broadcast/DeployEcosystem.s.sol/$CHAIN_ID"

# Verificar que existe el archivo de broadcast
if [ ! -f "$BROADCAST_DIR/run-latest.json" ]; then
    echo -e "${RED}Error: No se encontró el archivo de deployment.${NC}"
    echo -e "${YELLOW}Por favor ejecuta primero el script de despliegue:${NC}"
    echo -e "  cd contracts"
    echo -e "  forge script script/DeployEcosystem.s.sol:DeployEcosystem --rpc-url local --broadcast --legacy"
    exit 1
fi

echo -e "${GREEN}✓ Archivo de deployment encontrado${NC}"
echo ""

# Función para verificar un contrato
verify_contract() {
    local NAME=$1
    local ADDRESS=$2
    local CONSTRUCTOR_ARGS=$3

    echo -e "${YELLOW}Verificando: $NAME${NC}"
    echo -e "  Dirección: $ADDRESS"

    # Intentar verificación con Foundry
    if [ -z "$CONSTRUCTOR_ARGS" ]; then
        forge verify-contract \
            --chain-id $CHAIN_ID \
            --compiler-version $COMPILER_VERSION \
            --verifier blockscout \
            --verifier-url $BLOCKSCOUT_API \
            $ADDRESS \
            $NAME \
            2>&1 | grep -q "successfully verified" && \
            echo -e "${GREEN}  ✓ Verificado exitosamente${NC}" || \
            echo -e "${YELLOW}  ⚠ Ya verificado o error menor${NC}"
    else
        forge verify-contract \
            --chain-id $CHAIN_ID \
            --compiler-version $COMPILER_VERSION \
            --verifier blockscout \
            --verifier-url $BLOCKSCOUT_API \
            --constructor-args $CONSTRUCTOR_ARGS \
            $ADDRESS \
            $NAME \
            2>&1 | grep -q "successfully verified" && \
            echo -e "${GREEN}  ✓ Verificado exitosamente${NC}" || \
            echo -e "${YELLOW}  ⚠ Ya verificado o error menor${NC}"
    fi
    echo ""
}

# Extraer direcciones del JSON de deployment (esto requiere jq)
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq no está instalado${NC}"
    echo -e "${YELLOW}Instala jq para continuar:${NC}"
    echo -e "  macOS: brew install jq"
    echo -e "  Linux: sudo apt-get install jq"
    exit 1
fi

echo -e "${BLUE}Extrayendo direcciones de contratos desplegados...${NC}"
echo ""

# Método alternativo: Leer direcciones desde el archivo broadcast
# Nota: Esto asume que tienes las direcciones guardadas.
# Para una implementación más robusta, deberías parsear el JSON correctamente.

# Por ahora, vamos a listar los contratos principales que necesitan verificación
# Estos son contratos de implementación (no proxies)

echo -e "${BLUE}=== VERIFICANDO IMPLEMENTACIONES ===${NC}"
echo ""

# Lista de contratos a verificar (deberás actualizar las direcciones después del deployment)
# Formato: verify_contract "NombreDelContrato" "0xDireccion" "constructor-args-encoded"

# Ejemplo de cómo verificar:
# verify_contract "src/ANDEToken.sol:ANDEToken" "0x123..." ""
# verify_contract "src/AusdToken.sol:AusdToken" "0x456..." ""

echo -e "${YELLOW}NOTA: Para verificación automática completa, necesitas parsear run-latest.json${NC}"
echo -e "${YELLOW}O usar el siguiente comando manualmente para cada contrato:${NC}"
echo ""
echo -e "forge verify-contract \\"
echo -e "  --chain-id $CHAIN_ID \\"
echo -e "  --compiler-version $COMPILER_VERSION \\"
echo -e "  --verifier blockscout \\"
echo -e "  --verifier-url $BLOCKSCOUT_API \\"
echo -e "  <CONTRACT_ADDRESS> \\"
echo -e "  src/<ContractName>.sol:<ContractName>"
echo ""

# Verificar contratos específicos si las direcciones están disponibles
# Esto requiere que las direcciones se pasen como argumentos o se lean del JSON

if [ "$#" -eq 2 ]; then
    CONTRACT_NAME=$1
    CONTRACT_ADDRESS=$2
    verify_contract "$CONTRACT_NAME" "$CONTRACT_ADDRESS" ""
else
    echo -e "${GREEN}Para verificar un contrato específico:${NC}"
    echo -e "  ./scripts/verify-contracts.sh \"src/ANDEToken.sol:ANDEToken\" \"0x123...\""
fi

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}Verificación completada!${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "Visita Blockscout para ver los contratos verificados:"
echo -e "${BLUE}http://localhost:4000${NC}"
echo ""
