#!/bin/bash

# Script para forzar la producción de bloques en modo dev
# Usa eth_sendTransaction para crear transacciones dummy que fuercen bloques

RPC_URL="${1:-http://localhost:8545}"
ACCOUNT="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
INTERVAL="${2:-5}"  # Intervalo en segundos

echo "⛏️  Mining blocks every ${INTERVAL}s on ${RPC_URL}..."
echo "📍 Account: ${ACCOUNT}"
echo ""

while true; do
  # Envía una transacción dummy a sí mismo para forzar bloque
  RESULT=$(curl -s -X POST "${RPC_URL}" \
    -H "Content-Type: application/json" \
    -d "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"eth_sendTransaction\",
      \"params\": [{
        \"from\": \"${ACCOUNT}\",
        \"to\": \"${ACCOUNT}\",
        \"value\": \"0x1\",
        \"gas\": \"0x5208\"
      }],
      \"id\": 1
    }")
  
  TX_HASH=$(echo "$RESULT" | grep -o '"result":"0x[^"]*' | cut -d'"' -f4)
  
  if [ -n "$TX_HASH" ]; then
    echo "✅ Block mined: $TX_HASH"
  else
    ERROR=$(echo "$RESULT" | grep -o '"message":"[^"]*' | cut -d'"' -f4)
    echo "⚠️  $ERROR"
  fi
  
  sleep "$INTERVAL"
done
