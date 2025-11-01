#!/bin/bash
# ========================================
# ANDE Chain Adaptive Block Controller
# Professional adaptive system with external control
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
COMPOSE_DIR="/mnt/c/Users/sator/andelabs/ande"

# Adaptive Thresholds
THRESHOLD_BURST=50      # >50 txs = BURST mode (500ms blocks)
THRESHOLD_HIGH=20       # >20 txs = HIGH load (1s blocks)
THRESHOLD_MEDIUM=10     # >10 txs = MEDIUM load (2s blocks)
THRESHOLD_LOW=5         # >5 txs = LOW load (3s blocks)
# <5 txs = IDLE mode (5s blocks)

# Current state
CURRENT_MODE="IDLE"
CURRENT_BLOCK_TIME="1s"
MODE_SWITCHES=0
LAST_SWITCH_TIME=0

# Logging
LOG_FILE="/tmp/ande-adaptive-controller.log"

# Function to log with timestamp
log_event() {
    local level=$1
    local message=$2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | tee -a "$LOG_FILE"
}

# Function to get mempool stats
get_mempool_count() {
    local result=$(curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"txpool_status","params":[],"id":1}')
    
    local pending=$(echo $result | grep -o '"pending":"0x[^"]*"' | cut -d'"' -f4)
    local queued=$(echo $result | grep -o '"queued":"0x[^"]*"' | cut -d'"' -f4)
    
    local pending_dec=$((16#${pending#0x}))
    local queued_dec=$((16#${queued#0x}))
    
    echo $((pending_dec + queued_dec))
}

# Function to determine optimal mode
determine_optimal_mode() {
    local tx_count=$1
    
    if [ $tx_count -ge $THRESHOLD_BURST ]; then
        echo "BURST"
    elif [ $tx_count -ge $THRESHOLD_HIGH ]; then
        echo "HIGH"
    elif [ $tx_count -ge $THRESHOLD_MEDIUM ]; then
        echo "MEDIUM"
    elif [ $tx_count -ge $THRESHOLD_LOW ]; then
        echo "LOW"
    else
        echo "IDLE"
    fi
}

# Function to get target block time for mode
get_target_block_time() {
    local mode=$1
    
    case $mode in
        BURST)  echo "500ms" ;;
        HIGH)   echo "1s" ;;
        MEDIUM) echo "2s" ;;
        LOW)    echo "3s" ;;
        IDLE)   echo "5s" ;;
        *)      echo "1s" ;;
    esac
}

# Function to update docker-compose configuration
update_sequencer_config() {
    local new_block_time=$1
    local new_mode=$2
    
    log_event "INFO" "Updating configuration: $new_mode mode, block_time=$new_block_time"
    
    # Update environment variable
    cd "$COMPOSE_DIR"
    
    # Backup current config
    cp docker-compose.yml docker-compose.yml.backup
    
    # Update EVM_BLOCK_TIME
    sed -i "s/- EVM_BLOCK_TIME=.*/- EVM_BLOCK_TIME=$new_block_time/" docker-compose.yml
    
    log_event "INFO" "Configuration file updated"
}

# Function to restart sequencer
restart_sequencer() {
    log_event "INFO" "Restarting sequencer..."
    
    cd "$COMPOSE_DIR"
    
    # Graceful restart
    docker compose restart evolve-sequencer &> /dev/null
    
    # Wait for healthy
    local wait_count=0
    while [ $wait_count -lt 30 ]; do
        if curl -s http://localhost:7331/status &> /dev/null; then
            log_event "INFO" "Sequencer restarted successfully"
            return 0
        fi
        sleep 2
        ((wait_count++))
    done
    
    log_event "ERROR" "Sequencer restart timeout"
    return 1
}

# Function to switch mode
switch_mode() {
    local new_mode=$1
    local new_block_time=$2
    
    if [ "$new_mode" == "$CURRENT_MODE" ]; then
        return 0  # No change needed
    fi
    
    log_event "WARN" "MODE SWITCH: $CURRENT_MODE → $new_mode (block_time: $CURRENT_BLOCK_TIME → $new_block_time)"
    
    # Update configuration
    update_sequencer_config "$new_block_time" "$new_mode"
    
    # Restart sequencer
    if restart_sequencer; then
        CURRENT_MODE=$new_mode
        CURRENT_BLOCK_TIME=$new_block_time
        ((MODE_SWITCHES++))
        LAST_SWITCH_TIME=$(date +%s)
        
        log_event "INFO" "Mode switch successful (total switches: $MODE_SWITCHES)"
        return 0
    else
        log_event "ERROR" "Mode switch failed"
        # Restore backup
        cp docker-compose.yml.backup docker-compose.yml
        return 1
    fi
}

# Function to display status
display_status() {
    local tx_count=$1
    local optimal_mode=$2
    local target_time=$3
    
    clear
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║     ANDE CHAIN - ADAPTIVE BLOCK CONTROLLER                   ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""
    
    # Current state
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📊 Current State${NC}"
    echo -e "   Mode: ${GREEN}$CURRENT_MODE${NC}"
    echo -e "   Block Time: ${GREEN}$CURRENT_BLOCK_TIME${NC}"
    echo -e "   Mode Switches: ${YELLOW}$MODE_SWITCHES${NC}"
    echo ""
    
    # Mempool
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}💼 Mempool Analysis${NC}"
    echo -e "   Total Transactions: ${YELLOW}$tx_count${NC}"
    
    # Recommended action
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🎯 Recommendation${NC}"
    
    if [ "$optimal_mode" == "$CURRENT_MODE" ]; then
        echo -e "   ${GREEN}✓ Current mode is optimal${NC}"
    else
        echo -e "   ${YELLOW}⚡ Should switch to: $optimal_mode mode ($target_time blocks)${NC}"
    fi
    
    # Thresholds
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📊 Thresholds${NC}"
    echo -e "   BURST: ${RED}≥ $THRESHOLD_BURST txs${NC} → 500ms blocks"
    echo -e "   HIGH: ${YELLOW}≥ $THRESHOLD_HIGH txs${NC} → 1s blocks"
    echo -e "   MEDIUM: ${YELLOW}≥ $THRESHOLD_MEDIUM txs${NC} → 2s blocks"
    echo -e "   LOW: ${BLUE}≥ $THRESHOLD_LOW txs${NC} → 3s blocks"
    echo -e "   IDLE: ${BLUE}< $THRESHOLD_LOW txs${NC} → 5s blocks"
    
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Main control loop
main() {
    log_event "INFO" "Adaptive controller starting..."
    log_event "INFO" "Initial mode: $CURRENT_MODE, block_time: $CURRENT_BLOCK_TIME"
    
    while true; do
        # Get current mempool count
        local tx_count=$(get_mempool_count)
        
        # Determine optimal mode
        local optimal_mode=$(determine_optimal_mode $tx_count)
        local target_time=$(get_target_block_time $optimal_mode)
        
        # Display status
        display_status $tx_count $optimal_mode $target_time
        
        # Switch mode if needed
        if [ "$optimal_mode" != "$CURRENT_MODE" ]; then
            # Hysteresis: wait a few seconds before switching
            local current_time=$(date +%s)
            local time_since_switch=$((current_time - LAST_SWITCH_TIME))
            
            if [ $time_since_switch -gt 10 ]; then
                log_event "INFO" "Initiating mode switch after $time_since_switch seconds"
                switch_mode "$optimal_mode" "$target_time"
            else
                log_event "INFO" "Delaying mode switch (hysteresis: ${time_since_switch}s < 10s)"
            fi
        fi
        
        # Wait before next check
        sleep 5
    done
}

# Handle Ctrl+C
trap 'log_event "INFO" "Controller stopped by user"; exit 0' INT

# Run main loop
main
