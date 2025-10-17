#!/bin/bash

echo "🚀 Starting AndeChain Complete Stack"
echo "======================================"

# Start AndeChain
echo "📦 Starting AndeChain..."
make start

# Wait for chain to stabilize
echo "⏳ Waiting for chain to stabilize..."
sleep 10

# Start monitoring
echo "📊 Starting monitoring stack..."
make start-monitoring

echo ""
echo "✅ All services started!"
echo ""
echo "📊 Access Points:"
echo "  - RPC: http://localhost:8545"
echo "  - Grafana: http://localhost:3000 (admin/ande_dev_2025)"
echo "  - Prometheus: http://localhost:9090"
echo ""
echo "🔍 Check status:"
echo "  make status-monitoring"
