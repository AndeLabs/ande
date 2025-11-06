#!/bin/bash

################################################################################
# AndeChain SSL Setup Validation Script
# ====================================
# Version: 1.0.0
# Purpose: Comprehensive validation of SSL/TLS setup for production
# Environment: Production
# Author: AndeChain Infrastructure Team
#
# This script validates:
# - Certificate validity and expiry
# - TLS/SSL protocol versions
# - Cipher strength
# - CORS headers
# - Security headers
# - RPC connectivity
# - WebSocket functionality
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counter for results
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASS_COUNT++))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAIL_COUNT++))
}

print_warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
    ((WARN_COUNT++))
}

print_info() {
    echo -e "${BLUE}ℹ INFO${NC}: $1"
}

# ============================================================================
# Certificate Validation
# ============================================================================

validate_certificate_files() {
    print_header "Certificate File Validation"
    
    local cert_dir="/etc/letsencrypt/live/rpc.ande.network"
    
    # Check directory exists
    if [[ ! -d "${cert_dir}" ]]; then
        print_fail "Certificate directory does not exist: ${cert_dir}"
        return 1
    fi
    print_pass "Certificate directory exists"
    
    # Check fullchain.pem
    if [[ ! -f "${cert_dir}/fullchain.pem" ]]; then
        print_fail "fullchain.pem not found"
        return 1
    fi
    print_pass "fullchain.pem exists"
    
    # Check privkey.pem
    if [[ ! -f "${cert_dir}/privkey.pem" ]]; then
        print_fail "privkey.pem not found"
        return 1
    fi
    print_pass "privkey.pem exists"
    
    # Check permissions
    local privkey_perms=$(stat -c %a "${cert_dir}/privkey.pem")
    if [[ "${privkey_perms}" == "600" ]] || [[ "${privkey_perms}" == "400" ]]; then
        print_pass "privkey.pem has correct permissions (${privkey_perms})"
    else
        print_warn "privkey.pem has unusual permissions (${privkey_perms})"
    fi
}

validate_certificate_content() {
    print_header "Certificate Content Validation"
    
    local cert_file="/etc/letsencrypt/live/rpc.ande.network/fullchain.pem"
    
    # Check if valid X.509 certificate
    if ! openssl x509 -in "${cert_file}" -noout 2>/dev/null; then
        print_fail "Invalid X.509 certificate format"
        return 1
    fi
    print_pass "Valid X.509 certificate format"
    
    # Check certificate subject
    local subject=$(openssl x509 -subject -noout -in "${cert_file}")
    echo "  ${subject}"
    
    if echo "${subject}" | grep -q "rpc.ande.network"; then
        print_pass "Certificate is for rpc.ande.network"
    else
        print_warn "Certificate subject may not match domain"
    fi
    
    # Check expiry
    local expiry_date=$(openssl x509 -enddate -noout -in "${cert_file}" | cut -d= -f 2)
    local expiry_epoch=$(date -d "${expiry_date}" +%s)
    local current_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    echo "  Expires: ${expiry_date} (${days_left} days remaining)"
    
    if [[ ${days_left} -lt 0 ]]; then
        print_fail "Certificate has expired"
        return 1
    elif [[ ${days_left} -lt 7 ]]; then
        print_fail "Certificate expires in less than 7 days"
        return 1
    elif [[ ${days_left} -lt 30 ]]; then
        print_warn "Certificate expires in less than 30 days"
    else
        print_pass "Certificate is valid and has sufficient expiry time"
    fi
    
    # Check certificate chain
    local chain_count=$(grep -c "BEGIN CERTIFICATE" "${cert_file}")
    echo "  Certificate chain length: ${chain_count}"
    if [[ ${chain_count} -ge 2 ]]; then
        print_pass "Certificate chain contains intermediate certificates"
    else
        print_warn "Certificate chain may be incomplete"
    fi
}

# ============================================================================
# TLS/SSL Protocol Validation
# ============================================================================

validate_tls_protocols() {
    print_header "TLS/SSL Protocol Validation"
    
    # Test TLS 1.3
    if timeout 5 openssl s_client -connect localhost:443 -tls1_3 </dev/null 2>&1 | grep -q "TLSv1.3"; then
        print_pass "TLS 1.3 is supported"
    else
        print_warn "TLS 1.3 may not be supported"
    fi
    
    # Test TLS 1.2
    if timeout 5 openssl s_client -connect localhost:443 -tls1_2 </dev/null 2>&1 | grep -q "TLSv1.2"; then
        print_pass "TLS 1.2 is supported"
    else
        print_fail "TLS 1.2 is not supported"
    fi
    
    # Test weak TLS 1.1 (should NOT be supported)
    if timeout 5 openssl s_client -connect localhost:443 -tls1_1 </dev/null 2>&1 | grep -q "TLSv1.1"; then
        print_fail "TLS 1.1 is enabled (should be disabled)"
    else
        print_pass "TLS 1.1 is properly disabled"
    fi
    
    # Test SSL 3.0 (should NOT be supported)
    if timeout 5 openssl s_client -connect localhost:443 -ssl3 </dev/null 2>&1 | grep -q "SSLv3"; then
        print_fail "SSL 3.0 is enabled (should be disabled)"
    else
        print_pass "SSL 3.0 is properly disabled"
    fi
}

validate_cipher_suites() {
    print_header "Cipher Suite Validation"
    
    local ciphers=$(openssl s_client -connect localhost:443 -cipher HIGH 2>&1 | grep "Cipher" | head -1)
    
    if echo "${ciphers}" | grep -q "ECDHE"; then
        print_pass "ECDHE (Perfect Forward Secrecy) is enabled"
    else
        print_warn "ECDHE (Perfect Forward Secrecy) may not be primary cipher"
    fi
    
    if echo "${ciphers}" | grep -q "AES"; then
        print_pass "AES encryption is available"
    else
        print_warn "AES encryption may not be available"
    fi
    
    # Check for weak ciphers (should be disabled)
    if openssl s_client -connect localhost:443 -cipher NULL,EXPORT,eNULL,aNULL 2>&1 | grep -q "Cipher"; then
        print_fail "Weak ciphers are enabled"
    else
        print_pass "Weak ciphers are properly disabled"
    fi
}

# ============================================================================
# Security Headers Validation
# ============================================================================

validate_security_headers() {
    print_header "Security Headers Validation"
    
    local headers=$(curl -sk -I https://localhost 2>/dev/null || echo "")
    
    # HSTS
    if echo "${headers}" | grep -qi "Strict-Transport-Security"; then
        print_pass "HSTS header is present"
        local hsts_value=$(echo "${headers}" | grep -i "Strict-Transport-Security" | head -1)
        echo "  ${hsts_value}"
    else
        print_fail "HSTS header is missing"
    fi
    
    # X-Content-Type-Options
    if echo "${headers}" | grep -qi "X-Content-Type-Options"; then
        print_pass "X-Content-Type-Options header is present"
    else
        print_fail "X-Content-Type-Options header is missing"
    fi
    
    # X-Frame-Options
    if echo "${headers}" | grep -qi "X-Frame-Options"; then
        print_pass "X-Frame-Options header is present"
    else
        print_fail "X-Frame-Options header is missing"
    fi
    
    # X-XSS-Protection
    if echo "${headers}" | grep -qi "X-XSS-Protection"; then
        print_pass "X-XSS-Protection header is present"
    else
        print_warn "X-XSS-Protection header is missing (older browsers only)"
    fi
}

# ============================================================================
# CORS Headers Validation
# ============================================================================

validate_cors_headers() {
    print_header "CORS Headers Validation"
    
    local cors_response=$(curl -sk -H "Origin: http://example.com" \
        -H "Access-Control-Request-Method: POST" \
        -X OPTIONS https://localhost 2>/dev/null || echo "")
    
    if echo "${cors_response}" | grep -qi "Access-Control-Allow-Origin"; then
        print_pass "CORS Allow-Origin header is present"
        local cors_value=$(echo "${cors_response}" | grep -i "Access-Control-Allow-Origin" | head -1)
        echo "  ${cors_value}"
    else
        print_warn "CORS Allow-Origin header may be missing"
    fi
    
    if echo "${cors_response}" | grep -qi "Access-Control-Allow-Methods"; then
        print_pass "CORS Allow-Methods header is present"
    else
        print_warn "CORS Allow-Methods header may be missing"
    fi
}

# ============================================================================
# RPC Functionality Validation
# ============================================================================

validate_rpc_http() {
    print_header "RPC HTTP Validation"
    
    local response=$(curl -sk -X POST https://localhost \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        2>/dev/null || echo "{\"error\":\"failed\"}")
    
    if echo "${response}" | grep -q "0x181e"; then
        print_pass "RPC HTTP endpoint is functional (Chain ID: 6174)"
        echo "  Response: ${response}"
    else
        print_fail "RPC HTTP endpoint returned unexpected response"
        echo "  Response: ${response}"
    fi
}

validate_rpc_https_redirect() {
    print_header "HTTPS Redirect Validation"
    
    local response=$(curl -s -w "%{http_code}" -o /dev/null http://rpc.ande.network/ 2>/dev/null || echo "000")
    
    if [[ "${response}" == "301" ]] || [[ "${response}" == "302" ]]; then
        print_pass "HTTP correctly redirects to HTTPS"
    else
        print_warn "HTTP redirect status is ${response} (expected 301/302)"
    fi
}

validate_websocket() {
    print_header "WebSocket Validation"
    
    # Use curl to test WebSocket upgrade
    local ws_response=$(curl -sk -N \
        -H "Connection: Upgrade" \
        -H "Upgrade: websocket" \
        -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
        -H "Sec-WebSocket-Version: 13" \
        https://localhost 2>&1 || echo "")
    
    if echo "${ws_response}" | grep -qi "upgrade"; then
        print_pass "WebSocket upgrade header is supported"
    else
        print_info "WebSocket testing completed (may require specialized client)"
    fi
}

# ============================================================================
# Service Validation
# ============================================================================

validate_nginx_service() {
    print_header "Nginx Service Validation"
    
    # Check if running
    if systemctl -q is-active nginx; then
        print_pass "Nginx service is running"
    else
        print_fail "Nginx service is not running"
        return 1
    fi
    
    # Check if enabled
    if systemctl -q is-enabled nginx; then
        print_pass "Nginx service is enabled for auto-start"
    else
        print_warn "Nginx service is not enabled for auto-start"
    fi
    
    # Check configuration
    if sudo nginx -t 2>&1 | grep -q "successful"; then
        print_pass "Nginx configuration is valid"
    else
        print_fail "Nginx configuration test failed"
    fi
}

validate_port_listening() {
    print_header "Port Listening Validation"
    
    # Check port 80
    if sudo ss -tlnp 2>/dev/null | grep -q ":80 "; then
        print_pass "Port 80 (HTTP) is listening"
    else
        print_fail "Port 80 (HTTP) is not listening"
    fi
    
    # Check port 443
    if sudo ss -tlnp 2>/dev/null | grep -q ":443 "; then
        print_pass "Port 443 (HTTPS) is listening"
    else
        print_fail "Port 443 (HTTPS) is not listening"
    fi
    
    # Check RPC port
    if sudo ss -tlnp 2>/dev/null | grep -q ":8545 "; then
        print_pass "Port 8545 (RPC) is listening"
    else
        print_fail "Port 8545 (RPC) is not listening"
    fi
}

validate_certbot() {
    print_header "Certbot Configuration Validation"
    
    if command -v certbot &> /dev/null; then
        print_pass "Certbot is installed"
        local version=$(certbot --version 2>/dev/null | head -1)
        echo "  ${version}"
    else
        print_fail "Certbot is not installed"
        return 1
    fi
    
    # Check certificate list
    local cert_count=$(sudo certbot certificates 2>/dev/null | grep "Certificate Name" | wc -l)
    if [[ ${cert_count} -gt 0 ]]; then
        print_pass "Certbot has ${cert_count} certificate(s) configured"
    else
        print_warn "No certificates found in Certbot"
    fi
    
    # Check renewal timer
    if systemctl -q is-active certbot.timer 2>/dev/null; then
        print_pass "Certbot renewal timer is active"
    else
        print_warn "Certbot renewal timer is not active"
    fi
}

# ============================================================================
# Summary
# ============================================================================

print_summary() {
    print_header "Validation Summary"
    
    local total=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
    
    echo -e "Total checks: ${total}"
    echo -e "${GREEN}Passed: ${PASS_COUNT}${NC}"
    echo -e "${YELLOW}Warnings: ${WARN_COUNT}${NC}"
    echo -e "${RED}Failed: ${FAIL_COUNT}${NC}"
    
    echo ""
    
    if [[ ${FAIL_COUNT} -eq 0 ]]; then
        if [[ ${WARN_COUNT} -eq 0 ]]; then
            echo -e "${GREEN}✓ All validation checks passed!${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Validation passed with warnings. Review them above.${NC}"
            return 0
        fi
    else
        echo -e "${RED}✗ Validation failed! Fix the errors above.${NC}"
        return 1
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    echo -e "${BLUE}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║     AndeChain SSL/TLS Setup Validation                        ║
║     Production Environment                                    ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    validate_certificate_files
    validate_certificate_content
    validate_tls_protocols
    validate_cipher_suites
    validate_security_headers
    validate_cors_headers
    validate_rpc_http
    validate_rpc_https_redirect
    validate_websocket
    validate_nginx_service
    validate_port_listening
    validate_certbot
    
    print_summary
}

main "$@"
