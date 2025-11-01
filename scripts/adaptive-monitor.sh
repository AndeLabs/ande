#!/bin/bash
# ========================================
# ANDE Chain Adaptive System Monitor
# Real-time monitoring and metrics for adaptive block production
# ========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
RPC_URL="http://localhost:8545"
METRICS_URL="http://localhost:26660/metrics"
REFRESH_INTERVAL=5

# Thresholds for adaptive detection
MEMPOOL_THRESHOLD_HIGH=10
MEMPOOL_THRESHOLD_LOW=2
BLOCK_TIME_TARGET=1
IDLE_BLOCK_TIME=5

# Function to get metric
get_metric() {
    local metric_name=$1
    curl -s "$METRICS_URL" | grep "^$metric_name{" | awk '{print $NF}'
}

# Function to get mempool stats
get_mempool_stats() {
    local result=$(curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"txpool_status","params":[],"id":1}')
    
    local pending=$(echo $result | grep -o '"pending":"0x[^"]*"' | cut -d'"' -f4)
    local queued=$(echo $result | grep -o '"queued":"0x[^"]*"' | cut -d'"' -f4)
    
    # Convert from hex to decimal
    local pending_dec=$((16#${pending#0x}))
    local queued_dec=$((16#${queued#0x}))
    
    echo "$pending_dec:$queued_dec"
}

# Function to get block production timing
get_block_timing() {
    local height=$(get_metric "evnode_sequencer_latest_block_height")
    local timestamp=$(date +%s)
    echo "$height:$timestamp"
}

# Function to calculate actual block time
calculate_block_time() {
    local current_data=$1
    local previous_data=$2
    
    if [ -z "$previous_data" ]; then
        echo "N/A"
        return
    fi
    
    local current_height=$(echo $current_data | cut -d':' -f1)
    local current_time=$(echo $current_data | cut -d':' -f2)
    local prev_height=$(echo $previous_data | cut -d':' -f1)
    local prev_time=$(echo $previous_data | cut -d':' -f2)
    
    if [ "$current_height" == "$prev_height" ]; then
        echo "STALLED"
        return
    fi
    
    local blocks_diff=$((current_height - prev_height))
    local time_diff=$((current_time - prev_time))
    
    if [ "$blocks_diff" -eq 0 ]; then
        echo "N/A"
    else
        local avg_time=$((time_diff / blocks_diff))
        echo "${avg_time}s"
    fi
}

# Function to determine adaptive mode
determine_mode() {
    local pending=$1
    local queued=$2
    local block_time=$3
    
    local total_txs=$((pending + queued))
    
    if [ "$total_txs" -ge "$MEMPOOL_THRESHOLD_HIGH" ]; then
        echo "${GREEN}ACTIVE${NC} (High Load)"
    elif [ "$total_txs" -ge "$MEMPOOL_THRESHOLD_LOW" ]; then
        echo "${YELLOW}ACTIVE${NC} (Moderate Load)"
    else
        echo "${BLUE}IDLE${NC} (Low Load)"
    fi
}

# Function to get system recommendations
get_recommendations() {
    local pending=$1
    local queued=$2
    local block_time=$3
    
    local total_txs=$((pending + queued))
    
    echo -e "${CYAN}📊 Adaptive Recommendations:${NC}"
    
    if [ "$total_txs" -eq 0 ]; then
        echo -e "   ${BLUE}✓ Idle mode optimal: 5s blocks${NC}"
        echo -e "   ${BLUE}✓ No transactions = Energy efficient${NC}"
    elif [ "$total_txs" -lt "$MEMPOOL_THRESHOLD_LOW" ]; then
        echo -e "   ${YELLOW}⚡ Low load: 3s blocks recommended${NC}"
    elif [ "$total_txs" -lt "$MEMPOOL_THRESHOLD_HIGH" ]; then
        echo -e "   ${YELLOW}⚡ Moderate load: 2s blocks recommended${NC}"
    else
        echo -e "   ${GREEN}🚀 High load: 1s blocks optimal${NC}"
        echo -e "   ${GREEN}🚀 Maximum throughput mode${NC}"
    fi
}

# Function to display header
print_header() {
    clear
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║         ANDE CHAIN - ADAPTIVE SYSTEM MONITOR                 ║${NC}"
    echo -e "${MAGENTA}║              Real-Time Dynamic Metrics                       ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""
}

# Function to display adaptive dashboard
display_dashboard() {
    local mempool_stats=$1
    local block_data=$2
    local prev_block_data=$3
    
    local pending=$(echo $mempool_stats | cut -d':' -f1)
    local queued=$(echo $mempool_stats | cut -d':' -f2)
    local total_txs=$((pending + queued))
    
    local current_height=$(echo $block_data | cut -d':' -f1)
    local block_time=$(calculate_block_time "$block_data" "$prev_block_data")
    
    # Block Production Status
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📦 Block Production${NC}"
    echo -e "   Height: ${GREEN}$current_height${NC}"
    echo -e "   Actual Block Time: ${GREEN}$block_time${NC}"
    echo ""
    
    # Mempool Status
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}💼 Mempool Status${NC}"
    
    if [ "$total_txs" -gt 0 ]; then
        echo -e "   Pending: ${GREEN}$pending${NC}"
        echo -e "   Queued: ${YELLOW}$queued${NC}"
        echo -e "   Total: ${GREEN}$total_txs${NC}"
    else
        echo -e "   Pending: ${BLUE}$pending${NC}"
        echo -e "   Queued: ${BLUE}$queued${NC}"
        echo -e "   Total: ${BLUE}$total_txs${NC} (Idle)"
    fi
    echo ""
    
    # Adaptive Mode Detection
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🔄 Adaptive Mode${NC}"
    local mode=$(determine_mode $pending $queued $block_time)
    echo -e "   Current Mode: $mode"
    echo -e "   Target (Active): ${GREEN}${BLOCK_TIME_TARGET}s${NC}"
    echo -e "   Target (Idle): ${BLUE}${IDLE_BLOCK_TIME}s${NC}"
    echo ""
    
    # Recommendations
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    get_recommendations $pending $queued $block_time
    echo ""
    
    # Threshold Indicators
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📊 Thresholds${NC}"
    echo -e "   High Load Trigger: ${GREEN}≥ ${MEMPOOL_THRESHOLD_HIGH} txs${NC}"
    echo -e "   Low Load Trigger: ${YELLOW}≥ ${MEMPOOL_THRESHOLD_LOW} txs${NC}"
    echo -e "   Idle Trigger: ${BLUE}< ${MEMPOOL_THRESHOLD_LOW} txs${NC}"
    echo ""
    
    # DA Status
    local pending_blobs=$(get_metric "evnode_sequencer_da_submitter_pending_blobs")
    local da_height=$(get_metric "evnode_sequencer_da_inclusion_height")
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🌐 Data Availability${NC}"
    echo -e "   DA Height: ${GREEN}$da_height${NC}"
    echo -e "   Pending Blobs: ${YELLOW}$pending_blobs${NC}"
    echo ""
    
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Refreshing in ${REFRESH_INTERVAL}s... (Ctrl+C to stop)${NC}"
}

# Main monitoring loop
main() {
    local previous_block_data=""
    
    while true; do
        print_header
        
        local mempool_stats=$(get_mempool_stats)
        local block_data=$(get_block_timing)
        
        display_dashboard "$mempool_stats" "$block_data" "$previous_block_data"
        
        previous_block_data=$block_data
        
        sleep $REFRESH_INTERVAL
    done
}

# Run main function
main
