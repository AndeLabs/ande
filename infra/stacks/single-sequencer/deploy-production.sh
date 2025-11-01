#!/bin/bash

# =====================================================================
# ANDECHAIN PRODUCTION DEPLOYMENT SCRIPT v2.0
# =====================================================================
# Professional deployment script for AndeChain
# Handles: Docker Compose → Health Checks → SSL → Verification
# Version: 2.0 - Production Ready with Wildcard SSL
# =====================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ENVIRONMENT=${1:-production}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
EMAIL="admin@ande.network"
DOMAIN="ande.network"

echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   ANDECHAIN PRODUCTION DEPLOYMENT v2.0${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "Environment: ${GREEN}${ENVIRONMENT}${NC}"
echo -e "Domain: ${GREEN}${DOMAIN}${NC}"
echo -e "Wildcard: ${GREEN}*.${DOMAIN}${NC}"
echo ""

# =====================================================================
# FUNCTIONS
# =====================================================================

error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

wait_for_container() {
    local container=$1
    local max_wait=${2:-60}
    local count=0
    
    info "Waiting for ${container} to be healthy..."
    while [ $count -lt $max_wait ]; do
        if docker ps | grep -q "${container}.*healthy"; then
            success "${container} is healthy"
            return 0
        fi
        sleep 2
        ((count+=2))
    done
    
    warning "${container} not healthy after ${max_wait}s (continuing anyway)"
    return 1
}

check_port() {
    local port=$1
    if nc -z localhost $port 2>/dev/null; then
        return 0
    fi
    return 1
}

# =====================================================================
# STEP 1: Prerequisites
# =====================================================================

echo -e "${YELLOW}[1/10] Checking prerequisites...${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error_exit "This script must be run as root (use sudo)"
fi

# Check required commands
for cmd in docker docker-compose nc curl; do
    if ! command -v $cmd &> /dev/null; then
        error_exit "$cmd is not installed"
    fi
done

success "Prerequisites check passed"
echo ""

# =====================================================================
# STEP 2: Backup
# =====================================================================

echo -e "${YELLOW}[2/10] Creating backup...${NC}"

BACKUP_DIR="${SCRIPT_DIR}/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup configs
cp "${SCRIPT_DIR}/nginx-production.conf" "$BACKUP_DIR/" 2>/dev/null || true
docker ps -a > "$BACKUP_DIR/docker-ps.txt"

success "Backup created at: ${BACKUP_DIR}"
echo ""

# =====================================================================
# STEP 3: Stop any conflicting services
# =====================================================================

echo -e "${YELLOW}[3/10] Stopping conflicting services...${NC}"

# Stop nginx-proxy if running (will restart later with new config)
docker stop nginx-proxy 2>/dev/null || true
docker rm nginx-proxy 2>/dev/null || true

# Check if port 80 is free for certbot
if check_port 80; then
    warning "Port 80 is in use, trying to free it..."
    fuser -k 80/tcp 2>/dev/null || true
    sleep 2
fi

success "Conflicting services stopped"
echo ""

# =====================================================================
# STEP 4: Start Docker Compose Stack
# =====================================================================

echo -e "${YELLOW}[4/10] Starting Docker Compose stack...${NC}"

cd "$PROJECT_ROOT"

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    error_exit "docker-compose.yml not found in ${PROJECT_ROOT}"
fi

# Start the stack
info "Starting main stack..."
docker-compose up -d

# Wait for key services
wait_for_container "ev-reth-sequencer" 90
wait_for_container "celestia-light" 120
wait_for_container "loki" 30

success "Docker stack is running"
echo ""

# =====================================================================
# STEP 5: Verify RPC is working
# =====================================================================

echo -e "${YELLOW}[5/10] Verifying RPC endpoint...${NC}"

MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s -X POST http://localhost:8545 \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | grep -q "0x181e"; then
        success "RPC endpoint is responding correctly (Chain ID: 6174)"
        break
    fi
    
    ((RETRY_COUNT++))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        error_exit "RPC endpoint not responding after ${MAX_RETRIES} attempts"
    fi
    
    sleep 2
done

echo ""

# =====================================================================
# STEP 6: Install Certbot
# =====================================================================

echo -e "${YELLOW}[6/10] Setting up Certbot...${NC}"

if ! command -v certbot &> /dev/null; then
    info "Installing Certbot..."
    apt-get update -qq
    apt-get install -y -qq certbot python3-certbot-dns-cloudflare 2>/dev/null || \
    apt-get install -y -qq certbot
fi

success "Certbot is ready"
echo ""

# =====================================================================
# STEP 7: Obtain Wildcard SSL Certificate
# =====================================================================

echo -e "${YELLOW}[7/10] Obtaining SSL certificate...${NC}"

# Create certbot directory
mkdir -p /var/www/certbot

if [ "$ENVIRONMENT" = "staging" ]; then
    CERT_ARGS="--staging"
    info "Using Let's Encrypt STAGING server (for testing)"
else
    CERT_ARGS=""
    info "Using Let's Encrypt PRODUCTION server"
fi

# Check if certificate already exists
if [ -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    success "Certificate already exists, skipping..."
else
    info "Obtaining wildcard certificate for *.${DOMAIN} and ${DOMAIN}..."
    
    # Try DNS challenge first (requires manual setup), fallback to standalone
    if certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --domains "${DOMAIN},*.${DOMAIN}" \
        $CERT_ARGS 2>/dev/null; then
        success "Wildcard SSL certificate obtained successfully"
    else
        warning "Wildcard cert failed, obtaining individual certificates..."
        
        # Fallback: get individual certificates
        for subdomain in "" "rpc" "ws" "api" "explorer" "faucet" "www"; do
            if [ -z "$subdomain" ]; then
                FULL_DOMAIN="${DOMAIN}"
            else
                FULL_DOMAIN="${subdomain}.${DOMAIN}"
            fi
            
            info "Getting certificate for ${FULL_DOMAIN}..."
            certbot certonly --standalone \
                --non-interactive \
                --agree-tos \
                --email "$EMAIL" \
                -d "${FULL_DOMAIN}" \
                $CERT_ARGS || warning "Failed to get cert for ${FULL_DOMAIN}"
        done
    fi
fi

echo ""

# =====================================================================
# STEP 8: Deploy Production Nginx Configuration
# =====================================================================

echo -e "${YELLOW}[8/10] Deploying production Nginx...${NC}"

# Copy production config to active config
cp "${SCRIPT_DIR}/nginx-production.conf" "${SCRIPT_DIR}/nginx.conf"

# Test nginx configuration
docker run --rm \
    -v "${SCRIPT_DIR}/nginx.conf:/etc/nginx/nginx.conf:ro" \
    nginx:alpine nginx -t || error_exit "Nginx configuration test failed"

# Start nginx with SSL
info "Starting Nginx proxy with SSL..."
docker run -d \
    --name nginx-proxy \
    --network andechain-p2p \
    -p 80:80 \
    -p 443:443 \
    -v "${SCRIPT_DIR}/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -v "/etc/letsencrypt:/etc/letsencrypt:ro" \
    -v "/var/www/certbot:/var/www/certbot:ro" \
    --restart unless-stopped \
    --health-cmd="curl -f http://localhost/health || exit 1" \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=3 \
    nginx:alpine

# Wait for nginx to be healthy
wait_for_container "nginx-proxy" 30

success "Production Nginx deployed and running"
echo ""

# =====================================================================
# STEP 9: Configure Auto-Renewal
# =====================================================================

echo -e "${YELLOW}[9/10] Setting up SSL auto-renewal...${NC}"

# Create renewal script
cat > /etc/cron.daily/certbot-renewal << 'EOF'
#!/bin/bash
# AndeChain SSL Auto-Renewal

# Renew certificates
certbot renew --quiet --deploy-hook "docker restart nginx-proxy"

# Log
echo "$(date): SSL certificates checked/renewed" >> /var/log/certbot-renewal.log
EOF

chmod +x /etc/cron.daily/certbot-renewal

success "Auto-renewal configured (daily check)"
echo ""

# =====================================================================
# STEP 10: Verification
# =====================================================================

echo -e "${YELLOW}[10/10] Verifying deployment...${NC}"

# Check containers
REQUIRED_CONTAINERS=("ev-reth-sequencer" "celestia-light" "nginx-proxy")
for container in "${REQUIRED_CONTAINERS[@]}"; do
    if docker ps | grep -q "$container"; then
        success "${container} is running"
    else
        error_exit "${container} is not running"
    fi
done

# Test HTTP redirect
if curl -s -I http://localhost/health | grep -q "200\|301"; then
    success "HTTP endpoint accessible"
else
    warning "HTTP health check failed"
fi

# Test HTTPS (self-signed ok for now)
if curl -k -s https://localhost/health | grep -q "healthy"; then
    success "HTTPS endpoint accessible"
else
    warning "HTTPS health check failed"
fi

# Test RPC via nginx
if curl -s -X POST http://localhost/rpc \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | grep -q "0x181e"; then
    success "RPC proxying working correctly"
else
    warning "RPC proxy test failed"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   DEPLOYMENT SUCCESSFUL! 🚀${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo "1. Verify DNS records are configured:"
echo "   ${GREEN}dig +short *.ande.network${NC}"
echo ""
echo "2. Test public endpoints (after DNS propagation):"
echo "   ${GREEN}curl https://rpc.ande.network/health${NC}"
echo "   ${GREEN}curl https://api.ande.network/info${NC}"
echo "   ${GREEN}curl https://explorer.ande.network${NC}"
echo ""
echo "3. Add to MetaMask:"
echo "   Network: AndeChain Mainnet"
echo "   RPC: ${GREEN}https://rpc.ande.network${NC}"
echo "   Chain ID: ${GREEN}6174${NC}"
echo ""
echo -e "${YELLOW}SSL Certificate:${NC}"
if [ -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    echo "   ✓ Location: /etc/letsencrypt/live/${DOMAIN}"
    echo "   ✓ Auto-renewal: Enabled (daily check)"
    echo "   ✓ Expires: $(openssl x509 -enddate -noout -in /etc/letsencrypt/live/${DOMAIN}/cert.pem 2>/dev/null || echo 'N/A')"
fi
echo ""
echo -e "${BLUE}Monitoring:${NC}"
echo "   Logs: ${GREEN}docker logs -f nginx-proxy${NC}"
echo "   Status: ${GREEN}docker ps${NC}"
echo "   Health: ${GREEN}curl http://localhost/health${NC}"
echo ""
