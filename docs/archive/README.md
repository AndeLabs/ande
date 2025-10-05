# 📦 Archived Documentation

This directory contains historical reports and documentation that are no longer actively used but preserved for reference.

## Directory Structure

```
archive/
└── 2025-10-reports/    # Reports from October 2025 development cycle
    ├── BLOCKSCOUT_FIX_SUMMARY.md
    ├── BLOCKSCOUT_INTEGRATION.md
    ├── FIXES_APPLIED.md
    ├── HEALTH_CHECK_REPORT.md
    ├── TEST_COVERAGE_FINAL_REPORT.md
    └── TEST_COVERAGE_IMPROVEMENT.md
```

## Archive Policy

### What Gets Archived?

Documents are moved here when they:
- ✅ Are completed reports (integration, test coverage, health checks)
- ✅ Represent a specific point in time or milestone
- ✅ Are valuable for historical reference but not for daily development
- ✅ Have been superseded by newer versions or approaches

### What Stays in Root?

Active documentation remains in the project root:
- README.md, QUICK_START.md, ONBOARDING.md
- CHANGELOG.md, ROADMAP.md
- GIT_WORKFLOW.md, HEALTH_CHECK.md
- Technical specs (NATIVE_ANDE_MIGRATION.md, FAUCET.md)

## Using Archived Documents

To view archived reports:

```bash
# List all archived documents
ls -R docs/archive/

# View a specific report
cat docs/archive/2025-10-reports/TEST_COVERAGE_FINAL_REPORT.md
```

## Archive Naming Convention

Archives are organized by date and type:
- `YYYY-MM-reports/` - Monthly development reports
- `YYYY-QN-milestones/` - Quarterly milestone documentation
- `integrations/` - Integration-specific documentation

## Retention Policy

- **Keep**: Reports that document significant decisions or milestones
- **Remove**: Truly obsolete documents after 1 year (or move to wiki)
- **Review**: Annually evaluate archived content relevance

---

**Note**: These archived files are **not tracked in Git** to keep the repository lean. They exist only in local development environments for historical reference.
