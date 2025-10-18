#!/bin/bash

# AndeChain Mocha Testnet Deployment Script
# ========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDECHAIN_DIR="$(dirname "$SCRIPT_DIR")"
INFRA_DIR="$ANDECHAIN_DIR/infra"
TESTNET_DIR="$ANDECHAIN_DIR/infra/stacks/single-sequencer"

echo -e "${PURPLE}🌙 AndeChain Mocha Testnet Deployment${NC}"
echo -e "${PURPLE}======================================${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to print step
print_step() {
    echo -e "${CYAN}🔧 $1${NC}"
}

# Check prerequisites
echo -e "${CYAN}📋 Checking prerequisites...${NC}"

if ! command_exists docker; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command_exists docker compose; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

if ! command_exists forge; then
    print_error "Foundry is not installed. Please install Foundry first."
    echo "Run: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

print_status "Prerequisites verified"

# Navigate to andechain directory
cd "$ANDECHAIN_DIR"

# Step 1: Stop any existing services
print_step "Step 1: Stopping any existing services..."
echo -e "${YELLOW}🛑 Stopping existing AndeChain services...${NC}"
make stop 2>/dev/null || true
docker compose -f "$INFRA_DIR/docker-compose.celestia.yml" down 2>/dev/null || true
docker compose -f "$TESTNET_DIR/docker-compose.testnet.yml" down 2>/dev/null || true

# Step 2: Clean up old containers
print_step "Step 2: Cleaning up old containers..."
echo -e "${YELLOW}🧹 Cleaning up old containers and volumes...${NC}"
docker system prune -f --volumes 2>/dev/null || true

# Step 3: Build ande-reth with Mocha features
print_step "Step 3: Building ande-reth with Mocha testnet features..."
echo -e "${BLUE}🔨 Building ande-reth with ANDE Token Duality for Mocha...${NC}"
docker build -f Dockerfile.evm -t ande-reth:mocha --build-arg BUILD_TARGET=release --build-arg FEATURES="ande-integration,mev-detection,parallel-execution" .

# Step 4: Start Celestia Mocha DA Layer
print_step "Step 4: Starting Celestia Mocha DA Layer..."
echo -e "${BLUE}🌙 Connecting to Celestia Mocha Testnet...${NC}"
cd "$INFRA_DIR"
docker compose -f docker-compose.celestia.yml --env-file celestia-mocha.env up -d

# Wait for Celestia to be ready
echo -e "${YELLOW}⏳ Waiting for Celestia Mocha to connect (30 seconds)...${NC}"
sleep 30

# Verify Celestia connection
print_step "Verifying Celestia Mocha connection..."
if curl -s http://localhost:26657/status | jq -r '.result.node_info.network' | grep -q "mocha"; then
    print_status "Successfully connected to Celestia Mocha testnet"
else
    print_error "Failed to connect to Celestia Mocha testnet"
    docker compose -f docker-compose.celestia.yml logs celestia-light-client
    exit 1
fi

# Step 5: Start AndeChain Testnet Infrastructure
print_step "Step 5: Starting AndeChain Testnet Infrastructure..."
echo -e "${BLUE}🚀 Starting AndeChain with Celestia DA integration...${NC}"
cd "$TESTNET_DIR"

# Update docker-compose.testnet.yml to use mocha image
sed -i.bak 's/andelabs\/ev-reth:latest/ande-reth:mocha/g' docker-compose.testnet.yml

# Start testnet infrastructure
docker compose -f docker-compose.testnet.yml up -d --build

# Wait for services to be ready
echo -e "${YELLOW}⏳ Waiting for AndeChain services to be ready (60 seconds)...${NC}"
sleep 60

# Step 6: Check service health
print_step "Step 6: Checking service health..."

# Check ev-reth
if curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545 | grep -q "0x"; then
    print_status "AndeChain ev-reth is responding"
else
    print_error "AndeChain ev-reth is not responding"
    docker compose -f docker-compose.testnet.yml logs ev-reth-testnet
    exit 1
fi

# Check sequencer
if curl -s http://localhost:26660/metrics | grep -q "evolve"; then
    print_status "AndeChain sequencer is healthy"
else
    print_warning "AndeChain sequencer might still be starting up"
fi

# Check Prometheus
if curl -s http://localhost:9090/-/healthy | grep -q "OK"; then
    print_status "Prometheus is healthy"
else
    print_warning "Prometheus might still be starting up"
fi

# Check Grafana
if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    print_status "Grafana is healthy"
else
    print_warning "Grafana might still be starting up"
fi

# Step 7: Deploy ANDE Token Contracts
print_step "Step 7: Deploying ANDE Token Contracts..."
echo -e "${BLUE}📜 Deploying ANDE Token to Mocha testnet...${NC}"
cd "$ANDECHAIN_DIR/contracts"

# Create testnet .env if it doesn't exist
if [ ! -f ".env.mocha" ]; then
    echo "Creating .env.mocha with Mocha testnet configuration..."
    cat > .env.mocha << EOF
# AndeChain Mocha Testnet Configuration
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
RPC_URL=http://localhost:8545
CHAIN_ID=1234
ETHERSCAN_API_KEY=
VERIFIER_URL=http://localhost:4000/api
CELESTIA_NETWORK=mocha
EOF
    print_status "Created .env.mocha"
fi

# Load mocha environment
source .env.mocha

# Deploy ANDE Token
echo "Deploying ANDE Token to Mocha testnet..."
if forge script script/DeploySimple.s.sol --rpc-url "$RPC_URL" --broadcast --legacy --private-key "$PRIVATE_KEY"; then
    print_status "ANDE Token deployed successfully to Mocha testnet"
else
    print_error "ANDE Token deployment failed"
    exit 1
fi

# Step 8: Display deployment information
print_step "Step 8: Deployment Complete!"
echo ""
echo -e "${GREEN}🎉 AndeChain Mocha Testnet is ready!${NC}"
echo -e "${PURPLE}================================${NC}"
echo ""
echo -e "${CYAN}🌐 Network Endpoints:${NC}"
echo -e "${GREEN}  RPC HTTP:${NC}        http://localhost:8545"
echo -e "${GREEN}  RPC WebSocket:${NC}   ws://localhost:8546"
echo -e "${GREEN}  Explorer:${NC}        http://localhost:4000"
echo -e "${GREEN}  Prometheus:${NC}      http://localhost:9090"
echo -e "${GREEN}  Grafana:${NC}         http://localhost:3000 (admin/ande_testnet_2025)"
echo ""
echo -e "${CYAN}🌙 Celestia Mocha Integration:${NC}"
echo -e "${GREEN}  Celestia RPC:${NC}    http://localhost:26657"
echo -e "${GREEN}  Network:${NC}         mocha"
echo -e "${GREEN}  DA Gateway:${NC}      http://localhost:26659"
echo ""
echo -e "${CYAN}💰 ANDE Token Information:${NC}"
echo -e "${GREEN}  Precompile:${NC}      0x00000000000000000000000000000000000000FD"
echo -e "${GREEN}  Chain ID:${NC}        1234"
echo ""
echo -e "${CYAN}🔧 Management Commands:${NC}"
echo -e "${YELLOW}  Stop testnet:${NC}     make stop-mocha"
echo -e "${YELLOW}  View logs:${NC}        make logs-mocha"
echo -e "${YELLOW}  Health check:${NC}     make health-mocha"
echo -e "${YELLOW}  Restart service:${NC}  make restart-mocha-service SERVICE=<service>"
echo ""
echo -e "${CYAN}📊 Monitoring:${NC}"
echo -e "${YELLOW}  Grafana Dashboards:${NC} http://localhost:3000"
echo -e "${YELLOW}  Prometheus Metrics:${NC} http://localhost:9090"
echo ""
echo -e "${GREEN}🚀 Your AndeChain is now running on Celestia Mocha testnet!${NC}"
echo ""

# Restore original docker-compose.testnet.yml
cd "$TESTNET_DIR"
mv docker-compose.testnet.yml.bak docker-compose.testnet.yml 2>/dev/null || true

echo -e "${PURPLE}✨ Deployment completed successfully! ✨${NC}"