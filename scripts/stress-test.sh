#!/bin/bash
# ========================================
# ANDE Chain Stress Testing Script
# Automated stress tests for production readiness
# ========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
RPC_URL="http://localhost:8545"
METRICS_URL="http://localhost:26660/metrics"
TEST_DURATION=30
CONCURRENT_REQUESTS=100

# Function to print header
print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  ANDE CHAIN STRESS TEST${NC}"
    echo -e "${CYAN}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# Function to get metric value
get_metric() {
    local metric_name=$1
    curl -s "$METRICS_URL" | grep "^$metric_name " | awk '{print $2}'
}

# Function to get block height
get_block_height() {
    curl -s "$METRICS_URL" | grep "evnode_sequencer_latest_block_height" | awk '{print $2}'
}

# Test 1: High Frequency RPC Calls
test_high_frequency_rpc() {
    echo -e "${BLUE}Test 1: High Frequency RPC Calls${NC}"
    echo -e "Sending $CONCURRENT_REQUESTS concurrent eth_call requests..."
    
    local start_height=$(get_block_height)
    local start_time=$(date +%s)
    
    # Generate concurrent requests
    for i in $(seq 1 $CONCURRENT_REQUESTS); do
        curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" \
            -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"0x0000000000000000000000000000000000000001\",\"data\":\"0x\"},\"latest\"],\"id\":$i}" \
            > /dev/null &
    done
    
    wait
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local end_height=$(get_block_height)
    local blocks_produced=$((end_height - start_height))
    
    echo -e "   ${GREEN}✅ Completed in ${duration}s${NC}"
    echo -e "   Blocks produced during test: ${GREEN}$blocks_produced${NC}"
    echo ""
}

# Test 2: Large Data Transactions
test_large_data() {
    echo -e "${BLUE}Test 2: Large Data Transaction Simulation${NC}"
    echo -e "Sending 50 debug_traceCall requests with large data..."
    
    local start_height=$(get_block_height)
    
    for i in $(seq 1 50); do
        local hex_data=$(printf '%0128x' $i)
        curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" \
            -d "{\"jsonrpc\":\"2.0\",\"method\":\"debug_traceCall\",\"params\":[{\"to\":\"0x0000000000000000000000000000000000000001\",\"data\":\"0x$hex_data\"},\"latest\",{\"tracer\":\"callTracer\"}],\"id\":$i}" \
            > /dev/null &
    done
    
    wait
    
    local end_height=$(get_block_height)
    local blocks_produced=$((end_height - start_height))
    
    echo -e "   ${GREEN}✅ Completed${NC}"
    echo -e "   Blocks produced: ${GREEN}$blocks_produced${NC}"
    echo ""
}

# Test 3: Sustained Load
test_sustained_load() {
    echo -e "${BLUE}Test 3: Sustained Load (${TEST_DURATION}s)${NC}"
    echo -e "Maintaining constant load on RPC endpoint..."
    
    local start_height=$(get_block_height)
    local start_time=$(date +%s)
    local request_count=0
    
    while [ $(($(date +%s) - start_time)) -lt $TEST_DURATION ]; do
        for i in {1..10}; do
            curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" \
                -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
                > /dev/null &
            ((request_count++))
        done
        sleep 0.5
    done
    
    wait
    
    local end_height=$(get_block_height)
    local blocks_produced=$((end_height - start_height))
    local avg_block_time=$((TEST_DURATION / blocks_produced))
    
    echo -e "   ${GREEN}✅ Completed${NC}"
    echo -e "   Total requests: ${GREEN}$request_count${NC}"
    echo -e "   Blocks produced: ${GREEN}$blocks_produced${NC}"
    echo -e "   Avg block time: ${GREEN}${avg_block_time}s${NC}"
    echo ""
}

# Test 4: Resource Monitoring Under Load
test_resource_monitoring() {
    echo -e "${BLUE}Test 4: Resource Monitoring Under Load${NC}"
    
    # Start load in background
    for i in {1..200}; do
        curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" \
            -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"0x0000000000000000000000000000000000000001\"},\"latest\"],\"id\":$i}" \
            > /dev/null &
    done
    
    # Monitor resources during load
    echo -e "   Sampling resources during peak load..."
    sleep 2
    
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
        evolve-sequencer ev-reth-sequencer celestia-light
    
    wait
    
    echo -e "   ${GREEN}✅ Resource check completed${NC}"
    echo ""
}

# Test 5: DA Layer Stress
test_da_layer() {
    echo -e "${BLUE}Test 5: DA Layer Monitoring${NC}"
    
    local pending_before=$(get_metric "evnode_sequencer_da_submitter_pending_blobs")
    local failures_before=$(get_metric "evnode_sequencer_da_submitter_failures_total")
    
    echo -e "   Initial pending blobs: ${YELLOW}$pending_before${NC}"
    echo -e "   Initial failures: ${YELLOW}$failures_before${NC}"
    
    # Wait to see DA activity
    echo -e "   Monitoring DA for 30 seconds..."
    sleep 30
    
    local pending_after=$(get_metric "evnode_sequencer_da_submitter_pending_blobs")
    local failures_after=$(get_metric "evnode_sequencer_da_submitter_failures_total")
    
    echo -e "   Final pending blobs: ${YELLOW}$pending_after${NC}"
    echo -e "   Final failures: ${YELLOW}$failures_after${NC}"
    
    local new_failures=$((failures_after - failures_before))
    
    if [ "$new_failures" -eq 0 ]; then
        echo -e "   ${GREEN}✅ No new DA failures${NC}"
    else
        echo -e "   ${RED}⚠️  New failures: $new_failures${NC}"
    fi
    echo ""
}

# Function to check system health before tests
pre_test_check() {
    echo -e "${YELLOW}Pre-Test Health Check...${NC}"
    
    # Check if services are running
    if ! docker ps | grep -q "evolve-sequencer"; then
        echo -e "${RED}❌ Sequencer not running!${NC}"
        exit 1
    fi
    
    if ! docker ps | grep -q "ev-reth-sequencer"; then
        echo -e "${RED}❌ EVM not running!${NC}"
        exit 1
    fi
    
    # Check RPC
    if ! curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | grep -q "result"; then
        echo -e "${RED}❌ RPC not responding!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All systems ready${NC}"
    echo ""
}

# Function to display results summary
display_summary() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  TEST SUMMARY${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    local current_height=$(get_block_height)
    local pending_blobs=$(get_metric "evnode_sequencer_da_submitter_pending_blobs")
    local failures=$(get_metric "evnode_sequencer_da_submitter_failures_total")
    
    echo -e "   Current Block Height: ${GREEN}$current_height${NC}"
    echo -e "   Pending DA Blobs: ${YELLOW}$pending_blobs${NC}"
    echo -e "   Total DA Failures: ${YELLOW}$failures${NC}"
    
    # Check recent errors
    local error_count=$(docker logs evolve-sequencer --tail 200 2>&1 | grep -c '"level":"error"' || echo "0")
    
    if [ "$error_count" -gt 100 ]; then
        echo -e "   Error Count: ${RED}$error_count (HIGH)${NC}"
    elif [ "$error_count" -gt 20 ]; then
        echo -e "   Error Count: ${YELLOW}$error_count (MODERATE)${NC}"
    else
        echo -e "   Error Count: ${GREEN}$error_count (NORMAL)${NC}"
    fi
    
    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}✅ Stress tests completed!${NC}"
}

# Main function
main() {
    print_header
    pre_test_check
    
    test_high_frequency_rpc
    test_large_data
    test_sustained_load
    test_resource_monitoring
    test_da_layer
    
    display_summary
}

# Run main function
main "$@"
