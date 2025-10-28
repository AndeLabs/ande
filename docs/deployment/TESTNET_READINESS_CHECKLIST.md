# ✅ AndeChain Testnet Readiness Checklist

**Critical Items to Complete BEFORE Deploying to Testnet**

---

## 🔴 BLOCKING ISSUES (Must Fix Before Testnet)

### 1. Slither Security Findings - HIGH/CRITICAL
**Status**: ❌ NOT FIXED  
**File**: `/Users/munay/dev/ande-labs/andechain/contracts/SLITHER_CRITICAL_FINDINGS.md`  
**Impact**: Smart contracts have security vulnerabilities

**Required Actions:**
```bash
# 1. Review all findings in SLITHER_CRITICAL_FINDINGS.md
cat andechain/contracts/SLITHER_CRITICAL_FINDINGS.md

# 2. Fix each HIGH/CRITICAL finding:
# - Add SafeERC20 wrapper for token transfers
# - Add reentrancy guards where needed
# - Initialize all state variables
# - Fix divide-before-multiply patterns

# 3. Re-run Slither analysis
cd andechain/contracts
slither . --json slither-report.json

# 4. Verify no HIGH/CRITICAL findings remain
grep -i "high\|critical" slither-report.json
# Should return empty if all fixed
```

**Time Estimate**: 4-6 hours  
**Complexity**: Medium  
**Owner**: Smart Contract Team

---

### 2. ANDE Precompile Caller Validation - MEDIUM
**Status**: ⚠️ TODO (Disabled)  
**File**: `/Users/munay/dev/ande-labs/ev-reth/crates/evolve/src/evm_config/ande_precompile_provider.rs:112`  
**Impact**: Any contract can call the precompile, not just ANDEToken

**Current Issue:**
```rust
// NOTE: Caller validation is disabled for now because we need access to the EVM context
// to get msg.sender. This will be properly implemented when we integrate with the
// EvmBuilder and have access to the full execution context.
//
// TODO: Implement proper caller validation in the handler registration phase
```

**Required Actions:**
```bash
# 1. Integrate caller validation in precompile
# Location: ev-reth/crates/evolve/src/evm_config/ande_precompile_provider.rs

# 2. Add test for caller validation
cd ev-reth
cargo test ande_precompile_caller_validation

# 3. Verify ANDEToken can call but other addresses cannot
# (Will need to deploy ANDEToken first to get address)
```

**Time Estimate**: 4-6 hours  
**Complexity**: Medium-High (requires EVM integration)  
**Owner**: Protocol Team

---

### 3. Multi-Sig Wallet Setup - HIGH
**Status**: ❌ NOT IMPLEMENTED  
**Impact**: Admin keys are single-signer, critical operations unprotected

**Required Actions:**
```bash
# 1. Create 2-of-3 multi-sig for MINTER_ROLE
# Use Gnosis Safe or Safe Factory
# Signers: [Address1, Address2, Address3]

# 2. Create 3-of-5 multi-sig for DEFAULT_ADMIN_ROLE
# Signers: [Address1, Address2, Address3, Address4, Address5]

# 3. Deploy multi-sigs to testnet
# Record addresses in config file

# 4. Update ANDEToken contract
# Change admin from single address to multi-sig address

# 5. Test multi-sig operations
# Create proposal, sign with 2/3 signers, execute
```

**Recommended Tools:**
- Gnosis Safe (https://safe.global)
- Safe Factory Smart Contract
- Multi-Sig Web Interface

**Time Estimate**: 3-4 hours  
**Complexity**: Medium  
**Owner**: Operations Team

---

### 4. Governance Timelock Integration - HIGH
**Status**: ❌ NOT INTEGRATED  
**Impact**: Governance proposals execute immediately without delay

**Required Actions:**
```bash
# 1. Update AndeGovernor.sol
# Current: Executes proposals immediately after voting passes
# Required: Integrate with TimelockController

# 2. Add timelock delay (minimum 2 hours for testnet)
contract AndeGovernor is Governor, GovernorSettings, GovernorVotes, GovernorVotesQuorumFraction, GovernorTimelockControl {
    // ...
    constructor(...) Governor(...) GovernorSettings(1, 50400, 10000) GovernorVotes(...) ...
}

# 3. Deploy TimelockController with minimum delay
# minimum_delay = 2 hours = 7200 seconds

# 4. Grant Timelock roles to Governor
# PROPOSER_ROLE = AndeGovernor
# EXECUTOR_ROLE = address(0) (anyone can execute after delay)

# 5. Test governance workflow
# 1. Create proposal
# 2. Wait for voting period
# 3. Vote passes
# 4. Wait for timelock delay
# 5. Execute proposal
```

**File to Update**: `/Users/munay/dev/ande-labs/andechain/contracts/src/governance/AndeGovernor.sol`

**Time Estimate**: 2-3 hours  
**Complexity**: Medium  
**Owner**: Smart Contract Team

---

## 🟡 HIGH PRIORITY (Complete ASAP)

### 5. Contract Deployment Automation - HIGH
**Status**: ⚠️ PARTIAL  
**Files**: 
- `andechain/contracts/script/DeployCore.s.sol` (exists but not called)
- `andechain/scripts/deploy-testnet.sh` (incomplete)

**Required Actions:**
```bash
# 1. Verify DeployCore.s.sol exists and is complete
cat andechain/contracts/script/DeployCore.s.sol

# 2. Integrate into deploy script
# Update deploy-testnet.sh to:
# a) Compile contracts
cd andechain/contracts
forge build

# b) Deploy core contracts
forge script script/DeployCore.s.sol:DeployCore \
  --rpc-url http://localhost:8545 \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast \
  --verify

# c) Save deployed addresses to file
# contracts-deployed.json should contain:
# {
#   "ANDEToken": "0x...",
#   "AndeGovernor": "0x...",
#   "AndeTimelockController": "0x...",
#   "deployBlockNumber": 123
# }

# d) Verify contract initialization
forge script script/VerifyDeployment.s.sol \
  --rpc-url http://localhost:8545
```

**Time Estimate**: 2-3 hours  
**Complexity**: Medium  
**Owner**: DevOps Team

---

### 6. Environment Configuration Validation - HIGH
**Status**: ⚠️ PARTIAL  
**Impact**: Services may fail to start due to missing variables

**Required Actions:**
```bash
# 1. Create validation script
cat > scripts/validate-env.sh << 'EOF'
#!/bin/bash

REQUIRED_VARS=(
  "CHAIN_ID"
  "NETWORK_NAME"
  "FAUCET_PRIVATE_KEY"
  "EXPLORER_DB_PASSWORD"
  "DOCKER_USER"
  "DOCKER_GROUP"
)

echo "Validating environment variables..."
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "❌ Missing: $var"
    exit 1
  else
    echo "✅ Found: $var"
  fi
done

echo "✅ All required variables present"
EOF

# 2. Run validation
chmod +x scripts/validate-env.sh
./scripts/validate-env.sh

# 3. Verify all ports are available
for port in 8545 8546 4000 3001 7331; do
  if ! nc -z localhost $port 2>/dev/null; then
    echo "✅ Port $port available"
  else
    echo "❌ Port $port in use"
  fi
done
```

**Time Estimate**: 1-2 hours  
**Complexity**: Low  
**Owner**: DevOps Team

---

### 7. Database Initialization Verification - HIGH
**Status**: ⚠️ PARTIAL  
**Impact**: Explorer may not index blocks correctly

**Required Actions:**
```bash
# 1. Wait for database to be fully ready
echo "Waiting for databases to initialize..."
sleep 60

# 2. Verify database migrations ran successfully
docker logs andechain-explorer-backend 2>&1 | grep -E "Migration|success|ERROR"

# 3. Check database tables exist
docker exec andechain-explorer-db psql -U blockscout -d blockscout -c "\dt" | head -20

# 4. Verify explorer can connect to blockchain
curl -s http://localhost:4001/api/v1/stats | jq '.result' || echo "Explorer API not ready"

# 5. Wait for initial block indexing (may take 1-2 minutes)
echo "Waiting for block indexing..."
sleep 120

# 6. Verify blocks are indexed
curl -s http://localhost:4001/api/v1/blocks | jq '.result | length'
# Should show non-zero number
```

**Time Estimate**: 1 hour (mostly wait time)  
**Complexity**: Low  
**Owner**: DevOps Team

---

## 🟢 MEDIUM PRIORITY (Before Public Testnet)

### 8. Health Check Implementation - MEDIUM
**Status**: ⚠️ PARTIAL  
**Impact**: Can't reliably detect when services are ready

**Required Actions:**
```bash
# 1. Create comprehensive health check script
cat > scripts/health-check.sh << 'EOF'
#!/bin/bash

echo "=== AndeChain Testnet Health Check ==="

# Check RPC
echo -n "RPC endpoint: "
if curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | grep -q "0x7e3"; then
  echo "✅ Working"
else
  echo "❌ Failed"
  exit 1
fi

# Check block production
echo -n "Block production: "
BLOCK=$(curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq -r '.result' | xargs printf "%d\n")
if [ "$BLOCK" -gt 0 ]; then
  echo "✅ Block $BLOCK"
else
  echo "❌ No blocks produced"
  exit 1
fi

# Check explorer
echo -n "Block explorer: "
if curl -s http://localhost:4000 | grep -q "blockscout"; then
  echo "✅ Working"
else
  echo "❌ Failed"
  exit 1
fi

# Check faucet
echo -n "Faucet service: "
if curl -s http://localhost:8081/health | grep -q "ok"; then
  echo "✅ Working"
else
  echo "⚠️ Initializing"
fi

echo "✅ All critical services operational"
EOF

chmod +x scripts/health-check.sh

# 2. Run health check
./scripts/health-check.sh

# 3. Add to startup sequence
# Should be called after docker compose up
```

**Time Estimate**: 2 hours  
**Complexity**: Low  
**Owner**: DevOps Team

---

### 9. Contract Address Registry - MEDIUM
**Status**: ❌ NOT IMPLEMENTED  
**Impact**: Can't track deployed contract addresses

**Required Actions:**
```bash
# 1. Create registry file structure
mkdir -p deployments/testnet

# 2. After contract deployment, save addresses
cat > deployments/testnet/addresses.json << 'EOF'
{
  "network": "AndeChain Testnet",
  "chainId": 2019,
  "deploymentBlock": 5,
  "timestamp": "2025-10-28T14:30:00Z",
  "contracts": {
    "ANDEToken": {
      "address": "0x...",
      "abi": [...],
      "constructorArgs": {...}
    },
    "AndeGovernor": {
      "address": "0x...",
      "abi": [...]
    }
  }
}
EOF

# 3. Create deployment verification script
cat > scripts/verify-deployment.sh << 'EOF'
#!/bin/bash

ADDRESSES_FILE="deployments/testnet/addresses.json"

echo "Verifying deployed contracts..."

ANDE_TOKEN=$(jq -r '.contracts.ANDEToken.address' $ADDRESSES_FILE)

# Verify ANDEToken
echo -n "ANDEToken at $ANDE_TOKEN: "
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$ANDE_TOKEN\",\"latest\"],\"id\":1}" | \
  jq -r '.result' | grep -q "0x" && echo "✅ Deployed" || echo "❌ Not found"
EOF

chmod +x scripts/verify-deployment.sh
```

**Time Estimate**: 2 hours  
**Complexity**: Low  
**Owner**: Smart Contract Team

---

### 10. Monitoring Alerting Setup - MEDIUM
**Status**: ⚠️ PARTIAL  
**Impact**: Can't detect and respond to issues

**Required Actions:**
```bash
# 1. Fix Prometheus configuration
cat > config/monitoring/alert.rules.yml << 'EOF'
groups:
  - name: andechain_alerts
    interval: 30s
    rules:
      - alert: BlockProductionStopped
        expr: increase(eth_block_number[5m]) == 0
        for: 5m
        annotations:
          summary: "Block production stopped"
          
      - alert: HighErrorRate
        expr: rate(reth_errors_total[5m]) > 0.1
        for: 5m
        annotations:
          summary: "High error rate in ev-reth"
          
      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes{name="ande-ev-reth"} > 2000000000
        for: 5m
        annotations:
          summary: "ev-reth memory usage > 2GB"
EOF

# 2. Set up Alertmanager (optional)
cat > config/monitoring/alertmanager.yml << 'EOF'
global:
  resolve_timeout: 5m

route:
  receiver: 'default'
  group_by: ['alertname']

receivers:
  - name: 'default'
    # Add notification channels:
    # - email_configs: [...]
    # - slack_configs: [...]
    # - pagerduty_configs: [...]
EOF

# 3. Restart Prometheus with new config
docker compose restart ande-prometheus
```

**Time Estimate**: 2-3 hours  
**Complexity**: Medium  
**Owner**: DevOps Team

---

## ✅ NICE-TO-HAVE (Can do after testnet launch)

- [ ] Complete documentation (deployment guide, API docs, etc.)
- [ ] Comprehensive test suite (unit, integration, load tests)
- [ ] Performance benchmarking scripts
- [ ] Disaster recovery procedures
- [ ] Incident response playbook
- [ ] Key rotation procedures
- [ ] Rate limiting on RPC endpoints
- [ ] DDoS protection configuration
- [ ] Log aggregation setup (ELK, Splunk, etc.)
- [ ] Distributed tracing (Jaeger, etc.)

---

## 📊 Implementation Timeline

### Week 1 (Critical Path)
- **Day 1**: Fix Slither findings + Precompile caller validation
- **Day 2**: Multi-sig setup + Governance timelock integration
- **Day 3**: Deployment automation + Environment validation
- **Day 4**: Database verification + Health checks
- **Day 5**: Testing & bug fixes

**Estimated Effort**: 25-30 engineer-hours for small team

### Week 2 (Polish & Documentation)
- **Day 1**: Contract registry + Monitoring alerts
- **Day 2**: Documentation completion
- **Day 3**: Full integration testing
- **Day 4**: Stress testing & load testing
- **Day 5**: Final validation & deployment prep

**Estimated Effort**: 15-20 engineer-hours

---

## 🎯 Success Criteria

Before marking as "Testnet Ready", verify:

- [ ] All BLOCKING issues are fixed
- [ ] All HIGH priority items are complete
- [ ] Slither shows no HIGH/CRITICAL findings
- [ ] All contracts properly initialized
- [ ] Multi-sig wallets created and tested
- [ ] Governance timelock integrated and tested
- [ ] Deployment script runs successfully
- [ ] All environment variables validated
- [ ] Database migrations complete
- [ ] Block production stable (>5 continuous blocks)
- [ ] Transactions process successfully
- [ ] Block explorer indexes blocks correctly
- [ ] Faucet distributes tokens correctly
- [ ] Health check script shows all green
- [ ] No error logs in critical services
- [ ] Load test passes (100+ transactions)
- [ ] Team trained on deployment procedures
- [ ] Runbooks written for common issues
- [ ] Recovery procedures documented and tested

---

## 🚨 Red Flags

If any of these occur, DO NOT deploy to public testnet:

- ❌ Slither HIGH/CRITICAL findings still present
- ❌ Single-signer admin keys (no multi-sig)
- ❌ No timelock on governance
- ❌ Blocks not producing consistently
- ❌ Transactions failing
- ❌ RPC endpoint crashes
- ❌ Explorer doesn't index blocks
- ❌ Database corruption
- ❌ Memory leaks (growing RAM usage)
- ❌ Unhandled exceptions in logs
- ❌ No health monitoring in place
- ❌ No documented recovery procedures

---

## 📝 Sign-Off

**When all items complete, obtain sign-off from:**

- [ ] **Security**: "Smart contracts have been reviewed and are secure"
- [ ] **Engineering**: "All critical systems tested and stable"
- [ ] **Operations**: "Monitoring and alerting configured"
- [ ] **Product**: "Feature set meets testnet requirements"
- [ ] **Leadership**: "Approved for public testnet deployment"

---

**Document Version**: 1.0  
**Last Updated**: 2025-10-28  
**Testnet Target Date**: [SET DATE]
