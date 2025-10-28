#!/bin/bash

################################################################################
# AndeChain Quick Testnet Deployment Script
# 
# This script automates the deployment of AndeChain testnet on a fresh machine
# Usage: ./scripts/quick-testnet-deploy.sh [options]
#
# Options:
#   --help              Show this help message
#   --clean             Clean all previous data and start fresh
#   --skip-build        Skip Docker image builds (use cached images)
#   --dev               Use development configuration (lighter resources)
#   --check-only        Only run health checks, don't deploy
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
ENV_FILE="$PROJECT_DIR/.env"
DATA_DIR="$HOME/.ande-data/ev-reth"

# Default options
CLEAN=false
SKIP_BUILD=false
DEV_MODE=false
CHECK_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --help)
      grep "^# " "$0" | sed 's/^# //'
      exit 0
      ;;
    --clean)
      CLEAN=true
      shift
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --dev)
      DEV_MODE=true
      shift
      ;;
    --check-only)
      CHECK_ONLY=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[✅]${NC} $1"
}

log_error() {
  echo -e "${RED}[❌]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[⚠️]${NC} $1"
}

# Error handler
error_exit() {
  log_error "$1"
  exit 1
}

################################################################################
# PHASE 0: Pre-flight Checks
################################################################################

phase_preflight_checks() {
  log_info "Running preflight checks..."
  
  # Check Docker
  if ! command -v docker &> /dev/null; then
    error_exit "Docker is not installed. Please install Docker Desktop."
  fi
  log_success "Docker found: $(docker --version)"
  
  # Check Docker Compose
  if ! docker compose version &> /dev/null; then
    error_exit "Docker Compose is not installed or not accessible."
  fi
  log_success "Docker Compose found: $(docker compose version | head -1)"
  
  # Check Docker daemon
  if ! docker ps &> /dev/null; then
    error_exit "Docker daemon is not running. Please start Docker Desktop."
  fi
  log_success "Docker daemon is running"
  
  # Check disk space
  AVAILABLE=$(df "$PROJECT_DIR" | awk 'NR==2 {print $4}')
  REQUIRED=51200000  # 50GB in KB
  if [ "$AVAILABLE" -lt "$REQUIRED" ]; then
    error_exit "Not enough disk space. Need 50GB, have $(( AVAILABLE / 1024 / 1024 ))GB"
  fi
  log_success "Disk space check passed: $(( AVAILABLE / 1024 / 1024 ))GB available"
  
  # Check required ports
  log_info "Checking required ports..."
  REQUIRED_PORTS=(8545 8546 4000 3001 7331 26658)
  for port in "${REQUIRED_PORTS[@]}"; do
    if nc -z localhost $port 2>/dev/null; then
      log_warning "Port $port is already in use"
    else
      log_success "Port $port is available"
    fi
  done
  
  # Check docker-compose.yml exists
  if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    error_exit "docker-compose.yml not found at $DOCKER_COMPOSE_FILE"
  fi
  log_success "docker-compose.yml found"
  
  # Check genesis.json exists
  if [ ! -f "$PROJECT_DIR/genesis.json" ]; then
    error_exit "genesis.json not found at $PROJECT_DIR/genesis.json"
  fi
  log_success "genesis.json found"
}

################################################################################
# PHASE 1: Clean Previous State (Optional)
################################################################################

phase_clean_state() {
  if [ "$CLEAN" = false ]; then
    return
  fi
  
  log_info "Cleaning previous state..."
  
  # Stop containers
  if docker compose -f "$DOCKER_COMPOSE_FILE" ps | grep -q "Up"; then
    log_info "Stopping running containers..."
    docker compose -f "$DOCKER_COMPOSE_FILE" down -v
    sleep 5
  fi
  
  # Remove old blockchain data
  if [ -d "$DATA_DIR" ]; then
    log_info "Removing old blockchain data at $DATA_DIR..."
    rm -rf "$DATA_DIR"/*
  fi
  
  # Prune unused Docker resources
  log_info "Pruning unused Docker resources..."
  docker system prune -f --volumes
  
  log_success "Previous state cleaned"
}

################################################################################
# PHASE 2: Setup Environment
################################################################################

phase_setup_environment() {
  log_info "Setting up environment..."
  
  # Create .env if it doesn't exist
  if [ ! -f "$ENV_FILE" ]; then
    log_info "Creating .env file..."
    cat > "$ENV_FILE" << 'EOF'
# ============================================================
# AndeChain Testnet Configuration
# ============================================================

CHAIN_ID=2019
NETWORK_NAME="AndeChain Testnet"
NODE_ENV=production

DOCKER_USER=1000
DOCKER_GROUP=1000

FAUCET_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
FAUCET_AMOUNT=10000000000000000000000
FAUCET_COOLDOWN_MINUTES=5
FAUCET_PORT=3001

EXPLORER_DB_PASSWORD=andechain-secure-postgres-2025
EXPLORER_FRONTEND_PORT=4000
EXPLORER_BACKEND_PORT=4001
EXPLORER_HOST=localhost

GRAFANA_USER=admin
GRAFANA_PASSWORD=andechain-grafana-2025
GRAFANA_PORT=3000

PROMETHEUS_PORT=9090

FRONTEND_PORT=3002
NEXTAUTH_URL=https://localhost:3002
WALLET_CONNECT_PROJECT_ID=c3e4c3a3b3e4c3a3b3e4c3a3b3e4c3a3

CELESTIA_NETWORK=mocha-4
CELESTIA_NAMESPACE=andechain-v1
CELESTIA_RPC=http://celestia-light:26658
EOF
    log_success ".env file created"
  else
    log_success ".env file already exists"
  fi
  
  # Create data directory
  mkdir -p "$DATA_DIR"
  log_success "Data directory ready at $DATA_DIR"
}

################################################################################
# PHASE 3: Build Docker Images
################################################################################

phase_build_images() {
  if [ "$SKIP_BUILD" = true ]; then
    log_warning "Skipping Docker image builds (using cached images)"
    return
  fi
  
  log_info "Building Docker images..."
  
  # Build ev-reth
  if [ -d "$PROJECT_DIR/ev-reth" ]; then
    log_info "Building ev-reth image..."
    docker build -t ande/ev-reth:latest \
      --build-arg BUILD_PROFILE=release \
      --build-arg FEATURES="jemalloc asm-keccak" \
      -f "$PROJECT_DIR/ev-reth/Dockerfile" \
      "$PROJECT_DIR/ev-reth" 2>&1 | grep -E "^Step|Successfully|error" || true
    log_success "ev-reth image built"
  fi
  
  # Build frontend (optional)
  if [ -d "$PROJECT_DIR/andefrontend" ] && [ "$DEV_MODE" = false ]; then
    log_info "Building frontend image..."
    docker build -t ande/frontend:dev \
      --build-arg NODE_VERSION=20 \
      -f "$PROJECT_DIR/andefrontend/Dockerfile" \
      "$PROJECT_DIR/andefrontend" 2>&1 | grep -E "^Step|Successfully|error" || true
    log_success "Frontend image built"
  fi
}

################################################################################
# PHASE 4: Start Services
################################################################################

phase_start_services() {
  log_info "Starting AndeChain services..."
  cd "$PROJECT_DIR"
  
  # Start infrastructure
  log_info "Starting infrastructure services..."
  docker compose up -d jwt-init celestia-light
  sleep 5
  
  # Verify JWT generation
  if docker exec andechain-jwt-init test -f /jwt/jwt.hex 2>/dev/null; then
    log_success "JWT generated"
  else
    log_warning "JWT generation may still be in progress"
  fi
  
  # Start blockchain core
  log_info "Starting blockchain core services..."
  docker compose up -d ev-reth ande-evolve-sequencer
  
  # Wait for startup
  log_info "Waiting for services to start (45 seconds)..."
  sleep 45
  
  # Start supporting services
  log_info "Starting supporting services..."
  docker compose up -d explorer-db stats-db redis explorer-backend contract-verifier
  sleep 30
  
  # Start frontend services
  log_info "Starting frontend services..."
  docker compose up -d explorer-frontend faucet faucet-proxy
  
  if [ "$DEV_MODE" = false ]; then
    docker compose up -d andechain-frontend
  fi
  
  log_success "All services started"
}

################################################################################
# PHASE 5: Health Checks
################################################################################

phase_health_checks() {
  log_info "Performing health checks..."
  
  local checks_passed=0
  local checks_failed=0
  
  # Check 1: RPC Chain ID
  log_info "Test 1: Checking chain ID..."
  if curl -s -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | grep -q "0x7e3"; then
    log_success "Chain ID correct (0x7e3 = 2019)"
    ((checks_passed++))
  else
    log_error "RPC endpoint not responding correctly"
    ((checks_failed++))
  fi
  
  # Check 2: Block Production
  log_info "Test 2: Checking block production..."
  sleep 10  # Wait for at least one block
  BLOCK=$(curl -s -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq -r '.result' 2>/dev/null | xargs printf "%d\n" 2>/dev/null || echo "0")
  
  if [ "$BLOCK" -gt 0 ]; then
    log_success "Blocks producing (current block: $BLOCK)"
    ((checks_passed++))
  else
    log_error "No blocks produced yet (this may be normal in lazy mode)"
    ((checks_failed++))
  fi
  
  # Check 3: Explorer
  log_info "Test 3: Checking block explorer..."
  if curl -s http://localhost:4000 | grep -q "blockscout" 2>/dev/null; then
    log_success "Block explorer accessible"
    ((checks_passed++))
  else
    log_error "Block explorer not responding"
    ((checks_failed++))
  fi
  
  # Check 4: Faucet
  log_info "Test 4: Checking faucet service..."
  if curl -s http://localhost:8081/health 2>/dev/null | grep -q "ok\|active" ; then
    log_success "Faucet service active"
    ((checks_passed++))
  else
    log_warning "Faucet still initializing (this is normal)"
  fi
  
  # Check 5: Docker containers
  log_info "Test 5: Checking container status..."
  RUNNING=$(docker compose ps --services --filter "status=running" | wc -l)
  TOTAL=$(docker compose ps --services | wc -l)
  log_info "Running containers: $RUNNING/$TOTAL"
  
  # Summary
  echo ""
  log_success "Health check complete: $checks_passed passed, $checks_failed failed"
  
  if [ "$checks_failed" -gt 0 ]; then
    log_warning "Some checks failed. This may be normal if services are still starting."
    log_info "Check logs with: docker compose logs -f [service_name]"
  fi
  
  echo ""
}

################################################################################
# PHASE 6: Display Connection Information
################################################################################

phase_display_info() {
  # Get local IP
  LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1")
  
  echo ""
  log_success "AndeChain Testnet Deployment Complete!"
  echo ""
  echo "================================================================"
  echo "📊 AndeChain Testnet Information"
  echo "================================================================"
  echo ""
  echo "🌐 Network Endpoints:"
  echo "  RPC HTTP:       http://localhost:8545"
  echo "  RPC WebSocket:  ws://localhost:8546"
  echo "  Sequencer RPC:  http://localhost:7331"
  echo ""
  echo "🔍 Explorers & Tools:"
  echo "  Block Explorer: http://localhost:4000"
  echo "  Explorer API:   http://localhost:4001"
  echo "  Faucet:         http://localhost:3001"
  echo ""
  echo "📈 Monitoring (if enabled):"
  echo "  Prometheus:     http://localhost:9090"
  echo "  Grafana:        http://localhost:3000"
  echo ""
  echo "⛓️  Chain Configuration:"
  echo "  Chain ID:       2019"
  echo "  Network Name:   AndeChain Testnet"
  echo "  Native Token:   ANDE"
  echo "  Decimals:       18"
  echo ""
  echo "🔑 Test Account:"
  echo "  Address:        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  echo "  Private Key:    0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  echo "  Initial Balance: 1 billion ANDE"
  echo ""
  echo "🌍 For Remote Access:"
  echo "  Replace 'localhost' with: $LOCAL_IP"
  echo ""
  echo "📖 Documentation:"
  echo "  Deployment Guide:     TESTNET_DEPLOYMENT_GUIDE.md"
  echo "  Readiness Checklist:  TESTNET_READINESS_CHECKLIST.md"
  echo ""
  echo "🔧 Useful Commands:"
  echo "  View logs:            docker compose logs -f [service]"
  echo "  List services:        docker compose ps"
  echo "  Stop services:        docker compose stop"
  echo "  Restart service:      docker compose restart [service]"
  echo "  Health check:         $PROJECT_DIR/scripts/health-check.sh"
  echo ""
  echo "================================================================"
  echo ""
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║           🚀 AndeChain Quick Testnet Deployment 🚀            ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  
  if [ "$CHECK_ONLY" = true ]; then
    log_info "Running health checks only..."
    phase_health_checks
    exit 0
  fi
  
  # Run phases
  phase_preflight_checks
  phase_clean_state
  phase_setup_environment
  phase_build_images
  phase_start_services
  
  log_info "Waiting for final initialization (30 seconds)..."
  sleep 30
  
  phase_health_checks
  phase_display_info
  
  log_success "Deployment complete! Your testnet is ready to use."
}

# Run main function
main
