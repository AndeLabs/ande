#!/bin/bash

# AndeChain Gas Optimization Analysis Script
# =========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDECHAIN_DIR="$(dirname "$SCRIPT_DIR")"
CONTRACTS_DIR="$ANDECHAIN_DIR/contracts"

echo -e "${BLUE}⛽ AndeChain Gas Optimization Analysis${NC}"
echo "===================================="

# Function to run gas analysis
run_gas_analysis() {
    local test_pattern=$1
    local output_file=$2
    
    echo -e "${BLUE}📊 Running gas analysis for: $test_pattern${NC}"
    
    cd "$CONTRACTS_DIR"
    
    # Run tests with gas report
    if forge test --match-test "$test_pattern" --gas-report > "$output_file" 2>&1; then
        echo -e "${GREEN}✅ Gas analysis completed${NC}"
        return 0
    else
        echo -e "${RED}❌ Gas analysis failed${NC}"
        return 1
    fi
}

# Function to extract gas data
extract_gas_data() {
    local input_file=$1
    local contract_name=$2
    
    echo -e "${BLUE}📈 Extracting gas data for $contract_name${NC}"
    
    # Extract gas usage from report
    grep -A 20 "$contract_name Contract" "$input_file" | \
    grep -E "^\|.*\|" | \
    tail -n +3 | \
    head -n -1 | \
    while IFS='|' read -r _ function min avg median max calls; do
        # Clean up the data
        function=$(echo "$function" | xargs)
        min=$(echo "$min" | xargs)
        avg=$(echo "$avg" | xargs)
        max=$(echo "$max" | xargs)
        calls=$(echo "$calls" | xargs)
        
        if [[ -n "$function" && "$function" != "Function Name" ]]; then
            printf "%-30s | %10s | %10s | %10s | %8s\n" "$function" "$min" "$avg" "$max" "$calls"
        fi
    done
}

# Function to generate optimization report
generate_optimization_report() {
    echo -e "${BLUE}📋 Generating optimization report${NC}"
    
    local report_file="$ANDECHAIN_DIR/docs/gas_analysis_report.md"
    
    cat > "$report_file" << EOF
# AndeChain Gas Analysis Report

Generated on: $(date)

## MEV System Gas Usage

### MEVDistributor Contract

$(extract_gas_data "/tmp/mev_distributor_gas.txt" "MEVDistributor")

### MEVAuctionManager Contract

$(extract_gas_data "/tmp/mev_auction_manager_gas.txt" "MEVAuctionManager")

### VotingEscrow Contract

$(extract_gas_data "/tmp/voting_escrow_gas.txt" "VotingEscrow")

## Optimization Recommendations

Based on the gas analysis above, the following optimizations are recommended:

1. **High Gas Functions**: Focus on functions with >200,000 gas
2. **Frequently Called**: Optimize functions with high call counts
3. **Storage Operations**: Reduce storage reads/writes
4. **Loop Optimization**: Minimize loop iterations

## Next Steps

1. Implement critical optimizations
2. Re-run gas analysis
3. Compare before/after metrics
4. Deploy to testnet for validation

EOF

    echo -e "${GREEN}✅ Report generated: $report_file${NC}"
}

# Function to compare gas usage
compare_gas_usage() {
    local before_file=$1
    local after_file=$2
    local contract_name=$3
    
    echo -e "${BLUE}🔄 Comparing gas usage for $contract_name${NC}"
    
    echo "Function                    | Before    | After     | Savings   | % Change"
    echo "----------------------------|-----------|-----------|-----------|----------"
    
    # This is a simplified comparison - in practice, you'd want more sophisticated parsing
    echo "Comparison functionality to be implemented"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting gas optimization analysis${NC}"
    
    # Create temporary directory
    mkdir -p /tmp/gas_analysis
    
    # Run gas analysis for key contracts
    echo ""
    echo -e "${YELLOW}📊 Analyzing MEV contracts...${NC}"
    
    # MEV Distributor
    run_gas_analysis "testFullMEVFlow" "/tmp/mev_distributor_gas.txt"
    
    # MEV Auction Manager  
    run_gas_analysis "testFullAuctionFlow" "/tmp/mev_auction_manager_gas.txt"
    
    # Voting Escrow
    run_gas_analysis "test_CreateLock" "/tmp/voting_escrow_gas.txt"
    
    # Generate optimization report
    echo ""
    generate_optimization_report
    
    # Display summary
    echo ""
    echo -e "${BLUE}📋 Analysis Summary${NC}"
    echo "==================="
    echo "✅ Gas analysis completed for key contracts"
    echo "✅ Optimization report generated"
    echo "✅ Recommendations documented"
    echo ""
    echo -e "${BLUE}📂 Output Files:${NC}"
    echo "• Report: $ANDECHAIN_DIR/docs/gas_analysis_report.md"
    echo "• Raw data: /tmp/gas_analysis/"
    echo ""
    echo -e "${BLUE}🔧 Next Steps:${NC}"
    echo "1. Review the optimization report"
    echo "2. Implement recommended optimizations"
    echo "3. Re-run analysis to measure improvements"
    echo "4. Test optimizations on testnet"
    echo ""
    echo -e "${GREEN}🎉 Gas optimization analysis completed!${NC}"
}

# Help function
show_help() {
    echo "AndeChain Gas Optimization Analysis Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --compare  Compare before/after gas usage"
    echo "  -r, --report   Generate optimization report only"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run full analysis"
    echo "  $0 --report          # Generate report only"
    echo "  $0 --compare before.txt after.txt  # Compare gas usage"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -c|--compare)
        if [[ $# -ne 3 ]]; then
            echo "Error: --compare requires two files"
            show_help
            exit 1
        fi
        compare_gas_usage "$2" "$3" "Contract"
        exit 0
        ;;
    -r|--report)
        generate_optimization_report
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "Error: Unknown option $1"
        show_help
        exit 1
        ;;
esac