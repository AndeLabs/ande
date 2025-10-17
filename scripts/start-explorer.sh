#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔍 Starting AndeChain Block Explorer (Blockscout)${NC}"
echo ""

# Check if .env exists in eth-explorer directory
if [ ! -f "infra/stacks/eth-explorer/.env" ]; then
    echo -e "${RED}❌ Error: .env file not found in infra/stacks/eth-explorer/${NC}"
    echo -e "${YELLOW}Creating .env from template...${NC}"
    
    # Create .env file with default values
    cat > infra/stacks/eth-explorer/.env << 'EOF'
# Database
EXPLORER_DB_HOST=blockscout-db
EXPLORER_DB_PORT=5432
EXPLORER_POSTGRES_PASSWORD=blockscout_password

# Stats Database
EXPLORER_STATS_DB_HOST=stats-db
EXPLORER_STATS_DB_PORT=5432
EXPLORER_STATS_HOST=stats

# Redis
EXPLORER_REDIS_HOST=blockscout-redis

# RPC Connection
RETH_HOST=ev-reth-sequencer
RETH_HOST_HTTP_PORT=8545
RETH_HOST_WS_PORT=8546

# Network
CHAIN_ID=1234

# Frontend
EXPLORER_FRONTEND_PORT=4000
EXPLORER_BACKEND_HOST=blockscout-backend

# Backend exposed port (avoid conflict with backend internal port)
EXPLORER_BACKEND_EXTERNAL_PORT=4001
EOF
    
    echo -e "${GREEN}✅ .env file created with default values${NC}"
    echo -e "${YELLOW}⚠️  Please review and update infra/stacks/eth-explorer/.env if needed${NC}"
fi

# Check if ande-network exists
if ! docker network inspect ande-network >/dev/null 2>&1; then
    echo -e "${YELLOW}Creating ande-network...${NC}"
    docker network create ande-network
    echo -e "${GREEN}✅ Network created${NC}"
fi

# Check if ev-reth-sequencer is running
if ! docker ps | grep -q ev-reth-sequencer; then
    echo -e "${RED}❌ Error: ev-reth-sequencer is not running${NC}"
    echo -e "${YELLOW}Please start the blockchain first:${NC}"
    echo "  make start"
    exit 1
fi

echo -e "${GREEN}Starting Blockscout services...${NC}"
cd infra/stacks/eth-explorer

# Pull latest images
echo -e "${YELLOW}Pulling latest Blockscout images...${NC}"
docker-compose pull

# Start services
docker-compose up -d

echo ""
echo -e "${GREEN}✅ Blockscout Explorer started successfully!${NC}"
echo ""
echo -e "${YELLOW}📊 Services:${NC}"
echo "  Frontend:  http://localhost:4000"
echo "  Backend:   http://localhost:4001"
echo "  Stats API: http://localhost:8051"
echo ""
echo -e "${YELLOW}📝 Notes:${NC}"
echo "  - It may take 1-2 minutes for Blockscout to sync and be fully operational"
echo "  - Check logs: docker-compose logs -f"
echo "  - Stop: docker-compose down"
echo ""
echo -e "${GREEN}🔗 Explorer URL for frontend config:${NC}"
echo "  http://localhost:4000"
echo ""