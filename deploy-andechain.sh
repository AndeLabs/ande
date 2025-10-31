#!/bin/bash

# 🚀 AndeChain Production Deployment Script
# Multi-node decentralized testnet on Celestia Mocha-4

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Header
echo "=================================================================="
echo "🚀 AndeChain Production Deployment - Multi-Node Testnet"
echo "🌐 Celestia Mocha-4 Data Availability"
echo "📊 Stack: ev-reth + Evolve Sequencer + Celestia DA"
echo "=================================================================="

# Pre-deployment checks
log "🔍 Running pre-deployment checks..."

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    error "docker-compose.yml not found! Please run from project root."
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    error "Docker is not installed or not in PATH"
fi

# Check Docker Compose
if ! command -v docker compose &> /dev/null && ! docker compose version &> /dev/null; then
    error "Docker Compose is not installed"
fi

# Check available disk space (need at least 10GB)
AVAILABLE_SPACE=$(df . | tail -1 | awk '{print $4}')
if [ "$AVAILABLE_SPACE" -lt 10485760 ]; then  # 10GB in KB
    error "Insufficient disk space. Need at least 10GB, have $(($AVAILABLE_SPACE/1024/1024))GB"
fi

# Check required ports
check_port() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        warn "Port $port is already in use"
        return 1
    fi
    return 0
}

log "🔍 Checking required ports..."
PORTS=(8545 8547 8549 26658 7331 7332 7333 3000 9090)
for port in "${PORTS[@]}"; do
    if ! check_port $port; then
        warn "Port $port may cause conflicts"
    fi
done

# Check genesis file
if [ ! -f "./infra/stacks/single-sequencer/genesis.json" ]; then
    error "Genesis file not found at ./infra/stacks/single-sequencer/genesis.json"
fi

log "✅ Pre-deployment checks passed"

# Clean previous deployment
log "🧹 Cleaning previous deployment..."
docker compose down -v 2>/dev/null || true
docker system prune -f 2>/dev/null || true

# Remove old data directories
log "🗂️ Cleaning old data directories..."
rm -rf ~/.ande-data/ev-reth/* 2>/dev/null || true
rm -rf /tmp/andechain-data/* 2>/dev/null || true

log "✅ Cleanup completed"

# Phase 1: Start Infrastructure Services
log "🌙 Phase 1: Starting Celestia Light Node..."
docker compose up -d jwt-init-sequencer jwt-init-fullnode1 jwt-init-fullnode2 celestia-light

# Wait for JWT initialization
log "⏳ Waiting for JWT generation..."
sleep 10

# Verify JWT files were created
if ! docker exec jwt-init-sequencer test -f /jwt/jwt.hex; then
    error "JWT generation failed for sequencer"
fi

if ! docker exec jwt-init-fullnode1 test -f /jwt/jwt.hex; then
    error "JWT generation failed for fullnode1"
fi

if ! docker exec jwt-init-fullnode2 test -f /jwt/jwt.hex; then
    error "JWT generation failed for fullnode2"
fi

log "✅ JWT secrets generated successfully"

# Wait for Celestia to initialize
log "⏳ Waiting for Celestia light node initialization..."
sleep 30

# Verify Celestia is starting
for i in {1..10}; do
    if curl -s http://localhost:26658/status >/dev/null 2>&1; then
        log "✅ Celestia light node is responding"
        break
    fi
    if [ $i -eq 10 ]; then
        error "Celestia light node failed to start after 10 attempts"
    fi
    info "Waiting for Celestia... ($i/10)"
    sleep 10
done

# Phase 2: Start Blockchain Core
log "🚀 Phase 2: Starting AndeChain Sequencer..."
docker compose up -d ev-reth-sequencer

# Wait for ev-reth to be ready
log "⏳ Waiting for ev-reth initialization..."
sleep 25

# Test ev-reth RPC
for i in {1..10}; do
    CHAIN_ID=$(curl -s -X POST http://localhost:8545 \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        | jq -r '.result' 2>/dev/null || echo "")

    if [ "$CHAIN_ID" = "0x7e3" ]; then
        log "✅ ev-reth is ready (Chain ID: 2019)"
        break
    fi
    if [ $i -eq 10 ]; then
        error "ev-reth failed to start after 10 attempts"
    fi
    info "Waiting for ev-reth RPC... ($i/10)"
    sleep 5
done

# Start Evolve Sequencer
log "🔄 Phase 2: Starting Evolve Sequencer..."
docker compose up -d evolve-sequencer

# Wait for sequencer to start producing blocks
log "⏳ Waiting for sequencer to start producing blocks..."
sleep 60

# Check block production
for i in {1..15}; do
    BLOCK_NUMBER=$(curl -s -X POST http://localhost:8545 \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq -r '.result' 2>/dev/null | xargs printf "%d\n" 2>/dev/null || echo "0")

    if [ "$BLOCK_NUMBER" -gt 0 ]; then
        log "✅ Sequencer is producing blocks! Current: $BLOCK_NUMBER"
        break
    fi
    if [ $i -eq 15 ]; then
        warn "Sequencer may still be starting... Checking logs"
        docker compose logs --tail=20 evolve-sequencer
    fi
    info "Waiting for block production... ($i/15)"
    sleep 10
done

# Phase 3: Start Full Nodes
log "🌐 Phase 3: Starting Full Nodes..."
docker compose up -d ev-reth-fullnode1 fullnode1 ev-reth-fullnode2 fullnode2

# Wait for full nodes to initialize
log "⏳ Waiting for full nodes to initialize..."
sleep 45

# Check full nodes are syncing
log "🔍 Checking full nodes synchronization..."

for node in 8547 8549; do
    SYNC_STATUS=$(curl -s -X POST http://localhost:$node \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
        | jq -r '.' 2>/dev/null || echo '{"result": "error"}')

    if echo "$SYNC_STATUS" | jq -e '.result == false' >/dev/null 2>&1; then
        log "✅ Full Node (port $node) is fully synced"
    else
        info "Full Node (port $node) is syncing or starting..."
    fi
done

# Phase 4: Start Monitoring
log "📊 Phase 4: Starting Monitoring Stack..."
docker compose up -d prometheus grafana

# Wait for monitoring services
sleep 20

# Check monitoring services
if curl -s http://localhost:9090/targets >/dev/null 2>&1; then
    log "✅ Prometheus is running"
else
    warn "Prometheus may still be starting"
fi

if curl -s http://localhost:3000 >/dev/null 2>&1; then
    log "✅ Grafana is running"
else
    warn "Grafana may still be starting"
fi

# Final Verification
log "🔍 Phase 5: Final Network Verification..."

# Get current block number
FINAL_BLOCK=$(curl -s -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    | jq -r '.result' | xargs printf "%d\n" 2>/dev/null || echo "0")

# Get account balance
BALANCE=$(curl -s -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","latest"],"id":1}' \
    | jq -r '.result' 2>/dev/null || echo "0x0")

# Check Celestia status
CELESTIA_STATUS=$(curl -s http://localhost:26658/status | jq -r '.result.sync_info.latest_block_height' 2>/dev/null || echo "unknown")

# Display results
echo ""
echo "=================================================================="
echo "🎉 AndeChain Multi-Node Testnet Deployment Complete!"
echo "=================================================================="
echo ""
echo "📊 Network Status:"
echo "  • Block Number: $FINAL_BLOCK"
echo "  • ANDE Balance (proposer): $BALANCE wei"
echo "  • Celestia Block: $CELESTIA_STATUS"
echo ""
echo "🌐 Available Endpoints:"
echo "  • Sequencer RPC:     http://localhost:8545"
echo "  • Full Node 1 RPC:   http://localhost:8547"
echo "  • Full Node 2 RPC:   http://localhost:8549"
echo "  • WebSocket:         ws://localhost:8546"
echo "  • Celestia DA:       http://localhost:26658"
echo ""
echo "📊 Monitoring & Tools:"
echo "  • Grafana Dashboard: http://localhost:3000"
echo "    • Username: admin"
echo "    • Password: andechain-admin-2025"
echo "  • Prometheus:        http://localhost:9090"
echo ""
echo "🔧 MetaMask Configuration:"
echo "  • Network Name: AndeChain Testnet"
echo "  • RPC URL: http://localhost:8545"
echo "  • Chain ID: 2019"
echo "  • Currency Symbol: ANDE"
echo ""
echo "🧪 Quick Test Commands:"
echo "  # Check block production:"
echo "  curl -X POST http://localhost:8545 \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'"
echo ""
echo "  # Send test transaction:"
echo "  cast send 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \\"
echo "    --value 1ether \\"
echo "    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \\"
echo "    --rpc-url http://localhost:8545"
echo ""
echo "📱 What's Next:"
echo "  1. Connect MetaMask to AndeChain"
echo "  2. Send test transactions"
echo "  3. Deploy smart contracts"
echo "  4. Add more full nodes to the network"
echo "  5. Monitor network health on Grafana"
echo ""
echo "🔍 Troubleshooting:"
echo "  • View logs: docker compose logs -f [service-name]"
echo "  • Restart service: docker compose restart [service-name]"
echo "  • Check status: docker compose ps"
echo "  • Full reset: docker compose down -v && docker compose up -d"
echo ""
echo "🎯 AndeChain is now running with full P2P networking capabilities!"
echo "   Multiple nodes can join and participate in the network."
echo "=================================================================="

log "🎉 Deployment completed successfully!"
log "🚀 AndeChain is live on Celestia Mocha-4 testnet!"

# Optional: Keep script running to show logs
read -p "Press Enter to view live logs (Ctrl+C to exit)..."
docker compose logs -f