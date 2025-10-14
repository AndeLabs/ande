#!/bin/bash

# ZK Lazybridging Production Deployment Script
# ===========================================

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

# Default values
NETWORK="testnet"
RPC_URL="http://localhost:8545"
DEPLOYER_PRIVATE_KEY=""
VERIFY_CONTRACTS=true
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --rpc-url)
            RPC_URL="$2"
            shift 2
            ;;
        --private-key)
            DEPLOYER_PRIVATE_KEY="$2"
            shift 2
            ;;
        --no-verify)
            VERIFY_CONTRACTS=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Function to show help
show_help() {
    echo "ZK Lazybridging Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --network NETWORK     Network to deploy to (testnet/mainnet) [default: testnet]"
    echo "  --rpc-url URL         RPC endpoint [default: http://localhost:8545]"
    echo "  --private-key KEY     Deployer private key"
    echo "  --no-verify           Skip contract verification"
    echo "  --dry-run             Simulate deployment without executing"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --network testnet --private-key \$PRIVATE_KEY"
    echo "  $0 --network mainnet --rpc-url https://mainnet.infura.io/v3/YOUR_KEY"
    echo "  $0 --dry-run"
}

# Function to log messages
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if required tools are installed
    if ! command -v forge &> /dev/null; then
        log_error "Foundry is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check if private key is provided
    if [[ -z "$DEPLOYER_PRIVATE_KEY" && "$DRY_RUN" == false ]]; then
        log_error "Private key is required for deployment. Use --private-key option."
        exit 1
    fi
    
    # Check network connectivity
    if ! curl -s "$RPC_URL" > /dev/null; then
        log_error "Cannot connect to RPC URL: $RPC_URL"
        exit 1
    fi
    
    # Check if contracts are compiled
    if [[ ! -d "$CONTRACTS_DIR/out" ]]; then
        log "Compiling contracts..."
        cd "$CONTRACTS_DIR"
        forge build
    fi
    
    log_success "Prerequisites check passed"
}

# Function to deploy ZK Verifier
deploy_zk_verifier() {
    log "Deploying ZK Verifier contract..."
    
    cd "$CONTRACTS_DIR"
    
    local deploy_command="forge script script/DeployZKVerifier.s.sol --rpc-url $RPC_URL --broadcast"
    
    if [[ "$VERIFY_CONTRACTS" == true ]]; then
        deploy_command="$deploy_command --verify"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN: Would deploy ZK Verifier with command:"
        echo "$deploy_command"
        echo "0x1234567890123456789012345678901234567890"  # Mock address
        return
    fi
    
    deploy_command="$deploy_command --private-key $DEPLOYER_PRIVATE_KEY"
    
    if eval "$deploy_command"; then
        local verifier_address=$(grep "ZK Verifier deployed" broadcast/DeployZKVerifier.s.sol/*/run-latest.json | jq -r '.contracts[0].address')
        log_success "ZK Verifier deployed at: $verifier_address"
        echo "$verifier_address"
    else
        log_error "Failed to deploy ZK Verifier"
        exit 1
    fi
}

# Function to deploy LazybridgeRelay
deploy_lazybridge_relay() {
    local verifier_address=$1
    
    log "Deploying LazybridgeRelay contract..."
    
    cd "$CONTRACTS_DIR"
    
    local deploy_command="forge script script/DeployLazybridgeRelay.s.sol --rpc-url $RPC_URL --broadcast"
    
    if [[ "$VERIFY_CONTRACTS" == true ]]; then
        deploy_command="$deploy_command --verify"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN: Would deploy LazybridgeRelay with command:"
        echo "$deploy_command --sig \"run(address,address)\" $verifier_address 0x0000000000000000000000000000000000000000"
        echo "0x2345678901234567890123456789012345678901"  # Mock address
        return
    fi
    
    deploy_command="$deploy_command --private-key $DEPLOYER_PRIVATE_KEY --sig \"run(address,address)\" $verifier_address 0x0000000000000000000000000000000000000000"
    
    if eval "$deploy_command"; then
        local bridge_address=$(grep "LazybridgeRelay deployed" broadcast/DeployLazybridgeRelay.s.sol/*/run-latest.json | jq -r '.contracts[0].address')
        log_success "LazybridgeRelay deployed at: $bridge_address"
        echo "$bridge_address"
    else
        log_error "Failed to deploy LazybridgeRelay"
        exit 1
    fi
}

# Function to configure bridge
configure_bridge() {
    local bridge_address=$1
    
    log "Configuring bridge parameters..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN: Would configure bridge with default parameters"
        return
    fi
    
    cd "$CONTRACTS_DIR"
    
    # Configure minimum confirmations
    forge script script/ConfigureBridge.s.sol \
        --rpc-url "$RPC_URL" \
        --broadcast \
        --private-key "$DEPLOYER_PRIVATE_KEY" \
        --sig "run(address)" \
        "$bridge_address"
    
    log_success "Bridge configured successfully"
}

# Function to setup infrastructure
setup_infrastructure() {
    log "Setting up infrastructure components..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN: Would setup infrastructure components"
        return
    fi
    
    # Setup Celestia light client
    log "Setting up Celestia light client..."
    docker-compose -f "$ANDECHAIN_DIR/infra/docker-compose.celestia.yml" up -d
    
    # Setup ZK prover service
    log "Setting up ZK prover service..."
    docker-compose -f "$ANDECHAIN_DIR/infra/docker-compose.prover.yml" up -d
    
    # Setup IBC relayer
    log "Setting up IBC relayer..."
    docker-compose -f "$ANDECHAIN_DIR/infra/docker-compose.relayer.yml" up -d
    
    log_success "Infrastructure setup completed"
}

# Function to run integration tests
run_integration_tests() {
    log "Running integration tests..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN: Would run integration tests"
        return
    fi
    
    cd "$CONTRACTS_DIR"
    
    # Run lazybridge tests
    if forge test --match-contract LazybridgeRelayTest --rpc-url "$RPC_URL"; then
        log_success "Integration tests passed"
    else
        log_error "Integration tests failed"
        exit 1
    fi
}

# Function to setup monitoring
setup_monitoring() {
    log "Setting up monitoring..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN: Would setup monitoring"
        return
    fi
    
    # Deploy monitoring contracts
    cd "$CONTRACTS_DIR"
    
    forge script script/DeployMonitoring.s.sol \
        --rpc-url "$RPC_URL" \
        --broadcast \
        --private-key "$DEPLOYER_PRIVATE_KEY"
    
    # Setup Grafana dashboards
    "$ANDECHAIN_DIR/scripts/setup-grafana-dashboards.sh"
    
    log_success "Monitoring setup completed"
}

# Function to generate deployment report
generate_report() {
    local verifier_address=$1
    local bridge_address=$2
    
    log "Generating deployment report..."
    
    local report_file="$ANDECHAIN_DIR/deployment-reports/zk-lazybridging-$NETWORK-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# ZK Lazybridging Deployment Report

**Network**: $NETWORK  
**Deployment Date**: $(date)  
**Deployer**: $(echo "$DEPLOYER_PRIVATE_KEY" | cut -c1-10)...

## Deployed Contracts

### ZK Verifier
- **Address**: $verifier_address
- **Network**: $NETWORK
- **Verified**: $VERIFY_CONTRACTS

### LazybridgeRelay
- **Address**: $bridge_address
- **Network**: $NETWORK
- **Verified**: $VERIFY_CONTRACTS

## Infrastructure

- **Celestia Light Client**: Running
- **ZK Prover Service**: Running
- **IBC Relayer**: Running
- **Monitoring**: Configured

## Next Steps

1. Verify all services are running: \`make health-testnet\`
2. Run integration tests: \`forge test --match-contract LazybridgeRelayTest\`
3. Configure bridge parameters as needed
4. Monitor bridge performance via Grafana

## Support

- Documentation: [ZK Lazybridging Guide](./docs/ZK_LAZYBRIDGING_DEPLOYMENT.md)
- Issues: [GitHub Issues](https://github.com/AndeLabs/andechain/issues)
- Support: tech@andechain.com
EOF

    log_success "Deployment report generated: $report_file"
}

# Main deployment function
main() {
    log "Starting ZK Lazybridging deployment to $NETWORK"
    log "RPC URL: $RPC_URL"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN MODE - No actual deployment will be performed"
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Deploy contracts
    log "Phase 1: Contract Deployment"
    local verifier_address=$(deploy_zk_verifier)
    local bridge_address=$(deploy_lazybridge_relay "$verifier_address")
    
    # Configure bridge
    log "Phase 2: Bridge Configuration"
    configure_bridge "$bridge_address"
    
    # Setup infrastructure
    log "Phase 3: Infrastructure Setup"
    setup_infrastructure
    
    # Run tests
    log "Phase 4: Integration Testing"
    run_integration_tests
    
    # Setup monitoring
    log "Phase 5: Monitoring Setup"
    setup_monitoring
    
    # Generate report
    log "Phase 6: Report Generation"
    generate_report "$verifier_address" "$bridge_address"
    
    log_success "ZK Lazybridging deployment completed successfully!"
    
    if [[ "$DRY_RUN" == false ]]; then
        echo ""
        log "🎉 Deployment Summary:"
        echo "  ZK Verifier: $verifier_address"
        echo "  LazybridgeRelay: $bridge_address"
        echo "  Network: $NETWORK"
        echo ""
        log "📋 Next Steps:"
        echo "  1. Verify deployment: make health-testnet"
        echo "  2. Test bridge functionality"
        echo "  3. Monitor via Grafana: http://localhost:3000"
        echo "  4. Review deployment report"
    fi
}

# Execute main function
main