# AndeChain SSL/TLS Production Deployment Guide

**Version:** 1.0.0  
**Last Updated:** 2025-11-06  
**Environment:** Production  
**Author:** AndeChain Infrastructure Team

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Deployment Checklist](#deployment-checklist)
7. [Monitoring & Alerting](#monitoring--alerting)
8. [Maintenance](#maintenance)
9. [Troubleshooting](#troubleshooting)
10. [Rollback Procedure](#rollback-procedure)

---

## Overview

This deployment provides:

- **HTTPS/TLS Termination** for blockchain RPC endpoints
- **Reverse Proxy** to ev-reth-sequencer RPC node (localhost:8545)
- **WebSocket Support** for real-time blockchain connections
- **Security Hardening** with industry best practices
- **Automatic Certificate Renewal** from Let's Encrypt
- **High Availability** configuration with proper error handling
- **Comprehensive Logging** for monitoring and debugging

### Key Components

| Component | Version | Status |
|-----------|---------|--------|
| Nginx | 1.24.x | ✓ Production Ready |
| Certbot | 2.9.x | ✓ Production Ready |
| OpenSSL | 3.x | ✓ Production Ready |
| Linux | Ubuntu 24.04 LTS | ✓ Production Ready |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Internet Clients (MetaMask, Web3 Applications)           │
│         │                                                  │
│         ▼                                                  │
│  ┌──────────────────────────────────────┐                 │
│  │   Nginx (HTTPS Port 443)             │                 │
│  │   - SSL/TLS Termination              │                 │
│  │   - Reverse Proxy                    │                 │
│  │   - Rate Limiting                    │                 │
│  │   - CORS Headers                     │                 │
│  └──────────┬───────────────────────────┘                 │
│             │                                              │
│             ▼                                              │
│  ┌──────────────────────────────────────┐                 │
│  │   RPC Node (localhost:8545)          │                 │
│  │   - ev-reth-sequencer                │                 │
│  │   - Chain ID: 6174                   │                 │
│  │   - JSON-RPC 2.0 Compliant           │                 │
│  └──────────────────────────────────────┘                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### System Requirements

- **OS:** Ubuntu 24.04 LTS (WSL2 compatible)
- **CPU:** 2+ cores (4+ recommended)
- **RAM:** 4GB+ (8GB+ recommended)
- **Storage:** 50GB+ SSD
- **Network:** Static IP, ports 80/443 accessible from internet

### Software Requirements

- Nginx >= 1.24.0
- Certbot >= 2.9.0
- OpenSSL >= 3.0
- curl, openssl, systemctl

### DNS Configuration

- Domain: `rpc.ande.network` → IP: `189.28.81.202`
- Domain: `ws.ande.network` → IP: `189.28.81.202` (same IP, different domain)

### Access Requirements

- SSH access to server with sudo privileges
- Certificate email: admin@ande.network
- Ability to modify DNS records (for Let's Encrypt validation)

---

## Installation

### Step 1: Verify Prerequisites

```bash
# Check Ubuntu version
lsb_release -a

# Check internet connectivity
ping -c 1 rpc.ande.network

# Check DNS resolution
dig rpc.ande.network +short
# Expected: 189.28.81.202

# Check port accessibility
curl -I http://rpc.ande.network
# Expected: HTTP 200 or redirect
```

### Step 2: System Preparation

```bash
# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

# Install dependencies
sudo apt-get install -y \
    nginx \
    certbot \
    python3-certbot-nginx \
    curl \
    openssl \
    dnsutils

# Verify installations
nginx -v
certbot --version
openssl version
```

### Step 3: Deploy Configuration Files

```bash
# Copy production Nginx configuration
sudo cp infrastructure/nginx/nginx.conf.production \
         /etc/nginx/sites-available/rpc.ande.network

# Enable the site
sudo ln -sf /etc/nginx/sites-available/rpc.ande.network \
            /etc/nginx/sites-enabled/rpc.ande.network

# Remove default site
sudo rm -f /etc/nginx/sites-enabled/default

# Validate configuration
sudo nginx -t
# Expected: "syntax is ok" and "test is successful"
```

### Step 4: Install SSL Certificates

#### Option A: Let's Encrypt (Recommended)

```bash
# Stop Nginx temporarily for HTTP challenge
sudo systemctl stop nginx

# Obtain certificate (if port 80 is accessible)
sudo certbot certonly --standalone \
    -d rpc.ande.network \
    -d ws.ande.network \
    --agree-tos \
    --no-eff-email \
    -m admin@ande.network \
    --non-interactive

# Start Nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

#### Option B: Self-Signed (Temporary/Testing)

```bash
# Create self-signed certificate (valid 365 days)
sudo mkdir -p /etc/letsencrypt/live/rpc.ande.network

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/letsencrypt/live/rpc.ande.network/privkey.pem \
    -out /etc/letsencrypt/live/rpc.ande.network/fullchain.pem \
    -subj "/C=AR/ST=Buenos Aires/L=Buenos Aires/O=AndeChain/CN=rpc.ande.network"

# Fix permissions
sudo chmod 600 /etc/letsencrypt/live/rpc.ande.network/privkey.pem
sudo chmod 644 /etc/letsencrypt/live/rpc.ande.network/fullchain.pem

# Start Nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

### Step 5: Deploy Scripts

```bash
# Copy certificate renewal script
sudo cp infrastructure/scripts/renew-certificates.sh \
       /usr/local/bin/renew-certificates.sh

# Make executable
sudo chmod +x /usr/local/bin/renew-certificates.sh

# Copy validation script
sudo cp infrastructure/scripts/validate-ssl-setup.sh \
       /usr/local/bin/validate-ssl-setup.sh

sudo chmod +x /usr/local/bin/validate-ssl-setup.sh
```

### Step 6: Configure Cron Jobs

```bash
# Edit crontab
sudo crontab -e

# Add certificate renewal (runs at 2 AM and 2 PM)
0 2,14 * * * /usr/local/bin/renew-certificates.sh >> /var/log/ande-cert-renewal.log 2>&1

# Add daily validation (runs at 3 AM)
0 3 * * * /usr/local/bin/validate-ssl-setup.sh >> /var/log/ssl-validation.log 2>&1

# Save and exit
```

---

## Configuration

### Nginx Configuration

Location: `/etc/nginx/sites-available/rpc.ande.network`

**Key Settings:**

```nginx
# SSL Certificates
ssl_certificate /etc/letsencrypt/live/rpc.ande.network/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/rpc.ande.network/privkey.pem;

# TLS Configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;

# Proxy Backend
proxy_pass http://127.0.0.1:8545;
proxy_http_version 1.1;

# Rate Limiting
limit_req zone=rpc_limit burst=200 nodelay;
```

### Environment Variables

```bash
# For certificate renewal notifications
EMAIL_ENABLED=false
EMAIL_TO="admin@ande.network"

# For rate limiting
RPC_RATE_LIMIT="100r/s"
WS_RATE_LIMIT="50r/s"
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] System meets prerequisites
- [ ] DNS configured and resolving correctly
- [ ] Port 80/443 accessibility verified
- [ ] Backups taken of existing configuration
- [ ] Staging environment tested (if available)
- [ ] All team members notified of maintenance window

### Deployment

- [ ] Stop any running services that conflict
- [ ] Deploy Nginx configuration
- [ ] Validate Nginx configuration (`sudo nginx -t`)
- [ ] Deploy SSL certificates
- [ ] Deploy renewal and validation scripts
- [ ] Configure cron jobs
- [ ] Start Nginx service
- [ ] Enable Nginx auto-start

### Post-Deployment

- [ ] Run validation script: `sudo /usr/local/bin/validate-ssl-setup.sh`
- [ ] Test HTTP endpoint: `curl http://rpc.ande.network`
- [ ] Test HTTPS endpoint: `curl https://rpc.ande.network`
- [ ] Test RPC functionality:
  ```bash
  curl -X POST https://rpc.ande.network \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
  ```
- [ ] Verify logs: `sudo tail -50 /var/log/nginx/error.log`
- [ ] Check MetaMask connectivity
- [ ] Monitor for 24 hours before considering complete

---

## Monitoring & Alerting

### Log Files

| Log | Location | Purpose |
|-----|----------|---------|
| Nginx Access | `/var/log/nginx/access.log` | Request logs |
| Nginx Error | `/var/log/nginx/error.log` | Error tracking |
| Cert Renewal | `/var/log/ande-cert-renewal.log` | Certificate updates |
| Validation | `/var/log/ssl-validation.log` | Setup validation |

### Key Metrics to Monitor

```bash
# Check Nginx status
sudo systemctl status nginx

# Monitor live requests
tail -f /var/log/nginx/access.log

# Check certificate expiry
sudo certbot certificates

# Monitor RPC health
curl -s https://rpc.ande.network -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}'
```

### Alerting Rules

| Condition | Severity | Action |
|-----------|----------|--------|
| Certificate expires < 7 days | CRITICAL | Page on-call |
| Nginx service down | CRITICAL | Restart & page on-call |
| RPC endpoint unresponsive | HIGH | Investigate logs |
| Error rate > 5% | MEDIUM | Review logs & metrics |

---

## Maintenance

### Regular Tasks

#### Daily (Automated)

- Certificate renewal check
- SSL setup validation
- Log rotation

#### Weekly (Manual)

```bash
# Check certificate status
sudo certbot certificates

# Review error logs
sudo grep ERROR /var/log/nginx/error.log | tail -20

# Check RPC response times
grep "upstream_response_time" /var/log/nginx/access.log | tail -100 | \
  awk -F'"' '{print $NF}' | awk '{print $NF}' | sort -n | tail -10
```

#### Monthly (Manual)

```bash
# Full validation
sudo /usr/local/bin/validate-ssl-setup.sh

# Review certificate usage
sudo certbot certificates

# Clean old logs
sudo find /var/log/nginx -type f -mtime +30 -delete

# Test renewal process (dry-run)
sudo certbot renew --dry-run
```

#### Yearly (Manual)

- Complete security audit
- Certificate strategy review
- Dependency updates
- Documentation updates

### Backup Procedures

```bash
# Backup certificate and configuration
sudo tar -czf /mnt/backup/ande-ssl-backup-$(date +%Y%m%d).tar.gz \
    /etc/letsencrypt/ \
    /etc/nginx/sites-available/rpc.ande.network

# Verify backup
tar -tzf /mnt/backup/ande-ssl-backup-*.tar.gz | head -20
```

---

## Troubleshooting

### Common Issues

#### Issue: Certificate Renewal Fails

```bash
# Check logs
tail -50 /var/log/ande-cert-renewal.log

# Verify DNS
dig rpc.ande.network

# Test manual renewal
sudo certbot renew --dry-run -v

# Check port 80 accessibility
sudo ss -tlnp | grep :80
```

#### Issue: HTTPS Not Working

```bash
# Test Nginx
sudo nginx -t

# Check certificate
sudo openssl x509 -text -noout -in \
    /etc/letsencrypt/live/rpc.ande.network/fullchain.pem

# Check ports
sudo ss -tlnp | grep -E ":(80|443)"

# Test HTTPS locally
curl -k https://localhost
```

#### Issue: RPC Endpoint Unresponsive

```bash
# Check RPC service
curl http://localhost:8545 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Check Nginx proxy
curl -k https://localhost -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Check logs
tail -50 /var/log/nginx/error.log
```

### Performance Tuning

```bash
# Check current connections
netstat -an | grep ESTABLISHED | wc -l

# Monitor CPU usage
top -b -n 1 | grep nginx

# Check memory usage
free -h

# Review slow requests
grep "upstream_response_time" /var/log/nginx/access.log | \
  awk '$NF > 1 {print}' | tail -20
```

---

## Rollback Procedure

### Quick Rollback (< 5 minutes)

```bash
# 1. Disable new configuration
sudo rm /etc/nginx/sites-enabled/rpc.ande.network

# 2. Restore previous Nginx config if available
sudo cp /path/to/backup/nginx.conf.backup \
        /etc/nginx/sites-available/rpc.ande.network
sudo ln -s /etc/nginx/sites-available/rpc.ande.network \
           /etc/nginx/sites-enabled/

# 3. Test configuration
sudo nginx -t

# 4. Reload Nginx
sudo systemctl reload nginx

# 5. Verify
curl -I https://rpc.ande.network
```

### Full Rollback (from backup)

```bash
# 1. Backup current state
sudo tar -czf /mnt/backup/rollback-$(date +%s).tar.gz \
    /etc/letsencrypt/ \
    /etc/nginx/ \
    /usr/local/bin/renew-certificates.sh

# 2. Restore from backup
sudo tar -xzf /mnt/backup/ande-ssl-backup-YYYYMMDD.tar.gz -C /

# 3. Verify restoration
sudo nginx -t
sudo certbot certificates

# 4. Reload services
sudo systemctl reload nginx
```

---

## Contact & Support

**Infrastructure Team:** infrastructure@ande.network  
**On-Call:** Check on-call rotation schedule  
**Escalation:** Reach out to senior infrastructure engineer

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-11-06 | Infrastructure Team | Initial production release |

---

**Document Status:** APPROVED FOR PRODUCTION  
**Last Review:** 2025-11-06  
**Next Review:** 2026-11-06
