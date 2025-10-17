#!/bin/bash

# AndeChain Sequencer Entrypoint for Celestia Mocha Testnet
# ========================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to print header
print_header() {
    echo -e "${PURPLE}🌙 AndeChain Sequencer - Celestia Mocha Testnet${NC}"
    echo -e "${PURPLE}============================================${NC}"
}

# Load environment variables
if [ -f "/usr/local/lib/logging.sh" ]; then
    source /usr/local/lib/logging.sh
fi

print_header
echo ""

print_info "Initializing AndeChain Sequencer for Celestia Mocha..."
echo ""

# Check required environment variables
required_vars=(
    "EVM_ENGINE_URL"
    "EVM_ETH_URL" 
    "EVM_JWT_PATH"
    "EVM_BLOCK_TIME"
    "EVM_SIGNER_PASSPHRASE"
    "DA_ADDRESS"
    "DA_BLOCK_TIME"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    print_error "Missing required environment variables:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    exit 1
fi

print_status "Environment variables verified"

# Wait for EVM engine to be ready
print_info "Waiting for EVM engine to be ready..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -s -f "$EVM_ENGINE_URL" > /dev/null 2>&1; then
        print_status "EVM engine is ready"
        break
    fi
    
    if [ $attempt -eq $max_attempts ]; then
        print_error "EVM engine is not ready after $max_attempts attempts"
        exit 1
    fi
    
    print_warning "Attempt $attempt/$max_attempts: EVM engine not ready, waiting..."
    sleep 2
    ((attempt++))
done

# Wait for DA layer to be ready
print_info "Waiting for Celestia DA layer to be ready..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -s -f "$DA_ADDRESS" > /dev/null 2>&1; then
        print_status "Celestia DA layer is ready"
        break
    fi
    
    if [ $attempt -eq $max_attempts ]; then
        print_error "Celestia DA layer is not ready after $max_attempts attempts"
        exit 1
    fi
    
    print_warning "Attempt $attempt/$max_attempts: DA layer not ready, waiting..."
    sleep 2
    ((attempt++))
done

# Initialize sequencer if not already initialized
if [ ! -d "/root/.evm-single/config" ]; then
    print_info "Initializing sequencer..."
    evm-single init \
        --evnode.node.aggregator=true \
        --evnode.signer.passphrase="$EVM_SIGNER_PASSPHRASE" \
        --home /root/.evm-single
    print_status "Sequencer initialized"
else
    print_info "Sequencer already initialized"
fi

# Get JWT secret
if [ ! -f "$EVM_JWT_PATH" ]; then
    print_error "JWT secret file not found: $EVM_JWT_PATH"
    exit 1
fi

JWT_SECRET=$(cat "$EVM_JWT_PATH")
print_status "JWT secret loaded"

# Get genesis hash from EVM engine
print_info "Getting genesis hash from EVM engine..."
GENESIS_HASH=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x0", false],"id":1}' \
    "$EVM_ETH_URL" | jq -r '.result.hash')

if [ -z "$GENESIS_HASH" ] || [ "$GENESIS_HASH" = "null" ]; then
    print_error "Failed to get genesis hash from EVM engine"
    exit 1
fi

print_status "Genesis hash: $GENESIS_HASH"

# Display configuration
echo ""
print_info "Sequencer Configuration:"
echo "  EVM Engine URL: $EVM_ENGINE_URL"
echo "  EVM ETH URL: $EVM_ETH_URL"
echo "  DA Address: $DA_ADDRESS"
echo "  Block Time: $EVM_BLOCK_TIME"
echo "  DA Block Time: $DA_BLOCK_TIME"
echo "  Genesis Hash: $GENESIS_HASH"
echo "  Aggregator Mode: true"
echo ""

# Start the sequencer
print_info "Starting AndeChain sequencer..."
echo ""

exec evm-single start \
    --home /root/.evm-single \
    --evm.jwt-secret "$JWT_SECRET" \
    --evm.genesis-hash "$GENESIS_HASH" \
    --evm.engine-url "$EVM_ENGINE_URL" \
    --evm.eth-url "$EVM_ETH_URL" \
    --evnode.node.block-time "$EVM_BLOCK_TIME" \
    --evnode.node.aggregator=true \
    --evnode.signer.passphrase "$EVM_SIGNER_PASSPHRASE" \
    --evnode.da.block-time "$DA_BLOCK_TIME" \
    --evnode.da.address "$DA_ADDRESS" \
    --evnode.rpc.address=0.0.0.0:7331 \
    --evnode.p2p.listen-address=/ip4/0.0.0.0/tcp/7676 \
    --evnode.instrumentation.prometheus \
    --evnode.instrumentation.prometheus-listen-addr=:26660 \
    --log.level info