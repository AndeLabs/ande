#!/bin/bash
# ANDE Chain - Documentation Cleanup Script

echo "🧹 Cleaning up outdated documentation..."
echo ""

# Create archive directory
mkdir -p .archive/old-docs

# Move outdated/redundant docs to archive
echo "📦 Archiving outdated documents..."
mv andechain/CLAUDE.md .archive/old-docs/ 2>/dev/null || true
mv andechain/AUDITORIA.md .archive/old-docs/ 2>/dev/null || true
mv andechain/CELESTIA_INTEGRATION_SUMMARY.md .archive/old-docs/ 2>/dev/null || true
mv andechain/CELESTIA_STATUS.md .archive/old-docs/ 2>/dev/null || true
mv andechain/SOLUCION_FINAL_CELESTIA.md .archive/old-docs/ 2>/dev/null || true
mv andechain/TUTORIAL_SETUP.md .archive/old-docs/ 2>/dev/null || true
mv andechain/GRAFANA_SETUP_FINAL.md .archive/old-docs/ 2>/dev/null || true
mv andechain/MONITORING_SETUP_COMPLETE.md .archive/old-docs/ 2>/dev/null || true
mv andechain/MONITORING_STATUS.md .archive/old-docs/ 2>/dev/null || true
mv andechain/README_MONITORING.md .archive/old-docs/ 2>/dev/null || true
mv andechain/SECURITY_TESTING.md .archive/old-docs/ 2>/dev/null || true

echo "✅ Archived outdated documents"
echo ""

echo "📋 Keeping these essential documents:"
ls -1 andechain/*.md 2>/dev/null | sed 's/andechain\//  - /'

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Essential documentation structure:"
echo "  README.md              - Main entry point"
echo "  ARCHITECTURE.md        - Technical architecture"
echo "  INSTALL.md             - Installation guide"
echo "  PRODUCTION_READY.md    - Production deployment"
echo "  CONTRIBUTING.md        - Contribution guidelines"
echo "  SECURITY.md            - Security practices"
echo "  CHANGELOG.md           - Version history"
echo "  CELESTIA_SETUP.md      - Celestia DA setup"
echo "  MONITORING_GUIDE.md    - Monitoring setup"

