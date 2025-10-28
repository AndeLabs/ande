# Reference Documentation

Technical reference materials for AndeChain architecture and version management.

## Documents

### 1. **REPOSITORIES_GUIDE.md**
Complete guide to the AndeChain repository structure and multi-repository management.

**Covers:**
- Repository 1: AndeLabs/ande (main repository)
  - Smart contracts (Solidity)
  - Infrastructure (Docker, Kubernetes)
  - Frontend (Next.js dApp)
  - Deployment scripts
  
- Repository 2: AndeLabs/ande-reth (execution client)
  - Custom Reth fork for ANDE
  - EVOLVE sequencer integration
  - Parallel EVM execution
  - Token duality precompile

- Version control strategy
  - Versioning scheme (MAJOR.MINOR.PATCH-STAGE)
  - Semantic versioning for both repositories
  - Git submodule management

**Use for:** Understanding the codebase structure and managing multiple repositories.

---

### 2. **VERSIONS.md**
Version compatibility matrix and changelog for all components.

**Covers:**
- Current versions of all major components
- Compatibility matrix (which versions work together)
- Changelog for recent updates
- Breaking changes and migrations
- Upgrade procedures

**Use for:** Determining version compatibility and planning upgrades.

---

### 3. **DOCUMENTATION_INDEX.md**
Master index of all AndeChain documentation.

**Covers:**
- Quick navigation for all documents
- Use cases for each document
- Reading time estimates
- Document relationships and dependencies

**Use for:** Finding documentation on specific topics.

---

## Key Technical Concepts

### EVOLVE Sequencer
Modular rollup framework where the sequencer manages block building. Unlike traditional Reth, ev-reth does not manage block building directly—it receives built blocks from the EVOLVE sequencer via the Engine API.

### Token Duality
ANDE provides both:
- Native currency (balance in coin state)
- ERC-20 compatibility (via precompile at 0xFD)

This allows seamless interaction with both native transfers and EVM smart contracts.

### Celestia Integration
AndeChain uses Celestia for data availability on Mocha-4 testnet. DA submissions are handled by the sequencer and are non-blocking for block production.

### Parallel Execution
Custom transaction execution engine in ev-reth that enables parallel processing of independent transactions for improved throughput.

---

## Getting Started

1. Start with `REPOSITORIES_GUIDE.md` to understand the codebase structure
2. Review `VERSIONS.md` for current component versions
3. Use `DOCUMENTATION_INDEX.md` as a master reference
4. For deployment, see `docs/deployment/` directory

---

## Architecture Diagrams

### Block Production Flow
```
Sequencer (EVOLVE)
    ↓
Engine API (JSON-RPC)
    ↓
ev-reth (Execution Client)
    ↓
Chain State & Blocks
    ↓
RPC Endpoints (eth_*, web3_*)
```

### Repository Relationship
```
AndeLabs/ande (Main)
    ├── Submodule: ande-reth (Execution Client)
    ├── Contracts (Solidity)
    ├── Frontend (Next.js)
    └── Infrastructure (Docker, Kubernetes)
```

---

## Support

For deployment instructions, see `docs/deployment/` directory.
For operations and monitoring, see `docs/operations/` directory.
