#!/bin/bash
# ========================================
# ANDE Chain Production Monitoring Script
# Real-time monitoring with alerts
# ========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ALERT_THRESHOLD_BLOCKS_BEHIND=10
ALERT_THRESHOLD_DA_FAILURES=50
ALERT_THRESHOLD_PENDING_BLOBS=20
METRICS_URL="http://localhost:26660/metrics"
RPC_URL="http://localhost:8545"

# Function to print header
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  ANDE CHAIN PRODUCTION MONITOR${NC}"
    echo -e "${BLUE}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Function to get metric value
get_metric() {
    local metric_name=$1
    curl -s "$METRICS_URL" | grep "^$metric_name{" | awk '{print $NF}'
}

# Function to check block production
check_block_production() {
    echo -e "${BLUE}📊 Block Production Status:${NC}"
    
    local current_height=$(get_metric "evnode_sequencer_latest_block_height")
    local block_size=$(get_metric "evnode_sequencer_block_size_bytes")
    
    if [ -n "$current_height" ]; then
        echo -e "   Current Height: ${GREEN}$current_height${NC}"
        echo -e "   Block Size: ${GREEN}$block_size bytes${NC}"
        
        # Store current height for next check
        if [ -f /tmp/ande_last_height ]; then
            local last_height=$(cat /tmp/ande_last_height)
            local diff=$((current_height - last_height))
            
            if [ $diff -eq 0 ]; then
                echo -e "   ${RED}⚠️  WARNING: No new blocks produced!${NC}"
                return 1
            elif [ $diff -lt 5 ]; then
                echo -e "   ${YELLOW}⚠️  SLOW: Only $diff blocks in 15s${NC}"
            else
                echo -e "   ${GREEN}✅ Producing blocks normally ($diff in 15s)${NC}"
            fi
        fi
        
        echo "$current_height" > /tmp/ande_last_height
    else
        echo -e "   ${RED}❌ ERROR: Cannot fetch block height${NC}"
        return 1
    fi
    echo ""
}

# Function to check DA submissions
check_da_submissions() {
    echo -e "${BLUE}🌐 Data Availability Status:${NC}"
    
    local da_height=$(get_metric "evnode_sequencer_da_inclusion_height")
    local pending_blobs=$(get_metric "evnode_sequencer_da_submitter_pending_blobs")
    local failures=$(get_metric "evnode_sequencer_da_submitter_failures_total")
    local resends=$(get_metric "evnode_sequencer_da_submitter_resends_total")
    
    if [ -n "$da_height" ]; then
        echo -e "   DA Inclusion Height: ${GREEN}$da_height${NC}"
    fi
    
    if [ -n "$pending_blobs" ]; then
        if [ "$pending_blobs" -gt "$ALERT_THRESHOLD_PENDING_BLOBS" ]; then
            echo -e "   Pending Blobs: ${RED}$pending_blobs (HIGH!)${NC}"
        elif [ "$pending_blobs" -gt 5 ]; then
            echo -e "   Pending Blobs: ${YELLOW}$pending_blobs${NC}"
        else
            echo -e "   Pending Blobs: ${GREEN}$pending_blobs${NC}"
        fi
    fi
    
    if [ -n "$failures" ]; then
        echo -e "   Total Failures: ${YELLOW}$failures${NC}"
    fi
    
    if [ -n "$resends" ]; then
        echo -e "   Total Resends: ${YELLOW}$resends${NC}"
    fi
    
    # Check recent DA submissions from logs
    local recent_success=$(docker logs evolve-sequencer --tail 50 2>&1 | grep -c "successfully submitted items to DA layer" || echo "0")
    if [ "$recent_success" -gt 0 ]; then
        echo -e "   ${GREEN}✅ Recent DA submissions: $recent_success${NC}"
    else
        echo -e "   ${YELLOW}⚠️  No recent DA submissions${NC}"
    fi
    echo ""
}

# Function to check system resources
check_resources() {
    echo -e "${BLUE}💻 System Resources:${NC}"
    
    docker stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
        evolve-sequencer ev-reth-sequencer celestia-light | \
        while IFS=$'\t' read -r name cpu mem; do
            # Extract CPU percentage number
            cpu_num=$(echo "$cpu" | sed 's/%//' | sed 's/\..*//')
            
            # Color based on thresholds
            if [ "$cpu_num" -gt 80 ] 2>/dev/null; then
                echo -e "   ${RED}$name: CPU=$cpu MEM=$mem${NC}"
            elif [ "$cpu_num" -gt 50 ] 2>/dev/null; then
                echo -e "   ${YELLOW}$name: CPU=$cpu MEM=$mem${NC}"
            else
                echo -e "   ${GREEN}$name: CPU=$cpu MEM=$mem${NC}"
            fi
        done
    echo ""
}

# Function to check RPC health
check_rpc_health() {
    echo -e "${BLUE}🔌 RPC Health:${NC}"
    
    local block_number=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        "$RPC_URL" | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$block_number" ]; then
        local decimal_block=$((16#${block_number#0x}))
        echo -e "   ${GREEN}✅ RPC Responsive${NC}"
        echo -e "   EVM Block: ${GREEN}$decimal_block${NC}"
    else
        echo -e "   ${RED}❌ RPC Not Responding${NC}"
        return 1
    fi
    echo ""
}

# Function to check for errors
check_errors() {
    echo -e "${BLUE}⚠️  Recent Errors:${NC}"
    
    local error_count=$(docker logs evolve-sequencer --tail 100 2>&1 | grep -c '"level":"error"' || echo "0")
    
    if [ "$error_count" -gt 50 ]; then
        echo -e "   ${RED}❌ HIGH ERROR COUNT: $error_count in last 100 logs${NC}"
        echo -e "   ${YELLOW}Recent errors:${NC}"
        docker logs evolve-sequencer --tail 100 2>&1 | grep '"level":"error"' | tail -3 | while read line; do
            echo -e "   ${RED}$line${NC}"
        done
    elif [ "$error_count" -gt 10 ]; then
        echo -e "   ${YELLOW}⚠️  MODERATE ERROR COUNT: $error_count in last 100 logs${NC}"
    else
        echo -e "   ${GREEN}✅ Error count normal: $error_count${NC}"
    fi
    echo ""
}

# Function to display summary
display_summary() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  SUMMARY${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    local status="${GREEN}HEALTHY${NC}"
    local issues=0
    
    # Check if there are any issues
    local pending_blobs=$(get_metric "evnode_sequencer_da_submitter_pending_blobs")
    if [ -n "$pending_blobs" ] && [ "$pending_blobs" -gt "$ALERT_THRESHOLD_PENDING_BLOBS" ]; then
        status="${RED}DEGRADED${NC}"
        ((issues++))
    fi
    
    echo -e "   Chain Status: $status"
    echo -e "   Issues Detected: $issues"
    echo -e "${BLUE}========================================${NC}"
}

# Main monitoring loop
main() {
    if [ "$1" == "--watch" ]; then
        # Continuous monitoring mode
        while true; do
            clear
            print_header
            check_block_production
            check_da_submissions
            check_resources
            check_rpc_health
            check_errors
            display_summary
            
            echo -e "${BLUE}Refreshing in 15 seconds... (Ctrl+C to stop)${NC}"
            sleep 15
        done
    else
        # Single run
        print_header
        check_block_production
        check_da_submissions
        check_resources
        check_rpc_health
        check_errors
        display_summary
    fi
}

# Run main function
main "$@"
