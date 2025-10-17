#!/bin/sh
set -e

echo "🌉 Initializing Celestia Bridge Node for Mocha-4 testnet..."

# CRITICAL: Check if already initialized to avoid re-init issues
if [ ! -f "/home/celestia/config.toml" ]; then
    echo "📝 First time initialization..."
    # Initialize the bridge node for mocha (replaces deprecated full node)
    celestia bridge init --p2p.network mocha
    echo "✅ Bridge node initialized"
else
    echo "✅ Bridge node already initialized, skipping init"
fi

echo "✅ Bridge node initialized successfully"
echo ""
echo "📝 Note: Bridge nodes sync ALL headers from genesis (no trusted hash needed)"
echo "   This will take some time for initial sync but provides full data storage"
echo ""

# Generate wallet info for funding
echo "💰 Wallet Information:"
echo "This node needs TIA tokens to submit blobs for AndeChain"
echo "Faucet: https://mocha.celenium.io/faucet"
echo "Discord: #mocha-faucet channel - Use: \$request <CELESTIA-ADDRESS>"
echo ""

# Get the wallet address
WALLET_ADDRESS=$(celestia bridge auth admin --p2p.network mocha 2>&1 | grep "celestia1" || echo "")
if [ -n "$WALLET_ADDRESS" ]; then
    echo "📬 Wallet Address: $WALLET_ADDRESS"
    echo "   Fund this address with Mocha testnet TIA"
fi
echo ""

# Start the bridge node - Bridge nodes are the recommended way for rollups
echo "🚀 Starting Celestia Bridge Node for mocha-4..."
echo "   This may take several minutes for initial peer discovery and sync"
echo ""

exec celestia bridge start \
    --p2p.network mocha \
    --core.ip public-celestia-mocha4-consensus.numia.xyz \
    --core.port 9090 \
    --rpc.addr 0.0.0.0 \
    --rpc.port 26658
