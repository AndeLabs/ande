#!/bin/bash

# Simple Celestia setup script for AndeChain
set -e

echo "🌙 Setting up Celestia Light Client for AndeChain..."

# Start Celestia in background
echo "Starting Celestia light client..."
docker run -d --name celestia-setup \
  --network host \
  -v celestia-data:/home/celestia/.celestia-light \
  ghcr.io/celestiaorg/celestia-node:latest \
  celestia light start --p2p.network mocha

# Wait for startup
echo "Waiting for Celestia to start (30 seconds)..."
sleep 30

# Generate auth token
echo "Generating auth token..."
AUTH_TOKEN=$(docker exec celestia-setup celestia light auth admin 2>/dev/null || echo "")

if [ -n "$AUTH_TOKEN" ]; then
    echo "✅ Auth token generated: ${AUTH_TOKEN:0:20}..."
    
    # Update the .env file
    sed -i.bak "s/CELESTIA_AUTH_TOKEN=.*/CELESTIA_AUTH_TOKEN=$AUTH_TOKEN/" celestia-mocha.env
    
    echo "✅ Updated celestia-mocha.env with auth token"
    
    # Stop the setup container
    docker stop celestia-setup
    docker rm celestia-setup
    
    echo "✅ Setup complete! Ready to start AndeChain with Celestia DA"
else
    echo "❌ Failed to generate auth token"
    docker stop celestia-setup 2>/dev/null || true
    docker rm celestia-setup 2>/dev/null || true
    exit 1
fi