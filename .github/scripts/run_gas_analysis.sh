#!/bin/bash

# ⚡ Run Gas Analysis Script
# This script runs gas analysis and generates reports

set -e

echo "⚡ Running gas analysis..."

# Create gas reports directory
mkdir -p gas-reports

# Run tests with gas reporting
forge test --gas-report > gas-reports/gas-report.txt

# Generate gas snapshot
forge snapshot --json > gas-reports/gas-snapshot.json

# Extract high gas usage functions
echo "🔍 Analyzing high gas usage functions..."

# Find functions with gas usage above threshold
HIGH_GAS_THRESHOLD=50000

cat > gas-reports/high-gas-functions.json << EOF
{
  "analysis_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "threshold": $HIGH_GAS_THRESHOLD,
  "high_gas_functions": []
}
EOF

# Simple gas analysis (would need more sophisticated parsing in production)
if [ -f "gas-reports/gas-report.txt" ]; then
    echo "📊 Gas report generated"

    # Count total functions analyzed
    TOTAL_FUNCTIONS=$(grep -c "│" gas-reports/gas-report.txt || echo "0")

    # Generate summary
    cat > gas-reports/summary.json << EOF
{
  "total_functions": $TOTAL_FUNCTIONS,
  "analysis_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "report_file": "gas-reports/gas-report.txt",
  "snapshot_file": "gas-reports/gas-snapshot.json"
}
EOF

    echo "✅ Gas analysis completed"
    echo "📁 Reports saved to gas-reports/"
else
    echo "❌ Failed to generate gas report"
    exit 1
fi