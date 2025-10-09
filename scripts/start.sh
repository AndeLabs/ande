#!/bin/bash

# ==========================================
# AndeChain Unified Development Environment
# ==========================================
# Script unificado que reemplaza start-all.sh y start-dev.sh
# Inicia el ecosistema completo en el orden correcto:
# 1. Infraestructura Docker (blockchain + explorer + faucet)
# 2. Deploy de contratos
# 3. Configuración del relayer
# 4. Inicio opcional del relayer
# ==========================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INFRA_DIR="$PROJECT_ROOT/infra"
CONTRACTS_DIR="$PROJECT_ROOT/contracts"
RELAYER_DIR="$PROJECT_ROOT/relayer"
FRONTEND_DIR="$PROJECT_ROOT/../ande-frontend"

# URLs and settings
RPC_URL="http://localhost:8545"
BLOCKSCOUT_URL="http://localhost:4000"
FAUCET_URL="http://localhost:8081"
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
MAX_RETRIES=30
RETRY_DELAY=2

# Parse command line arguments
START_RELAYER=false
START_FRONTEND=false
SKIP_CONTRACTS=false
ANDE_MODE=false

show_help() {
    echo -e "${CYAN}AndeChain Unified Development Environment${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --relayer     Iniciar el relayer después del deploy"
    echo "  --frontend    Iniciar el frontend Next.js"
    echo "  --ande        Usar stack ANDE Token Duality"
    echo "  --no-contracts Omitir deploy de contratos (útil con --ande)"
    echo "  --help        Mostrar esta ayuda"
    echo ""
    echo "Examples:"
    echo "  $0                           # Inicia infraestructura + contratos"
    echo "  $0 --relayer                 # + relayer"
    echo "  $0 --ande                    # Stack ANDE completo"
    echo "  $0 --ande --no-contracts     # Solo infraestructura ANDE"
    echo "  $0 --relayer --frontend      # Todo el stack"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --relayer)
            START_RELAYER=true
            shift
            ;;
        --frontend)
            START_FRONTEND=true
            shift
            ;;
        --ande)
            ANDE_MODE=true
            shift
            ;;
        --no-contracts)
            SKIP_CONTRACTS=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Opción desconocida '$1'${NC}"
            show_help
            exit 1
            ;;
    esac
done

# ==========================================
# UTILITY FUNCTIONS
# ==========================================
print_step() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}▶ $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Function to wait for RPC to be ready
wait_for_rpc() {
    print_info "Esperando RPC en $RPC_URL..."

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

    print_error "RPC no respondió después de $((MAX_RETRIES * RETRY_DELAY)) segundos"
    return 1
}

# Function to extract contract address from broadcast JSON
extract_address() {
    local contract_name=$1
    local chain_id="1234"
    local broadcast_file="$CONTRACTS_DIR/broadcast/DeployEcosystem.s.sol/$chain_id/run-latest.json"

    if [ ! -f "$broadcast_file" ]; then
        print_error "Archivo de broadcast no encontrado: $broadcast_file"
        return 1
    fi

    grep -A 5 "\"contractName\": \"$contract_name\"" "$broadcast_file" | \
        grep "\"contractAddress\"" | \
        awk -F'"' '{print $4}' | head -1
}

# ==========================================
# BANNER
# ==========================================
clear

if [ "$ANDE_MODE" = true ]; then
    echo -e "${MAGENTA}"
    cat << "EOF"
    _              _       ____ _           _
   / \   _ __   __| | ___ / ___| |__   __ _(_)_ __
  / _ \ | '_ \ / _` |/ _ \ |   | '_ \ / _` | | '_ \
 / ___ \| | | | (_| |  __/ |___| | | | (_| | | | | |
/_/   \_\_| |_|\__,_|\___|\____|_| |_|\__,_|_|_| |_|

    🔥 ANDE Token Duality Development Environment 🔥
EOF
    echo -e "${NC}"
else
    echo -e "${CYAN}"
    cat << "EOF"
    _              _       ____ _           _
   / \   _ __   __| | ___ / ___| |__   __ _(_)_ __
  / _ \ | '_ \ / _` |/ _ \ |   | '_ \ / _` | | '_ \
 / ___ \| | | | (_| |  __/ |___| | | | (_| | | | | |
/_/   \_\_| |_|\__,_|\___|\____|_| |_|\__,_|_|_| |_|

    Standard Development Environment
EOF
    echo -e "${NC}"
fi

echo ""
print_info "Configuración:"
echo "  • Modo ANDE: $([ "$ANDE_MODE" = true ] && echo "✅ Activado" || echo "❌ Desactivado")"
echo "  • Iniciar Relayer: $([ "$START_RELAYER" = true ] && echo "✅ Sí" || echo "❌ No")"
echo "  • Iniciar Frontend: $([ "$START_FRONTEND" = true ] && echo "✅ Sí" || echo "❌ No")"
echo "  • Deploy Contratos: $([ "$SKIP_CONTRACTS" = true ] && echo "❌ Omitido" || echo "✅ Sí")"
echo ""

# ==========================================
# PASO 1: INFRAESTRUCTURA
# ==========================================
print_step "PASO 1/4: Infraestructura Docker"

cd "$INFRA_DIR"

# Determinar qué docker-compose usar
if [ "$ANDE_MODE" = true ]; then
    COMPOSE_FILE="stacks/single-sequencer/docker-compose.ande.yml"
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "Docker compose ANDE no encontrado: $COMPOSE_FILE"
        exit 1
    fi
    print_info "Usando stack ANDE Token Duality..."
    COMPOSE_CMD="docker compose -f $COMPOSE_FILE"
else
    COMPOSE_FILE="docker-compose.yml"
    print_info "Usando stack estándar..."
    COMPOSE_CMD="docker compose"
fi

# Check if containers are already running
if $COMPOSE_CMD ps 2>/dev/null | grep -q "Up"; then
    print_warning "Contenedores ya están corriendo"
    print_info "¿Reiniciar servicios? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_info "Reiniciando servicios..."
        $COMPOSE_CMD down -v
        sleep 2
    else
        print_warning "Usando infraestructura existente"
    fi
fi

print_info "Iniciando servicios Docker..."
$COMPOSE_CMD up -d --build

# Wait for RPC
wait_for_rpc || exit 1

print_success "Infraestructura lista"
echo ""

# Show running services
print_info "Servicios activos:"
$COMPOSE_CMD ps --format "  • {{.Name}} - {{.Status}}" | head -8
echo ""

# ==========================================
# PASO 2: DEPLOY DE CONTRATOS (si no se omite)
# ==========================================
if [ "$SKIP_CONTRACTS" = false ]; then
    print_step "PASO 2/4: Deploy de Smart Contracts"

    cd "$CONTRACTS_DIR"

    # Build contracts first
    print_info "Compilando contratos..."
    forge build --silent

    # Deploy
    print_info "Desplegando ecosistema de contratos..."
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
    print_info "Contratos principales:"
    local broadcast_file="$CONTRACTS_DIR/broadcast/DeployEcosystem.s.sol/1234/run-latest.json"

    if [ -f "$broadcast_file" ]; then
        echo "  • ANDEToken:     $(extract_address "ANDEToken" || echo "No encontrado")"
        echo "  • AusdToken:     $(extract_address "AusdToken" || echo "No encontrado")"
        echo "  • AndeBridge:    $(extract_address "AndeBridge" || echo "No encontrado")"
        echo "  • EthereumBridge: $(extract_address "EthereumBridge" || echo "No encontrado")"
        echo ""
        print_info "Archivo completo: $broadcast_file"
    else
        print_warning "No se pudo leer el archivo de broadcast"
    fi
    echo ""
else
    print_step "PASO 2/4: Deploy de Contratos OMITIDO"
    print_warning "Omitiendo deploy de contratos (--no-contracts)"
    echo ""
fi

# ==========================================
# PASO 3: CONFIGURACIÓN DEL RELAYER (si se solicita)
# ==========================================
if [ "$START_RELAYER" = true ]; then
    print_step "PASO 3/4: Configurando Relayer"

    if [ "$SKIP_CONTRACTS" = true ]; then
        print_warning "No se puede configurar el relayer sin deploy de contratos"
        print_info "Ejecuta sin --no-contracts para configurar el relayer automáticamente"
    else
        cd "$RELAYER_DIR"

        # Extract deployed addresses
        ANDE_BRIDGE=$(extract_address "AndeBridge")
        ETHEREUM_BRIDGE=$(extract_address "EthereumBridge")

        if [ -z "$ANDE_BRIDGE" ] || [ -z "$ETHEREUM_BRIDGE" ]; then
            print_error "No se pudieron extraer las direcciones de los bridges"
            exit 1
        fi

        print_success "Direcciones extraídas:"
        echo "  • AndeBridge: $ANDE_BRIDGE"
        echo "  • EthereumBridge: $ETHEREUM_BRIDGE"

        # Update .env file
        print_info "Actualizando .env del relayer..."
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

        print_success "Relayer configurado"
    fi
    echo ""
else
    print_step "PASO 3/4: Configuración Relayer OMITIDA"
    print_info "Usa --relayer para configurar e iniciar el relayer"
    echo ""
fi

# ==========================================
# PASO 4: INFORMACIÓN FINAL
# ==========================================
print_step "PASO 4/4: Sistema Listo"

print_success "AndeChain está corriendo correctamente!"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🔗 URLs de Acceso:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  • RPC Endpoint:    $RPC_URL"
echo "  • Block Explorer:  $BLOCKSCOUT_URL"
echo "  • Faucet:          $FAUCET_URL"
if [ "$ANDE_MODE" = true ]; then
    echo "  • ANDE Precompile: 0x00000000000000000000000000000000000000FD"
fi
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}👛 Cuenta Pre-financiada:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Address:     0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
echo "  Private Key: $PRIVATE_KEY"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}🎯 Comandos Útiles:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  • Ver logs:        cd infra && $COMPOSE_CMD logs -f"
echo "  • Detener todo:    cd infra && $COMPOSE_CMD down"
echo "  • Reset completo:  cd infra && $COMPOSE_CMD down -v"
echo "  • Verificar contratos: ./scripts/verify-contracts.sh"
echo ""

if [ "$START_RELAYER" = true ] && [ "$SKIP_CONTRACTS" = false ]; then
    print_info "Iniciando relayer en segundo plano..."
    cd "$RELAYER_DIR"

    if [ ! -d "node_modules" ]; then
        print_info "Instalando dependencias del relayer..."
        npm install --silent
    fi

    # Start relayer in background
    npm start > /dev/null 2>&1 &
    RELAYER_PID=$!
    echo $RELAYER_PID > .relayer.pid
    print_success "Relayer iniciado (PID: $RELAYER_PID)"
    echo ""
fi

if [ "$START_FRONTEND" = true ]; then
    print_info "Iniciando frontend Next.js..."
    cd "$FRONTEND_DIR"

    if [ ! -d "node_modules" ]; then
        print_info "Instalando dependencias del frontend..."
        npm install --silent
    fi

    # Start frontend in background
    npm run dev > /dev/null 2>&1 &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > .frontend.pid
    print_success "Frontend iniciado (PID: $FRONTEND_PID) - http://localhost:9002"
    echo ""
fi

echo -e "${GREEN}🚀 Sistema listo para desarrollar!${NC}"
echo ""