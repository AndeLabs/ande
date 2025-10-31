#!/bin/bash

# ANDE Chain Health Check & Auto-Recovery Script
# Monitorea la salud de los servicios y realiza recuperación automática

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
HEALTH_LOG="${LOG_DIR}/health-check-$(date +%Y-%m-%d).log"
ALERT_FILE="${LOG_DIR}/alerts.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Crear directorio de logs
mkdir -p "${LOG_DIR}"

# Funciones
log_message() {
    local level=$1
    shift
    local message="$@"
    echo -e "${TIMESTAMP} [${level}] ${message}" | tee -a "${HEALTH_LOG}"
}

log_alert() {
    local service=$1
    local message=$2
    echo -e "${TIMESTAMP} [ALERT] ${service}: ${message}" | tee -a "${ALERT_FILE}"
}

check_ev_reth() {
    local service="ev-reth-sequencer"
    log_message "INFO" "Verificando ${service}..."

    if ! docker compose ps ${service} | grep -q "Up"; then
        log_message "ERROR" "${service} no está corriendo"
        log_alert "${service}" "Container no está en estado Up"
        return 1
    fi

    # Verificar RPC
    if ! curl -s -X POST http://localhost:8545 \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | grep -q "result"; then
        log_message "ERROR" "RPC de ${service} no responde"
        log_alert "${service}" "RPC endpoint no responde"
        return 1
    fi

    log_message "INFO" "${service} está saludable"
    return 0
}

check_evolve() {
    local service="evolve-sequencer"
    log_message "INFO" "Verificando ${service}..."

    if ! docker compose ps ${service} | grep -q "Up"; then
        log_message "ERROR" "${service} no está corriendo"
        log_alert "${service}" "Container no está en estado Up"
        return 1
    fi

    # Verificar status endpoint
    if ! curl -s -f http://localhost:7331/status > /dev/null 2>&1; then
        log_message "ERROR" "Status endpoint de ${service} no responde"
        log_alert "${service}" "Status endpoint no responde"
        return 1
    fi

    log_message "INFO" "${service} está saludable"
    return 0
}

check_celestia() {
    local service="celestia-light"
    log_message "INFO" "Verificando ${service}..."

    if ! docker compose ps ${service} | grep -q "Up"; then
        log_message "ERROR" "${service} no está corriendo"
        log_alert "${service}" "Container no está en estado Up"
        return 1
    fi

    # Verificar conectividad RPC
    if ! curl -s -f http://localhost:26658/health > /dev/null 2>&1; then
        log_message "WARN" "Celestia RPC puede no estar completamente sincronizado"
    fi

    log_message "INFO" "${service} está saludable"
    return 0
}

check_prometheus() {
    local service="prometheus"
    log_message "INFO" "Verificando ${service}..."

    if ! docker compose ps ${service} | grep -q "Up"; then
        log_message "ERROR" "${service} no está corriendo"
        log_alert "${service}" "Container no está en estado Up"
        return 1
    fi

    if ! curl -s -f http://localhost:9090/-/healthy > /dev/null 2>&1; then
        log_message "ERROR" "${service} no está saludable"
        log_alert "${service}" "Health check falló"
        return 1
    fi

    log_message "INFO" "${service} está saludable"
    return 0
}

check_grafana() {
    local service="grafana"
    log_message "INFO" "Verificando ${service}..."

    if ! docker compose ps ${service} | grep -q "Up"; then
        log_message "ERROR" "${service} no está corriendo"
        log_alert "${service}" "Container no está en estado Up"
        return 1
    fi

    if ! curl -s -f http://localhost:3000/api/health > /dev/null 2>&1; then
        log_message "ERROR" "${service} no está saludable"
        log_alert "${service}" "Health check falló"
        return 1
    fi

    log_message "INFO" "${service} está saludable"
    return 0
}

check_nginx() {
    local service="nginx-proxy"
    log_message "INFO" "Verificando ${service}..."

    if ! docker compose ps ${service} | grep -q "Up"; then
        log_message "ERROR" "${service} no está corriendo"
        log_alert "${service}" "Container no está en estado Up"
        return 1
    fi

    if ! curl -s -f http://localhost/health > /dev/null 2>&1; then
        log_message "ERROR" "${service} no responde en health endpoint"
        log_alert "${service}" "Health check falló"
        return 1
    fi

    log_message "INFO" "${service} está saludable"
    return 0
}

check_disk_space() {
    log_message "INFO" "Verificando espacio en disco..."
    local usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

    if [ ${usage} -gt 90 ]; then
        log_message "ERROR" "Uso de disco crítico: ${usage}%"
        log_alert "DISK" "Espacio insuficiente: ${usage}% usado"
        return 1
    elif [ ${usage} -gt 75 ]; then
        log_message "WARN" "Uso de disco alto: ${usage}%"
    else
        log_message "INFO" "Espacio en disco: ${usage}% (OK)"
    fi

    return 0
}

check_memory() {
    log_message "INFO" "Verificando memoria..."
    local mem_usage=$(free | awk 'NR==2 {printf("%.0f", $3/$2 * 100)}')

    if [ ${mem_usage} -gt 90 ]; then
        log_message "ERROR" "Uso de memoria crítico: ${mem_usage}%"
        log_alert "MEMORY" "Memoria crítica: ${mem_usage}% usado"
        return 1
    elif [ ${mem_usage} -gt 75 ]; then
        log_message "WARN" "Uso de memoria alto: ${mem_usage}%"
    else
        log_message "INFO" "Uso de memoria: ${mem_usage}% (OK)"
    fi

    return 0
}

restart_service() {
    local service=$1
    log_message "WARN" "Reiniciando ${service}..."

    if docker compose restart ${service}; then
        log_message "INFO" "${service} reiniciado exitosamente"
        sleep 10
        return 0
    else
        log_message "ERROR" "Falló el reinicio de ${service}"
        log_alert "${service}" "Falló el reinicio automático"
        return 1
    fi
}

get_block_number() {
    curl -s -X POST http://localhost:8545 \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | \
        grep -o '"result":"0x[^"]*"' | cut -d'"' -f4 | xargs printf "%d\n"
}

print_status_report() {
    log_message "INFO" "=================================="
    log_message "INFO" "Reporte de Estado - $(date '+%Y-%m-%d %H:%M:%S')"
    log_message "INFO" "=================================="

    # Block info
    local block_num=$(get_block_number 2>/dev/null || echo "N/A")
    log_message "INFO" "Bloque actual: ${block_num}"

    # Container status
    log_message "INFO" "Estado de contenedores:"
    docker compose ps | tail -n +2 | while read -r line; do
        log_message "INFO" "  $(echo $line | awk '{print $1, $2, $7}')"
    done

    log_message "INFO" "=================================="
}

# Main execution
main() {
    cd "${SCRIPT_DIR}"

    log_message "INFO" "Iniciando verificación de salud de ANDE Chain..."

    local all_healthy=true
    local restart_needed=""

    # Verificaciones principales
    if ! check_ev_reth; then
        all_healthy=false
        restart_needed="${restart_needed} ev-reth-sequencer"
    fi

    if ! check_evolve; then
        all_healthy=false
        restart_needed="${restart_needed} evolve-sequencer"
    fi

    if ! check_celestia; then
        all_healthy=false
        restart_needed="${restart_needed} celestia-light"
    fi

    if ! check_prometheus; then
        all_healthy=false
        restart_needed="${restart_needed} prometheus"
    fi

    if ! check_grafana; then
        all_healthy=false
        restart_needed="${restart_needed} grafana"
    fi

    if ! check_nginx; then
        all_healthy=false
        restart_needed="${restart_needed} nginx-proxy"
    fi

    # Verificaciones de recursos
    check_disk_space || all_healthy=false
    check_memory || all_healthy=false

    # Reintentar servicios críticos
    if [ -n "${restart_needed}" ]; then
        for service in ${restart_needed}; do
            log_message "WARN" "Intentando recuperación de ${service}..."
            if restart_service "${service}"; then
                sleep 30
                if [[ "${service}" == "ev-reth-sequencer" ]]; then
                    check_ev_reth
                elif [[ "${service}" == "evolve-sequencer" ]]; then
                    check_evolve
                elif [[ "${service}" == "celestia-light" ]]; then
                    check_celestia
                fi
            fi
        done
    fi

    # Reporte final
    print_status_report

    if [ "${all_healthy}" = true ]; then
        log_message "INFO" "✅ Todas las verificaciones pasaron"
        exit 0
    else
        log_message "ERROR" "❌ Algunas verificaciones fallaron"
        exit 1
    fi
}

# Ejecutar main
main "$@"
