# 🚀 AndeChain Testnet Deployment Guide

**Complete Step-by-Step Implementation for Fresh Machine**

---

## 📋 Prerequisites Checklist

Before starting deployment, ensure you have:

### Hardware Requirements
- [ ] Minimum 4GB RAM (recommended 8GB+)
- [ ] 50GB free disk space
- [ ] Multi-core CPU (2+ cores)
- [ ] Stable internet connection (10+ Mbps)
- [ ] Linux/macOS/Windows with WSL2

### Software Requirements (Installed on Target Machine)
- [ ] Docker Desktop (latest stable) - https://www.docker.com/products/docker-desktop
- [ ] Docker Compose v2.0+ - Included with Docker Desktop
- [ ] Git - https://git-scm.com/download
- [ ] Foundry (optional for contract development) - `curl -L https://foundry.paradigm.xyz | bash`
- [ ] Curl/wget - For testing endpoints

### Network Requirements
- [ ] Port 8545 available (RPC HTTP)
- [ ] Port 8546 available (WebSocket)
- [ ] Port 4000 available (Block Explorer)
- [ ] Port 3001 available (Faucet)
- [ ] Port 7331 available (Sequencer RPC)
- [ ] Ports 26658-26659 available (Celestia)

---

## 🎯 Phase 1: Prepare Target Machine

### Step 1.1: Clone AndeChain Repository

```bash
# Go to your desired directory
cd /path/to/projects

# Clone the repository
git clone <ANDECHAIN_REPO_URL> ande-labs
cd ande-labs

# Verify directory structure
ls -la
# Should see: docker-compose.yml, genesis.json, ev-reth/, andechain/, etc.

# Verify Docker Compose file exists
ls -la docker-compose.yml
```

**Expected Output:**
```
docker-compose.yml exists and is readable
ev-reth directory present
andechain/contracts directory present
genesis.json present
```

### Step 1.2: Verify Docker Installation

```bash
# Test Docker
docker --version
# Should output: Docker version X.X.X or higher

# Test Docker Compose
docker compose version
# Should output: Docker Compose version X.X.X or higher

# Test Docker daemon is running
docker ps
# Should output empty container list (not error)

# Check available disk space
df -h | grep -E '/$|/data'
# Ensure at least 50GB free
```

### Step 1.3: Create Data Directories

```bash
# Create persistent storage directory for blockchain data
mkdir -p ~/.ande-data/ev-reth

# Verify permissions
ls -la ~/.ande-data/

# Create logs directory (optional but recommended)
mkdir -p ~/.ande-logs
```

### Step 1.4: Verify Network Access

```bash
# Test internet connectivity
ping -c 1 8.8.8.8

# Test DNS resolution
nslookup github.com

# Test Celestia testnet connectivity (optional)
curl -s https://rpc-mocha.pops.one:26657/status | head -20
```

---

## 🎯 Phase 2: Configure AndeChain

### Step 2.1: Create Environment File

```bash
# Create .env file in project root
cat > .env << 'EOF'
# ============================================================
# AndeChain Testnet Configuration
# ============================================================

# Network Configuration
CHAIN_ID=2019
NETWORK_NAME="AndeChain Testnet"
NODE_ENV=production

# Docker Configuration
DOCKER_USER=1000
DOCKER_GROUP=1000

# Faucet Configuration
FAUCET_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
FAUCET_AMOUNT=10000000000000000000000
FAUCET_COOLDOWN_MINUTES=5
FAUCET_PORT=3001

# Explorer Configuration
EXPLORER_DB_PASSWORD=andechain-secure-postgres-2025
EXPLORER_FRONTEND_PORT=4000
EXPLORER_BACKEND_PORT=4001
EXPLORER_HOST=localhost

# Grafana Configuration (optional)
GRAFANA_USER=admin
GRAFANA_PASSWORD=andechain-grafana-2025
GRAFANA_PORT=3000

# Prometheus Configuration (optional)
PROMETHEUS_PORT=9090

# Frontend Configuration
FRONTEND_PORT=3002
NEXTAUTH_URL=https://localhost:3002
WALLET_CONNECT_PROJECT_ID=c3e4c3a3b3e4c3a3b3e4c3a3b3e4c3a3

# Celestia Configuration (Mocha-4 Testnet)
CELESTIA_NETWORK=mocha-4
CELESTIA_NAMESPACE=andechain-v1
CELESTIA_RPC=http://celestia-light:26658
EOF

# Verify .env file
cat .env
```

### Step 2.2: Verify Genesis Configuration

```bash
# Check genesis.json exists and is valid JSON
cat genesis.json | jq '.config | {chainId, andechain}'

# Expected output should show:
# chainId: 2019
# andechain: object with configuration
```

**Expected Output:**
```json
{
  "chainId": 2019,
  "andechain": {
    "name": "AndeChain Sovereign Rollup",
    "version": "1.0.0-beta",
    "type": "sovereign",
    "nativeCurrency": {
      "name": "ANDE",
      "symbol": "ANDE",
      "decimals": 18
    }
  }
}
```

### Step 2.3: Verify Docker Compose Configuration

```bash
# Validate docker-compose.yml syntax
docker compose config > /dev/null && echo "✅ docker-compose.yml is valid" || echo "❌ Invalid syntax"

# Check services are defined
docker compose config --services
# Should list: ev-reth, evolve-sequencer, celestia-light, explorer-backend, explorer-frontend, etc.

# Verify critical volumes
docker compose config | grep -A 5 "ev-reth-data"
```

---

## 🎯 Phase 3: Build Custom Docker Images

### Step 3.1: Build ev-reth Image

```bash
# Navigate to ev-reth directory
cd ev-reth

# Build the custom ev-reth image
docker build -t ande/ev-reth:latest \
  --build-arg BUILD_PROFILE=release \
  --build-arg FEATURES="jemalloc asm-keccak" \
  -f Dockerfile .

# Verify build succeeded
docker image ls | grep ande/ev-reth
# Should show: ande/ev-reth  latest  [IMAGE_ID]  [TIME]  [SIZE]

# Test the image
docker run --rm ande/ev-reth:latest --version
# Should output ev-reth version information

cd ..
```

**Expected Output:**
```
Successfully built ande/ev-reth:latest
ev-reth version X.X.X
```

### Step 3.2: Build AndeChain Frontend (Optional)

```bash
# Navigate to frontend
cd andefrontend

# Build frontend image
docker build -t ande/frontend:dev \
  --build-arg NODE_VERSION=20 \
  -t development .

# Verify build
docker image ls | grep ande/frontend

cd ..
```

---

## 🎯 Phase 4: Start Services

### Step 4.1: Clean Previous State (Important!)

```bash
# Remove old containers and volumes
docker compose down -v

# Remove old blockchain data
rm -rf ~/.ande-data/ev-reth/*

# Verify cleanup
docker ps -a | wc -l  # Should be minimal or 0
ls ~/.ande-data/ev-reth  # Should be empty or not exist
```

### Step 4.2: Start Infrastructure Services First

```bash
# Start only infrastructure services
docker compose up -d jwt-init celestia-light

# Wait for JWT generation
sleep 5

# Verify JWT was created
docker exec andechain-jwt-init ls -la /jwt/
# Should show jwt.hex file

# Check Celestia is starting (may take a minute)
sleep 20
docker logs andechain-celestia | tail -20
```

### Step 4.3: Start Blockchain Core Services

```bash
# Start ev-reth and sequencer
docker compose up -d ev-reth ande-evolve-sequencer

# Wait for ev-reth to initialize (30-40 seconds)
sleep 40

# Check ev-reth is healthy
docker logs ande-ev-reth | tail -20
# Should show "Transaction pool initialized" and "P2P networking initialized"

# Check sequencer is running
docker logs ande-evolve-sequencer | tail -20
# Should show "executor started" and "execution loop started"
```

**Expected Logs:**
```
ande-ev-reth: Transaction pool initialized
ande-ev-reth: P2P networking initialized
ande-ev-reth: Status connected_peers=0 latest_block=0

ande-evolve-sequencer: initialized state chain_id=evolve-test component=executor height=0
ande-evolve-sequencer: executor started component=executor
```

### Step 4.4: Verify Blockchain is Producing Blocks

```bash
# Wait for lazy block interval (30+ seconds)
sleep 35

# Check current block number
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq '.result' | xargs printf "%d\n"

# Should output: 1 or higher (indicates blocks are being produced)

# Repeat check after another 30 seconds
sleep 30
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq '.result' | xargs printf "%d\n"

# Should show higher block number
```

### Step 4.5: Start Supporting Services

```bash
# Start explorer and database services
docker compose up -d explorer-db stats-db redis explorer-backend contract-verifier

# Wait for databases to initialize (30-45 seconds)
sleep 45

# Check databases are healthy
docker ps | grep -E "explorer-db|stats-db|redis"
# Should show all three running (healthy)

# Check explorer backend logs
docker logs andechain-explorer-backend | tail -30
# Should show "successfully completed" for migrations
```

### Step 4.6: Start Frontend and Faucet

```bash
# Start remaining services
docker compose up -d explorer-frontend faucet faucet-proxy andechain-frontend

# Wait for services to start (30 seconds)
sleep 30

# Check all services are running
docker ps --format "table {{.Names}}\t{{.Status}}"
# Should show all containers running (mostly healthy)
```

---

## 🎯 Phase 5: Verify All Services

### Step 5.1: RPC Endpoint Tests

```bash
# Test 1: Chain ID verification
echo "=== Test 1: Chain ID ==="
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq '.result'
# Expected: "0x7e3" (2019 in decimal)

# Test 2: Latest block
echo "=== Test 2: Latest Block ==="
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq '.result' | xargs printf "%d\n"
# Expected: 1 or higher

# Test 3: Get block details
echo "=== Test 3: Block Details ==="
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}' | jq '.result | {number, hash, timestamp}'

# Test 4: Account balance
echo "=== Test 4: Test Account Balance ==="
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","latest"],"id":1}' | jq '.result'
# Expected: "0x33b2e3c9fd0803ce8000000" (1 billion ANDE)

# Test 5: Chain not syncing
echo "=== Test 5: Syncing Status ==="
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' | jq '.result'
# Expected: false (not syncing, already at latest)
```

### Step 5.2: Explorer Service Tests

```bash
# Test 1: Explorer Frontend
echo "=== Test 1: Explorer Frontend ==="
curl -s http://localhost:4000 | head -20
# Should return HTML (Blockscout frontend)

# Test 2: Explorer Backend Health
echo "=== Test 2: Explorer Backend Health ==="
curl -s http://localhost:4001/api/v1/health | jq '.'
# Should return success response

# Test 3: Chain Stats
echo "=== Test 3: Chain Statistics ==="
curl -s "http://localhost:4001/api/v1/stats?module=ethereum&action=ethsupply" | jq '.result'
# May take a minute to initialize
```

### Step 5.3: Faucet Service Tests

```bash
# Test 1: Faucet health
echo "=== Test 1: Faucet Health ==="
curl -s http://localhost:8081/health | jq '.'

# Test 2: Faucet frontend
echo "=== Test 2: Faucet Frontend ==="
curl -s http://localhost:3001 | head -20
```

### Step 5.4: Sequencer Health Check

```bash
# Check sequencer RPC
echo "=== Test 1: Sequencer RPC Health ==="
curl -s http://localhost:7331 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq '.'

# Check sequencer logs for errors
echo "=== Test 2: Sequencer Status ==="
docker logs ande-evolve-sequencer | grep -E "produced block|INF|ERR" | tail -20
```

---

## 🎯 Phase 6: Test Transactions

### Step 6.1: Send Test Transaction (Using Cast)

```bash
# Install Foundry (if not already installed)
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc

# Send 1 ANDE from test account
cast send 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  --value 1ether \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://localhost:8545

# Expected output: Transaction receipt with:
# status: 1 (success)
# blockNumber: [block number]
# transactionHash: [hash]
```

### Step 6.2: Verify Transaction in Explorer

```bash
# Get the transaction hash from previous step
TX_HASH="0x..."  # Replace with actual hash

# Query transaction via RPC
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$TX_HASH\"],\"id\":1}" | jq '.result | {blockNumber, status, gasUsed}'

# Check transaction in explorer (wait 30 seconds for indexing)
sleep 30
curl -s "http://localhost:4001/api/v1/transactions/$TX_HASH" | jq '.result'
```

### Step 6.3: Verify Balance Changes

```bash
# Check sender balance decreased
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","latest"],"id":1}' | jq '.result' | xargs printf "%d\n"

# Check recipient balance increased
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0x70997970C51812dc3A010C7d01b50e0d17dc79C8","latest"],"id":1}' | jq '.result' | xargs printf "%d\n"
```

---

## 🎯 Phase 7: Access Services

### Available Endpoints

| Service | URL | Purpose |
|---------|-----|---------|
| **RPC HTTP** | http://localhost:8545 | JSON-RPC API |
| **RPC WebSocket** | ws://localhost:8546 | WebSocket API |
| **Block Explorer** | http://localhost:4000 | Blockscout UI |
| **Explorer API** | http://localhost:4001 | REST API for blockchain data |
| **Faucet** | http://localhost:3001 | Token faucet |
| **Sequencer** | http://localhost:7331 | Sequencer RPC (internal) |
| **Metrics** | http://localhost:9090 | Prometheus (if enabled) |
| **Dashboards** | http://localhost:3000 | Grafana (if enabled) |
| **dApp Frontend** | http://localhost:3002 | AndeChain frontend (if running) |

### Connect MetaMask

```
Network Name: AndeChain Testnet
RPC URL: http://[YOUR_IP]:8545
Chain ID: 2019
Currency Symbol: ANDE
Block Explorer URL: http://[YOUR_IP]:4000
```

Replace `[YOUR_IP]` with your machine's IP address (not localhost if accessing from another machine).

---

## 🎯 Phase 8: Monitoring & Logs

### View Service Logs

```bash
# Follow all logs
docker compose logs -f

# Follow specific service logs
docker compose logs -f ande-ev-reth
docker compose logs -f ande-evolve-sequencer
docker compose logs -f andechain-explorer-backend

# View last N lines
docker compose logs --tail=100 ande-ev-reth
```

### Check Service Status

```bash
# All services
docker compose ps

# Specific service
docker compose ps ande-ev-reth

# Detailed stats
docker stats

# Check logs for errors
docker compose logs | grep -i error
```

### Common Log Messages

**ev-reth Healthy:**
```
Status connected_peers=0 latest_block=X
Forkchoice updated head_block_hash=...
```

**Sequencer Healthy:**
```
produced block component=executor height=X txs=0
executor started component=executor
```

**Explorer Healthy:**
```
Block 0 imported
Index had to catch up
```

---

## ⚠️ Troubleshooting

### Issue: Container Won't Start

```bash
# Check logs
docker compose logs [service_name]

# Restart service
docker compose restart [service_name]

# Rebuild from scratch
docker compose down -v
docker system prune -f
docker compose up -d --build
```

### Issue: RPC Not Responding

```bash
# Check ev-reth is running
docker ps | grep ande-ev-reth

# Check logs for errors
docker logs ande-ev-reth | tail -50

# Restart ev-reth
docker compose restart ande-ev-reth

# Wait 30 seconds for startup
sleep 30
curl http://localhost:8545 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

### Issue: Blocks Not Producing

```bash
# Check sequencer is running
docker ps | grep ande-evolve-sequencer

# Check sequencer logs
docker logs ande-evolve-sequencer | tail -100 | grep -E "produced|height|error"

# Check sequencer can reach ev-reth
docker exec ande-evolve-sequencer curl -s http://ev-reth:8545 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Restart sequencer
docker compose restart ande-evolve-sequencer
```

### Issue: Port Already in Use

```bash
# Find what's using the port
lsof -i :8545

# Kill the process
kill -9 [PID]

# Or change port in .env and docker-compose.yml
```

### Issue: Out of Disk Space

```bash
# Check disk usage
df -h

# Clean up old Docker images/containers
docker system prune -a

# Clear logs
docker compose logs --tail=0 -f > /dev/null

# Remove old blockchain data
rm -rf ~/.ande-data/ev-reth/
```

---

## 🔄 Maintenance Operations

### Restart All Services

```bash
docker compose restart
```

### Stop Services (Preserve Data)

```bash
docker compose stop
```

### Start Services (Resume)

```bash
docker compose start
```

### Full Cleanup (Fresh Start)

```bash
# This WILL delete all blockchain data
docker compose down -v
rm -rf ~/.ande-data/ev-reth/*
docker system prune -f

# Restart fresh
docker compose up -d
```

### Update Images

```bash
# Pull latest images
docker compose pull

# Rebuild custom images
docker build -t ande/ev-reth:latest ev-reth

# Restart with new images
docker compose up -d --build
```

---

## 📊 Performance Baseline

These are expected metrics on a normal machine:

| Metric | Expected | Issue If |
|--------|----------|----------|
| Block Time | ~30 seconds (lazy mode) | > 1 minute |
| RPC Response Time | < 100ms | > 500ms |
| Memory Usage (ev-reth) | 200-500MB | > 2GB |
| Disk I/O (ev-reth) | Minimal | Constant high I/O |
| Explorer Indexing | Catches up within 1 minute | Never catches up |

---

## ✅ Final Validation Checklist

- [ ] All services running (`docker compose ps` shows all healthy)
- [ ] RPC endpoint responds correctly
- [ ] Blocks are being produced (block height increasing)
- [ ] Transactions can be sent and confirmed
- [ ] Block explorer shows blocks and transactions
- [ ] Faucet service is accessible
- [ ] No error messages in critical service logs
- [ ] Can connect with MetaMask using RPC endpoint
- [ ] Network shows correct Chain ID (2019)
- [ ] Native currency displays as ANDE (not ETH)

---

## 🎉 Success! Your AndeChain Testnet is Ready

Once all validation checks pass:

1. **Testnet URL**: http://[YOUR_IP]:8545 (replace [YOUR_IP] with actual IP)
2. **Chain ID**: 2019
3. **Currency**: ANDE
4. **Explorer**: http://[YOUR_IP]:4000
5. **Faucet**: http://[YOUR_IP]:3001

You can now:
- ✅ Develop and test smart contracts
- ✅ Run integration tests
- ✅ Perform load testing
- ✅ Verify transaction processing
- ✅ Test governance features
- ✅ Experiment with token mechanics

---

## 📞 Support & Debugging

**For issues, check in this order:**

1. Check logs: `docker compose logs -f [service]`
2. Verify connectivity: `curl http://localhost:8545 -X POST ...`
3. Check disk space: `df -h`
4. Check Docker: `docker ps` and `docker stats`
5. Restart service: `docker compose restart [service]`
6. Full reset: Clean previous state section above

---

**Version**: 1.0.0  
**Last Updated**: 2025-10-28  
**AndeChain**: Sovereign Rollup on Celestia DA
