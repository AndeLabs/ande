# Operations Documentation

Guides for running, monitoring, and maintaining AndeChain in production.

## Documents

### 1. **EXECUTIVE_SUMMARY.md**
High-level overview of AndeChain current state, readiness level, and deployment status.

**Covers:**
- System overview and architecture summary
- Current operational status
- Key metrics and performance indicators
- Readiness assessment for production
- Outstanding issues and mitigation strategies
- Deployment recommendations

**Use for:** Understanding the current state of the system at a glance.

---

### 2. **PRODUCTION_STATUS.md**
Detailed current state of all AndeChain components.

**Covers:**
- Blockchain component status
- Execution client (ev-reth) status
- Smart contracts deployment status
- Explorer (Blockscout) status
- Faucet service status
- RPC endpoint verification
- Block production metrics
- Data availability (Celestia) status

**Use for:** Checking specific component health and performance.

---

### 3. **PRODUCTION_READY.md**
Comprehensive assessment of production readiness with detailed checklist.

**Covers:**
- Core functionality verification
- Smart contract security
- Infrastructure stability
- Data integrity checks
- Performance optimization
- Monitoring and alerting setup
- Backup and disaster recovery
- Security hardening
- Documentation completeness

**Use for:** Validating production readiness before mainnet deployment.

---

### 4. **DOCKER_PRODUCTION_SPEC.md**
Detailed Docker configuration and container specifications for production deployment.

**Covers:**
- Container specifications for each service
  - ev-reth execution client
  - EVOLVE sequencer
  - Blockscout explorer
  - Faucet service
  - Supporting services (PostgreSQL, Redis, etc.)

- Resource requirements
  - CPU and memory limits
  - Storage requirements
  - Network bandwidth

- Environment variables and configuration
- Health check configurations
- Logging and monitoring setup
- Security best practices

**Use for:** Understanding Docker container requirements and configuration.

---

## Common Operations

### Checking Chain Status
```bash
# Check latest block
curl -s http://localhost:8545 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq

# Check peer count
curl -s http://localhost:8545 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' | jq
```

### Monitoring Block Production
```bash
# Watch blocks in real-time
watch -n 2 'curl -s http://localhost:8545 -X POST \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}" | jq'
```

### Checking Account Balances
```bash
# Get balance of an account
curl -s http://localhost:8545 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0xYourAddress","latest"],"id":1}' | jq
```

### Container Logs
```bash
# View ev-reth logs
docker-compose logs -f ev-reth

# View sequencer logs
docker-compose logs -f sequencer

# View explorer logs
docker-compose logs -f blockscout-backend
```

---

## Troubleshooting

### Chain Not Producing Blocks
1. Check sequencer status: `docker-compose logs sequencer`
2. Verify ev-reth is running: `docker-compose ps`
3. Check RPC connectivity: See "Checking Chain Status" above
4. Review TESTNET_DEPLOYMENT_GUIDE.md troubleshooting section

### High Memory Usage
1. Check container usage: `docker stats`
2. Review DOCKER_PRODUCTION_SPEC.md for memory limits
3. Consider adjusting heap size for JVM services

### RPC Timeout Issues
1. Check network connectivity
2. Verify Docker port mappings: `docker-compose ps`
3. Check service logs for errors

---

## Monitoring and Alerting

For detailed monitoring setup, see DOCKER_PRODUCTION_SPEC.md monitoring section.

Recommended tools:
- Prometheus for metrics collection
- Grafana for visualization
- AlertManager for alerts

---

## Support

For deployment instructions, see `docs/deployment/` directory.
For architecture and reference information, see `docs/reference/` directory.
