#!/bin/bash
# ========================================
# ANDE Chain Transaction Generator
# Generate realistic transaction load for adaptive testing
# ========================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
RPC_URL="http://localhost:8545"
CHAIN_ID="0x181e"  # 6174 in hex

# Transaction patterns
PATTERN_LOW=5      # 5 tx/batch
PATTERN_MEDIUM=20  # 20 tx/batch
PATTERN_HIGH=50    # 50 tx/batch

print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         ANDE CHAIN - TRANSACTION GENERATOR                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to send batch of debug_traceCall (simulated transactions)
send_trace_batch() {
    local count=$1
    local pattern_name=$2
    
    echo -e "${BLUE}Sending $count simulated transactions ($pattern_name load)...${NC}"
    
    for i in $(seq 1 $count); do
        local hex_value=$(printf '%x' $((RANDOM * RANDOM)))
        curl -s -X POST "$RPC_URL" \
            -H "Content-Type: application/json" \
            -d "{\"jsonrpc\":\"2.0\",\"method\":\"debug_traceCall\",\"params\":[{\"from\":\"0x0000000000000000000000000000000000000000\",\"to\":\"0x0000000000000000000000000000000000000001\",\"value\":\"0x$hex_value\"},\"latest\",{\"tracer\":\"callTracer\"}],\"id\":$i}" \
            > /dev/null &
        
        # Small delay to simulate realistic batching
        if [ $((i % 10)) -eq 0 ]; then
            sleep 0.1
        fi
    done
    
    wait
    echo -e "${GREEN}✓ Batch completed${NC}"
}

# Function to check mempool
check_mempool() {
    local result=$(curl -s -X POST "$RPC_URL" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"txpool_status","params":[],"id":1}')
    
    local pending=$(echo $result | grep -o '"pending":"0x[^"]*"' | cut -d'"' -f4)
    local queued=$(echo $result | grep -o '"queued":"0x[^"]*"' | cut -d'"' -f4)
    
    local pending_dec=$((16#${pending#0x}))
    local queued_dec=$((16#${queued#0x}))
    
    echo -e "${YELLOW}Mempool: $pending_dec pending, $queued_dec queued${NC}"
}

# Pattern 1: Low Load (Idle mode test)
pattern_low_load() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Pattern 1: Low Load (Testing Idle Mode)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    send_trace_batch $PATTERN_LOW "LOW"
    sleep 2
    check_mempool
    echo -e "${GREEN}Expected: Should maintain 5s idle block time${NC}"
    sleep 8
}

# Pattern 2: Medium Load (Moderate activity)
pattern_medium_load() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Pattern 2: Medium Load (Testing Moderate Mode)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    send_trace_batch $PATTERN_MEDIUM "MEDIUM"
    sleep 2
    check_mempool
    echo -e "${GREEN}Expected: Should reduce to 2-3s block time${NC}"
    sleep 5
}

# Pattern 3: High Load (Active mode test)
pattern_high_load() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Pattern 3: High Load (Testing Active Mode)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    send_trace_batch $PATTERN_HIGH "HIGH"
    sleep 2
    check_mempool
    echo -e "${GREEN}Expected: Should activate 1s block time${NC}"
    sleep 3
}

# Pattern 4: Burst Load (Stress test)
pattern_burst_load() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Pattern 4: Burst Load (Testing Scalability)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    for burst in {1..3}; do
        echo -e "${YELLOW}Burst $burst/3${NC}"
        send_trace_batch 100 "BURST"
        sleep 3
        check_mempool
    done
    
    echo -e "${GREEN}Expected: Should handle bursts without degradation${NC}"
    sleep 5
}

# Pattern 5: Sustained High Load
pattern_sustained_high() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Pattern 5: Sustained High Load (30s)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local duration=30
    local start_time=$(date +%s)
    local batch_count=0
    
    while [ $(($(date +%s) - start_time)) -lt $duration ]; do
        send_trace_batch 20 "SUSTAINED"
        ((batch_count++))
        sleep 2
        
        if [ $((batch_count % 3)) -eq 0 ]; then
            check_mempool
        fi
    done
    
    echo -e "${GREEN}Expected: Should maintain 1s blocks throughout${NC}"
    sleep 5
}

# Menu
show_menu() {
    echo -e "\n${CYAN}Select Transaction Pattern:${NC}"
    echo -e "  ${GREEN}1${NC} - Low Load (5 txs)"
    echo -e "  ${GREEN}2${NC} - Medium Load (20 txs)"
    echo -e "  ${GREEN}3${NC} - High Load (50 txs)"
    echo -e "  ${GREEN}4${NC} - Burst Load (3x100 txs)"
    echo -e "  ${GREEN}5${NC} - Sustained High (30s continuous)"
    echo -e "  ${GREEN}6${NC} - Full Test Suite (All patterns)"
    echo -e "  ${GREEN}7${NC} - Continuous Load (Run until stopped)"
    echo -e "  ${GREEN}0${NC} - Exit"
    echo ""
    echo -ne "${YELLOW}Enter choice: ${NC}"
}

# Full test suite
run_full_suite() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              RUNNING FULL TEST SUITE                         ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    pattern_low_load
    sleep 10
    
    pattern_medium_load
    sleep 10
    
    pattern_high_load
    sleep 10
    
    pattern_burst_load
    sleep 10
    
    pattern_sustained_high
    
    echo -e "\n${GREEN}✓ Full test suite completed!${NC}"
    echo -e "${YELLOW}Check adaptive monitor for mode transitions${NC}"
}

# Continuous load
run_continuous() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         CONTINUOUS LOAD (Ctrl+C to stop)                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    local iteration=1
    
    while true; do
        echo -e "\n${BLUE}Iteration $iteration${NC}"
        
        # Vary the load randomly
        local load=$((RANDOM % 3 + 1))
        
        case $load in
            1) send_trace_batch 10 "CONTINUOUS-LOW" ;;
            2) send_trace_batch 30 "CONTINUOUS-MED" ;;
            3) send_trace_batch 60 "CONTINUOUS-HIGH" ;;
        esac
        
        check_mempool
        ((iteration++))
        sleep 3
    done
}

# Main function
main() {
    print_header
    
    if [ "$1" == "--auto" ]; then
        run_full_suite
        exit 0
    fi
    
    if [ "$1" == "--continuous" ]; then
        run_continuous
        exit 0
    fi
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1) pattern_low_load ;;
            2) pattern_medium_load ;;
            3) pattern_high_load ;;
            4) pattern_burst_load ;;
            5) pattern_sustained_high ;;
            6) run_full_suite ;;
            7) run_continuous ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
    done
}

main "$@"
