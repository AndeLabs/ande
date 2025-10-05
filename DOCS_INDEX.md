# 📚 AndeChain Documentation Index

> **Central hub for all project documentation** - Navigate to the right resource for your needs

## 🚀 Getting Started

| Document | Purpose | Audience |
|----------|---------|----------|
| [README.md](README.md) | Project overview and quick introduction | Everyone |
| [QUICK_START.md](QUICK_START.md) | Step-by-step setup guide for local development | New developers |
| [ONBOARDING.md](ONBOARDING.md) | Comprehensive operations manual with role-based guides | Developers, DevOps, Auditors |

## 📖 Core Documentation

### Essential Project Files

| Document | Purpose | Update Frequency |
|----------|---------|------------------|
| [CHANGELOG.md](CHANGELOG.md) | Version history and release notes | Every release |
| [ROADMAP.md](ROADMAP.md) | Product vision and development milestones | Monthly |
| [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) | Community guidelines and expected behavior | Rarely |
| [SECURITY.md](SECURITY.md) | Security policy and vulnerability reporting | As needed |

### Development Workflows

| Document | Purpose | When to Use |
|----------|---------|-------------|
| [GIT_WORKFLOW.md](GIT_WORKFLOW.md) | Git branching strategy and commit conventions | Before every commit/PR |
| [HEALTH_CHECK.md](HEALTH_CHECK.md) | System verification commands and diagnostics | When debugging issues |

## 🏗️ Technical Specifications

| Document | Purpose | Audience |
|----------|---------|----------|
| [NATIVE_ANDE_MIGRATION.md](NATIVE_ANDE_MIGRATION.md) | Native ANDE token migration guide | Smart contract developers |
| [FAUCET.md](FAUCET.md) | Faucet service documentation and usage | Frontend developers, testers |

## 📁 Subdirectory Documentation

### Smart Contracts (`contracts/`)
- [contracts/README.md](contracts/README.md) - Foundry project setup and contract architecture
- `contracts/src/` - Individual contract documentation in source files

### Infrastructure (`infra/`)
- [infra/README.md](infra/README.md) - Docker rollup stack configuration

### Relayer (`relayer/`)
- [relayer/README.md](relayer/README.md) - Bridge relayer service setup

## 📊 Temporary Documentation (Not Tracked in Git)

These files are auto-generated or temporary and should **not** be committed:

### Reports
- `HEALTH_CHECK_REPORT.md` - System health audit output (regenerate with health check commands)
- `TEST_COVERAGE_FINAL_REPORT.md` - Test coverage analysis (regenerate with `forge coverage`)
- `TEST_COVERAGE_IMPROVEMENT.md` - Coverage improvement tracking (temporary)

### Integration Logs
- `BLOCKSCOUT_INTEGRATION.md` - BlockScout integration notes (archive after completion)
- `BLOCKSCOUT_FIX_SUMMARY.md` - BlockScout troubleshooting (archive after completion)

### Fix Tracking
- `FIXES_APPLIED.md` - Running log of fixes (can be archived or moved to issues)

## 🗂️ Documentation Strategy

### What Gets Tracked in Git?

✅ **Always Tracked:**
- Essential project documentation (README, CHANGELOG, etc.)
- Developer guides (ONBOARDING, QUICK_START)
- Technical specifications (NATIVE_ANDE_MIGRATION, FAUCET)
- Workflow documents (GIT_WORKFLOW, HEALTH_CHECK)
- Long-term planning (ROADMAP)
- All README.md files in subdirectories

❌ **Never Tracked (Ignored):**
- Auto-generated reports (`*_REPORT.md`)
- Temporary fix logs (`FIXES_APPLIED.md`)
- Integration notes (archive separately when complete)
- AI assistant files (`CLAUDE.md`, `GEMINI.md`)

### Document Lifecycle

1. **Active Development** → Keep in root directory
2. **Completed/Archived** → Move to `docs/archive/` or delete
3. **Reference Material** → Keep if broadly useful, otherwise archive

## 🔍 Quick Reference

### For New Developers
1. Start with [README.md](README.md)
2. Follow [QUICK_START.md](QUICK_START.md)
3. Deep dive with [ONBOARDING.md](ONBOARDING.md)
4. Learn workflow from [GIT_WORKFLOW.md](GIT_WORKFLOW.md)

### For Contributors
1. Review [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
2. Follow [GIT_WORKFLOW.md](GIT_WORKFLOW.md)
3. Check [ROADMAP.md](ROADMAP.md) for current priorities

### For Security Researchers
1. Read [SECURITY.md](SECURITY.md)
2. Review [contracts/README.md](contracts/README.md)
3. Study individual contract files in `contracts/src/`

### For DevOps/Operators
1. Start with [infra/README.md](infra/README.md)
2. Use [HEALTH_CHECK.md](HEALTH_CHECK.md) for diagnostics
3. Refer to [ONBOARDING.md](ONBOARDING.md) DevOps section

## 📝 Contributing to Documentation

When adding new documentation:

1. **Permanent docs** → Add exception to `.gitignore` (see lines 40-79)
2. **Temporary reports** → Let default `*.md` ignore rule handle it
3. **Update this index** → Add entry in appropriate section
4. **Follow naming** → Use descriptive UPPER_SNAKE_CASE for root-level docs

### Documentation Standards
- Use clear, descriptive titles
- Include table of contents for long documents
- Add "last updated" date for technical specs
- Link between related documents
- Keep audience in mind (developer, user, auditor)

## 🏷️ Document Categories

### By Stability
- **Stable** (rarely changes): CODE_OF_CONDUCT.md, SECURITY.md
- **Regular updates**: CHANGELOG.md, ROADMAP.md
- **Living documents**: ONBOARDING.md, contracts/README.md
- **Temporary**: *_REPORT.md, FIXES_APPLIED.md

### By Audience
- **Everyone**: README.md, CODE_OF_CONDUCT.md
- **Developers**: ONBOARDING.md, GIT_WORKFLOW.md, contracts/README.md
- **DevOps**: infra/README.md, HEALTH_CHECK.md
- **Security**: SECURITY.md, contract source code
- **Product**: ROADMAP.md

---

**Last Updated**: October 2025
**Maintained By**: AndeChain Core Team
**Questions?** Open an issue or check [ONBOARDING.md](ONBOARDING.md) for contact info
