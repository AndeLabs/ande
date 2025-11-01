# 🚀 AndeChain Production Deployment Guide

## 📋 Overview

This guide covers the complete production deployment of AndeChain with:
- ✅ SSL/TLS certificates (Let's Encrypt)
- ✅ Professional subdomain structure
- ✅ Rate limiting and security
- ✅ High availability configuration
- ✅ Auto-renewal of certificates
- ✅ CORS and security headers

---

## 🌐 Production Architecture

### Domains Structure

| Domain | Purpose | Backend |
|--------|---------|---------|
| `rpc.ande.network` | JSON-RPC endpoint | ev-reth-sequencer:8545 |
| `ws.ande.network` | WebSocket endpoint | ev-reth-sequencer:8546 |
| `api.ande.network` | REST API & utilities | Multiple services |
| `ande.network` | Main website | Static landing page |
| `www.ande.network` | WWW redirect | Redirects to ande.network |

### Security Features

- **SSL/TLS**: All traffic encrypted with Let's Encrypt certificates
- **Rate Limiting**: 
  - RPC: 10 req/s per IP (burst: 20)
  - API: 50 req/s per IP (burst: 50)
  - WebSocket: 5 concurrent connections per IP
- **CORS**: Properly configured for web3 applications
- **HSTS**: Strict-Transport-Security enabled
- **DDoS Protection**: Connection limits and timeouts

---

## 🔧 Prerequisites

### 1. Server Requirements

```bash
# Minimum specifications
- OS: Ubuntu 20.04 LTS or later
- RAM: 16GB minimum, 32GB recommended
- CPU: 4 cores minimum, 8 cores recommended
- Disk: 500GB SSD minimum
- Network: Static public IP address
```

### 2. Required Software

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt-get update
sudo apt-get install -y docker-compose

# Install Certbot
sudo apt-get install -y certbot python3-certbot-nginx

# Install nginx (for certbot plugin)
sudo apt-get install -y nginx
```

### 3. DNS Configuration

**IMPORTANT**: Configure these DNS records **BEFORE** running the deployment script:

```
# A Records (point to your server's public IP: 189.28.81.202)
rpc.ande.network.    IN  A  189.28.81.202
ws.ande.network.     IN  A  189.28.81.202
api.ande.network.    IN  A  189.28.81.202
ande.network.        IN  A  189.28.81.202
www.ande.network.    IN  A  189.28.81.202

# Optional: AAAA Records for IPv6
rpc.ande.network.    IN  AAAA  YOUR_IPV6_ADDRESS
ws.ande.network.     IN  AAAA  YOUR_IPV6_ADDRESS
api.ande.network.    IN  AAAA  YOUR_IPV6_ADDRESS
ande.network.        IN  AAAA  YOUR_IPV6_ADDRESS
www.ande.network.    IN  AAAA  YOUR_IPV6_ADDRESS
```

**DNS Propagation Check**:
```bash
# Verify DNS is propagated (wait 5-60 minutes after configuring DNS)
nslookup rpc.ande.network
nslookup ws.ande.network
nslookup api.ande.network
nslookup ande.network
```

---

## 📦 Deployment Steps

### Step 1: Prepare the Environment

```bash
cd /mnt/c/Users/sator/andelabs/ande/infra/stacks/single-sequencer

# Make deployment script executable
chmod +x deploy-production.sh

# Verify current services are running
docker ps
```

### Step 2: Test with Staging (Optional but Recommended)

```bash
# Use Let's Encrypt staging server for testing
sudo ./deploy-production.sh staging
```

This will:
- Obtain staging SSL certificates (won't be trusted by browsers)
- Deploy nginx configuration
- Test the full setup

### Step 3: Production Deployment

```bash
# Deploy to production
sudo ./deploy-production.sh production
```

The script will:
1. ✅ Check prerequisites
2. ✅ Backup current configuration
3. ✅ Install/update Certbot
4. ✅ Obtain SSL certificates for all domains
5. ✅ Deploy production nginx configuration
6. ✅ Restart Docker containers
7. ✅ Configure auto-renewal
8. ✅ Verify deployment

### Step 4: Verification

```bash
# Test HTTP to HTTPS redirect
curl -I http://rpc.ande.network

# Test RPC endpoint
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Expected response: {"jsonrpc":"2.0","id":1,"result":"0x181e"}

# Test API endpoint
curl https://api.ande.network/info

# Test WebSocket (requires websocat or wscat)
websocat wss://ws.ande.network

# Test main website
curl https://ande.network
```

---

## 🔒 Security Configuration

### Firewall Setup

```bash
# Install ufw (Uncomplicated Firewall)
sudo apt-get install -y ufw

# Allow SSH (IMPORTANT: Do this first!)
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable
sudo ufw status
```

### SSL Certificate Auto-Renewal

Certificates auto-renew via cron job at `/etc/cron.daily/certbot-renewal`.

Manual renewal:
```bash
# Test renewal (dry run)
sudo certbot renew --dry-run

# Force renewal
sudo certbot renew --force-renewal

# Restart nginx after renewal
docker restart nginx-proxy
```

### Rate Limiting Configuration

Edit `nginx-production.conf` to adjust rate limits:

```nginx
# Standard RPC (10 req/s)
limit_req_zone $binary_remote_addr zone=rpc_standard:10m rate=10r/s;

# Premium RPC (100 req/s) - for whitelisted IPs
limit_req_zone $binary_remote_addr zone=rpc_premium:10m rate=100r/s;

# WebSocket connections (5 concurrent)
limit_conn_zone $binary_remote_addr zone=ws_limit:10m;
```

---

## 📊 Monitoring

### Health Checks

```bash
# RPC health
curl https://rpc.ande.network/health

# API health
curl https://api.ande.network/health

# Check all containers
docker ps

# View logs
docker logs nginx-proxy -f
docker logs ev-reth-sequencer -f
docker logs evolve-sequencer -f
```

### Metrics Endpoints

```bash
# Prometheus metrics (protected)
https://api.ande.network/metrics

# Grafana dashboard
https://api.ande.network/grafana
```

---

## 🔧 Maintenance

### Update Nginx Configuration

```bash
# Edit configuration
nano nginx-production.conf

# Test configuration
docker run --rm -v $(pwd)/nginx-production.conf:/etc/nginx/nginx.conf:ro \
  nginx:alpine nginx -t

# Apply changes
docker restart nginx-proxy
```

### Restart Services

```bash
# Restart individual services
docker restart nginx-proxy
docker restart ev-reth-sequencer
docker restart evolve-sequencer

# Restart all services
docker restart $(docker ps -q)
```

### View Logs

```bash
# Real-time logs
docker logs -f nginx-proxy
docker logs -f ev-reth-sequencer
docker logs -f evolve-sequencer

# Last 100 lines
docker logs --tail 100 nginx-proxy

# JSON formatted logs
docker logs nginx-proxy 2>&1 | grep -E '\{.*\}'
```

### Backup

```bash
# Manual backup
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup configuration
cp nginx-production.conf "$BACKUP_DIR/"
cp .env.ande.testnet "$BACKUP_DIR/"

# Backup SSL certificates
sudo cp -r /etc/letsencrypt "$BACKUP_DIR/"

# Export Docker volumes
docker run --rm -v ev-reth-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/${BACKUP_DIR}/ev-reth-data.tar.gz -C /data .
```

---

## 🌍 MetaMask Configuration

Users can add AndeChain to MetaMask:

```javascript
{
  "chainId": "0x181e", // 6174 in decimal
  "chainName": "AndeChain Mainnet",
  "nativeCurrency": {
    "name": "ANDE",
    "symbol": "ANDE",
    "decimals": 18
  },
  "rpcUrls": ["https://rpc.ande.network"],
  "blockExplorerUrls": ["https://explorer.ande.network"]
}
```

### Add Network Button (for websites)

```javascript
async function addAndeChain() {
  try {
    await window.ethereum.request({
      method: 'wallet_addEthereumChain',
      params: [{
        chainId: '0x181e',
        chainName: 'AndeChain Mainnet',
        nativeCurrency: {
          name: 'ANDE',
          symbol: 'ANDE',
          decimals: 18
        },
        rpcUrls: ['https://rpc.ande.network'],
        blockExplorerUrls: ['https://explorer.ande.network']
      }]
    });
  } catch (error) {
    console.error('Failed to add AndeChain:', error);
  }
}
```

---

## 🚨 Troubleshooting

### Issue: SSL Certificate Failed

```bash
# Check DNS propagation
nslookup rpc.ande.network

# Check port 80 is accessible
curl -I http://rpc.ande.network

# Retry certificate with verbose logging
sudo certbot certonly --standalone \
  --non-interactive \
  --agree-tos \
  --email admin@ande.network \
  -d rpc.ande.network \
  --verbose
```

### Issue: RPC Not Responding

```bash
# Check if ev-reth-sequencer is running
docker ps | grep ev-reth-sequencer

# Check logs
docker logs ev-reth-sequencer --tail 100

# Restart service
docker restart ev-reth-sequencer

# Test direct connection (bypass nginx)
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

### Issue: High CPU/Memory Usage

```bash
# Check resource usage
docker stats

# Check specific container
docker stats ev-reth-sequencer

# Restart resource-heavy container
docker restart ev-reth-sequencer
```

### Issue: Rate Limiting Too Aggressive

```bash
# Edit nginx config
nano nginx-production.conf

# Find and adjust rate limits
# Example: Change from 10r/s to 50r/s
limit_req_zone $binary_remote_addr zone=rpc_standard:10m rate=50r/s;

# Restart nginx
docker restart nginx-proxy
```

---

## 📞 Support

- **Documentation**: https://docs.ande.network
- **GitHub**: https://github.com/andechain
- **Discord**: https://discord.gg/andechain
- **Email**: admin@ande.network

---

## ✅ Production Checklist

Before going live, verify:

- [ ] DNS records configured and propagated
- [ ] SSL certificates obtained for all domains
- [ ] Nginx configuration deployed
- [ ] All Docker containers running (ev-reth, evolve, nginx)
- [ ] Health checks passing
- [ ] RPC endpoint responding correctly
- [ ] WebSocket endpoint working
- [ ] Rate limiting configured
- [ ] Firewall rules applied
- [ ] SSL auto-renewal configured
- [ ] Monitoring dashboards accessible
- [ ] Backup strategy in place
- [ ] Documentation updated
- [ ] Team notified

---

## 📝 Notes

- **Chain ID**: 6174 (0x181e)
- **Native Currency**: ANDE
- **Block Time**: ~2 seconds
- **Consensus**: Evolve (optimistic rollup)
- **DA Layer**: Celestia Mocha-4
- **Token Duality**: ANDE functions as both native currency and ERC-20

---

**Last Updated**: 2025-11-01
**Version**: 1.0.0
**Status**: Production Ready ✅
