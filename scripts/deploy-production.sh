#!/bin/bash
# =========================================================================
# ANDE CHAIN - PRODUCTION DEPLOYMENT SCRIPT
# =========================================================================
# Professional deployment with all advanced features enabled
# Features: Parallel EVM, MEV Integration, Adaptive Lazy Mode, Advanced Monitoring
# =========================================================================

set -euo pipefail

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
CONFIG_DIR="$PROJECT_ROOT/config"

# Deployment options
ENABLE_PARALLEL_EVM="${ENABLE_PARALLEL_EVM:-true}"
ENABLE_MEV="${ENABLE_MEV:-true}"
ENABLE_LAZY_MODE="${ENABLE_LAZY_MODE:-true}"
ENABLE_MONITORING="${ENABLE_MONITORING:-true}"

# =========================================================================
# Helper Functions
# =========================================================================

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${MAGENTA}$1${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}▶ $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# =========================================================================
# Pre-flight Checks
# =========================================================================

preflight_checks() {
    print_section "Running Pre-flight Checks"
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running"
        exit 1
    fi
    print_success "Docker is running"
    
    # Check if Docker Compose is available
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    print_success "Docker Compose is available"
    
    # Check if config directory exists
    if [ ! -d "$CONFIG_DIR" ]; then
        print_error "Config directory not found: $CONFIG_DIR"
        exit 1
    fi
    print_success "Config directory found"
    
    # Check required config files
    local required_configs=(
        "parallel-evm.production.toml"
        "mev-integration.production.toml"
        "monitoring.production.yaml"
        "prometheus-alerts.yml"
    )
    
    for config in "${required_configs[@]}"; do
        if [ ! -f "$CONFIG_DIR/$config" ]; then
            print_error "Required config file not found: $config"
            exit 1
        fi
    done
    print_success "All required config files present"
    
    # Check available system resources
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 16 ]; then
        print_warning "System has less than 16GB RAM (found: ${total_mem}GB)"
        print_warning "Parallel EVM performance may be limited"
    else
        print_success "Sufficient memory available (${total_mem}GB)"
    fi
    
    local cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt 8 ]; then
        print_warning "System has less than 8 CPU cores (found: ${cpu_cores})"
        print_warning "Consider reducing concurrency_level in parallel-evm.production.toml"
    else
        print_success "Sufficient CPU cores available (${cpu_cores})"
    fi
    
    # Check available disk space
    local available_disk=$(df -BG "$PROJECT_ROOT" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_disk" -lt 100 ]; then
        print_warning "Less than 100GB disk space available (found: ${available_disk}GB)"
    else
        print_success "Sufficient disk space available (${available_disk}GB)"
    fi
}

# =========================================================================
# Configuration Summary
# =========================================================================

show_configuration() {
    print_section "Deployment Configuration"
    
    echo -e "${CYAN}Features Enabled:${NC}"
    echo ""
    
    if [ "$ENABLE_PARALLEL_EVM" = "true" ]; then
        echo -e "  ${GREEN}✓${NC} Parallel EVM Execution (16 workers)"
        echo -e "    ${CYAN}→${NC} High Throughput Profile"
        echo -e "    ${CYAN}→${NC} Lazy Updates for ANDE Token Duality"
        echo -e "    ${CYAN}→${NC} Advanced Dependency Analysis"
    else
        echo -e "  ${RED}✗${NC} Parallel EVM Execution (Sequential only)"
    fi
    
    echo ""
    
    if [ "$ENABLE_MEV" = "true" ]; then
        echo -e "  ${GREEN}✓${NC} MEV Integration"
        echo -e "    ${CYAN}→${NC} Arbitrage Detection"
        echo -e "    ${CYAN}→${NC} Sandwich Attack Detection"
        echo -e "    ${CYAN}→${NC} Liquidation Opportunities"
        echo -e "    ${CYAN}→${NC} MEV Auction System"
        echo -e "    ${CYAN}→${NC} Automatic Distribution to Stakers"
    else
        echo -e "  ${RED}✗${NC} MEV Integration"
    fi
    
    echo ""
    
    if [ "$ENABLE_LAZY_MODE" = "true" ]; then
        echo -e "  ${GREEN}✓${NC} Adaptive Lazy Mode"
        echo -e "    ${CYAN}→${NC} 5s blocks when idle"
        echo -e "    ${CYAN}→${NC} 1s blocks when active"
        echo -e "    ${CYAN}→${NC} Automatic DA cost optimization"
    else
        echo -e "  ${RED}✗${NC} Adaptive Lazy Mode (Fixed 1s blocks)"
    fi
    
    echo ""
    
    if [ "$ENABLE_MONITORING" = "true" ]; then
        echo -e "  ${GREEN}✓${NC} Advanced Monitoring"
        echo -e "    ${CYAN}→${NC} Prometheus Metrics (3 endpoints)"
        echo -e "    ${CYAN}→${NC} Grafana Dashboards"
        echo -e "    ${CYAN}→${NC} Alert Rules (30+ alerts)"
        echo -e "    ${CYAN}→${NC} Performance Tracking"
    else
        echo -e "  ${RED}✗${NC} Advanced Monitoring (Basic only)"
    fi
    
    echo ""
    echo -e "${CYAN}Network Configuration:${NC}"
    echo -e "  Chain ID: ${GREEN}6174${NC}"
    echo -e "  Network: ${GREEN}ANDE Chain Testnet${NC}"
    echo -e "  DA Layer: ${GREEN}Celestia Mocha-4${NC}"
    echo ""
}

# =========================================================================
# Build Docker Images
# =========================================================================

build_images() {
    print_section "Building Docker Images"
    
    cd "$PROJECT_ROOT"
    
    # Check if ev-reth image exists
    if docker images | grep -q "ev-reth-andechain"; then
        print_info "ev-reth image already exists"
        read -p "Rebuild image? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Rebuilding ev-reth image..."
            docker-compose build ev-reth-sequencer
            print_success "Image rebuilt"
        else
            print_info "Skipping rebuild"
        fi
    else
        print_info "Building ev-reth image (this may take several minutes)..."
        docker-compose build ev-reth-sequencer
        print_success "Image built successfully"
    fi
}

# =========================================================================
# Start Services
# =========================================================================

start_services() {
    print_section "Starting ANDE Chain Services"
    
    cd "$PROJECT_ROOT"
    
    print_info "Starting infrastructure services..."
    docker-compose up -d celestia-light prometheus grafana loki
    
    sleep 5
    
    print_info "Waiting for Celestia light node to be healthy..."
    local max_wait=120
    local waited=0
    while [ $waited -lt $max_wait ]; do
        if docker-compose ps celestia-light | grep -q "healthy"; then
            print_success "Celestia light node is healthy"
            break
        fi
        echo -n "."
        sleep 5
        waited=$((waited + 5))
    done
    
    if [ $waited -ge $max_wait ]; then
        print_error "Celestia light node failed to become healthy"
        exit 1
    fi
    
    print_info "Starting execution and consensus layers..."
    docker-compose up -d ev-reth-sequencer evolve-sequencer
    
    print_info "Starting remaining services..."
    docker-compose up -d
    
    print_success "All services started"
}

# =========================================================================
# Wait for Services
# =========================================================================

wait_for_services() {
    print_section "Waiting for Services to be Ready"
    
    # Wait for ev-reth RPC
    print_info "Waiting for ev-reth RPC..."
    local max_wait=60
    local waited=0
    while [ $waited -lt $max_wait ]; do
        if curl -sf -X POST -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            http://localhost:8545 >/dev/null 2>&1; then
            print_success "ev-reth RPC is responding"
            break
        fi
        echo -n "."
        sleep 2
        waited=$((waited + 2))
    done
    
    if [ $waited -ge $max_wait ]; then
        print_error "ev-reth RPC failed to start"
        exit 1
    fi
    
    # Wait for Evolve sequencer
    print_info "Waiting for Evolve sequencer..."
    max_wait=60
    waited=0
    while [ $waited -lt $max_wait ]; do
        if curl -sf http://localhost:7331/status >/dev/null 2>&1; then
            print_success "Evolve sequencer is responding"
            break
        fi
        echo -n "."
        sleep 2
        waited=$((waited + 2))
    done
    
    if [ $waited -ge $max_wait ]; then
        print_warning "Evolve sequencer is slow to start (this is normal)"
    fi
    
    # Check Prometheus
    if curl -sf http://localhost:9090/-/healthy >/dev/null 2>&1; then
        print_success "Prometheus is healthy"
    else
        print_warning "Prometheus is not responding"
    fi
    
    # Check Grafana
    if curl -sf http://localhost:3000/api/health >/dev/null 2>&1; then
        print_success "Grafana is healthy"
    else
        print_warning "Grafana is not responding"
    fi
}

# =========================================================================
# Verify Deployment
# =========================================================================

verify_deployment() {
    print_section "Verifying Deployment"
    
    # Check block production
    local block_num=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://localhost:8545 | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$block_num" ]; then
        local block_dec=$((16#${block_num#0x}))
        print_success "Current block: $block_dec"
    else
        print_error "Failed to get block number"
    fi
    
    # Check mempool
    local mempool=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"txpool_status","params":[],"id":1}' \
        http://localhost:8545)
    
    if [ -n "$mempool" ]; then
        print_success "Mempool status: OK"
    else
        print_warning "Failed to get mempool status"
    fi
    
    # Check metrics endpoints
    if curl -sf http://localhost:9001/metrics >/dev/null 2>&1; then
        print_success "Main metrics endpoint: http://localhost:9001/metrics"
    else
        print_warning "Main metrics endpoint not responding"
    fi
    
    if [ "$ENABLE_PARALLEL_EVM" = "true" ]; then
        if curl -sf http://localhost:9091/metrics >/dev/null 2>&1; then
            print_success "Parallel EVM metrics: http://localhost:9091/metrics"
        else
            print_warning "Parallel EVM metrics not responding"
        fi
    fi
    
    if [ "$ENABLE_MEV" = "true" ]; then
        if curl -sf http://localhost:9092/mev-metrics >/dev/null 2>&1; then
            print_success "MEV metrics: http://localhost:9092/mev-metrics"
        else
            print_warning "MEV metrics not responding"
        fi
    fi
}

# =========================================================================
# Display Access Information
# =========================================================================

show_access_info() {
    print_section "Access Information"
    
    echo ""
    echo -e "${CYAN}RPC Endpoints:${NC}"
    echo -e "  HTTP RPC:      ${GREEN}http://localhost:8545${NC}"
    echo -e "  WebSocket:     ${GREEN}ws://localhost:8546${NC}"
    echo ""
    
    echo -e "${CYAN}Monitoring Dashboards:${NC}"
    echo -e "  Prometheus:    ${GREEN}http://localhost:9090${NC}"
    echo -e "  Grafana:       ${GREEN}http://localhost:3000${NC}"
    echo -e "                 ${YELLOW}(admin / andechain-admin-2025)${NC}"
    echo ""
    
    echo -e "${CYAN}Metrics Endpoints:${NC}"
    echo -e "  Main:          ${GREEN}http://localhost:9001/metrics${NC}"
    echo -e "  Parallel EVM:  ${GREEN}http://localhost:9091/metrics${NC}"
    echo -e "  MEV System:    ${GREEN}http://localhost:9092/mev-metrics${NC}"
    echo -e "  Evolve:        ${GREEN}http://localhost:26660/metrics${NC}"
    echo ""
    
    echo -e "${CYAN}Useful Commands:${NC}"
    echo -e "  View logs:           ${YELLOW}docker-compose logs -f${NC}"
    echo -e "  Check status:        ${YELLOW}docker-compose ps${NC}"
    echo -e "  Stop services:       ${YELLOW}docker-compose down${NC}"
    echo -e "  Monitor blocks:      ${YELLOW}./scripts/adaptive-monitor.sh${NC}"
    echo -e "  Generate txs:        ${YELLOW}./scripts/tx-generator.sh${NC}"
    echo ""
}

# =========================================================================
# Main Deployment Flow
# =========================================================================

main() {
    print_header "ANDE CHAIN - PRODUCTION DEPLOYMENT"
    
    echo -e "${MAGENTA}Deploying ANDE Chain with advanced features...${NC}"
    echo ""
    
    # Run pre-flight checks
    preflight_checks
    
    # Show configuration
    show_configuration
    
    # Confirm deployment
    echo ""
    read -p "$(echo -e ${YELLOW}Proceed with deployment? ${NC}[Y/n]: )" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
    
    # Build images
    build_images
    
    # Start services
    start_services
    
    # Wait for services
    wait_for_services
    
    # Verify deployment
    verify_deployment
    
    # Show access information
    show_access_info
    
    print_header "DEPLOYMENT COMPLETE"
    
    print_success "ANDE Chain is running with all advanced features!"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo -e "  1. Monitor block production: ${YELLOW}./scripts/adaptive-monitor.sh${NC}"
    echo -e "  2. Generate test transactions: ${YELLOW}./scripts/tx-generator.sh${NC}"
    echo -e "  3. Check Grafana dashboards: ${GREEN}http://localhost:3000${NC}"
    echo ""
}

# Run main function
main "$@"
