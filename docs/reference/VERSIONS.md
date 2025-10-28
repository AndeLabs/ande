# 📦 AndeChain Version Control

**Current Version Status & Compatibility Matrix**

---

## Current Release Versions

### ande (Main Repository)
**Repository**: https://github.com/AndeLabs/ande  
**Current Version**: `v1.0.0-beta`  
**Release Date**: 2025-10-28  
**Status**: ✅ Testnet Ready

**Includes:**
- ✅ Smart contracts (Solidity)
- ✅ Deployment scripts
- ✅ Docker Compose configurations
- ✅ Block explorer setup (Blockscout)
- ✅ Faucet service
- ✅ dApp frontend (React)
- ✅ Infrastructure & monitoring

---

### ande-reth (Execution Client)
**Repository**: https://github.com/AndeLabs/ande-reth  
**Current Version**: `v1.0.0-ande-beta`  
**Release Date**: 2025-10-28  
**Status**: ✅ Testnet Ready

**Features:**
- ✅ Custom Reth fork (based on reth v0.3.x)
- ✅ ANDE Token Duality precompile (0xFD)
- ✅ Parallel EVM execution engine
- ✅ EVOLVE sequencer integration
- ✅ Custom payload builder
- ✅ Production-optimized build

---

## Version Compatibility

### Recommended Combinations

```
╔════════════════════════════════════════════════════════════════════╗
║ ande Version  │ ande-reth Version │ Status    │ Use Case          ║
╠════════════════════════════════════════════════════════════════════╣
║ v1.0.0-beta   │ v1.0.0-ande-beta  │ ✅ Stable │ Current Testnet   ║
║ v1.0.0-rc1    │ v1.0.0-ande-rc1   │ ⏳ Coming │ Release Candidate ║
║ v1.0.0        │ v1.0.0-ande       │ ⏳ Coming │ Mainnet Ready     ║
║ v1.1.0        │ v1.0.1-ande+      │ ⏳ Coming │ Next Release      ║
╚════════════════════════════════════════════════════════════════════╝
```

### Compatibility Rules

- ✅ ande v1.0.0-beta requires ande-reth >= v1.0.0-ande-beta
- ✅ ande-reth v1.0.0-ande-beta requires no specific ande version
- ⚠️ Always pin specific versions (never use "latest" in production)
- ⚠️ Test integration before upgrading either component

---

## Version History

### ande Repository

#### v1.0.0-beta (2025-10-28) - CURRENT
**Status**: ✅ Testnet Ready

**New in this version:**
- ✅ Complete deployment automation
- ✅ Blockscout v9.0.2 integration
- ✅ Multi-environment support
- ✅ Smart contract compilation fixes
- ✅ Documentation complete (6 guides)
- ✅ Faucet service operational
- ✅ Health check automation

**Known Issues:**
- ⚠️ Celestia DA auth token needs configuration
- ⚠️ Some smart contracts need Slither fixes
- ⚠️ Precompile caller validation not yet implemented

**Migration from previous:**
- First public release
- No upgrades needed

---

### ande-reth Repository

#### v1.0.0-ande-beta (2025-10-28) - CURRENT
**Status**: ✅ Testnet Ready  
**Based on**: Reth v0.3.x

**Features:**
- ✅ ANDE Token Duality precompile at 0xFD
- ✅ Parallel transaction execution engine
- ✅ EVOLVE consensus integration
- ✅ Custom payload builder
- ✅ Production security features
- ✅ Optimized for sovereign rollup

**Tested On:**
- ✅ Ubuntu 22.04 LTS
- ✅ macOS (Intel & Apple Silicon)
- ✅ Docker (Linux & Desktop)

**Known Issues:**
- ⚠️ Caller validation in precompile disabled (TODO)
- ⚠️ Some edge cases in parallel execution under investigation

**Performance Characteristics:**
- Block time: ~30 seconds (lazy mode)
- RPC latency: < 100ms
- Memory usage: 200-500MB
- CPU usage: 2-4 cores

---

## Dependency Graph

```
ande (main)
├── DEPENDS ON:
│   └── ande-reth (git submodule at ev-reth/)
│
├── Also uses:
│   ├── Docker (build infrastructure)
│   ├── PostgreSQL (explorer database)
│   ├── Redis (cache)
│   ├── Blockscout v9.0.2 (explorer)
│   └── Celestia v0.27.5 (data availability)
│
└── Generates:
    ├── Smart contracts (compiled to bytecode)
    ├── Docker images
    ├── Block explorer
    └── Token faucet
```

---

## Breaking Changes by Version

### v1.0.0-beta (2025-10-28)
**First release** - No previous versions to migrate from

**If upgrading from earlier development:**
- 🔄 Blockscout explorer database schema may differ
- 🔄 Smart contract ABIs have been updated
- 🔄 Docker Compose file structure changed
- 🔄 Environment variables may need updates

**Migration steps:**
```bash
# 1. Backup old data
docker compose down -v

# 2. Remove old volumes
docker volume prune -f

# 3. Pull new version
git pull origin main

# 4. Update submodule
git submodule update --remote

# 5. Redeploy
docker compose up -d
```

---

## Planned Releases

### v1.0.0-rc1 (PLANNED)
**Target**: Q4 2025

**Planned changes:**
- [ ] Fix all Slither security findings
- [ ] Implement precompile caller validation
- [ ] Add multi-sig wallet support
- [ ] Integrate governance timelock
- [ ] Complete security audit
- [ ] Performance optimization

---

### v1.0.0 (PLANNED)
**Target**: Q1 2026

**Planned changes:**
- [ ] Remove "beta" designation
- [ ] Final security audit passed
- [ ] Full documentation
- [ ] Mainnet configuration
- [ ] Long-term support commitment

---

## Version Pinning Examples

### docker-compose.yml

```yaml
# CORRECT: Pin to specific version
services:
  ev-reth:
    image: ghcr.io/andelabs/ande-reth:v1.0.0-ande-beta
    build:
      context: ./ev-reth
      dockerfile: Dockerfile
      args:
        VERSION: v1.0.0-ande-beta
```

### .env

```bash
# Pin versions for reproducibility
ANDE_VERSION=v1.0.0-beta
ANDE_RETH_VERSION=v1.0.0-ande-beta
EVM_RETH_VERSION=0.3.x
BLOCKSCOUT_VERSION=9.0.2
CELESTIA_VERSION=0.27.5
```

### Git Submodule

```bash
# Pin ev-reth to specific version
cd ev-reth
git checkout v1.0.0-ande-beta
cd ..
git add ev-reth
git commit -m "Pin ev-reth to v1.0.0-ande-beta"
```

---

## Version Support Matrix

| Version | Release | Type | Support Until | Status |
|---------|---------|------|---------------|--------|
| v1.0.0-beta | 2025-10-28 | Beta | TBD | ✅ Active |
| v1.0.0-rc1 | Planned | RC | TBD | ⏳ Planned |
| v1.0.0 | Planned | Stable | 2027-10-28 | ⏳ Planned |

---

## Checking Current Versions

### In ande Repository

```bash
# Check main repo version
cat VERSIONS.md | grep "Current Release Versions" -A 10

# Check ande-reth submodule version
cd ev-reth
git describe --tags
git log --oneline -1

# Check from git tags
git tag | grep ande
```

### In ande-reth Repository

```bash
# Check version
git describe --tags
git log --oneline -1

# Check Cargo.toml version
grep '^version' Cargo.toml
```

### Running Services

```bash
# Check ev-reth version from running container
docker exec ande-ev-reth ev-reth --version

# Check ande frontend version
docker logs ande-frontend | grep -i version
```

---

## Upgrade Procedures

### Minor Version Upgrade (e.g., 1.0.0 → 1.1.0)

```bash
# 1. Backup current state
docker compose down
tar -czf backup-$(date +%s).tar.gz ~/.ande-data/

# 2. Update code
git pull origin main
git submodule update --remote

# 3. Check compatibility
grep "requires.*>=" TESTNET_READINESS_CHECKLIST.md

# 4. Rebuild images
docker compose build --no-cache

# 5. Start services
docker compose up -d

# 6. Verify health
./scripts/quick-testnet-deploy.sh --check-only
```

### Major Version Upgrade (e.g., 1.0.0 → 2.0.0)

```bash
# 1. Read migration guide
cat MIGRATIONS/v1-to-v2.md

# 2. Backup everything
docker compose down -v
tar -czf backup-major-$(date +%s).tar.gz ~/.ande-data/

# 3. Update code and docs
git pull origin main
git checkout v2.0.0

# 4. Check breaking changes
cat MIGRATIONS/v1-to-v2.md

# 5. Apply migrations
# (Follow migration guide for your specific changes)

# 6. Rebuild from scratch
docker system prune -a
docker compose build --no-cache

# 7. Start and test
docker compose up -d
sleep 60
./scripts/quick-testnet-deploy.sh --check-only
```

---

## Security Updates

### Critical Security Issues

If a critical security issue is discovered:

1. **Immediate Response** (within 24 hours)
   - Create patch release (e.g., v1.0.1)
   - Push to GitHub
   - Notify users

2. **Deployment** (ASAP)
   ```bash
   git pull origin main
   git checkout [security-patch-tag]
   docker compose up -d --build
   ```

3. **Documentation**
   - Update SECURITY.md
   - Add to VERSIONS.md
   - Post security advisory

---

## Version Changelog Template

### For Each Release

```markdown
## v1.x.x (DATE)

### New Features
- ✅ Feature 1
- ✅ Feature 2

### Bug Fixes
- 🐛 Fix 1
- 🐛 Fix 2

### Breaking Changes
- ⚠️ Change 1
- ⚠️ Change 2

### Dependencies
- ✅ ande-reth >= v1.x.x
- ✅ Blockscout >= 9.0.0

### Migration Guide
- Step 1
- Step 2

### Known Issues
- ⚠️ Issue 1
- ⚠️ Issue 2
```

---

## Version Lookup

### Find What You're Running

```bash
# Check docker-compose.yml pinned versions
grep "image:" docker-compose.yml | grep -v "^#"

# Check .env versions
grep VERSION .env

# Check git tags in ande repo
git describe --tags

# Check ande-reth submodule
cd ev-reth && git describe --tags && cd ..

# Check running container versions
docker compose exec ande-ev-reth ev-reth --version
```

---

## Support & Issues

### Where to Report Issues

- **ande issues**: https://github.com/AndeLabs/ande/issues
- **ande-reth issues**: https://github.com/AndeLabs/ande-reth/issues
- **Both repos**: Cross-link issues between repos

### Include Version Info in Issues

```markdown
**Version Information:**
- ande: v1.0.0-beta
- ande-reth: v1.0.0-ande-beta
- Docker: 25.0.0
- OS: Ubuntu 22.04

**Steps to reproduce:**
1. ...
2. ...
```

---

## Summary

**Current Status:**
- ✅ ande v1.0.0-beta (Testnet Ready)
- ✅ ande-reth v1.0.0-ande-beta (Testnet Ready)
- ✅ Both versions compatible and tested together
- ✅ Deployment scripts working correctly
- ✅ Full documentation provided

**Key Rules:**
1. Always pin specific versions
2. Never use "latest" in production
3. Test after any version update
4. Keep both repos in sync
5. Document version dependencies

**Next Steps:**
1. Tag both repositories with current versions
2. Set up GitHub Actions for automated testing
3. Create release notes
4. Announce to users
5. Monitor for issues

---

**Document Version**: 1.0  
**Last Updated**: 2025-10-28  
**Next Review**: 2025-11-28
