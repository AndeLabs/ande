#!/bin/bash
echo "=== Testing All AndeChain Endpoints ==="
echo ""

# Test localhost first (these should all work)
echo "1. Testing localhost endpoints:"
echo -n "   RPC (8545): "
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
echo ""

echo -n "   WebSocket (8546): "
curl -s -o /dev/null -w "%{http_code}" http://localhost:8546 2>/dev/null || echo "N/A (WebSocket)"
echo ""

echo -n "   Evolve API (7331): "
curl -s -o /dev/null -w "%{http_code}" http://localhost:7331/health 2>/dev/null || echo "N/A"
echo ""

echo -n "   Blockscout API (4000): "
curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/api/v2/stats
echo ""

echo -n "   Grafana (3000): "
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health
echo ""

echo -n "   Nginx health: "
curl -s -o /dev/null -w "%{http_code}" http://localhost/health
echo ""
echo ""

# Get current block
BLOCK=$(curl -s -X POST http://localhost:8545 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq -r '.result')
BLOCK_DEC=$((16#${BLOCK#0x}))
echo "Current block: $BLOCK_DEC"
echo ""

# Test with Host headers (simulating domain access)
echo "2. Testing nginx reverse proxy with domain simulation:"
echo -n "   rpc.ande.network: "
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost \
  -H "Host: rpc.ande.network" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
echo ""

echo -n "   api.ande.network: "
curl -s -o /dev/null -w "%{http_code}" http://localhost \
  -H "Host: api.ande.network"
echo ""

echo -n "   explorer.ande.network: "
curl -s -o /dev/null -w "%{http_code}" http://localhost/api/v2/stats \
  -H "Host: explorer.ande.network"
echo ""

echo -n "   status.ande.network: "
curl -s -o /dev/null -w "%{http_code}" http://localhost/api/health \
  -H "Host: status.ande.network"
echo ""

echo ""
echo "=== Endpoint Test Complete ==="
