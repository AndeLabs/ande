#!/bin/bash

# =====================================================================
# ANDECHAIN PRODUCTION DEPLOYMENT SCRIPT
# =====================================================================
# This script deploys AndeChain to production with SSL/TLS support
# Usage: ./deploy-production.sh [staging|production]
# =====================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-production}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAINS="rpc.ande.network ws.ande.network api.ande.network ande.network www.ande.network"
EMAIL="admin@ande.network"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}ANDECHAIN PRODUCTION DEPLOYMENT${NC}"
echo -e "${BLUE}=========================================${NC}"
echo -e "Environment: ${GREEN}${ENVIRONMENT}${NC}"
echo -e "Domains: ${GREEN}${DOMAINS}${NC}"
echo ""

# =====================================================================
# STEP 1: Prerequisites Check
# =====================================================================

echo -e "${YELLOW}[1/8] Checking prerequisites...${NC}"

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root or with sudo${NC}"
   exit 1
fi

# Check required commands
for cmd in docker docker-compose nginx certbot; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# =====================================================================
# STEP 2: Backup Current Configuration
# =====================================================================

echo -e "${YELLOW}[2/8] Creating backup...${NC}"

BACKUP_DIR="${SCRIPT_DIR}/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup current nginx config
if [ -f "${SCRIPT_DIR}/nginx.conf" ]; then
    cp "${SCRIPT_DIR}/nginx.conf" "$BACKUP_DIR/nginx.conf.backup"
    echo -e "${GREEN}✓ Nginx config backed up${NC}"
fi

# Backup docker containers state
docker ps -a > "$BACKUP_DIR/docker-ps.txt"
echo -e "${GREEN}✓ Docker state backed up${NC}"

echo -e "${GREEN}✓ Backup created at: ${BACKUP_DIR}${NC}"
echo ""

# =====================================================================
# STEP 3: Install Certbot with Nginx Plugin
# =====================================================================

echo -e "${YELLOW}[3/8] Setting up Certbot...${NC}"

# Install certbot if not already installed
if ! command -v certbot &> /dev/null; then
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

echo -e "${GREEN}✓ Certbot ready${NC}"
echo ""

# =====================================================================
# STEP 4: Obtain SSL Certificates
# =====================================================================

echo -e "${YELLOW}[4/8] Obtaining SSL certificates...${NC}"

# Stop nginx temporarily to obtain certificates
docker stop nginx-proxy 2>/dev/null || true

# Obtain certificates for each domain
for domain in $DOMAINS; do
    echo -e "Obtaining certificate for ${GREEN}${domain}${NC}..."
    
    if [ "$ENVIRONMENT" = "staging" ]; then
        # Use staging server for testing
        certbot certonly --standalone \
            --non-interactive \
            --agree-tos \
            --email "$EMAIL" \
            --staging \
            -d "$domain" || echo -e "${YELLOW}Warning: Failed to obtain cert for ${domain}${NC}"
    else
        # Production certificates
        certbot certonly --standalone \
            --non-interactive \
            --agree-tos \
            --email "$EMAIL" \
            -d "$domain" || echo -e "${YELLOW}Warning: Failed to obtain cert for ${domain}${NC}"
    fi
done

echo -e "${GREEN}✓ SSL certificates obtained${NC}"
echo ""

# =====================================================================
# STEP 5: Deploy New Nginx Configuration
# =====================================================================

echo -e "${YELLOW}[5/8] Deploying new nginx configuration...${NC}"

# Copy production config
cp "${SCRIPT_DIR}/nginx-production.conf" "${SCRIPT_DIR}/nginx.conf"

echo -e "${GREEN}✓ Nginx configuration deployed${NC}"
echo ""

# =====================================================================
# STEP 6: Update Docker Configuration
# =====================================================================

echo -e "${YELLOW}[6/8] Updating Docker containers...${NC}"

# Restart nginx with new config and SSL certificates
docker stop nginx-proxy 2>/dev/null || true
docker rm nginx-proxy 2>/dev/null || true

docker run -d \
    --name nginx-proxy \
    --network single-sequencer_ande-net \
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

echo -e "${GREEN}✓ Nginx proxy restarted with SSL${NC}"
echo ""

# =====================================================================
# STEP 7: Configure Auto-Renewal
# =====================================================================

echo -e "${YELLOW}[7/8] Setting up SSL auto-renewal...${NC}"

# Create renewal script
cat > /etc/cron.daily/certbot-renewal << 'EOF'
#!/bin/bash
# Auto-renewal script for AndeChain SSL certificates

certbot renew --quiet --deploy-hook "docker restart nginx-proxy"

# Log renewal
echo "$(date): SSL certificates renewed" >> /var/log/certbot-renewal.log
EOF

chmod +x /etc/cron.daily/certbot-renewal

echo -e "${GREEN}✓ Auto-renewal configured${NC}"
echo ""

# =====================================================================
# STEP 8: Verification
# =====================================================================

echo -e "${YELLOW}[8/8] Verifying deployment...${NC}"

# Wait for nginx to start
sleep 5

# Check if containers are running
if ! docker ps | grep -q "nginx-proxy"; then
    echo -e "${RED}✗ Nginx proxy is not running${NC}"
    exit 1
fi

if ! docker ps | grep -q "ev-reth-sequencer"; then
    echo -e "${RED}✗ EV-Reth sequencer is not running${NC}"
    exit 1
fi

if ! docker ps | grep -q "evolve-sequencer"; then
    echo -e "${YELLOW}⚠ Evolve sequencer is not running (will restart)${NC}"
    docker restart evolve-sequencer
fi

# Test health endpoints
echo -e "\nTesting endpoints..."

# Test HTTP redirect
if curl -s -o /dev/null -w "%{http_code}" http://localhost/health | grep -q "301\|200"; then
    echo -e "${GREEN}✓ HTTP redirect working${NC}"
else
    echo -e "${YELLOW}⚠ HTTP redirect test failed${NC}"
fi

# Test HTTPS health
if curl -k -s -o /dev/null -w "%{http_code}" https://localhost/health | grep -q "200"; then
    echo -e "${GREEN}✓ HTTPS health check working${NC}"
else
    echo -e "${YELLOW}⚠ HTTPS health check failed${NC}"
fi

# Test RPC endpoint
if curl -s -X POST http://localhost/rpc \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | grep -q "0x181e"; then
    echo -e "${GREEN}✓ RPC endpoint working${NC}"
else
    echo -e "${YELLOW}⚠ RPC endpoint test failed${NC}"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo -e "1. Configure DNS records:"
echo -e "   ${GREEN}rpc.ande.network${NC}    A    189.28.81.202"
echo -e "   ${GREEN}ws.ande.network${NC}     A    189.28.81.202"
echo -e "   ${GREEN}api.ande.network${NC}    A    189.28.81.202"
echo -e "   ${GREEN}ande.network${NC}        A    189.28.81.202"
echo -e "   ${GREEN}www.ande.network${NC}    A    189.28.81.202"
echo ""
echo -e "2. Test endpoints:"
echo -e "   ${GREEN}https://rpc.ande.network/health${NC}"
echo -e "   ${GREEN}https://api.ande.network/info${NC}"
echo -e "   ${GREEN}https://ande.network${NC}"
echo ""
echo -e "3. Update MetaMask:"
echo -e "   Network Name: AndeChain Mainnet"
echo -e "   RPC URL: ${GREEN}https://rpc.ande.network${NC}"
echo -e "   Chain ID: ${GREEN}6174${NC}"
echo -e "   Currency Symbol: ${GREEN}ANDE${NC}"
echo ""
echo -e "${YELLOW}Note: SSL certificates will auto-renew every 60 days${NC}"
echo ""
