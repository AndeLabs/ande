#!/bin/bash
# 🔧 ANDE Chain Systemd Service Setup
# This script creates and enables a systemd service for ANDE Chain

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
USER=$(logname || echo $SUDO_USER)

echo "🔧 Setting up ANDE Chain systemd service"
echo "========================================"
echo "Project directory: $PROJECT_DIR"
echo "User: $USER"

# Create systemd service file
cat > /etc/systemd/system/andechain.service <<EOF
[Unit]
Description=ANDE Chain - Sovereign EVM Rollup on Celestia
Documentation=https://github.com/andechain
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
User=$USER
Group=$USER

# Start command
ExecStart=/usr/bin/docker-compose up -d

# Stop command
ExecStop=/usr/bin/docker-compose down

# Restart policy
Restart=on-failure
RestartSec=30s

# Resource limits
LimitNOFILE=65536

# Environment
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Service file created: /etc/systemd/system/andechain.service"

# Reload systemd
systemctl daemon-reload

# Enable service
systemctl enable andechain.service

echo "✅ Service enabled for auto-start on boot"

# Show status
systemctl status andechain.service --no-pager || true

echo ""
echo "📋 Service Management Commands:"
echo "   sudo systemctl start andechain    # Start the chain"
echo "   sudo systemctl stop andechain     # Stop the chain"
echo "   sudo systemctl restart andechain  # Restart the chain"
echo "   sudo systemctl status andechain   # Check status"
echo "   sudo journalctl -u andechain -f   # View logs"
echo ""
echo "✅ ANDE Chain will now start automatically on server boot!"
