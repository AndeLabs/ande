#!/bin/bash

# AndeChain + Celestia Quick Setup Script
# Automates the entire setup process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CELESTIA_VERSION="v0.27.5-mocha"
CELESTIA_NETWORK="mocha"
CELESTIA_RPC_PORT="26658"
ANDECHAIN_RPC_PORT="8545"
WORK_DIR="$HOME/celestia"
ANDECHAIN_DIR="/Users/munay/dev/ande-labs/andechain"

# Functions
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
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
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing=()
    
    if ! command_exists git; then
        missing+=("git")
    fi
    
    if ! command_exists docker; then
        missing+=("docker")
    fi
    
    if ! command_exists docker-compose; then
        missing+=("docker-compose")
    fi
    
    if ! command_exists make; then
        missing+=("make")
    fi
    
    if ! command_exists node; then
        missing+=("node")
    fi
    
    if ! command_exists npm; then
        missing+=("npm")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing[*]}"
        print_info "Please install missing tools and run this script again"
        exit 1
    fi
    
    print_success "All prerequisites satisfied"
}

# Install Celestia
install_celestia() {
    print_header "Installing Celestia Light Node"
    
    # Create working directory
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # Detect OS
    local os=""
    local arch=""
    
    case "$(uname -s)" in
        Darwin*)    os="darwin";;
        Linux*)     os="linux";;
        *)          print_error "Unsupported OS: $(uname -s)"; exit 1;;
    esac
    
    case "$(uname -m)" in
        x86_64)    arch="amd64";;
        arm64)     arch="arm64";;
        *)         print_error "Unsupported architecture: $(uname -m)"; exit 1;;
    esac
    
    local filename="celestia-node-${os}-${arch}-${CELESTIA_VERSION}.tar.gz"
    local url="https://github.com/celestiaorg/celestia-node/releases/download/${CELESTIA_VERSION}/${filename}"
    
    print_info "Downloading Celestia ${CELESTIA_VERSION} for ${os}-${arch}"
    
    if [ ! -f "celestia-node" ]; then
        curl -L "$url" -o celestia-node.tar.gz
        tar -xzf celestia-node.tar.gz
        chmod +x celestia-node
        rm celestia-node.tar.gz
    else
        print_warning "Celestia binary already exists, skipping download"
    fi
    
    # Verify installation
    local version=$("./celestia-node" version)
    if [[ "$version" == *"$CELESTIA_VERSION"* ]]; then
        print_success "Celestia ${CELESTIA_VERSION} installed successfully"
    else
        print_error "Celestia version mismatch. Expected: ${CELESTIA_VERSION}, Got: ${version}"
        exit 1
    fi
}

# Initialize Celestia
initialize_celestia() {
    print_header "Initializing Celestia Light Node"
    
    cd "$WORK_DIR"
    
    # Check if already initialized
    if [ -d "$HOME/.celestia-light-${CELESTIA_NETWORK}" ]; then
        print_warning "Celestia already initialized"
        return
    fi
    
    print_info "Initializing Celestia light node on ${CELESTIA_NETWORK}"
    
    # Initialize node (non-interactive)
    echo -e "andechain-key\npassword123\npassword123" | "./celestia-node" light init \
        --core.ip rpc-mocha-4.celestia-mocha.com \
        --p2p.network "$CELESTIA_NETWORK"
    
    print_success "Celestia light node initialized"
}

# Start Celestia
start_celestia() {
    print_header "Starting Celestia Light Node"
    
    cd "$WORK_DIR"
    
    # Check if already running
    if pgrep -f "celestia-node light start" > /dev/null; then
        print_warning "Celestia is already running"
        return
    fi
    
    print_info "Starting Celestia light node..."
    
    # Start in background
    nohup "./celestia-node" light start \
        --core.ip rpc-mocha-4.celestia-mocha.com \
        --p2p.network "$CELESTIA_NETWORK" \
        --rpc.addr 0.0.0.0 \
        --rpc.port "$CELESTIA_RPC_PORT" \
        --gateway.addr 0.0.0.0 \
        --gateway.port 26659 \
        --keyring-backend os \
        > celestia-light.log 2>&1 &
    
    local pid=$!
    echo "$pid" > celestia.pid
    
    # Wait for startup
    sleep 10
    
    # Check if running
    if pgrep -f "celestia-node light start" > /dev/null; then
        print_success "Celestia light node started (PID: $pid)"
    else
        print_error "Failed to start Celestia light node"
        print_error "Check logs: tail -f $WORK_DIR/celestia-light.log"
        exit 1
    fi
}

# Generate auth token
generate_auth_token() {
    print_header "Generating Celestia Auth Token"
    
    cd "$WORK_DIR"
    
    # Wait a bit more for node to be ready
    sleep 5
    
    # Generate token
    local token=$(./celestia-node auth admin --p2p.network "$CELESTIA_NETWORK" 2>/dev/null || echo "")
    
    if [ -z "$token" ]; then
        print_error "Failed to generate auth token"
        print_error "Make sure Celestia node is running properly"
        exit 1
    fi
    
    echo "$token" > ~/.celestia-auth-token
    print_success "Auth token generated and saved"
    print_info "Token: $token"
}

# Configure AndeChain
configure_andechain() {
    print_header "Configuring AndeChain"
    
    cd "$ANDECHAIN_DIR"
    
    # Check if AndeChain directory exists
    if [ ! -d "$ANDECHAIN_DIR" ]; then
        print_error "AndeChain directory not found: $ANDECHAIN_DIR"
        print_info "Please clone AndeChain repository first"
        exit 1
    fi
    
    # Read auth token
    local auth_token=$(cat ~/.celestia-auth-token)
    
    # Update evnode.yaml
    local evnode_config="infra/.evm-single/config/evnode.yaml"
    if [ -f "$evnode_config" ]; then
        print_info "Updating evnode.yaml configuration"
        
        # Backup original
        cp "$evnode_config" "${evnode_config}.backup"
        
        # Update configuration
        sed -i.bak "s|da_address:.*|da_address: \"http://host.docker.internal:26658\"|g" "$evnode_config"
        sed -i.bak "s|auth_token:.*|auth_token: \"$auth_token\"|g" "$evnode_config"
        sed -i.bak "s|namespace:.*|namespace: \"73100c8d\"|g" "$evnode_config"
        
        print_success "evnode.yaml updated"
    else
        print_error "evnode.yaml not found: $evnode_config"
        exit 1
    fi
    
    # Update docker-compose.yml
    local docker_compose="infra/stacks/single-sequencer/docker-compose.yml"
    if [ -f "$docker_compose" ]; then
        print_info "Updating docker-compose.yml configuration"
        
        # Backup original
        cp "$docker_compose" "${docker_compose}.backup"
        
        # Add auth token environment variable
        if ! grep -q "CELESTIA_AUTH_TOKEN" "$docker_compose"; then
            sed -i.bak "/environment:/a\      - CELESTIA_AUTH_TOKEN=$auth_token" "$docker_compose"
        fi
        
        # Add extra_hosts if not present
        if ! grep -q "host.docker.internal" "$docker_compose"; then
            sed -i.bak "/single-sequencer:/,/^[[:space:]]*$/ s|^[[:space:]]*$|    extra_hosts:\n      - \"host.docker.internal:host-gateway\"|" "$docker_compose"
        fi
        
        print_success "docker-compose.yml updated"
    else
        print_error "docker-compose.yml not found: $docker_compose"
        exit 1
    fi
}

# Start AndeChain
start_andechain() {
    print_header "Starting AndeChain"
    
    cd "$ANDECHAIN_DIR"
    
    print_info "Starting AndeChain infrastructure..."
    
    # Stop existing containers
    make full-stop || true
    
    # Start infrastructure
    make full-start
    
    # Wait for startup
    sleep 30
    
    # Check if containers are running
    if docker ps | grep -q "single-sequencer" && docker ps | grep -q "ev-reth-sequencer"; then
        print_success "AndeChain containers started successfully"
    else
        print_error "Failed to start AndeChain containers"
        print_error "Check: docker ps"
        exit 1
    fi
}

# Run integration tests
run_tests() {
    print_header "Running Integration Tests"
    
    local all_tests_passed=true
    
    # Test 1: Celestia Health
    print_info "Test 1: Celestia Node Health"
    if curl -s "http://localhost:$CELESTIA_RPC_PORT" > /dev/null; then
        print_success "Celestia Light Node is healthy"
    else
        print_error "Celestia Light Node is not responding"
        all_tests_passed=false
    fi
    
    # Test 2: AndeChain RPC
    print_info "Test 2: AndeChain RPC Health"
    local response=$(curl -s "http://localhost:$ANDECHAIN_RPC_PORT" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' || echo "")
    
    if echo "$response" | grep -q "result"; then
        print_success "AndeChain RPC is healthy"
    else
        print_error "AndeChain RPC is not responding"
        all_tests_passed=false
    fi
    
    # Test 3: Docker Connectivity
    print_info "Test 3: Docker Container Connectivity"
    if docker exec single-sequencer curl -s "http://host.docker.internal:$CELESTIA_RPC_PORT" > /dev/null; then
        print_success "Docker container can reach Celestia"
    else
        print_error "Docker container cannot reach Celestia"
        all_tests_passed=false
    fi
    
    if [ "$all_tests_passed" = true ]; then
        print_success "🎉 ALL TESTS PASSED!"
        print_success "✅ AndeChain + Celestia integration is fully functional"
    else
        print_error "❌ Some tests failed. Please check the configuration"
        exit 1
    fi
}

# Show status
show_status() {
    print_header "System Status"
    
    echo -e "${BLUE}Celestia Light Node:${NC}"
    if pgrep -f "celestia-node light start" > /dev/null; then
        local pid=$(pgrep -f "celestia-node light start")
        echo -e "  Status: ${GREEN}Running (PID: $pid)${NC}"
        echo -e "  Version: ${GREEN}$(cd $WORK_DIR && ./celestia-node version)${NC}"
        echo -e "  RPC: ${GREEN}http://localhost:$CELESTIA_RPC_PORT${NC}"
    else
        echo -e "  Status: ${RED}Not running${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}AndeChain:${NC}"
    if docker ps | grep -q "single-sequencer"; then
        echo -e "  Status: ${GREEN}Running${NC}"
        echo -e "  RPC: ${GREEN}http://localhost:$ANDECHAIN_RPC_PORT${NC}"
    else
        echo -e "  Status: ${RED}Not running${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Network:${NC}"
    echo -e "  Celestia Network: ${GREEN}$CELESTIA_NETWORK${NC}"
    echo -e "  Auth Token: ${GREEN}$(cat ~/.celestia-auth-token 2>/dev/null || echo 'Not found')${NC}"
}

# Cleanup function
cleanup() {
    print_header "Cleanup"
    
    print_info "Stopping Celestia..."
    if [ -f "$WORK_DIR/celestia.pid" ]; then
        local pid=$(cat "$WORK_DIR/celestia.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            print_success "Celestia stopped"
        fi
        rm -f "$WORK_DIR/celestia.pid"
    fi
    
    print_info "Stopping AndeChain..."
    cd "$ANDECHAIN_DIR"
    make full-stop || true
    
    print_success "Cleanup completed"
}

# Main function
main() {
    print_header "AndeChain + Celestia Quick Setup"
    
    # Parse arguments
    case "${1:-setup}" in
        setup)
            check_prerequisites
            install_celestia
            initialize_celestia
            start_celestia
            generate_auth_token
            configure_andechain
            start_andechain
            run_tests
            show_status
            ;;
        test)
            run_tests
            ;;
        status)
            show_status
            ;;
        stop)
            cleanup
            ;;
        restart)
            cleanup
            sleep 5
            start_celestia
            generate_auth_token
            start_andechain
            run_tests
            ;;
        *)
            echo "Usage: $0 {setup|test|status|stop|restart}"
            echo ""
            echo "Commands:"
            echo "  setup    - Complete setup and start all services"
            echo "  test     - Run integration tests"
            echo "  status   - Show system status"
            echo "  stop     - Stop all services"
            echo "  restart  - Restart all services"
            exit 1
            ;;
    esac
}

# Trap signals
trap cleanup EXIT

# Run main function
main "$@"