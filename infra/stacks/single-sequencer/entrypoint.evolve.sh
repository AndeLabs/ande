#!/bin/bash

echo "🚀 Initializing Evolve sequencer for AndeChain..."

# Initialize evolve config if not exists
if [ ! -f "/root/.evolve/config/evnode.yaml" ]; then
    echo "📝 Initializing evolve config..."
    evm-single init \
        --home=/root/.evolve \
        --evnode.node.aggregator=true \
        --evnode.signer.passphrase=secret \
        --evnode.da.address=http://local-da:7980 \
        --evnode.node.block_time=2s
fi

echo "🚀 Starting Evolve sequencer..."
exec evm-single start \
    --home=/root/.evolve \
    --evm.eth-url=http://ev-reth-sequencer:8545 \
    --evm.engine-url=http://ev-reth-sequencer:8551 \
    --evm.jwt-secret=/root/jwt/jwt.hex \
    --evm.genesis-hash=0xf2bbf7248c3a5c0788b31525c7a725376e566f1bdfcfb924bb7c548e92476dfb \
    --evnode.node.aggregator=true \
    --evnode.da.address=http://local-da:7980 \
    --evnode.signer.passphrase=secret