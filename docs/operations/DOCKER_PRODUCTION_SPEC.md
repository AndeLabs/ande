# AndeChain Docker Production Migration Specification

## Overview

This specification outlines the complete migration of AndeChain to a production-ready Docker environment, integrating EVOLVE sequencer, Celestia DA, and all supporting services into a unified, scalable infrastructure.

## Current State Analysis

### Existing Infrastructure
- **EVOLVE Sequencer**: Operational with Celestia Mocha-4 DA
- **Block Production**: ~2 seconds, chainId 2019 for testnet
- **Frontend**: Next.js with Wagmi integration
- **Issue**: Network mismatch errors (1234 vs 2019)
- **Issue**: Faucet connectivity problems between local and Docker services

### Pain Points
1. Mixed local/Docker deployment causing network conflicts
2. Faucet service disconnected from RPC endpoints
3. Port conflicts between services
4. Inconsistent environment configurations
5. Manual deployment processes

## Target Architecture

### Production Stack Components

```yaml
Services:
  - ev-reth-sequencer: Custom EVM client (Rust)
  - celestia-da: Data Availability layer
  - bundler-4337: Account abstraction bundler
  - relayer: Cross-chain bridge service
  - faucet-api: Token distribution service
  - faucet-ui: Faucet web interface
  - explorer: Blockscout blockchain explorer
  - frontend: Next.js dApp interface
  - postgres: Database for explorer and services
  - redis: Caching and session management
```

### Network Architecture

```yaml
Networks:
  evstack_shared:
    driver: bridge
    external: false
    
Port Mappings:
  ev-reth-sequencer: 8545 (RPC), 8546 (WS)
  faucet-api: 8081
  faucet-ui: 3001
  explorer: 4000
  frontend: 3000
  postgres: 5432
  redis: 6379
```

## Implementation Plan

### Phase 1: Infrastructure Foundation

#### 1.1 Docker Compose Architecture
- Create `docker-compose.prod.yml` with all services
- Implement unified network configuration (`evstack_shared`)
- Standardize environment variable management
- Set up service health checks and dependencies

#### 1.2 Service Definitions
```yaml
# ev-reth-sequencer
ev-reth-sequencer:
  build: ./ev-reth
  ports: ["8545:8545", "8546:8546"]
  environment:
    - CHAIN_ID=2019
    - DA_LAYER=celestia
  networks: [evstack_shared]
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8545"]
    interval: 10s
    timeout: 5s
    retries: 3
```

#### 1.3 Configuration Management
- Environment-specific `.env` files:
  - `.env.local` (development)
  - `.env.testnet` (chainId 2019)
  - `.env.mainnet` (production)
- Secrets management for production keys
- Dynamic configuration loading

### Phase 2: Service Integration

#### 2.1 EVOLVE Faucet Integration
- Configure EVOLVE faucet to connect to `ev-reth-sequencer:8545`
- Set up proper environment variables:
  ```env
  WEB3_PROVIDER=http://ev-reth-sequencer:8545
  CHAIN_ID=2019
  FAUCET_PRIVATE_KEY=[secure key management]
  FAUCET_AMOUNT=1000000000000000000  # 1 ETH
  COOLDOWN_PERIOD=86400  # 24 hours
  ```

#### 2.2 Frontend Configuration
- Update `web3-provider.tsx` for dynamic chain handling
- Implement proper network switching logic
- Configure RPC endpoints to use Docker service names internally
- External access through proper port mapping

#### 2.3 Explorer Integration
- Configure Blockscout to connect to ev-reth RPC
- Set up PostgreSQL database with proper schemas
- Implement indexing for transactions and contracts

### Phase 3: Production Hardening

#### 3.1 Security Configuration
- Implement proper secret management
- Set up HTTPS termination
- Configure firewalls and access controls
- Implement rate limiting

#### 3.2 Monitoring & Logging
- Centralized logging with structured formats
- Health check endpoints for all services
- Metrics collection (Prometheus-compatible)
- Alerting for critical failures

#### 3.3 Backup & Recovery
- Database backup strategies
- Blockchain data persistence
- Disaster recovery procedures

## Service Specifications

### EV-Reth Sequencer
```yaml
Service: ev-reth-sequencer
Port: 8545 (HTTP RPC), 8546 (WebSocket)
Dependencies: [celestia-da]
Health Check: RPC call to eth_blockNumber
Resources:
  Memory: 4GB minimum, 8GB recommended
  CPU: 4 cores minimum
  Storage: 500GB SSD for blockchain data
```

### Celestia DA
```yaml
Service: celestia-da
Port: 26659 (RPC), 26660 (P2P)
Network: Mocha-4 (testnet), Mainnet (production)
Resources:
  Memory: 2GB minimum
  CPU: 2 cores minimum
  Storage: 100GB for DA node
```

### EVOLVE Faucet
```yaml
Services:
  faucet-api:
    Port: 8081
    Dependencies: [ev-reth-sequencer, redis]
    Environment:
      - WEB3_PROVIDER=http://ev-reth-sequencer:8545
      - CHAIN_ID=2019
      - REDIS_URL=redis://redis:6379
  
  faucet-ui:
    Port: 3001
    Dependencies: [faucet-api]
    Environment:
      - FAUCET_API_URL=http://faucet-api:8081
```

### Blockscout Explorer
```yaml
Service: blockscout
Port: 4000
Dependencies: [ev-reth-sequencer, postgres]
Environment:
  - DATABASE_URL=postgresql://postgres:password@postgres:5432/explorer
  - ETHEREUM_JSONRPC_HTTP_URL=http://ev-reth-sequencer:8545
  - ETHEREUM_JSONRPC_WS_URL=ws://ev-reth-sequencer:8546
```

### Frontend dApp
```yaml
Service: frontend
Port: 3000
Dependencies: [ev-reth-sequencer]
Build Context: ./andefrontend
Environment:
  - NEXT_PUBLIC_RPC_URL=http://localhost:8545
  - NEXT_PUBLIC_CHAIN_ID=2019
  - NEXT_PUBLIC_FAUCET_URL=http://localhost:3001
```

## Environment Configurations

### Development Environment
```yaml
# .env.local
CHAIN_ID=1234
RPC_URL=http://localhost:8545
FAUCET_AMOUNT=10000000000000000000  # 10 ETH
ENABLE_DEBUG_LOGS=true
```

### Testnet Environment
```yaml
# .env.testnet
CHAIN_ID=2019
RPC_URL=http://ev-reth-sequencer:8545
FAUCET_AMOUNT=1000000000000000000   # 1 ETH
COOLDOWN_PERIOD=3600                # 1 hour
CELESTIA_NETWORK=mocha-4
```

### Production Environment
```yaml
# .env.mainnet
CHAIN_ID=[TBD]
RPC_URL=http://ev-reth-sequencer:8545
FAUCET_AMOUNT=100000000000000000    # 0.1 ETH
COOLDOWN_PERIOD=86400               # 24 hours
CELESTIA_NETWORK=celestia
ENABLE_MONITORING=true
ENABLE_ALERTS=true
```

## Deployment Scripts

### Make Commands
```makefile
# Start full production stack
make prod-start:
	docker-compose -f docker-compose.prod.yml --env-file .env.testnet up -d

# Health check all services
make prod-health:
	./scripts/check-services-health.sh

# Deploy smart contracts
make prod-deploy-contracts:
	./scripts/deploy-contracts.sh --network testnet

# Backup data
make prod-backup:
	./scripts/backup-production-data.sh
```

### Health Check Script
```bash
#!/bin/bash
# scripts/check-services-health.sh

services=(
  "ev-reth-sequencer:8545"
  "faucet-api:8081/health"
  "faucet-ui:3001"
  "blockscout:4000"
  "frontend:3000"
)

for service in "${services[@]}"; do
  if curl -f "http://localhost:${service}" > /dev/null 2>&1; then
    echo "✓ $service is healthy"
  else
    echo "✗ $service is not responding"
    exit 1
  fi
done
```

## Migration Strategy

### Step 1: Preparation
1. Create backup of current configuration
2. Document current service ports and dependencies
3. Test new Docker configuration in isolated environment

### Step 2: Gradual Migration
1. Deploy new Docker stack alongside existing services
2. Test connectivity between all services
3. Verify faucet functionality with testnet
4. Validate frontend interactions with new RPC endpoints

### Step 3: Cutover
1. Update DNS/load balancer to point to new stack
2. Monitor all services for stability
3. Verify end-to-end user workflows
4. Decommission old infrastructure

### Step 4: Validation
1. Run comprehensive test suite
2. Verify all integrations work correctly
3. Test failure scenarios and recovery
4. Document final configuration

## Success Criteria

### Functional Requirements
- [ ] All services start successfully with `docker-compose up`
- [ ] Frontend can connect to blockchain via Docker RPC
- [ ] Faucet can distribute tokens successfully
- [ ] Explorer indexes blocks and transactions
- [ ] Cross-chain bridge functionality works
- [ ] Account abstraction (ERC-4337) bundler operates correctly

### Performance Requirements
- [ ] Block production maintains ~2 second intervals
- [ ] Frontend response times < 200ms for user interactions
- [ ] RPC calls respond within 500ms average
- [ ] Faucet transactions confirm within 10 seconds

### Operational Requirements
- [ ] Services automatically restart on failure
- [ ] Health checks detect and report issues
- [ ] Logs are centralized and searchable
- [ ] Backup and recovery procedures tested
- [ ] Monitoring alerts function correctly

## Risk Mitigation

### High-Risk Areas
1. **Data Loss**: Implement comprehensive backup strategy
2. **Service Dependencies**: Use health checks and retry logic
3. **Network Configuration**: Test all port mappings thoroughly
4. **Secret Management**: Never commit secrets to version control

### Rollback Plan
1. Keep current infrastructure running during migration
2. Implement quick rollback scripts
3. Test rollback procedures in staging environment
4. Document emergency procedures

## Timeline

### Week 1: Infrastructure Setup
- Create Docker Compose configurations
- Set up networking and environment management
- Implement health checks and monitoring

### Week 2: Service Integration
- Integrate EVOLVE faucet with new RPC endpoints
- Configure Blockscout explorer
- Update frontend for new architecture

### Week 3: Testing & Validation
- Comprehensive integration testing
- Performance validation
- Security audit
- Documentation update

### Week 4: Deployment & Monitoring
- Production deployment
- Post-deployment monitoring
- Issue resolution
- Final documentation

## Maintenance & Operations

### Daily Operations
- Monitor service health dashboards
- Check log aggregation for errors
- Verify backup completion
- Review resource utilization

### Weekly Operations
- Update dependencies and security patches
- Review performance metrics
- Test backup recovery procedures
- Update documentation as needed

### Monthly Operations
- Security audit and penetration testing
- Capacity planning and resource optimization
- Disaster recovery testing
- Stakeholder reporting

---

*This specification serves as the foundation for migrating AndeChain to a production-ready Docker environment. All implementation should follow the principles outlined in the project constitution and undergo proper review processes.*