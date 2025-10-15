#!/bin/bash

# AndeChain Grafana Dashboard Setup Script
# ========================================

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
DASHBOARDS_DIR="$ANDECHAIN_DIR/infra/stacks/single-sequencer/grafana-dashboards"

echo -e "${BLUE}📊 Setting up Grafana Dashboards${NC}"
echo "=================================="

# Function to check if Grafana is ready
wait_for_grafana() {
    local max_attempts=30
    local attempt=1
    
    echo -e "${BLUE}⏳ Waiting for Grafana to be ready...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:3000/api/health | grep -q "ok"; then
            echo -e "${GREEN}✅ Grafana is ready${NC}"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    echo -e "${RED}❌ Grafana is not ready after ${max_attempts} attempts${NC}"
    return 1
}

# Function to import dashboard
import_dashboard() {
    local dashboard_file=$1
    local dashboard_name=$2
    
    echo -e "${BLUE}📈 Importing dashboard: $dashboard_name${NC}"
    
    # Use Grafana API to import dashboard
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic YWRtaW46YW5kZV90ZXN0bmV0XzIwMjU=" \
        -d @"$dashboard_file" \
        http://localhost:3000/api/dashboards/db)
    
    if echo "$response" | grep -q '"status":"success"'; then
        echo -e "${GREEN}✅ Dashboard imported successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to import dashboard${NC}"
        echo "Response: $response"
        return 1
    fi
}

# Function to create Prometheus datasource
create_datasource() {
    echo -e "${BLUE}🔌 Creating Prometheus datasource...${NC}"
    
    local datasource='{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://prometheus-testnet:9090",
        "access": "proxy",
        "isDefault": true,
        "jsonData": {
            "timeInterval": "5s"
        }
    }'
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic YWRtaW46YW5kZV90ZXN0bmV0XzIwMjU=" \
        -d "$datasource" \
        http://localhost:3000/api/datasources)
    
    if echo "$response" | grep -q '"message":"Datasource added"'; then
        echo -e "${GREEN}✅ Prometheus datasource created${NC}"
        return 0
    elif echo "$response" | grep -q '"message":"Data source with the same name already exists"'; then
        echo -e "${YELLOW}⚠️  Prometheus datasource already exists${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to create datasource${NC}"
        echo "Response: $response"
        return 1
    fi
}

# Check prerequisites
echo -e "${BLUE}📋 Checking prerequisites...${NC}"

if ! command_exists curl; then
    print_error "curl is not installed. Please install curl first."
    exit 1
fi

# Check if Grafana is running
if ! curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Grafana is not running. Please start the testnet first:${NC}"
    echo "make deploy-testnet"
    exit 1
fi

# Wait for Grafana to be ready
wait_for_grafana

# Create Prometheus datasource
create_datasource

# Import dashboards
echo ""
echo -e "${BLUE}📊 Importing dashboards...${NC}"

# Import MEV Dashboard
if [ -f "$DASHBOARDS_DIR/ande-mev-dashboard.json" ]; then
    import_dashboard "$DASHBOARDS_DIR/ande-mev-dashboard.json" "AndeChain MEV System"
else
    echo -e "${RED}❌ MEV dashboard file not found${NC}"
fi

# Import Parallel Execution Dashboard
if [ -f "$DASHBOARDS_DIR/parallel-execution-dashboard.json" ]; then
    import_dashboard "$DASHBOARDS_DIR/parallel-execution-dashboard.json" "AndeChain Parallel Execution"
else
    echo -e "${RED}❌ Parallel Execution dashboard file not found${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Grafana dashboards setup completed!${NC}"
echo ""
echo -e "${BLUE}📊 Access your dashboards:${NC}"
echo "Grafana: http://localhost:3000"
echo "Username: admin"
echo "Password: ande_testnet_2025"
echo ""
echo -e "${BLUE}📈 Available dashboards:${NC}"
echo "• AndeChain MEV System Dashboard"
echo "• AndeChain Parallel Execution Dashboard"
echo ""
echo -e "${BLUE}🔧 Management commands:${NC}"
echo "View dashboards: http://localhost:3000/dashboards"
echo "Prometheus:    http://localhost:9090"
echo "Health check:  make health-testnet"