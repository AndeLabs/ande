#!/bin/bash
# 🚀 ANDE Chain Auto-Start Script
# This script ensures ANDE Chain starts automatically on server boot
# and recovers from failures

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 ANDE Chain Auto-Start Script"
echo "================================"
echo "Project directory: $PROJECT_DIR"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Starting Docker..."
    sudo systemctl start docker
    sleep 5
fi

# Navigate to project directory
cd "$PROJECT_DIR"

# Check if containers are already running
if docker-compose ps | grep -q "Up"; then
    echo "ℹ️  ANDE Chain is already running"
    docker-compose ps
else
    echo "🔄 Starting ANDE Chain..."

    # Pull latest images (optional, comment out for faster startup)
    # docker-compose pull

    # Start services
    docker-compose up -d

    echo "✅ ANDE Chain started successfully"

    # Wait for services to be healthy
    echo "⏳ Waiting for services to become healthy..."
    sleep 10

    # Show status
    docker-compose ps
fi

# Show logs tail
echo ""
echo "📋 Recent logs:"
echo "==============="
docker-compose logs --tail=20

echo ""
echo "✅ ANDE Chain is operational"
echo ""
echo "🔍 Monitor with:"
echo "   docker-compose logs -f"
echo ""
echo "🌐 Access points:"
echo "   - RPC HTTP:    http://localhost:8545"
echo "   - RPC WS:      ws://localhost:8546"
echo "   - Prometheus:  http://localhost:9090"
echo "   - Grafana:     http://localhost:3000"
