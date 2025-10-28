# ⚡ AndeChain Testnet - Quick Start (5 Minutes)

**For experienced devops engineers who want to deploy quickly**

---

## Prerequisites (2 minutes)

```bash
# Ensure you have:
# ✅ Docker Desktop installed (with compose v2+)
# ✅ 50GB+ free disk space
# ✅ Git installed
# ✅ Ports 8545, 8546, 4000, 3001, 7331, 26658 available

# Verify:
docker --version          # Docker version X.X.X or higher
docker compose version    # Docker Compose version X.X.X or higher
df -h | grep -E "/$|/data" # Check disk space
```

---

## Option A: Fully Automated (Recommended)

### Step 1: Clone & Deploy (3 minutes)

```bash
# Clone repo
git clone <ANDECHAIN_REPO_URL> ande-labs
cd ande-labs

# Run automated deployment
./scripts/quick-testnet-deploy.sh

# That's it! Script will:
# ✅ Check prerequisites
# ✅ Create .env configuration
# ✅ Build Docker images
# ✅ Start all services
# ✅ Run health checks
# ✅ Display connection info
```

### Step 2: Verify (1 minute)

```bash
# Run health checks anytime
./scripts/quick-testnet-deploy.sh --check-only

# Should show:
# ✅ Chain ID correct
# ✅ Blocks producing
# ✅ Block explorer accessible
# ✅ Faucet service active
```

---

## Option B: Manual Steps (For Understanding)

### Step 1: Setup (2 minutes)

```bash
git clone <ANDECHAIN_REPO_URL> ande-labs
cd ande-labs

# Create environment
mkdir -p ~/.ande-data/ev-reth

# Create .env
cat > .env << 'EOF'
CHAIN_ID=2019
DOCKER_USER=1000
DOCKER_GROUP=1000
FAUCET_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
EXPLORER_DB_PASSWORD=andechain-secure-postgres-2025
FAUCET_PORT=3001
EXPLORER_FRONTEND_PORT=4000
EXPLORER_BACKEND_PORT=4001
EOF
```

### Step 2: Start Services (2 minutes)

```bash
# Start all services
docker compose up -d

# Wait for initialization
sleep 60

# Verify health
docker compose ps

# Should show most services as "Up" or "healthy"
```

### Step 3: Test (1 minute)

```bash
# Check RPC
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq '.'

# Should return a block number > 0

# Open explorer
open http://localhost:4000  # macOS
# or visit in browser
```

---

## 🎯 After Deployment - What to Do Next

### Test Network Access

```bash
# 1. Check chain ID
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq '.result'
# Expected: "0x7e3" (2019)

# 2. Check balance
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","latest"],"id":1}' | jq '.result'
# Expected: Large number (1 billion ANDE)

# 3. Check latest block
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}' | jq '.result | {number, hash}'
```

### Send Test Transaction (Optional)

```bash
# Install Foundry if needed
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc

# Send 1 ANDE
cast send 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  --value 1ether \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://localhost:8545

# Expected: Transaction receipt with status 1 (success)
```

### Connect MetaMask

```
Network: AndeChain Testnet
RPC URL: http://[YOUR_IP]:8545
Chain ID: 2019
Symbol: ANDE
Explorer: http://[YOUR_IP]:4000
```

---

## 📊 Service Ports

| Service | Port | URL |
|---------|------|-----|
| RPC HTTP | 8545 | http://localhost:8545 |
| RPC WS | 8546 | ws://localhost:8546 |
| Explorer | 4000 | http://localhost:4000 |
| Explorer API | 4001 | http://localhost:4001 |
| Faucet | 3001 | http://localhost:3001 |
| Sequencer | 7331 | http://localhost:7331 |
| Prometheus | 9090 | http://localhost:9090 |
| Grafana | 3000 | http://localhost:3000 |

---

## 🔧 Common Operations

### View Logs

```bash
# All logs
docker compose logs -f

# Specific service
docker compose logs -f ande-ev-reth
docker compose logs -f ande-evolve-sequencer
docker compose logs -f andechain-explorer-backend
```

### Restart Service

```bash
docker compose restart ande-ev-reth
docker compose restart ande-evolve-sequencer
```

### Stop All

```bash
docker compose stop
```

### Start All

```bash
docker compose start
```

### Full Cleanup (Fresh Start)

```bash
# WARNING: This deletes all blockchain data
docker compose down -v
rm -rf ~/.ande-data/ev-reth/*
docker compose up -d
```

---

## ⚠️ Troubleshooting

### Issue: RPC not responding

```bash
# Check if ev-reth is running
docker ps | grep ande-ev-reth

# Check logs
docker logs ande-ev-reth | tail -50

# Restart
docker compose restart ande-ev-reth
sleep 30
curl http://localhost:8545 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

### Issue: Blocks not producing

```bash
# Check sequencer logs
docker logs ande-evolve-sequencer | grep -E "produced|height|error" | tail -20

# Restart sequencer
docker compose restart ande-evolve-sequencer
sleep 30
```

### Issue: Out of disk space

```bash
# Check usage
df -h

# Clean up
docker system prune -a
```

---

## 📈 Performance Expectations

| Metric | Expected |
|--------|----------|
| Block Time | 30 seconds (lazy mode) |
| RPC Response | < 100ms |
| Memory (ev-reth) | 200-500MB |
| Transaction Finality | 1 block |
| Chain Stability | Continuous |

---

## 🎯 Next Steps After Deployment

1. **Test RPC Endpoints** ✅ (Done above)
2. **Send Transactions** ✅ (Done above)
3. **Deploy Smart Contracts** → See `andechain/contracts/README.md`
4. **Test Governance** → Deploy contracts, create proposals
5. **Load Testing** → Send 100+ transactions
6. **Monitor Performance** → Check Prometheus/Grafana

---

## 📚 Full Documentation

For detailed information, see:
- `TESTNET_DEPLOYMENT_GUIDE.md` - Complete step-by-step guide
- `TESTNET_READINESS_CHECKLIST.md` - Pre-launch checklist
- `PRODUCTION_STATUS_REPORT.md` - Current system status

---

## 🚀 Summary

**Total Time: 5 minutes** ⏱️

Your AndeChain testnet is now:
- ✅ Running with latest code
- ✅ Producing blocks every 30 seconds
- ✅ Fully functional for development
- ✅ Ready for smart contract deployment
- ✅ Accessible via standard Ethereum RPC

**Chain Ready**: Yes 🎉

---

**Questions?** Check logs or review full documentation.
