#!/bin/bash
# Cleanup script for contracts directory
echo "🧹 Cleaning contracts directory..."
cd contracts
rm -rf script.backup out cache broadcast coverage test-results 2>/dev/null || true
mkdir -p reports deployments
mv slither*.* reports/ 2>/dev/null || true
echo "✅ Cleanup complete!"
ls -la
