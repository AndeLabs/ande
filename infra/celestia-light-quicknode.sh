#!/bin/sh
set -e

echo "🌙 Initializing Celestia Light Node with QuickNode backend..."

# Initialize the light node for mocha
if [ ! -f "/home/celestia/config.toml" ]; then
    echo "📝 First time initialization..."
    celestia light init --p2p.network mocha
    echo "✅ Light node initialized"
else
    echo "✅ Light node already initialized"
fi

echo ""
echo "🔗 Configuring QuickNode as consensus endpoint..."
echo "   Endpoint: divine-crimson-pine.celestia-mocha.quiknode.pro"
echo ""

# Generate wallet address for funding (if needed)
echo "💰 Wallet Information:"
echo "   If you need to submit blobs, fund this wallet with TIA"
echo "   Faucet: https://mocha.celenium.io/faucet"
echo ""

# Start the light node with QuickNode as core endpoint
echo "🚀 Starting Celestia Light Node connected to QuickNode..."
echo "   This provides the DA RPC interface that AndeChain needs"
echo ""

exec celestia light start \
    --p2p.network mocha \
    --core.ip divine-crimson-pine.celestia-mocha.quiknode.pro \
    --rpc.addr 0.0.0.0 \
    --rpc.port 26658
