#!/bin/bash

# ==========================================
# AndeChain Development Environment Starter
# ==========================================
# Este script garantiza el orden correcto:
# 1. Infraestructura
# 2. Deploy de contratos
# 3. Configuración del relayer
# 4. Inicio del relayer
# ==========================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$PROJECT_ROOT/andechain/infra"
CONTRACTS_DIR="$PROJECT_ROOT/andechain/contracts"
RELAYER_DIR="$PROJECT_ROOT/andechain/relayer"
RPC_URL="http://localhost:8545"
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
MAX_RETRIES=30
RETRY_DELAY=2

# Function to print colored messages
print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Function to wait for RPC to be ready
wait_for_rpc() {
    print_step "Esperando a que el RPC esté disponible en $RPC_URL..."

    for i in $(seq 1 $MAX_RETRIES); do
        if curl -s -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            $RPC_URL > /dev/null 2>&1; then
            print_success "RPC está listo!"
            return 0
        fi
        echo -n "."
        sleep $RETRY_DELAY
    done

    print_error "RPC no respondió después de $MAX_RETRIES intentos"
    return 1
}

# Function to extract contract address from broadcast JSON
extract_address() {
    local contract_name=$1
    local broadcast_file="$CONTRACTS_DIR/broadcast/DeployBridge.s.sol/12345/run-latest.json"

    if [ ! -f "$broadcast_file" ]; then
        print_error "Archivo de broadcast no encontrado: $broadcast_file"
        return 1
    fi

    # Extract address - this is a simple grep/awk approach
    # Adjust based on your actual broadcast JSON structure
    grep -A 5 "\"contractName\": \"$contract_name\"" "$broadcast_file" | \
        grep "\"contractAddress\"" | \
        awk -F'"' '{print $4}' | head -1
}

# ==========================================
# PASO 1: INFRAESTRUCTURA
# ==========================================
print_step "1/4 - Levantando infraestructura Docker..."

cd "$INFRA_DIR"

# Check if containers are already running
if docker compose ps | grep -q "Up"; then
    print_warning "Contenedores ya están corriendo. ¿Resetear? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_step "Reseteando infraestructura..."
        docker compose down -v
        docker compose up -d --build
    else
        print_warning "Usando infraestructura existente"
    fi
else
    docker compose up -d --build
fi

# Wait for RPC
wait_for_rpc || exit 1

print_success "Infraestructura lista"

# ==========================================
# PASO 2: DEPLOY DE CONTRATOS
# ==========================================
print_step "2/4 - Desplegando contratos..."

cd "$CONTRACTS_DIR"

# Build contracts first
print_step "Compilando contratos..."
forge build

# Deploy
print_step "Ejecutando script de deploy..."
export PRIVATE_KEY=$PRIVATE_KEY
forge script script/DeployBridge.s.sol \
    --tc DeployBridge \
    --rpc-url local \
    --broadcast \
    --legacy  # Use legacy transactions for local dev

if [ $? -ne 0 ]; then
    print_error "Deploy de contratos falló"
    exit 1
fi

print_success "Contratos desplegados"

# ==========================================
# PASO 3: CONFIGURACIÓN DEL RELAYER
# ==========================================
print_step "3/4 - Configurando relayer con las direcciones desplegadas..."

cd "$RELAYER_DIR"

# Extract deployed addresses
ANDE_BRIDGE=$(extract_address "AndeBridge")
ETHEREUM_BRIDGE=$(extract_address "EthereumBridge")

if [ -z "$ANDE_BRIDGE" ] || [ -z "$ETHEREUM_BRIDGE" ]; then
    print_error "No se pudieron extraer las direcciones de los contratos"
    print_warning "Verifica el archivo: $CONTRACTS_DIR/broadcast/DeployBridge.s.sol/12345/run-latest.json"
    exit 1
fi

print_success "Direcciones extraídas:"
echo "  - AndeBridge: $ANDE_BRIDGE"
echo "  - EthereumBridge: $ETHEREUM_BRIDGE"

# Update .env file
print_step "Actualizando $RELAYER_DIR/.env..."

cat > "$RELAYER_DIR/.env" << EOF
# RPC Endpoints
ANDECHAIN_RPC_URL="http://localhost:8545"
ETHEREUM_RPC_URL="http://localhost:8545"
CELESTIA_NODE_URL="http://localhost:26659"

# Relayer Wallet
RELAYER_PRIVATE_KEY="$PRIVATE_KEY"

# Deployed Contract Addresses (Auto-generated)
ANDE_BRIDGE_ADDRESS="$ANDE_BRIDGE"
ETHEREUM_BRIDGE_ADDRESS="$ETHEREUM_BRIDGE"
EOF

print_success "Archivo .env actualizado"

# ==========================================
# PASO 4: INICIAR RELAYER
# ==========================================
print_step "4/4 - Iniciando relayer..."

# Check if node_modules exists
if [ ! -d "$RELAYER_DIR/node_modules" ]; then
    print_step "Instalando dependencias del relayer..."
    npm install
fi

print_success "Todas las etapas completadas exitosamente!"
echo ""
print_step "El relayer se iniciará ahora. Presiona Ctrl+C para detenerlo."
echo ""

# Start relayer (this will block)
npm start
