# 🏔️ ANDE Chain - Sovereign EVM Rollup

<div align="center">

**Low-Cost, High-Speed Blockchain Infrastructure for Latin America**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.25-blue.svg)](https://soliditylang.org/)
[![Rust](https://img.shields.io/badge/Rust-ev--reth-orange.svg)](https://www.rust-lang.org/)
[![Celestia](https://img.shields.io/badge/DA-Celestia-purple.svg)](https://celestia.org/)

[Website](https://andechain.com) • [Documentation](#-documentation) • [Discord](https://discord.gg/andechain) • [Twitter](https://twitter.com/andechain)

</div>

---

## 🎯 What is ANDE Chain?

ANDE Chain is a **Sovereign EVM Rollup** using Celestia for Data Availability. We're building financial infrastructure for Latin America with:

- 🚀 **100-500+ TPS** - Parallel EVM execution
- ⚡ **~2s block time** - Fast finality
- 💰 **Ultra-low fees** - Celestia DA reduces costs by 90%+
- 🔧 **Full sovereignty** - Independent consensus, no L1 settlement
- 🛠️ **EVM Compatible** - Deploy Solidity contracts unchanged

### 🏗️ Decentralized Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Celestia Mocha-4 Testnet                 │
│                   (Data Availability Layer)                │
└─────────────────────┬───────────────────────────────────────┘
                      │ DA Submissions
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                 AndeChain P2P Network                      │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │  Sequencer  │◄──►│ Full Node 1 │◄──►│ Full Node 2 │◄─►│
│  │ (Producer)  │    │ (Validator) │    │ (Validator) │     │
│  │  Port: 7676 │    │ Port: 7677  │    │ Port: 7678  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                   AndeChain Stack                         │
│  📱 dApps & Wallets (EVM Compatible)                     │
│         ↓                                                │
│  🚀 ev-reth (Modified Reth)                              │
│     • EVM Execution Layer                                │
│     • ANDE Precompile (0x...FD)                         │
│     • Parallel Transaction Processing                    │
│         ↓                                                │
│  🔄 Evolve Sequencer (ExRollkit)                         │
│     • Block Production & Consensus                       │
│         ↓                                                │
│  📊 Celestia DA                                          │
│     • Data Availability Layer                            │
│     • Mocha-4 (testnet)                                  │
│         ↓                                                │
│  🔍 Blockscout Explorer                                  │
└─────────────────────────────────────────────────────────────┘
```

**Key Features:**
- 🌐 **Multi-node P2P network** - Decentralized architecture
- 🔄 **Auto-discovery** - Nodes connect automatically
- ⚡ **Parallel EVM** - High-throughput transaction processing
- 🛡️ **Full sovereignty** - Independent consensus using Celestia DA

---

## ⚡ Quick Start

### One-Command Setup

```bash
# Clone and setup
git clone https://github.com/andelabs/andechain.git
cd andechain

# Deploy multi-node testnet (sequencer + 2 full nodes)
docker-compose up -d

# Wait 2-3 minutes for initialization
```

**That's it!** Your decentralized ANDE Chain testnet is running. 🎉

**Available at:**
- 🌐 **Sequencer RPC**: `http://localhost:8545`
- 🌐 **Full Node 1 RPC**: `http://localhost:8547`
- 🌐 **Full Node 2 RPC**: `http://localhost:8549`
- 🔍 **Explorer**: `http://localhost:4000`
- 📊 **Grafana**: `http://localhost:3000`
- 🌐 **Celestia DA**: `http://localhost:26658`

### Next Steps

```bash
# Check system health
make health

# Run tests
make test-all

# Deploy to testnet (requires Celestia Mocha-4 setup)
make deploy-testnet
```

---

## 📚 Documentation

### 🚀 Deployment & Quick Start

**New to ANDE Chain?** Start here for testnet deployment:

| Document | Time | Description |
|----------|------|-------------|
| **[Quick Start](docs/deployment/QUICK_START.md)** | 5 min | Deploy ANDE Chain in 5 minutes |
| **[Deployment Guide](docs/deployment/TESTNET_DEPLOYMENT_GUIDE.md)** | 30 min | Complete step-by-step deployment with explanations |
| **[Readiness Checklist](docs/deployment/TESTNET_READINESS_CHECKLIST.md)** | 15 min | Production readiness verification |
| **[Deployment Scripts](scripts/quick-testnet-deploy.sh)** | Auto | Fully automated one-command deployment |

### 📖 Architecture & Reference

| Document | Description |
|----------|-------------|
| **[Repositories Guide](docs/reference/REPOSITORIES_GUIDE.md)** | Multi-repository structure and management |
| **[Version Compatibility](docs/reference/VERSIONS.md)** | Component versions and compatibility matrix |
| **[Documentation Index](docs/reference/DOCUMENTATION_INDEX.md)** | Master index of all documentation |

### 🔧 Operations & Monitoring

| Document | Description |
|----------|-------------|
| **[Executive Summary](docs/operations/EXECUTIVE_SUMMARY.md)** | System overview and readiness status |
| **[Production Status](docs/operations/PRODUCTION_STATUS.md)** | Current component health and metrics |
| **[Production Ready](docs/operations/PRODUCTION_READY.md)** | Comprehensive production readiness checklist |
| **[Docker Specification](docs/operations/DOCKER_PRODUCTION_SPEC.md)** | Container configuration and requirements |

### 🛠️ Development

| Document | Description |
|----------|-------------|
| **[Contributing](CONTRIBUTING.md)** | How to contribute to ANDE Chain |
| **[Security](SECURITY.md)** | Security best practices |

### 🌐 Smart Contracts

| Document | Description |
|----------|-------------|
| **[Contract Deployment](contracts/README.md)** | Deploy and verify smart contracts |

---

## 🔧 Technology Stack

### Core Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Execution Layer** | [ev-reth](../ev-reth/) (Modified Reth) | EVM execution, parallel processing |
| **Consensus** | Evolve Sequencer (ExRollkit) | Block production & ordering |
| **Data Availability** | [Celestia](https://celestia.org) | DA layer (Mocha-4/Mainnet) |
| **Explorer** | [Blockscout](https://blockscout.com) | Self-hosted block explorer |
| **Smart Contracts** | Solidity 0.8.25 | Token, Staking, Governance |

### Custom Features

- 🎯 **ANDE Precompile** (`0x00000000000000000000000000000000000000FD`)
  - Native token transfers for Token Duality
  - Direct balance manipulation in EVM
  
- ⚡ **Parallel EVM**
  - Multi-version memory
  - Concurrent transaction execution
  - 3-5x TPS improvement

- 🎮 **MEV Protection**
  - MEV detection & fair distribution
  - Searcher integration

---

## 📦 Repository Structure

```
andechain/
├── contracts/          # Smart contracts (Foundry)
│   ├── src/           # Contract source code
│   ├── script/        # Deployment scripts
│   └── test/          # Contract tests
│
├── infra/             # Infrastructure (Docker)
│   └── stacks/
│       └── single-sequencer/  # Main stack
│
├── ev-reth/           # Modified Reth (see ../ev-reth/)
│   └── crates/evolve/ # ANDE customizations
│
├── docs/              # Additional documentation
│
└── Makefile           # Production commands
```

---

## 🚀 Key Commands

### Development

```bash
make deploy-local          # Complete local deployment
make start-local          # Start infrastructure only
make test-all             # Run all tests
make security-audit       # Security analysis
make clean                # Clean artifacts
```

### Deployment

```bash
make deploy-testnet       # Deploy to testnet (Celestia Mocha-4)
make deploy-mainnet       # Deploy to mainnet (requires validation)
make verify ENV=testnet   # Verify contracts on Blockscout
```

### Monitoring

```bash
make health               # System health check
make celestia-status      # Check Celestia DA status
make logs                 # View all logs
make monitor-start        # Start Grafana monitoring
```

**See all commands:** `make help`

---

## 🌍 Networks

### Local Development

- **Chain ID:** 1234
- **RPC:** http://localhost:8545
- **Explorer:** http://localhost:4000
- **DA:** Mock/Local Celestia

### Testnet

- **Chain ID:** 1234
- **RPC:** https://testnet-rpc.andechain.com (coming soon)
- **Explorer:** https://testnet-explorer.andechain.com (coming soon)
- **DA:** Celestia Mocha-4

### Mainnet

- **Status:** Coming Soon
- **DA:** Celestia Mainnet

---

## 🔐 Security

ANDE Chain is built with security as a priority:

- ✅ Audited smart contracts
- ✅ Bug bounty program (coming soon)
- ✅ Encrypted keystore system (no raw private keys)
- ✅ Circuit breakers for emergency stops
- ✅ Multi-signature wallet support

**Report vulnerabilities:** security@andelabs.io

---

## 🤝 Contributing

We welcome contributions! Before starting:

1. Read [CONTRIBUTING.md](CONTRIBUTING.md)
2. Check [open issues](https://github.com/andelabs/andechain/issues)
3. Join our [Discord](https://discord.gg/andechain)

### Development Process

```bash
# 1. Fork & clone
git clone https://github.com/YOUR_USERNAME/andechain.git

# 2. Create branch
git checkout -b feature/amazing-feature

# 3. Make changes & test
make test-all

# 4. Commit (use conventional commits)
git commit -m "feat: add amazing feature"

# 5. Push & create PR
git push origin feature/amazing-feature
```

---

## 🎓 Learn More

### Technical Documentation

- 📖 [Architecture Deep Dive](ARCHITECTURE.md)
- 🔧 [Smart Contract Documentation](contracts/README.md)
- 🌐 [Celestia Integration](CELESTIA_SETUP.md)

### External Resources

- [Celestia Documentation](https://docs.celestia.org/)
- [Reth Book](https://paradigmxyz.github.io/reth/)
- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity Documentation](https://docs.soliditylang.org/)

---

## 🌟 Features Roadmap

### Phase 1: MVP (Current)
- ✅ EVM execution (ev-reth)
- ✅ Celestia DA integration
- ✅ Basic smart contracts (Token, Staking)
- ✅ Blockscout explorer
- ✅ Parallel EVM execution

### Phase 2: Decentralization
- ⏳ Decentralized sequencer set
- ⏳ On-chain governance (AndeGovernor)
- ⏳ Sequencer registry & slashing
- ⏳ Native account abstraction

### Phase 3: DeFi Ecosystem
- ⏳ DEX (Uniswap V3 fork)
- ⏳ Lending protocol
- ⏳ Stablecoin (CDP system)
- ⏳ Cross-chain bridges

### Phase 4: Ecosystem Growth
- ⏳ Developer grants program
- ⏳ Ecosystem fund
- ⏳ Regional expansion

---

## 💬 Community

Join our growing community:

- 💬 **Discord:** [discord.gg/andechain](https://discord.gg/andechain)
- 🐦 **Twitter:** [@AndeChain](https://twitter.com/andechain)
- 📰 **Blog:** [blog.andelabs.io](https://blog.andelabs.io)
- 📧 **Email:** hello@andelabs.io

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

Built with amazing open-source tools:

- [Reth](https://github.com/paradigmxyz/reth) by Paradigm
- [Celestia](https://celestia.org) for Data Availability
- [Foundry](https://getfoundry.sh) by Paradigm
- [Blockscout](https://blockscout.com) for Explorer
- [ExRollkit](https://github.com/evstack) by Evølve

Special thanks to all contributors and the Latin American blockchain community.

---

<div align="center">

**🏔️ Building Sovereign Financial Infrastructure for Latin America**

[Get Started](INSTALL.md) • [Architecture](ARCHITECTURE.md) • [Community](https://discord.gg/andechain)

Made with ❤️ by [ANDE Labs](https://andelabs.io)

</div>