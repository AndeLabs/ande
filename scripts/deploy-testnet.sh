#!/bin/bash

# AndeChain Testnet Deployment Script
# ===================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDECHAIN_DIR="$(dirname "$SCRIPT_DIR")"
TESTNET_DIR="$ANDECHAIN_DIR/infra/stacks/single-sequencer"

echo -e "${BLUE}🚀 AndeChain Testnet Deployment${NC}"
echo "=================================="

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

# Check prerequisites
echo -e "${BLUE}📋 Checking prerequisites...${NC}"

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

# Navigate to testnet directory
cd "$TESTNET_DIR"

# Stop any existing testnet
echo -e "${BLUE}🛑 Stopping any existing testnet...${NC}"
docker compose -f docker-compose.testnet.yml down -v 2>/dev/null || true

# Clean up old containers
echo -e "${BLUE}🧹 Cleaning up old containers...${NC}"
docker system prune -f --volumes 2>/dev/null || true

# Build ev-reth with testnet features
echo -e "${BLUE}🔨 Building ev-reth with testnet features...${NC}"
cd "$ANDECHAIN_DIR"
docker build -f Dockerfile.evm -t ande-reth:testnet --build-arg BUILD_TARGET=release --build-arg FEATURES="ande-integration,mev-detection,parallel-execution" .

# Start testnet infrastructure
echo -e "${BLUE}🐳 Starting testnet infrastructure...${NC}"
cd "$TESTNET_DIR"
docker compose -f docker-compose.testnet.yml up -d --build

# Wait for services to be ready
echo -e "${BLUE}⏳ Waiting for services to be ready...${NC}"
sleep 45

# Check service health
echo -e "${BLUE}🏥 Checking service health...${NC}"

# Check ev-reth
if curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545 | grep -q "0x"; then
    print_status "ev-reth testnet is responding"
else
    print_error "ev-reth testnet is not responding"
    docker compose -f docker-compose.testnet.yml logs ev-reth-testnet
    exit 1
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

# Deploy MEV system contracts
echo -e "${BLUE}📜 Deploying MEV system contracts...${NC}"
cd "$ANDECHAIN_DIR/contracts"

# Create testnet .env if it doesn't exist
if [ ! -f ".env.testnet" ]; then
    echo "Creating .env.testnet with testnet configuration..."
    cat > .env.testnet << EOF
# Testnet Configuration
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
RPC_URL=http://localhost:8545
CHAIN_ID=1234
ETHERSCAN_API_KEY=
VERIFIER_URL=http://localhost:4000/api
EOF
    print_status "Created .env.testnet"
fi

# Load testnet environment
source .env.testnet

# Deploy MEV system
echo "Deploying MEV system to testnet..."
if forge script script/DeployMEVSystem.s.sol --rpc-url "$RPC_URL" --broadcast --legacy --private-key "$PRIVATE_KEY"; then
    print_status "MEV system deployed successfully"
else
    print_error "MEV system deployment failed"
    exit 1
fi

# Display testnet information
echo -e "${BLUE}📊 Testnet Information${NC}"
echo "======================="
echo -e "${GREEN}🌐 RPC HTTP:${NC}     http://localhost:8545"
echo -e "${GREEN}🌐 RPC WebSocket:${NC} ws://localhost:8546"
echo -e "${GREEN}📊 Prometheus:${NC}    http://localhost:9090"
echo -e "${GREEN}📈 Grafana:${NC}       http://localhost:3000 (admin/ande_testnet_2025)"
echo -e "${GREEN}🔍 Explorer:${NC}      http://localhost:4000"
echo -e "${GREEN}💰 ANDE Precompile:${NC} 0x00000000000000000000000000000000000000FD"
echo ""
echo -e "${BLUE}📜 Contract Deployment Status${NC}"
echo "==============================="
echo "Check the explorer for deployed contract addresses"
echo ""
echo -e "${BLUE}🔧 Management Commands${NC}"
echo "========================"
echo "Stop testnet:    docker compose -f $TESTNET_DIR/docker-compose.testnet.yml down"
echo "View logs:       docker compose -f $TESTNET_DIR/docker-compose.testnet.yml logs -f"
echo "Restart service: docker compose -f $TESTNET_DIR/docker-compose.testnet.yml restart [service]"
echo ""
echo -e "${GREEN}🎉 AndeChain Testnet is ready!${NC}"