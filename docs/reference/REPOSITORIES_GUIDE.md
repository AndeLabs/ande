# 📦 AndeChain Repositories Guide

**Managing Two Separate GitHub Repositories**

---

## Repository Structure

### Repository 1: AndeLabs/ande (Main)
**URL**: https://github.com/AndeLabs/ande  
**Purpose**: Main AndeChain repository (contracts, infrastructure, frontend)  
**Languages**: Solidity, TypeScript, Shell scripts  

**Contains:**
```
ande/
├── andechain/
│   ├── contracts/          # Smart contracts (Solidity)
│   │   ├── src/           # ANDEToken, Governance, etc.
│   │   ├── script/        # Deployment scripts
│   │   └── foundry.toml
│   ├── infra/
│   │   └── stacks/        # Docker Compose configurations
│   │       ├── single-sequencer/
│   │       ├── eth-explorer/
│   │       └── eth-faucet/
│   └── scripts/           # Deployment automation
├── andefrontend/          # Next.js dApp frontend
├── docker-compose.yml     # Main testnet stack
├── genesis.json          # Chain configuration
└── .gitignore
```

**Key Files:**
- `docker-compose.yml` - Main production testnet stack
- `genesis.json` - Chain genesis configuration
- `andechain/contracts/` - All smart contracts
- `andechain/scripts/` - Deployment scripts
- `scripts/quick-testnet-deploy.sh` - Automated deployment

---

### Repository 2: AndeLabs/ande-reth (Custom Execution Client)
**URL**: https://github.com/AndeLabs/ande-reth  
**Purpose**: Custom Reth fork with ANDE-specific features  
**Language**: Rust  

**Contains:**
```
ande-reth/
├── crates/
│   ├── reth/             # Core Reth implementation
│   ├── evolve/           # ANDE-specific modules
│   │   ├── src/
│   │   │   ├── evm_config/      # ANDE precompile (0xFD)
│   │   │   ├── parallel/        # Parallel execution
│   │   │   └── ...
│   │   ├── PARALLEL_SECURITY.md # Security analysis
│   │   └── Cargo.toml
│   └── tests/            # Integration tests
├── Dockerfile           # Build image for ev-reth
├── Cargo.toml          # Rust workspace
├── CHANGELOG.md        # Version history
└── README.md           # Documentation
```

**Key Features:**
- ANDE Token Duality precompile (0xFD)
- Parallel EVM execution engine
- EVOLVE sequencer integration
- Custom payload builder

---

## Version Control Strategy

### Versioning Scheme

**Format**: `MAJOR.MINOR.PATCH-STAGE`

**Example**: `1.0.0-beta` or `1.2.3-rc1`

#### Main Repository (ande)
```
1.0.0-beta       = Beta testnet phase
1.0.0-rc1        = Release candidate
1.0.0            = Mainnet ready
1.1.0            = Minor feature release
2.0.0            = Major breaking changes
```

#### ande-reth Repository
```
ev-reth-1.0.0-ande-beta      = Beta with ANDE features
ev-reth-1.0.0-ande-rc1       = Release candidate
ev-reth-1.0.0-ande           = Production version
```

---

## Dependency Management

### ande-reth is a Dependency of ande

```
ande (main)
  └── docker-compose.yml
      └── build: ./ev-reth/Dockerfile
          └── Pulls from: github.com/AndeLabs/ande-reth
```

### Version Pinning

#### In docker-compose.yml
```yaml
# Option 1: Use tag from ande-reth releases
ev-reth:
  image: ghcr.io/andelabs/ande-reth:v1.0.0-ande-beta
  
# Option 2: Build from local submodule
ev-reth:
  build:
    context: ./ev-reth
    dockerfile: Dockerfile
    args:
      FEATURES: "jemalloc asm-keccak"

# Option 3: Build from GitHub
ev-reth:
  build:
    context: https://github.com/AndeLabs/ande-reth.git#main
    dockerfile: Dockerfile
```

---

## Repository Setup Instructions

### For Fresh Installation

#### Step 1: Clone Main Repository
```bash
git clone https://github.com/AndeLabs/ande.git ande-labs
cd ande-labs
```

#### Step 2: Add ande-reth as Submodule (Recommended)
```bash
# Add ande-reth as submodule
git submodule add https://github.com/AndeLabs/ande-reth.git ev-reth

# Initialize submodule
git submodule init
git submodule update --recursive
```

#### Step 3: Verify Setup
```bash
# Check submodule status
git submodule status
# Output: [hash] ev-reth (HEAD detached at [hash])

# Verify directory structure
ls -la
# Should show ev-reth/ directory

# Check ev-reth contents
ls ev-reth/
# Should show: crates/, Dockerfile, Cargo.toml, etc.
```

#### Step 4: Update Submodule Pinned Version
```bash
cd ev-reth
git checkout v1.0.0-ande-beta  # Pin to specific version
cd ..
git add ev-reth
git commit -m "Update ev-reth to v1.0.0-ande-beta"
```

---

## Working with Both Repositories

### Scenario 1: Update ande-reth, Test in ande

```bash
# 1. Update ande-reth (in separate checkout)
cd ~/dev/ande-reth
git pull origin main
git checkout -b feature/new-feature
# ... make changes ...
git commit -am "Add new feature"
git push origin feature/new-feature
# ... create PR ...

# 2. Update submodule in ande to test
cd ~/dev/ande-labs
git submodule update --remote  # Get latest from ande-reth
# OR pin to specific commit:
cd ev-reth
git checkout [commit-hash]
cd ..
git add ev-reth
git commit -m "Test ande-reth feature branch"

# 3. Test with docker-compose
docker compose build --no-cache ev-reth
docker compose up -d

# 4. If tests pass, merge PR in ande-reth
# Then update submodule to released version in ande

# 5. Update submodule back to stable
cd ev-reth
git checkout v1.0.0-ande-beta
cd ..
git add ev-reth
git commit -m "Revert to stable ande-reth v1.0.0-ande-beta"
```

### Scenario 2: Fix Bug in ande-reth

```bash
# 1. Create feature branch in ande-reth repo
cd ~/dev/ande-reth
git checkout -b fix/precompile-issue
# ... fix code ...
cargo test
cargo build --release
git commit -am "Fix precompile caller validation"
git push origin fix/precompile-issue

# 2. Create release in ande-reth
git tag v1.0.1-ande-beta
git push origin v1.0.1-ande-beta

# 3. Update ande submodule
cd ~/dev/ande-labs
git submodule update --remote ev-reth
cd ev-reth
git checkout v1.0.1-ande-beta
cd ..
git add ev-reth
git commit -m "Update ande-reth to v1.0.1-ande-beta (fixes precompile issue)"
git push origin main
```

### Scenario 3: Release New Version

```bash
# 1. In ande-reth: Create release tag
cd ~/dev/ande-reth
git tag -a v1.0.0-ande -m "AndeChain testnet release"
git push origin v1.0.0-ande

# 2. Create GitHub Release on ande-reth
# - Go to https://github.com/AndeLabs/ande-reth/releases
# - Create release from tag v1.0.0-ande
# - Add release notes

# 3. In ande: Update submodule reference
cd ~/dev/ande-labs
git submodule update --remote ev-reth
cd ev-reth
git checkout v1.0.0-ande
cd ..

# 4. Update docker-compose.yml with image tag
# Change: ghcr.io/andelabs/ande-reth:latest
# To: ghcr.io/andelabs/ande-reth:v1.0.0-ande

# 5. Create release in ande
git add ev-reth docker-compose.yml
git commit -m "Release v1.0.0-ande testnet"
git tag -a v1.0.0-ande-testnet -m "AndeChain testnet v1.0.0"
git push origin main v1.0.0-ande-testnet

# 6. Create GitHub Release on ande
# - Go to https://github.com/AndeLabs/ande/releases
# - Create release from tag v1.0.0-ande-testnet
# - Include deployment instructions
```

---

## CI/CD Considerations

### GitHub Actions Workflow

#### For ande-reth Repository
```yaml
# .github/workflows/build-ev-reth.yml
name: Build ev-reth

on:
  push:
    branches: [main]
    tags: ['v*-ande*']
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker image
        run: |
          docker build -t ghcr.io/andelabs/ande-reth:${{ github.ref_name }} .
      
      - name: Test build
        run: cargo test --release
      
      - name: Push image (on release)
        if: startsWith(github.ref, 'refs/tags/v')
        run: |
          docker push ghcr.io/andelabs/ande-reth:${{ github.ref_name }}
```

#### For ande Repository (depends on ande-reth)
```yaml
# .github/workflows/test-deployment.yml
name: Test Deployment

on:
  push:
    branches: [main]
    paths:
      - 'docker-compose.yml'
      - 'genesis.json'
      - 'andechain/**'
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: true
      
      - name: Build images
        run: docker compose build
      
      - name: Start services
        run: docker compose up -d
      
      - name: Health check
        run: |
          sleep 30
          ./scripts/quick-testnet-deploy.sh --check-only
      
      - name: Run tests
        run: |
          # Test RPC
          curl -X POST http://localhost:8545 ...
          # Test transactions
          # etc.
```

---

## Documentation Synchronization

### When ande-reth Changes

1. **Update ande-reth README**
   - Document any breaking changes
   - Update feature list
   - Add migration guide if needed

2. **Update ande documentation**
   - Add notes about ande-reth version requirement
   - Document new features from ande-reth
   - Update PRODUCTION_STATUS_REPORT.md

3. **Update Version File**
   ```bash
   # Create ande/VERSIONS.md
   cat > VERSIONS.md << 'EOF'
   # AndeChain Versions
   
   ## Current Versions
   - ande: v1.0.0-ande-testnet
   - ande-reth: v1.0.0-ande-beta
   
   ## Compatibility
   - ande v1.0.0 requires ande-reth >= v1.0.0-ande
   
   ## Changelog
   ...
   EOF
   ```

---

## Troubleshooting Multi-Repo Setup

### Issue: Submodule Not Initialized
```bash
# Solution 1: Initialize submodule
git submodule init
git submodule update --recursive

# Solution 2: Clone with submodules
git clone --recurse-submodules https://github.com/AndeLabs/ande.git
```

### Issue: Changes in ev-reth Not Appearing
```bash
# Solution: Update submodule reference
git submodule update --remote
cd ev-reth
git pull origin main  # or checkout specific tag
cd ..
git add ev-reth
git commit -m "Update ande-reth to latest"
```

### Issue: Building Wrong ev-reth Version
```bash
# Solution: Verify submodule version
cd ev-reth
git log --oneline -1
git describe --tags

# Update if needed
git checkout v1.0.0-ande-beta
cd ..
git add ev-reth
git commit -m "Pin ev-reth to v1.0.0-ande-beta"
```

### Issue: Docker Build Failing
```bash
# Solution 1: Rebuild with no cache
docker compose build --no-cache ev-reth

# Solution 2: Check Dockerfile path
ls ev-reth/Dockerfile

# Solution 3: Verify context
docker build -t ande/ev-reth:latest \
  -f ev-reth/Dockerfile \
  ev-reth/
```

---

## Version Compatibility Matrix

| ande Version | ande-reth Version | Status | Notes |
|--------------|------------------|--------|-------|
| 1.0.0-beta | v1.0.0-ande-beta | ✅ Stable | Current testnet |
| 1.0.0-rc1 | v1.0.0-ande-rc1 | ⏳ Coming | Release candidate |
| 1.0.0 | v1.0.0-ande | ⏳ Coming | Mainnet ready |
| 1.1.0 | v1.0.1-ande+ | ⏳ Coming | Next features |

---

## Release Checklist

### For ande-reth Release

- [ ] Create feature branch
- [ ] Make code changes
- [ ] Run all tests: `cargo test --all`
- [ ] Build release: `cargo build --release`
- [ ] Update CHANGELOG.md
- [ ] Update README.md if needed
- [ ] Create git tag: `git tag v1.x.x-ande-xyz`
- [ ] Push to GitHub: `git push origin v1.x.x-ande-xyz`
- [ ] Create GitHub Release
- [ ] Build and push Docker image
- [ ] Notify ande team to update submodule

### For ande Release

- [ ] Update submodule to latest stable ande-reth
- [ ] Verify docker-compose.yml references correct ande-reth version
- [ ] Update TESTNET_DEPLOYMENT_GUIDE.md with version info
- [ ] Update VERSIONS.md
- [ ] Run full deployment test
- [ ] Update all documentation
- [ ] Create git tag: `git tag v1.x.x-ande-testnet`
- [ ] Push to GitHub
- [ ] Create GitHub Release with deployment guide
- [ ] Update docker images on GHCR

---

## Best Practices

### For Development Teams

1. **Always Pin Versions in docker-compose.yml**
   ```yaml
   # ❌ Bad - Always pulls latest
   image: ghcr.io/andelabs/ande-reth:latest
   
   # ✅ Good - Pin to specific version
   image: ghcr.io/andelabs/ande-reth:v1.0.0-ande-beta
   ```

2. **Keep Submodule Updated in Main Branch**
   ```bash
   # Before merging to main
   git submodule update --remote
   git add ev-reth
   git commit -m "Update submodule"
   ```

3. **Document Changes Across Repos**
   - If ande-reth changes, document in ande
   - If ande changes, note if ande-reth compatibility affected
   - Keep VERSIONS.md up to date

4. **Test Integration Before Release**
   ```bash
   # In ande repo with updated submodule
   docker compose up -d
   ./scripts/quick-testnet-deploy.sh --check-only
   # Verify all tests pass
   ```

5. **Use Semantic Versioning**
   - MAJOR: Breaking changes
   - MINOR: New features (backward compatible)
   - PATCH: Bug fixes

---

## Migration Guide: From Single to Dual Repo

If you previously had everything in one repo:

```bash
# 1. Create new ande-reth repo with ev-reth code
git clone https://github.com/AndeLabs/ande.git temp
cd temp
git subtree split --prefix=ev-reth -b ev-reth-branch
# Push to new ande-reth repo

# 2. In ande repo, remove ev-reth directory
git rm -r ev-reth

# 3. Add as submodule
git submodule add https://github.com/AndeLabs/ande-reth.git ev-reth

# 4. Update docker-compose.yml paths if needed
# (Paths should still work: ./ev-reth/Dockerfile)

# 5. Commit
git commit -am "Split ev-reth to separate repository"
```

---

## Summary

**Key Points:**

1. ✅ **Two repositories**: ande (main) and ande-reth (execution client)
2. ✅ **Submodule usage**: ande-reth as git submodule in ande
3. ✅ **Version pinning**: Always pin specific versions in docker-compose.yml
4. ✅ **Documentation**: Keep VERSIONS.md and README.md in sync
5. ✅ **CI/CD**: Each repo has own workflows, tested independently
6. ✅ **Releases**: Coordinate releases between repos
7. ✅ **Testing**: Test integration after any submodule update

**Next Steps:**

1. Add git submodules if not already present
2. Create VERSIONS.md tracking file
3. Set up GitHub Actions workflows
4. Document all version dependencies
5. Train team on multi-repo workflow

---

**Version**: 1.0  
**Date**: 2025-10-28  
**Status**: Complete
