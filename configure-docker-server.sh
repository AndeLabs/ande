#!/bin/bash

# 🔧 AndeChain Server Docker Configuration Script
# Configuración profesional de Docker Engine para producción

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log() {
    echo -e "${GREEN}✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

step() {
    echo -e "\n${BOLD}🔧 Step $1: $2${NC}"
    echo "=================================================================="
}

echo "=================================================================="
echo "🖥️ AndeChain Server Docker Configuration"
echo "Configuración profesional para entorno de producción"
echo "=================================================================="

# Allow running with sudo
if [ "$EUID" -ne 0 ]; then
    error "This script requires sudo privileges. Run with: sudo ./configure-docker-server.sh"
fi

TARGET_USER=${SUDO_USER:-$USER}
log "Configuring Docker for user: $TARGET_USER"

# Step 1: Check current Docker installation
step "1/8" "Checking Docker Installation"

if ! command -v docker &> /dev/null; then
    error "Docker Engine is not installed. Please install Docker Engine first."
fi

if ! command -v docker compose &> /dev/null; then
    error "Docker Compose is not installed. Please install Docker Compose plugin first."
fi

log "Docker Engine: $(docker --version)"
log "Docker Compose: $(docker compose version)"

# Step 2: Check user groups and permissions
step "2/8" "Configuring Docker Permissions"

if id "$TARGET_USER" | grep -q docker; then
    log "User $TARGET_USER already in docker group"
else
    info "Adding user $TARGET_USER to docker group..."
    usermod -aG docker "$TARGET_USER"
    warn "You will need to log out and log back in for group changes to take effect."
    warn "Run 'newgrp docker' after this script if you want to continue immediately."
fi

# Fix Docker socket permissions immediately
chown root:docker /var/run/docker.sock
chmod 660 /var/run/docker.sock
log "Docker socket permissions fixed immediately"

# Step 3: Create Docker daemon configuration
step "3/8" "Creating Optimized Docker Configuration"

mkdir -p /etc/docker
mkdir -p /etc/docker/daemon.d

# Create main daemon configuration optimized for AndeChain
tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "default-ulimits": {
    "nofile": {
      "Name": "Max Open Files",
      "Hard": 1048576,
      "Soft": 1048576
    },
    "nproc": {
      "Name": "Max User Processes",
      "Hard": 1048576,
      "Soft": 1048576
    },
    "memlock": {
      "Name": "Memory Lock",
      "Hard": -1,
      "Soft": -1
    }
  },
  "exec-opts": [
    "native.cgroupdriver=systemd",
    "default-ulimit=nofile=1048576:1048576",
    "default-ulimit=nproc=1048576:1048576"
  ],
  "default-runtime": "runc",
  "runtimes": {
    "runc": {
      "path": "runc"
    }
  },
  "live-restore": true,
  "userland-proxy": false,
  "ip-forward": true,
  "iptables": true,
  "bridge": "none",
  "metrics-addr": "0.0.0.0:9323"
}
EOF

log "Created main Docker daemon configuration"

# Create AndeChain-specific configuration
sudo tee /etc/docker/daemon.d/andechain.json > /dev/null <<'EOF'
{
  "storage-opts": [
    "overlay2.size=500G"
  ],
  "experimental": false,
  "debug": false
}
EOF

log "Created AndeChain-specific Docker configuration"

# Step 4: Configure system limits
step "4/8" "Configuring System Limits for Blockchain"

# Create sysctl configuration for blockchain workloads
sudo tee /etc/sysctl.d/99-andechain.conf > /dev/null <<'EOF'
# File system limits for blockchain
fs.file-max = 2097152
fs.inotify.max_user_watches = 1048576

# Memory management
vm.max_map_count = 262144
vm.swappiness = 1

# Networking configuration
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr

# Docker networking
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

log "Created system limits configuration"

# Apply sysctl changes
sudo sysctl -p /etc/sysctl.d/99-andechain.conf

# Step 5: Configure systemd services (if available)
step "5/8" "Configuring SystemD Services"

if command -v systemctl &> /dev/null && systemctl list-unit-files | grep -q docker.service; then
    info "Docker systemd service found, applying optimizations..."

    # Create or update docker systemd service
    mkdir -p /etc/systemd/system/docker.service.d
    tee /etc/systemd/system/docker.service.d/override.conf > /dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s
MemoryMax=16G
EOF

    systemctl daemon-reload
    log "Updated Docker systemd service configuration"
else
    warn "SystemD not available, skipping systemd configuration"
fi

# Step 6: Install monitoring tools
step "6/8" "Installing Monitoring Tools"

# Update package list
info "Updating package lists..."
apt-get update

# Install system monitoring tools
info "Installing system monitoring tools..."
apt-get install -y htop iotop nethogs sysstat jq

# Install Docker CLI tools
info "Installing Docker CLI tools..."
apt-get install -y docker-ce-cli docker-compose-plugin

log "Installed monitoring and Docker CLI tools"

# Step 7: Create monitoring scripts
step "7/8" "Creating Monitoring Scripts"

# Create AndeChain monitor script
tee /usr/local/bin/andechain-monitor.sh > /dev/null <<'EOF'
#!/bin/bash

echo "🚀 AndeChain Production Monitor"
echo "=========================="
echo "Time: $(date)"
echo ""

# System resources
echo "📊 System Resources:"
echo "RAM: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2 " (" $3*100/$2 "%)"}')"
echo "CPU Load: $(uptime | awk -F'load average:' '{print $2, $3, $4}' | xargs)"
echo "Disk: $(df -h . | tail -1 | awk '{print $4 " free (" $5 " used)"}')"
echo ""

# Docker containers
echo "🐳 Docker Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -10
echo ""

# Docker resource usage
echo "📈 Docker Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" | head -10
echo ""

# Network ports
echo "🌐 Network Ports:"
ss -tuln | grep -E ":85[4-7]|:26658|:3000|:9090|:733[0-3]" | head -10
echo ""

# AndeChain specific checks
echo "🔗 AndeChain Status:"
if curl -s http://localhost:8545 >/dev/null; then
    BLOCK=$(curl -s -X POST http://localhost:8545 \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        2>/dev/null | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4 | head -1)
    if [ -n "$BLOCK" ]; then
        echo "✅ Sequencer RPC: Responding (Block: $BLOCK)"
    else
        echo "⚠️  Sequencer RPC: No response"
    fi
else
    echo "❌ Sequencer RPC: Not accessible"
fi

if curl -s http://localhost:26658/status >/dev/null; then
    echo "✅ Celestia DA: Connected"
else
    echo "❌ Celestia DA: Not connected"
fi

echo ""
echo "📊 System Health Check: $(date)"
EOF

chmod +x /usr/local/bin/andechain-monitor.sh

# Create Docker health check script
tee /usr/local/bin/docker-health.sh > /dev/null <<'EOF'
#!/bin/bash

echo "🔍 Docker Health Check"
echo "===================="

# Docker daemon status
if systemctl is-active --quiet docker 2>/dev/null; then
    echo "✅ Docker daemon: Running"
else
    echo "❌ Docker daemon: Not running"
    echo "Run: sudo systemctl start docker"
fi

# Docker socket permissions
if [ -w /var/run/docker.sock ]; then
    echo "✅ Docker socket: Accessible"
else
    echo "❌ Docker socket: No write permission"
    echo "Run: sudo usermod -aG docker \$USER && newgrp docker"
fi

# Docker containers
CONTAINER_COUNT=$(docker ps --format "{{.Names}}" | wc -l)
echo "✅ Running containers: $CONTAINER_COUNT"

# Docker system info
DISK_USAGE=$(docker system df --format "{{.Type}}\t{{.Size}}\t{{.Reclaimable}}" | tail -1)
echo "💾 Docker disk usage: $DISK_USAGE"

# Memory pressure
MEMORY_PRESSURE=$(cat /proc/pressure/memory 2>/dev/null | grep some | tail -1 || echo "N/A")
echo "💭 Memory pressure: $MEMORY_PRESSURE"

echo ""
echo "📊 Quick Stats:"
docker system df --format "table {{.Type}}\t{{.Total}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}"
echo ""
echo "🔧 Recommendations:"
if [ "$CONTAINER_COUNT" -gt 0 ]; then
    echo "✅ Docker containers running well"
else
    echo "⚠️  No containers running - start AndeChain with: ./deploy-andechain.sh"
fi
EOF

chmod +x /usr/local/bin/docker-health.sh

log "Created monitoring scripts"

# Step 8: Apply configuration
step "8/8" "Applying Configuration and Starting Services"

# Apply new Docker configuration
if command -v systemctl &> /dev/null; then
    info "Restarting Docker daemon with new configuration..."
    systemctl restart docker

    # Wait for Docker to start
    sleep 5

    # Enable Docker to start on boot
    systemctl enable docker

    if systemctl is-active --quiet docker; then
        log "Docker daemon restarted successfully"
    else
        error "Docker daemon failed to restart after configuration"
    fi
else
    warn "SystemD not available, please restart Docker manually"
    warn "Run: systemctl restart docker or restart Docker Desktop"
fi

# Verify Docker permissions work
sleep 2
if docker ps >/dev/null 2>&1; then
    log "✅ Docker permissions working correctly"
else
    warn "⚠️ Docker permissions may need adjustment"
    warn "Try running: newgrp docker or log out and back in"
fi

echo ""
echo "=================================================================="
echo "🎉 Docker Configuration Complete!"
echo "=================================================================="
echo ""

echo "📋 Configuration Applied:"
echo "  ✅ Docker Engine optimized for blockchain workloads"
echo "  ✅ System limits configured for high performance"
echo "  ✅ Memory management optimized"
echo "  ✅ Network settings enhanced"
echo "  ✅ Monitoring tools installed"
echo "  ✅ Health check scripts created"
echo ""
echo "🚀 Next Steps:"
echo "  1. Run health check: docker-health.sh"
echo "  2. Verify resources: andechain-monitor.sh"
echo " 3. Deploy AndeChain: ./deploy-andechain.sh"
echo "  4. Monitor performance: andechain-monitor.sh"
echo ""
echo "📊 Expected Performance:"
echo "  • Block time: ~2 seconds"
echo "  • RPC response: <50ms"
echo "  • Memory usage: 2-4GB total"
echo "  • High throughput P2P networking"
echo ""
echo "🔧 Useful Commands:"
echo "  • Health check: docker-health.sh"
echo "  • Monitor: andechain-monitor.sh"
echo "  • Docker stats: docker stats"
echo "  • System resources: htop"
echo "  • Network connections: ss -tuln"
echo ""
echo "📚 Documentation:"
echo "  • Full setup guide: SERVER_DOCKER_SETUP.md"
echo "  • Troubleshooting: Check logs with journalctl -u docker"
echo ""
echo "✅ Docker server is now configured for AndeChain production!"

# Verify configuration at the end
echo ""
echo "🔍 Final Configuration Verification:"
echo "======================================"

# Docker version
echo "Docker: $(docker --version)"
echo "Compose: $(docker compose version)"

# System info
echo "System: $(uname -a)"
echo "RAM: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "CPUs: $(nproc)"

# Docker info
echo "Docker info:"
echo "  Storage Driver: $(docker info 2>/dev/null | grep 'Storage Driver' | cut -d: -f2 | xargs)"
echo "  Cgroup Driver: $(docker info 2>/dev/null | grep 'Cgroup Driver' | cut -d: -f2 | xargs)"

# Test Docker functionality
if docker run --rm hello-world >/dev/null 2>&1; then
    log "✅ Docker test: Container can run successfully"
else
    warn "⚠️  Docker test: Failed to run container - check logs"
fi

echo ""
log "🎉 Docker server configuration completed successfully!"
echo "🚀 Ready to deploy AndeChain with optimal performance!"