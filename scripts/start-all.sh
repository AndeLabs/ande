#!/bin/bash

# ==========================================
# AndeChain - Script de Inicio Completo
# ==========================================
# Inicia todo el ecosistema en el orden correcto:
# 1. Infraestructura Docker (blockchain + explorer)
# 2. Deploy de contratos
# 3. Relayer (opcional)
# ==========================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INFRA_DIR="$PROJECT_ROOT/infra"
CONTRACTS_DIR="$PROJECT_ROOT/contracts"
RELAYER_DIR="$PROJECT_ROOT/relayer"
RPC_URL="http://localhost:8545"
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
MAX_RETRIES=30
RETRY_DELAY=2

# Function to print colored messages
print_step() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}▶ $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Function to wait for RPC to be ready
wait_for_rpc() {
    print_info "Esperando a que el RPC esté disponible en $RPC_URL..."

    for i in $(seq 1 $MAX_RETRIES); do
        if curl -s -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            $RPC_URL > /dev/null 2>&1; then
            print_success "RPC está listo y respondiendo!"
            return 0
        fi
        echo -n "."
        sleep $RETRY_DELAY
    done

    print_error "RPC no respondió después de $((MAX_RETRIES * RETRY_DELAY)) segundos"
    return 1
}

# ==========================================
# BANNER
# ==========================================
clear
echo -e "${CYAN}"
cat << "EOF"
    _              _       ____ _           _
   / \   _ __   __| | ___ / ___| |__   __ _(_)_ __
  / _ \ | '_ \ / _` |/ _ \ |   | '_ \ / _` | | '_ \
 / ___ \| | | | (_| |  __/ |___| | | | (_| | | | | |
/_/   \_\_| |_|\__,_|\___|\____|_| |_|\__,_|_|_| |_|

    Desarrollo Local - Script de Inicio Automático
EOF
echo -e "${NC}"
echo ""

# ==========================================
# PASO 1: INFRAESTRUCTURA
# ==========================================
print_step "PASO 1/3: Infraestructura Docker"

cd "$INFRA_DIR"

# Check if containers are already running
if docker compose ps 2>/dev/null | grep -q "Up"; then
    print_warning "Algunos contenedores ya están corriendo"
    print_info "Reiniciando servicios para asegurar estado limpio..."
    docker compose down
    sleep 2
fi

print_info "Iniciando servicios Docker..."
docker compose up -d --build

# Wait for RPC
wait_for_rpc || exit 1

print_success "Infraestructura lista"
echo ""

# Show running services
print_info "Servicios activos:"
docker compose ps --format "  • {{.Name}} - {{.Status}}" | head -8
echo ""

# ==========================================
# PASO 2: DEPLOY DE CONTRATOS
# ==========================================
print_step "PASO 2/3: Deploy de Smart Contracts"

cd "$CONTRACTS_DIR"

# Build contracts first
print_info "Compilando contratos..."
forge build --silent

# Deploy
print_info "Desplegando ecosistema completo de contratos..."
export PRIVATE_KEY=$PRIVATE_KEY
forge script script/DeployEcosystem.s.sol \
    --tc DeployEcosystem \
    --rpc-url local \
    --broadcast \
    --legacy \
    --silent

if [ $? -ne 0 ]; then
    print_error "Deploy de contratos falló"
    exit 1
fi

print_success "Contratos desplegados exitosamente"
echo ""

# Show key deployed contracts
print_info "Contratos principales desplegados:"
BROADCAST_FILE="$CONTRACTS_DIR/broadcast/DeployEcosystem.s.sol/1234/run-latest.json"

if [ -f "$BROADCAST_FILE" ]; then
    # Extract some key addresses
    ANDE_TOKEN=$(grep -A 5 '"contractName": "ANDEToken"' "$BROADCAST_FILE" | grep '"contractAddress"' | awk -F'"' '{print $4}' | head -1)
    ANDE_BRIDGE=$(grep -A 5 '"contractName": "AndeBridge"' "$BROADCAST_FILE" | grep '"contractAddress"' | awk -F'"' '{print $4}' | head -1)

    echo "  • ANDEToken:   $ANDE_TOKEN"
    echo "  • AndeBridge:  $ANDE_BRIDGE"
    echo ""
    print_info "Archivo completo: $BROADCAST_FILE"
else
    print_warning "No se pudo leer el archivo de broadcast"
fi
echo ""

# ==========================================
# PASO 3: INFORMACIÓN FINAL
# ==========================================
print_step "PASO 3/3: Sistema Listo"

print_success "AndeChain está corriendo correctamente!"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ URLs de Acceso:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  🔗 RPC Endpoint:       http://localhost:8545"
echo "  🔍 Block Explorer:     http://localhost:4000"
echo "  💧 Faucet:             http://localhost:8081"
echo "  🌐 Frontend (Next.js): http://localhost:9002"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Cuenta Pre-financiada:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Address:     0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
echo "  Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📌 Próximos Pasos:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  1. Ver logs:           cd infra && docker compose logs -f"
echo "  2. Detener todo:       make stop"
echo "  3. Reset completo:     make reset"
echo "  4. Ver contratos:      http://localhost:4000"
echo ""
echo -e "${GREEN}¡Listo para desarrollar! 🚀${NC}"
echo ""
