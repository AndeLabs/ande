#!/bin/bash
# =========================================================================
# ANDE CHAIN - COMPREHENSIVE PERFORMANCE DASHBOARD
# =========================================================================
# Real-time monitoring of all advanced features:
# - Parallel EVM execution metrics
# - MEV detection and capture
# - Adaptive lazy mode behavior
# - DA submission performance
# =========================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
RPC_URL="http://localhost:8545"
METRICS_MAIN="http://localhost:9001/metrics"
METRICS_PARALLEL="http://localhost:9091/metrics"
METRICS_MEV="http://localhost:9092/mev-metrics"
METRICS_EVOLVE="http://localhost:26660/metrics"

REFRESH_INTERVAL=2

# =========================================================================
# Metric Collection Functions
# =========================================================================

get_block_number() {
    curl -s -X POST "$RPC_URL" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4 | xargs printf "%d\n"
}

get_mempool_status() {
    local result=$(curl -s -X POST "$RPC_URL" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"txpool_status","params":[],"id":1}')
    
    local pending=$(echo "$result" | grep -o '"pending":"0x[^"]*"' | cut -d'"' -f4)
    local queued=$(echo "$result" | grep -o '"queued":"0x[^"]*"' | cut -d'"' -f4)
    
    echo "$((16#${pending#0x})),$((16#${queued#0x}))"
}

get_metric_value() {
    local endpoint=$1
    local metric_name=$2
    
    curl -s "$endpoint" 2>/dev/null | grep "^$metric_name" | grep -v "#" | awk '{print $2}' | head -1
}

get_parallel_evm_metrics() {
    if ! curl -sf "$METRICS_PARALLEL" >/dev/null 2>&1; then
        echo "unavailable"
        return
    fi
    
    local concurrency=$(get_metric_value "$METRICS_PARALLEL" "parallel_concurrency_level" || echo "0")
    local parallel_ratio=$(get_metric_value "$METRICS_PARALLEL" "parallel_execution_ratio" || echo "0")
    local worker_util=$(get_metric_value "$METRICS_PARALLEL" "parallel_worker_utilization" || echo "0")
    local conflicts=$(get_metric_value "$METRICS_PARALLEL" "parallel_conflicts_total" || echo "0")
    
    echo "$concurrency,$parallel_ratio,$worker_util,$conflicts"
}

get_mev_metrics() {
    if ! curl -sf "$METRICS_MEV" >/dev/null 2>&1; then
        echo "unavailable"
        return
    fi
    
    local opportunities=$(get_metric_value "$METRICS_MEV" "mev_opportunities_detected" || echo "0")
    local captured=$(get_metric_value "$METRICS_MEV" "mev_total_captured" || echo "0")
    local buffer=$(get_metric_value "$METRICS_MEV" "mev_buffer_amount" || echo "0")
    local auctions=$(get_metric_value "$METRICS_MEV" "mev_auctions_total" || echo "0")
    
    echo "$opportunities,$captured,$buffer,$auctions"
}

get_da_metrics() {
    if ! curl -sf "$METRICS_EVOLVE" >/dev/null 2>&1; then
        echo "unavailable"
        return
    fi
    
    local submissions=$(get_metric_value "$METRICS_EVOLVE" "da_submissions_total" || echo "0")
    local failures=$(get_metric_value "$METRICS_EVOLVE" "da_submission_failures" || echo "0")
    local avg_cost=$(get_metric_value "$METRICS_EVOLVE" "da_avg_gas_cost" || echo "0")
    
    echo "$submissions,$failures,$avg_cost"
}

# =========================================================================
# Display Functions
# =========================================================================

clear_screen() {
    printf '\033[2J\033[H'
}

draw_box() {
    local width=$1
    local title=$2
    
    echo -e "${CYAN}╔$(printf '═%.0s' $(seq 1 $((width-2))))╗${NC}"
    printf "${CYAN}║${NC} ${WHITE}%-$((width-4))s${NC} ${CYAN}║${NC}\n" "$title"
    echo -e "${CYAN}╠$(printf '═%.0s' $(seq 1 $((width-2))))╣${NC}"
}

draw_bottom() {
    local width=$1
    echo -e "${CYAN}╚$(printf '═%.0s' $(seq 1 $((width-2))))╝${NC}"
}

format_number() {
    local num=$1
    if [ "$num" -ge 1000000000 ]; then
        printf "%.2fB" $(echo "scale=2; $num/1000000000" | bc)
    elif [ "$num" -ge 1000000 ]; then
        printf "%.2fM" $(echo "scale=2; $num/1000000" | bc)
    elif [ "$num" -ge 1000 ]; then
        printf "%.2fK" $(echo "scale=2; $num/1000" | bc)
    else
        echo "$num"
    fi
}

get_status_indicator() {
    local value=$1
    local threshold=$2
    
    if (( $(echo "$value > $threshold" | bc -l) )); then
        echo "${GREEN}●${NC}"
    else
        echo "${YELLOW}●${NC}"
    fi
}

# =========================================================================
# Main Dashboard
# =========================================================================

display_dashboard() {
    local block=$1
    local prev_block=$2
    local mempool_data=$3
    local parallel_data=$4
    local mev_data=$5
    local da_data=$6
    
    clear_screen
    
    # Header
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}           ${WHITE}ANDE CHAIN - PRODUCTION PERFORMANCE DASHBOARD${NC}              ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Calculate block rate
    local block_rate=0
    if [ "$prev_block" -gt 0 ]; then
        block_rate=$(echo "scale=1; ($block - $prev_block) / $REFRESH_INTERVAL" | bc)
    fi
    
    # Parse mempool data
    IFS=',' read -r pending queued <<< "$mempool_data"
    
    # Determine mode based on block rate
    local mode="IDLE (5s blocks)"
    local mode_color=$YELLOW
    if (( $(echo "$block_rate > 0.8" | bc -l) )); then
        mode="ACTIVE (1s blocks)"
        mode_color=$GREEN
    fi
    
    # ========================================================================
    # BLOCKCHAIN STATUS
    # ========================================================================
    draw_box 76 "BLOCKCHAIN STATUS"
    printf "${CYAN}║${NC} Block Number:      ${WHITE}%-20s${NC} Mode: ${mode_color}%-20s${NC} ${CYAN}║${NC}\n" "$block" "$mode"
    printf "${CYAN}║${NC} Block Rate:        ${WHITE}%-20s${NC} Pending TX: ${YELLOW}%-17s${NC} ${CYAN}║${NC}\n" "${block_rate} blocks/s" "$pending"
    printf "${CYAN}║${NC} Mempool Status:    Pending: ${YELLOW}%-5s${NC} Queued: ${YELLOW}%-5s${NC}                      ${CYAN}║${NC}\n" "$pending" "$queued"
    draw_bottom 76
    echo ""
    
    # ========================================================================
    # PARALLEL EVM METRICS
    # ========================================================================
    if [ "$parallel_data" != "unavailable" ]; then
        IFS=',' read -r concurrency parallel_ratio worker_util conflicts <<< "$parallel_data"
        
        local parallel_pct=$(echo "scale=1; $parallel_ratio * 100" | bc)
        local worker_pct=$(echo "scale=1; $worker_util * 100" | bc)
        
        draw_box 76 "PARALLEL EVM EXECUTION"
        printf "${CYAN}║${NC} Concurrency Level: ${WHITE}%-15s${NC} Parallel Ratio: ${GREEN}%-15s${NC} ${CYAN}║${NC}\n" "$concurrency workers" "${parallel_pct}%"
        printf "${CYAN}║${NC} Worker Utilization:${GREEN}%-15s${NC} Total Conflicts: ${YELLOW}%-14s${NC} ${CYAN}║${NC}\n" "${worker_pct}%" "$conflicts"
        
        # Performance indicator
        local perf_status="OPTIMAL"
        local perf_color=$GREEN
        if (( $(echo "$parallel_ratio < 0.5" | bc -l) )); then
            perf_status="LOW"
            perf_color=$YELLOW
        fi
        if (( $(echo "$worker_util > 0.9" | bc -l) )); then
            perf_status="SATURATED"
            perf_color=$RED
        fi
        
        printf "${CYAN}║${NC} Performance:       ${perf_color}%-20s${NC}                                  ${CYAN}║${NC}\n" "$perf_status"
        draw_bottom 76
        echo ""
    else
        draw_box 76 "PARALLEL EVM EXECUTION"
        printf "${CYAN}║${NC} ${RED}Status: Metrics endpoint not available${NC}                              ${CYAN}║${NC}\n"
        draw_bottom 76
        echo ""
    fi
    
    # ========================================================================
    # MEV INTEGRATION METRICS
    # ========================================================================
    if [ "$mev_data" != "unavailable" ]; then
        IFS=',' read -r opportunities captured buffer auctions <<< "$mev_data"
        
        local captured_fmt=$(format_number $captured)
        local buffer_fmt=$(format_number $buffer)
        
        draw_box 76 "MEV INTEGRATION"
        printf "${CYAN}║${NC} Opportunities:     ${WHITE}%-15s${NC} Total Captured: ${GREEN}%-16s${NC} ${CYAN}║${NC}\n" "$opportunities" "${captured_fmt} wei"
        printf "${CYAN}║${NC} Current Buffer:    ${YELLOW}%-15s${NC} Auctions: ${WHITE}%-21s${NC} ${CYAN}║${NC}\n" "${buffer_fmt} wei" "$auctions"
        
        # Buffer status
        local buffer_status="NORMAL"
        local buffer_color=$GREEN
        if [ "$buffer" -gt 100000000000000000000 ]; then  # > 100 ANDE
            buffer_status="HIGH - Ready for distribution"
            buffer_color=$YELLOW
        fi
        if [ "$buffer" -gt 500000000000000000000 ]; then  # > 500 ANDE
            buffer_status="CRITICAL - Should auto-deposit"
            buffer_color=$RED
        fi
        
        printf "${CYAN}║${NC} Buffer Status:     ${buffer_color}%-50s${NC} ${CYAN}║${NC}\n" "$buffer_status"
        draw_bottom 76
        echo ""
    else
        draw_box 76 "MEV INTEGRATION"
        printf "${CYAN}║${NC} ${RED}Status: Metrics endpoint not available${NC}                              ${CYAN}║${NC}\n"
        draw_bottom 76
        echo ""
    fi
    
    # ========================================================================
    # DATA AVAILABILITY METRICS
    # ========================================================================
    if [ "$da_data" != "unavailable" ]; then
        IFS=',' read -r submissions failures avg_cost <<< "$da_data"
        
        local success_rate=100
        if [ "$submissions" -gt 0 ]; then
            success_rate=$(echo "scale=1; (($submissions - $failures) / $submissions) * 100" | bc)
        fi
        
        draw_box 76 "DATA AVAILABILITY (CELESTIA)"
        printf "${CYAN}║${NC} Total Submissions: ${WHITE}%-15s${NC} Failures: ${YELLOW}%-20s${NC} ${CYAN}║${NC}\n" "$submissions" "$failures"
        printf "${CYAN}║${NC} Success Rate:      ${GREEN}%-15s${NC} Avg Gas Cost: ${WHITE}%-16s${NC} ${CYAN}║${NC}\n" "${success_rate}%" "${avg_cost} utia"
        
        # DA health status
        local da_status="HEALTHY"
        local da_color=$GREEN
        if (( $(echo "$success_rate < 95" | bc -l) )); then
            da_status="DEGRADED"
            da_color=$YELLOW
        fi
        if (( $(echo "$success_rate < 80" | bc -l) )); then
            da_status="UNHEALTHY"
            da_color=$RED
        fi
        
        printf "${CYAN}║${NC} DA Health:         ${da_color}%-50s${NC} ${CYAN}║${NC}\n" "$da_status"
        draw_bottom 76
        echo ""
    else
        draw_box 76 "DATA AVAILABILITY (CELESTIA)"
        printf "${CYAN}║${NC} ${RED}Status: Metrics endpoint not available${NC}                              ${CYAN}║${NC}\n"
        draw_bottom 76
        echo ""
    fi
    
    # ========================================================================
    # SYSTEM INFORMATION
    # ========================================================================
    draw_box 76 "SYSTEM INFORMATION"
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local cpu_color=$GREEN
    if (( $(echo "$cpu_usage > 70" | bc -l) )); then cpu_color=$YELLOW; fi
    if (( $(echo "$cpu_usage > 90" | bc -l) )); then cpu_color=$RED; fi
    
    # Memory usage
    local mem_used=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    local mem_color=$GREEN
    if [ "$mem_used" -gt 70 ]; then mem_color=$YELLOW; fi
    if [ "$mem_used" -gt 90 ]; then mem_color=$RED; fi
    
    printf "${CYAN}║${NC} CPU Usage:         ${cpu_color}%-15s${NC} Memory Usage: ${mem_color}%-19s${NC} ${CYAN}║${NC}\n" "${cpu_usage}%" "${mem_used}%"
    
    # Docker stats
    local container_count=$(docker ps -q | wc -l)
    printf "${CYAN}║${NC} Running Containers:${WHITE}%-15s${NC}                                  ${CYAN}║${NC}\n" "$container_count"
    
    draw_bottom 76
    
    # ========================================================================
    # FOOTER
    # ========================================================================
    echo ""
    echo -e "${CYAN}Press Ctrl+C to exit${NC} | Refresh: ${REFRESH_INTERVAL}s | $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo -e "${CYAN}Endpoints:${NC}"
    echo -e "  RPC: ${WHITE}$RPC_URL${NC}  |  Grafana: ${WHITE}http://localhost:3000${NC}  |  Prometheus: ${WHITE}http://localhost:9090${NC}"
}

# =========================================================================
# Main Loop
# =========================================================================

main() {
    echo "Initializing ANDE Chain Performance Dashboard..."
    echo "Connecting to endpoints..."
    
    # Check RPC connectivity
    if ! curl -sf "$RPC_URL" >/dev/null 2>&1; then
        echo "Error: Cannot connect to RPC at $RPC_URL"
        exit 1
    fi
    
    local prev_block=0
    
    # Main monitoring loop
    while true; do
        # Collect metrics
        local block=$(get_block_number 2>/dev/null || echo "0")
        local mempool=$(get_mempool_status 2>/dev/null || echo "0,0")
        local parallel=$(get_parallel_evm_metrics 2>/dev/null || echo "unavailable")
        local mev=$(get_mev_metrics 2>/dev/null || echo "unavailable")
        local da=$(get_da_metrics 2>/dev/null || echo "unavailable")
        
        # Display dashboard
        display_dashboard "$block" "$prev_block" "$mempool" "$parallel" "$mev" "$da"
        
        # Update previous block
        prev_block=$block
        
        # Wait for next refresh
        sleep $REFRESH_INTERVAL
    done
}

# Trap Ctrl+C
trap 'echo -e "\n${GREEN}Dashboard stopped${NC}"; exit 0' INT

main "$@"
