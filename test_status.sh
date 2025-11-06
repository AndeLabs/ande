#!/bin/bash
echo "=== AndeChain Testnet Status Check ==="
echo ""

echo "1. Chain Status:"
BLOCK_HEX=$(curl -s -X POST http://localhost:8545 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq -r '.result')
BLOCK_DEC=$((16#${BLOCK_HEX#0x}))
CHAIN_ID=$(curl -s -X POST http://localhost:8545 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq -r '.result')
CHAIN_ID_DEC=$((16#${CHAIN_ID#0x}))
echo "   Chain ID: $CHAIN_ID_DEC (0x${CHAIN_ID#0x})"
echo "   Current Block: $BLOCK_DEC"
echo ""

echo "2. RPC Endpoints:"
echo -n "   Direct (8545): "
curl -s -X POST http://localhost:8545 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}' > /dev/null && echo "✓ OK" || echo "✗ FAIL"
echo -n "   Health check: "
curl -s http://localhost/health > /dev/null && echo "✓ OK" || echo "✗ FAIL"
echo ""

echo "3. Blockscout API:"
STATS=$(curl -s http://localhost:4000/api/v2/stats)
TOTAL_BLOCKS=$(echo $STATS | jq -r '.total_blocks // "N/A"')
TOTAL_TXS=$(echo $STATS | jq -r '.total_transactions // "N/A"')
echo "   Indexed Blocks: $TOTAL_BLOCKS"
echo "   Total Transactions: $TOTAL_TXS"
echo ""

echo "4. Docker Services:"
docker ps --format "   {{.Names}}: {{.Status}}" | grep -E "(ev-reth|evolve|nginx|blockscout|postgres|celestia)"
echo ""

echo "5. Celestia DA Layer:"
CELESTIA_HEALTHY=$(docker ps --filter name=celestia-light --format "{{.Status}}" | grep -o "healthy\|starting")
if [ "$CELESTIA_HEALTHY" = "healthy" ]; then
    echo "   Status: ✓ Healthy (DA submissions active)"
else
    echo "   Status: ⏳ Starting (DA submissions pending)"
fi
echo ""

echo "=== Test Complete ==="
