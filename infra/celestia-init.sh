#!/bin/sh
set -e

echo "🌙 Initializing Celestia Light Node for Mocha-4 testnet..."

# Initialize the node for mocha-4
celestia light init --p2p.network mocha

# Get trusted hash and height (updated for mocha-4 with v6.1.1-mocha)
TRUSTED_HEIGHT=8428847
TRUSTED_HASH="0679C900DAFF13F9F240931DC01A9CC589A7D12BE045D1D4EAF541BBB8DF48BF"

echo "✅ Trusted height: $TRUSTED_HEIGHT"
echo "✅ Trusted hash: $TRUSTED_HASH"

# Update config.toml - replace the empty values
CONFIG_FILE="/home/celestia/config.toml"

echo "📝 Updating configuration..."

# Simple sed replacements for the specific lines
sed -i 's/SyncFromHash = ""/SyncFromHash = "0679C900DAFF13F9F240931DC01A9CC589A7D12BE045D1D4EAF541BBB8DF48BF"/' "$CONFIG_FILE"
sed -i 's/SyncFromHeight = 0/SyncFromHeight = 8428847/' "$CONFIG_FILE"

echo "✅ Configuration updated successfully"

# Verify
if grep -q "SyncFromHeight = 8428847" "$CONFIG_FILE"; then
    echo "✅ Verified: Configuration is correct"
    grep "SyncFromHeight\|SyncFromHash" "$CONFIG_FILE"
else
    echo "⚠️  Warning: Could not verify configuration, showing [Header.Syncer] section:"
    grep -A 5 "\[Header.Syncer\]" "$CONFIG_FILE"
fi

# Start the light node with mocha-4 configuration
echo "🚀 Starting Celestia Light Node for mocha-4..."
exec celestia light start \
    --p2p.network mocha \
    --core.ip public-celestia-mocha4-consensus.numia.xyz \
    --core.port 9090 \
    --rpc.addr 0.0.0.0 \
    --rpc.port 26658
