# Deployment Documentation

Complete guides for deploying AndeChain testnet on your infrastructure.

## Quick Navigation

### 1. **QUICK_START.md** (5 minutes)
Fastest way to get AndeChain running. Perfect for initial setup and quick deployments.

**Covers:**
- Prerequisites checklist
- Automated deployment option
- Manual deployment option
- Testing and verification
- Common operations

**Use when:** You want to deploy immediately without deep configuration details.

---

### 2. **TESTNET_DEPLOYMENT_GUIDE.md** (30-45 minutes)
Complete step-by-step deployment guide with detailed explanations of each phase.

**Covers:**
- Phase 1: Prerequisites and environment setup
- Phase 2: Repository configuration and submodules
- Phase 3: Docker container builds
- Phase 4: Service orchestration
- Phase 5: Chain initialization and first blocks
- Phase 6: Verification and testing
- Phase 7: Monitoring and operations
- Phase 8: Troubleshooting and optimization

**Use when:** You need to understand the full deployment process or troubleshoot issues.

---

### 3. **TESTNET_READINESS_CHECKLIST.md** (15 minutes)
Critical checklist before production deployment.

**Covers:**
- Blocking issues (must fix before deployment)
- High-priority issues (should fix)
- Medium-priority optimizations (nice to have)
- Infrastructure requirements
- Security considerations
- Performance targets

**Use when:** Validating your deployment is production-ready.

---

## Automated Deployment

The `scripts/quick-testnet-deploy.sh` script automates the entire deployment process:

```bash
cd /path/to/ande
chmod +x scripts/quick-testnet-deploy.sh
./scripts/quick-testnet-deploy.sh
```

**Available options:**
- `--clean`: Remove all persistent data and start fresh
- `--skip-build`: Skip Docker image building
- `--dev`: Start in development mode
- `--check-only`: Run preflight checks without deploying

---

## Deployment on Another PC

### Requirements
- Docker and Docker Compose (latest versions)
- 4+ GB RAM
- 20GB+ disk space
- Git with submodule support

### Steps

1. **Clone the repository with submodules:**
   ```bash
   git clone --recurse-submodules https://github.com/AndeLabs/ande.git
   cd ande
   ```

2. **Follow QUICK_START.md** for fastest deployment

3. **Or follow TESTNET_DEPLOYMENT_GUIDE.md** for detailed setup

---

## Troubleshooting

See **TESTNET_DEPLOYMENT_GUIDE.md** troubleshooting section for common issues and solutions.

## Support

For detailed architecture information, see `docs/reference/REPOSITORIES_GUIDE.md`.
