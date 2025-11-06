#!/bin/bash

################################################################################
# AndeChain SSL Certificate Renewal Script
# ============================================
# Version: 1.0.0
# Purpose: Automatically renew SSL certificates from Let's Encrypt
# Environment: Production
# Author: AndeChain Infrastructure Team
#
# Features:
# - Robust error handling and logging
# - Certificate expiry monitoring
# - Automatic renewal with validation
# - Nginx reload with health check
# - Email notifications for failures
# - Lock file to prevent concurrent executions
#
# Usage: ./renew-certificates.sh [--force] [--dry-run] [--verbose]
# Cron: 0 2,14 * * * /usr/local/bin/renew-certificates.sh >> /var/log/cert-renewal.log 2>&1
################################################################################

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"

# Logging
LOG_FILE="/var/log/ande-cert-renewal.log"
ERROR_LOG="/var/log/ande-cert-renewal-error.log"
LOCK_FILE="/var/run/ande-cert-renewal.lock"
LOCK_TIMEOUT=3600  # 1 hour

# Certificate paths
CERT_DIR="/etc/letsencrypt/live"
DOMAINS=("rpc.ande.network" "ws.ande.network" "api.ande.network" "explorer.ande.network" "status.ande.network" "faucet.ande.network")
PRIMARY_DOMAIN="rpc.ande.network"

# Services
NGINX_SERVICE="nginx"
SYSTEMCTL_CMD="systemctl"

# Thresholds
RENEWAL_THRESHOLD_DAYS=30  # Renew if less than 30 days
CHECK_THRESHOLD_DAYS=7     # Warn if less than 7 days

# Notification
EMAIL_ENABLED=false
EMAIL_TO="admin@ande.network"
HOSTNAME=$(hostname)

# Flags
DRY_RUN=false
VERBOSE=false
FORCE_RENEWAL=false

# ============================================================================
# Functions
# ============================================================================

# Logging functions
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_error() {
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [ERROR] ${message}" | tee -a "${ERROR_LOG}" >&2
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_debug() {
    if [[ "${VERBOSE}" == true ]]; then
        log "DEBUG" "$@"
    fi
}

# Lock management
acquire_lock() {
    local lock_pid=""
    
    if [[ -f "${LOCK_FILE}" ]]; then
        lock_pid=$(cat "${LOCK_FILE}" 2>/dev/null || echo "")
        if [[ -n "${lock_pid}" ]] && kill -0 "${lock_pid}" 2>/dev/null; then
            log_error "Another instance is running (PID: ${lock_pid})"
            return 1
        else
            log_warn "Removing stale lock file"
            rm -f "${LOCK_FILE}"
        fi
    fi
    
    echo $$ > "${LOCK_FILE}"
    log_debug "Lock acquired (PID: $$)"
    return 0
}

release_lock() {
    rm -f "${LOCK_FILE}"
    log_debug "Lock released"
}

# Certificate functions
get_certificate_expiry() {
    local domain=$1
    local cert_file="${CERT_DIR}/${domain}/fullchain.pem"
    
    if [[ ! -f "${cert_file}" ]]; then
        echo ""
        return 1
    fi
    
    openssl x509 -enddate -noout -in "${cert_file}" | cut -d= -f 2
}

get_days_until_expiry() {
    local domain=$1
    local expiry_date
    
    expiry_date=$(get_certificate_expiry "$domain")
    if [[ -z "${expiry_date}" ]]; then
        echo "-1"
        return 1
    fi
    
    local expiry_epoch
    expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null || echo "0")
    local current_epoch
    current_epoch=$(date +%s)
    
    if [[ ${expiry_epoch} -eq 0 ]]; then
        echo "-1"
        return 1
    fi
    
    echo $(( (expiry_epoch - current_epoch) / 86400 ))
}

check_certificate_status() {
    local domain=$1
    local days_left
    
    days_left=$(get_days_until_expiry "$domain")
    
    if [[ ${days_left} -lt 0 ]]; then
        log_error "Certificate for ${domain} has expired or status unknown!"
        return 1
    fi
    
    if [[ ${days_left} -lt ${CHECK_THRESHOLD_DAYS} ]]; then
        log_warn "Certificate for ${domain} expires in ${days_left} days (CRITICAL)"
        return 2
    elif [[ ${days_left} -lt ${RENEWAL_THRESHOLD_DAYS} ]]; then
        log_info "Certificate for ${domain} expires in ${days_left} days (renewal recommended)"
        return 0
    else
        log_debug "Certificate for ${domain} is valid for ${days_left} more days"
        return 3
    fi
}

check_all_certificates() {
    local needs_renewal=0
    local any_critical=0
    
    log_info "Checking certificate status..."
    
    for domain in "${DOMAINS[@]}"; do
        check_certificate_status "$domain"
        local status=$?
        
        case ${status} in
            1)  # Expired
                any_critical=1
                ;;
            2)  # Less than 7 days
                any_critical=1
                ;;
            0)  # Less than 30 days
                needs_renewal=1
                ;;
        esac
    done
    
    if [[ ${any_critical} -eq 1 ]]; then
        log_error "One or more certificates are in critical condition!"
        return 2
    elif [[ ${needs_renewal} -eq 1 ]] || [[ "${FORCE_RENEWAL}" == true ]]; then
        log_info "Certificate renewal is needed"
        return 0
    else
        log_info "All certificates are valid, no renewal needed"
        return 1
    fi
}

renew_certificates() {
    log_info "Starting certificate renewal..."
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "DRY RUN MODE - No changes will be made"
        certbot renew --dry-run --quiet 2>&1 | tee -a "${LOG_FILE}" || {
            log_error "Certificate renewal dry-run failed"
            return 1
        }
    else
        log_info "Running certbot renewal..."
        certbot renew --quiet 2>&1 | tee -a "${LOG_FILE}" || {
            log_error "Certificate renewal failed"
            send_notification "Certificate Renewal Failed" "Certbot renewal process failed on ${HOSTNAME}. Check ${ERROR_LOG}"
            return 1
        }
    fi
    
    log_info "Certificate renewal completed successfully"
    return 0
}

validate_nginx_config() {
    log_info "Validating Nginx configuration..."
    
    if ! ${SYSTEMCTL_CMD} -q is-active ${NGINX_SERVICE}; then
        log_warn "Nginx is not running"
        return 1
    fi
    
    if ! nginx -t 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "Nginx configuration test failed"
        return 1
    fi
    
    log_debug "Nginx configuration is valid"
    return 0
}

reload_nginx() {
    log_info "Reloading Nginx..."
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "DRY RUN MODE - Skipping Nginx reload"
        return 0
    fi
    
    if ! ${SYSTEMCTL_CMD} reload ${NGINX_SERVICE} 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "Failed to reload Nginx"
        send_notification "Nginx Reload Failed" "Failed to reload Nginx on ${HOSTNAME}"
        return 1
    fi
    
    sleep 2  # Give Nginx time to reload
    
    if ! ${SYSTEMCTL_CMD} -q is-active ${NGINX_SERVICE}; then
        log_error "Nginx stopped after reload!"
        ${SYSTEMCTL_CMD} restart ${NGINX_SERVICE}
        send_notification "Nginx Restart Required" "Nginx stopped after reload on ${HOSTNAME}. Restarted."
        return 1
    fi
    
    log_info "Nginx reloaded successfully"
    return 0
}

health_check_rpc() {
    log_info "Performing RPC health check..."
    
    local response
    local status_code
    
    response=$(curl -s -w "\n%{http_code}" -k https://localhost -X POST \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        2>&1 || echo "")
    
    status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [[ "${status_code}" != "200" ]]; then
        log_error "RPC health check failed (HTTP ${status_code})"
        return 1
    fi
    
    if echo "${body}" | grep -q "0x181e"; then
        log_info "RPC health check passed (Chain ID: 6174)"
        return 0
    else
        log_error "RPC health check failed (unexpected response)"
        log_debug "Response: ${body}"
        return 1
    fi
}

send_notification() {
    if [[ "${EMAIL_ENABLED}" == true ]]; then
        local subject=$1
        local message=$2
        
        {
            echo "Subject: [AndeChain] ${subject}"
            echo "From: noreply@ande.network"
            echo "To: ${EMAIL_TO}"
            echo ""
            echo "${message}"
            echo ""
            echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "Host: ${HOSTNAME}"
        } | sendmail "${EMAIL_TO}" 2>/dev/null || {
            log_warn "Failed to send email notification"
        }
    fi
}

show_usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
    --force         Force certificate renewal even if not needed
    --dry-run       Run in dry-run mode (no changes)
    --verbose       Enable verbose logging
    --help          Show this help message

Examples:
    ${SCRIPT_NAME}                  # Normal execution
    ${SCRIPT_NAME} --dry-run        # Test without making changes
    ${SCRIPT_NAME} --force --verbose # Force renewal with detailed logging

EOF
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_RENEWAL=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Acquire lock
    if ! acquire_lock; then
        exit 1
    fi
    
    trap release_lock EXIT
    
    log_info "=== Certificate Renewal Script Started ==="
    log_info "Mode: $([ "${DRY_RUN}" == true ] && echo "DRY-RUN" || echo "PRODUCTION")"
    
    # Check certificate status
    if ! check_all_certificates; then
        if [[ $? -ne 1 ]]; then
            log_error "Certificate status check failed"
            release_lock
            exit 1
        fi
        log_info "No renewal needed at this time"
        exit 0
    fi
    
    # Validate Nginx before attempting renewal
    if ! validate_nginx_config; then
        log_error "Nginx configuration validation failed, aborting renewal"
        send_notification "Nginx Config Invalid" "Nginx configuration validation failed on ${HOSTNAME}"
        release_lock
        exit 1
    fi
    
    # Renew certificates
    if ! renew_certificates; then
        release_lock
        exit 1
    fi
    
    # Validate config after renewal
    if ! validate_nginx_config; then
        log_error "Nginx configuration invalid after renewal"
        send_notification "Nginx Config Invalid After Renewal" "Configuration validation failed on ${HOSTNAME}"
        release_lock
        exit 1
    fi
    
    # Reload Nginx
    if ! reload_nginx; then
        release_lock
        exit 1
    fi
    
    # Health check
    if ! health_check_rpc; then
        log_warn "RPC health check failed after renewal"
        send_notification "RPC Health Check Failed" "RPC health check failed on ${HOSTNAME} after certificate renewal"
        release_lock
        exit 1
    fi
    
    log_info "=== Certificate Renewal Completed Successfully ==="
    send_notification "Certificate Renewal Success" "Certificate renewal completed successfully on ${HOSTNAME}"
    exit 0
}

# Run main function
main "$@"
