#!/bin/bash

# 🔧 Setup Environment Script
# This script sets up the environment for CI/CD pipeline

set -e

echo "🔧 Setting up CI/CD environment..."

# Create necessary directories
mkdir -p artifacts
mkdir -p test-results
mkdir -p coverage
mkdir -p gas-reports
mkdir -p security-reports
mkdir -p ai-analysis

# Set permissions for scripts
chmod +x .github/scripts/*.sh
chmod +x .github/scripts/*.py
chmod +x .github/scripts/*.js

# Check if required tools are available
echo "🔍 Checking required tools..."

command -v forge >/dev/null 2>&1 || { echo "❌ Foundry not found"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "❌ Node.js not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "❌ Python3 not found"; exit 1; }

# Validate environment variables if they exist
if [ -n "$PRIVATE_KEY" ]; then
    echo "✅ PRIVATE_KEY is set"
else
    echo "⚠️  PRIVATE_KEY not set (may be needed for deployment)"
fi

if [ -n "$GEMINI_API_KEY" ]; then
    echo "✅ GEMINI_API_KEY is set"
else
    echo "⚠️  GEMINI_API_KEY not set (AI analysis will be skipped)"
fi

# Display Foundry version
echo "🛠️  Foundry version:"
forge --version

# Display Node.js version
echo "🟢 Node.js version:"
node --version

# Display Python version
echo "🐍 Python version:"
python3 --version

echo "✅ Environment setup completed successfully!"