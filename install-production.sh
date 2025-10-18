#!/bin/bash
# ANDE Chain - Production System Installer
set -e

echo "╔════════════════════════════════════════════════╗"
echo "║  ANDE Chain - Production System Installer     ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# Install production Makefile
echo "📦 Installing production Makefile..."
if [ -f Makefile ]; then
    mv Makefile Makefile.backup.old
    echo "   Old Makefile backed up as Makefile.backup.old"
fi
cp Makefile.production Makefile
echo "   ✅ Production Makefile installed"
echo ""

# Run setup
echo "🔧 Running initial setup..."
make setup
echo ""

# Print next steps
echo "╔════════════════════════════════════════════════╗"
echo "║  Installation Complete!                        ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo ""
echo "1. Create encrypted keystore:"
echo "   cast wallet import deployer-local --interactive"
echo ""
echo "2. Deploy locally:"
echo "   make deploy-local"
echo ""
echo "3. Check health:"
echo "   make health"
echo ""
echo "📚 Full documentation: INSTALL.md"
echo "❓ Help: make help"
echo ""

