#!/bin/bash

# 📊 Run Coverage Analysis Script
# This script runs Foundry coverage and generates reports

set -e

echo "🧪 Running Foundry coverage analysis..."

# Create coverage directory
mkdir -p coverage

# Run coverage with Foundry
forge coverage --report lcov --report html --output-dir coverage

# Generate coverage summary
echo "📈 Coverage Summary:"
forge coverage --report summary

# Extract coverage percentage
COVERAGE_PERCENTAGE=$(forge coverage --report summary | grep -o '[0-9]*\.[0-9]*%' | head -1)

echo "✅ Coverage analysis completed: $COVERAGE_PERCENTAGE"

# Save coverage metrics to file for CI
cat > coverage/metrics.json << EOF
{
  "coverage_percentage": "$COVERAGE_PERCENTAGE",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "files_analyzed": $(find src -name "*.sol" | wc -l)
}
EOF

echo "📊 Coverage metrics saved to coverage/metrics.json"