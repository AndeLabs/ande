#!/bin/bash

# 🔍 Docker Setup Verification Script
# Verificación rápida del estado de configuración Docker

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo "=================================================================="
echo "🔍 Docker Setup Verification"
echo "Estado actual de configuración Docker para AndeChain"
echo "=================================================================="

# Check 1: Docker Installation
echo ""
echo "1️⃣ Docker Installation:"
if command -v docker &> /dev/null; then
    echo "   ✅ Docker Engine: $(docker --version)"
else
    error "   ❌ Docker Engine: Not installed"
    echo "      Install with: sudo apt-get install docker.io"
fi

if command -v docker compose &> /dev/null; then
    echo "   ✅ Docker Compose: $(docker compose version)"
else
    error "   ❌ Docker Compose: Not installed"
    echo "      Install with: sudo apt-get install docker-compose-plugin"
fi

# Check 2: Docker Permissions
echo ""
echo "2️⃣ Docker Permissions:"
if docker ps >/dev/null 2>&1; then
    log "   ✅ Docker daemon: Accessible without sudo"
else
    error "   ❌ Docker daemon: Permission denied"
    echo "      Fix: sudo usermod -aG docker \$USER && newgrp docker"
    echo "      Or: Log out and log back in"
fi

# Check 3: Docker Daemon Status
echo ""
echo "3️⃣ Docker Daemon Status:"
if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet docker 2>/dev/null; then
        log "   ✅ Docker daemon: Running (systemd)"
    else
        warn "   ⚠️  Docker daemon: Not running (systemd)"
        echo "      Start with: sudo systemctl start docker"
    fi
else
    # Check if Docker is running without systemd
    if docker info >/dev/null 2>&1; then
        log "   ✅ Docker daemon: Running (non-systemd)"
    else
        error "   ❌ Docker daemon: Not running"
        echo "      Start with: sudo systemctl start docker"
        echo "      Or restart Docker Desktop"
    fi
fi

# Check 4: Docker Configuration
echo ""
echo "4️⃣ Docker Configuration:"
if [ -f /etc/docker/daemon.json ]; then
    log "   ✅ Docker daemon config: Present at /etc/docker/daemon.json"

    # Check storage driver
    STORAGE=$(docker info 2>/dev/null | grep "Storage Driver" | cut -d: -f2 | xargs)
    if [ "$STORAGE" = "overlay2" ]; then
        log "   ✅ Storage Driver: $STORAGE (optimal)"
    else
        warn "   ⚠️  Storage Driver: $STORAGE (overlay2 recommended)"
    fi

    # Check cgroup driver
    CGROUP=$(docker info 2>/dev/null | grep "Cgroup Driver" | cut -d: -f2 | xargs)
    if [ "$CGROUP" = "systemd" ]; then
        log "   ✅ Cgroup Driver: $CGROUP (optimal)"
    else
        warn "   ⚠️  Cgroup Driver: $CGROUP (systemd recommended)"
    fi
else
    warn "   ⚠️  Docker daemon config: Using defaults"
    echo "      For optimal performance, create /etc/docker/daemon.json"
fi

# Check 5: System Resources
echo ""
echo "5️⃣ System Resources:"
RAM_TOTAL=$(free -h | grep '^Mem:' | awk '{print $2}')
RAM_AVAILABLE=$(free -h | grep '^Mem:' | awk '{print $7}')
echo "   📊 RAM: $RAM_AVAILABLE available / $RAM_TOTAL total"

CPU_COUNT=$(nproc)
echo "   🖥️  CPUs: $CPU_COUNT cores"

DISK_AVAILABLE=$(df -h . | tail -1 | awk '{print $4}')
echo "   💾 Disk: $DISK_AVAILABLE available"

# Memory assessment
RAM_MB=$(free -m | grep '^Mem:' | awk '{print $2}')
if [ "$RAM_MB" -gt 8000 ]; then
    log "   ✅ Memory: Sufficient for production"
elif [ "$RAM_MB" -gt 4000 ]; then
    warn "   ⚠️  Memory: Limited but usable for testing"
else
    error "   ❌ Memory: Insufficient (<4GB)"
fi

# Check 6: Network Ports
echo ""
echo "6️⃣ Network Ports:"
PORTS=(8545 8547 8549 26658 7331 3000 9090)
AVAILABLE=0
TOTAL=${#PORTS[@]}

for port in "${PORTS[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo "   ⚠️  Port $port: In use"
    else
        AVAILABLE=$((AVAILABLE + 1))
    fi
done

if [ "$AVAILABLE" -eq "$TOTAL" ]; then
    log "   ✅ Network Ports: All $TOTAL required ports available"
else
    warn "   ⚠️  Network Ports: $AVAILABLE/$TOTAL available (may cause conflicts)"
fi

# Check 7: Docker Images
echo ""
echo "7️⃣ Docker Images Availability:"
IMAGES=(
    "ghcr.io/celestiaorg/celestia-node:v0.27.5-mocha"
    "ghcr.io/evstack/ev-node-evm-single:main"
    "alpine:3.22.0"
    "prom/prometheus:latest"
    "grafana/grafana:latest"
)

LOCAL_IMAGES=0
for image in "${IMAGES[@]}"; do
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "$(echo $image | cut -d: -f1):$(echo $image | cut -d: -f2)"; then
        LOCAL_IMAGES=$((LOCAL_IMAGES + 1))
        echo "   ✅ $(echo $image | cut -d: -f1):$(echo $image | cut -d: -f2): Available locally"
    else
        echo "   ℹ️  $(echo $image | cut -d: -f1):$(echo $image | cut -d: -f2): Will be pulled"
    fi
done

# Check 8: Project Files
echo ""
echo "8️⃣ Project Files:"
PROJECT_FILES=(
    "docker-compose.yml"
    "./infra/stacks/single-sequencer/genesis.json"
    "./infra/stacks/single-sequencer/prometheus.yml"
    "./infra/stacks/single-sequencer/grafana.ini"
)

for file in "${PROJECT_FILES[@]}"; do
    if [ -f "$file" ]; then
        log "   ✅ $(basename $file): Present"
    else
        error "   ❌ $(basename $file): Missing"
    fi
done

# Check 9: Tools Installation
echo ""
echo "9️⃣ Required Tools:"
TOOLS=("curl" "python3")
INSTALLED_TOOLS=0

for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        INSTALLED_TOOLS=$((INSTALLED_TOOLS + 1))
        log "   ✅ $tool: Available"
    else
        warn "   ⚠️  $tool: Missing (install with: sudo apt-get install $tool)"
    fi
done

if [ "$INSTALLED_TOOLS" -eq "${#TOOLS[@]}" ]; then
    log "   ✅ All required tools installed"
else
    warn "   ⚠️  Some tools missing"
fi

# Optional tools
OPTIONAL_TOOLS=("jq" "htop" "cast")
echo "   ℹ️  Optional Tools:"
for tool in "${OPTIONAL_TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "      ✅ $tool: Available"
    else
        echo "      ⚠️  $tool: Not installed (optional)"
    fi
done

# Summary
echo ""
echo "=================================================================="
echo "📊 Verification Summary"
echo "=================================================================="

TOTAL_CHECKS=10
PASSED_CHECKS=0

# Count actual passes
[ "$RAM_MB" -gt 4000 ] && PASSED_CHECKS=$((PASSED_CHECKS + 1))
docker ps >/dev/null 2>&1 && PASSED_CHECKS=$((PASSED_CHECKS + 1))
[ -f /etc/docker/daemon.json ] && PASSED_CHECKS=$((PASSED_CHECKS + 1))
[ "$AVAILABLE" -eq "$TOTAL" ] && PASSED_CHECKS=$((PASSED_CHECKS + 1))
[ "$INSTALLED_TOOLS" -eq "${#TOOLS[@]}" ] && PASSED_CHECKS=$((PASSED_CHECKS + 1))

for file in "${PROJECT_FILES[@]}"; do
    [ -f "$file" ] && PASSED_CHECKS=$((PASSED_CHECKS + 1))
done

echo "Checks passed: $PASSED_CHECKS/$TOTAL_CHECKS"

if [ "$PASSED_CHECKS" -ge 8 ]; then
    log "🎉 VERIFICATION PASSED: Ready for AndeChain deployment!"
    echo ""
    echo "🚀 Next Steps:"
    echo "  1. Run configuration: ./configure-docker-server.sh (if not done)"
    echo " 2. Deploy AndeChain: ./deploy-andechain.sh"
    echo " 3. Monitor: andechain-monitor.sh"
elif [ "$PASSED_CHECKS" -ge 6 ]; then
    warn "⚠️  VERIFICATION: Some issues detected but deployment may work"
    echo ""
    echo "🔧 Recommendations:"
    if [ "$RAM_MB" -lt 4000 ]; then
        echo "  • Increase WSL2 memory (see .wslconfig)"
    fi
    if [ "$AVAILABLE" -lt "$TOTAL" ]; then
        echo "  • Free up network ports"
    fi
    echo "  • Continue with: ./deploy-andechain.sh (monitor for issues)"
else
    error "❌ VERIFICATION FAILED: Critical issues must be resolved first"
    echo ""
    echo "🔧 Required Actions:"
    echo "  • Install missing tools"
    echo "  • Fix Docker permissions"
    echo "  • Free up system resources"
    echo "  • Check project files"
    echo ""
    echo "Run: ./configure-docker-server.sh for automatic setup"
fi

echo ""
echo "🔧 Quick Commands:"
echo "  • Health check: docker-health.sh"
echo "  • Monitor: andechain-monitor.sh"
echo "  • Docker status: docker ps"
echo "  • System resources: free -h && htop"
echo ""
echo "📚 Documentation:"
echo "  • Full setup: SERVER_DOCKER_SETUP.md"
echo "  • WSL2 guide: DOCKER_SETUP_WSL2.md"
echo "=================================================================="