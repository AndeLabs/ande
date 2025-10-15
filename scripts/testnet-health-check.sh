#!/bin/bash

# AndeChain Testnet Health Check Script
# =====================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TESTNET_DIR="$(dirname "$0")/../infra/stacks/single-sequencer"

echo -e "${BLUE}🏥 AndeChain Testnet Health Check${NC}"
echo "=================================="

# Function to check service
check_service() {
    local service_name=$1
    local url=$2
    local expected_pattern=$3
    
    echo -n "Checking $service_name... "
    
    if curl -s "$url" 2>/dev/null | grep -q "$expected_pattern"; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
}

# Function to check RPC
check_rpc() {
    local rpc_url=$1
    local method=$2
    
    echo -n "Checking RPC $method... "
    
    local response=$(curl -s -X POST -H "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":[],\"id\":1}" \
        "$rpc_url" 2>/dev/null)
    
    if echo "$response" | grep -q '"result"'; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        echo "Response: $response"
        return 1
    fi
}

# Function to check container
check_container() {
    local container_name=$1
    
    echo -n "Checking container $container_name... "
    
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name.*Up"; then
        echo -e "${GREEN}✅ RUNNING${NC}"
        return 0
    else
        echo -e "${RED}❌ NOT RUNNING${NC}"
        return 1
    fi
}

echo -e "${BLUE}📦 Container Status${NC}"
echo "===================="

check_container "ev-reth-testnet"
check_container "single-sequencer-testnet"
check_container "local-da-testnet"
check_container "prometheus-testnet"
check_container "grafana-testnet"

echo ""
echo -e "${BLUE}🔗 Network Connectivity${NC}"
echo "========================="

check_rpc "http://localhost:8545" "eth_chainId"
check_rpc "http://localhost:8545" "eth_blockNumber"
check_rpc "http://localhost:8545" "net_version"

echo ""
echo -e "${BLUE}📊 Monitoring Services${NC}"
echo "======================="

check_service "Prometheus" "http://localhost:9090/-/healthy" "OK"
check_service "Grafana" "http://localhost:3000/api/health" "ok"

echo ""
echo -e "${BLUE}💰 ANDE Precompile Check${NC}"
echo "=========================="

echo -n "Checking ANDE precompile balance... "
local balance=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0x00000000000000000000000000000000000000FD","latest"],"id":1}' \
    http://localhost:8545 | jq -r '.result // "error"')

if [ "$balance" != "error" ] && [ "$balance" != "null" ]; then
    echo -e "${GREEN}✅ OK${NC} (Balance: $balance wei)"
else
    echo -e "${RED}❌ FAILED${NC}"
fi

echo ""
echo -e "${BLUE}📈 MEV System Status${NC}"
echo "====================="

# Check MEV metrics endpoint if available
echo -n "Checking MEV metrics... "
if curl -s "http://localhost:9002/metrics" 2>/dev/null | grep -q "mev_"; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${YELLOW}⚠️  NOT AVAILABLE${NC}"
fi

# Check Parallel Execution metrics
echo -n "Checking Parallel Execution metrics... "
if curl -s "http://localhost:9002/parallel/metrics" 2>/dev/null | grep -q "parallel_"; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${YELLOW}⚠️  NOT AVAILABLE${NC}"
fi

echo ""
echo -e "${BLUE}📊 System Resources${NC}"
echo "=================="

echo "Disk usage:"
df -h | grep -E "(Filesystem|/dev/)"

echo ""
echo "Memory usage:"
free -h 2>/dev/null || echo "Memory info not available"

echo ""
echo "Docker stats:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "(CONTAINER|testnet)"

echo ""
echo -e "${BLUE}📝 Recent Logs Summary${NC}"
echo "======================"

echo "Recent ev-reth errors:"
docker logs ev-reth-testnet --since=5m 2>&1 | grep -i error | tail -3 || echo "No recent errors"

echo ""
echo "Recent sequencer errors:"
docker logs single-sequencer-testnet --since=5m 2>&1 | grep -i error | tail -3 || echo "No recent errors"

echo ""
echo -e "${GREEN}🎉 Health check completed!${NC}"