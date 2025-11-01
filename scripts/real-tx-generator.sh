#!/bin/bash
# =========================================================================
# ANDE CHAIN - REAL TRANSACTION GENERATOR
# =========================================================================
# Generates real signed transactions using eth_sendRawTransaction
# Tests adaptive lazy mode by populating actual mempool
# =========================================================================

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
CHAIN_ID="6174"  # 0x181e in decimal

# Test accounts (these are well-known test private keys - NEVER use in production)
PRIVATE_KEYS=(
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"  # Account 0
    "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"  # Account 1
    "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"  # Account 2
    "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"  # Account 3
    "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a"  # Account 4
)

ADDRESSES=(
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
    "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
    "0x90F79bf6EB2c4f870365E785982E1f101E93b906"
    "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"
)

# =========================================================================
# Helper Functions
# =========================================================================

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  ${MAGENTA}ANDE CHAIN - REAL TRANSACTION GENERATOR${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}▶ $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# =========================================================================
# Transaction Functions
# =========================================================================

# Get nonce for address
get_nonce() {
    local address=$1
    local result=$(curl -s -X POST "$RPC_URL" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionCount\",\"params\":[\"$address\",\"latest\"],\"id\":1}")
    echo $result | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4
}

# Get gas price
get_gas_price() {
    local result=$(curl -s -X POST "$RPC_URL" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}')
    echo $result | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4
}

# Check mempool status
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

# Create and sign transaction using eth_signTransaction
create_transaction() {
    local from_address=$1
    local to_address=$2
    local value=$3
    local nonce=$4
    local gas_price=$5
    
    # Create transaction object
    local tx_obj="{\"from\":\"$from_address\",\"to\":\"$to_address\",\"value\":\"$value\",\"gas\":\"0x5208\",\"gasPrice\":\"$gas_price\",\"nonce\":\"$nonce\"}"
    
    # For simplicity, we'll create a basic transaction
    # In production, use ethers.js or web3.py for proper signing
    echo "$tx_obj"
}

# Send simple ETH transfer (using legacy method for compatibility)
send_eth_transfer() {
    local from_idx=$1
    local to_idx=$2
    local amount=$3
    
    local from_addr="${ADDRESSES[$from_idx]}"
    local to_addr="${ADDRESSES[$to_idx]}"
    
    # Get nonce
    local nonce=$(get_nonce "$from_addr")
    local nonce_dec=$((16#${nonce#0x}))
    
    # Get gas price
    local gas_price=$(get_gas_price)
    
    # Use eth_sendTransaction (requires unlocked account or node with --unlock)
    # For testnet with pre-funded accounts
    local result=$(curl -s -X POST "$RPC_URL" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_sendTransaction\",\"params\":[{\"from\":\"$from_addr\",\"to\":\"$to_addr\",\"value\":\"$amount\",\"gas\":\"0x5208\",\"gasPrice\":\"$gas_price\"}],\"id\":1}")
    
    if echo "$result" | grep -q "error"; then
        return 1
    else
        local tx_hash=$(echo $result | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4)
        echo "$tx_hash"
        return 0
    fi
}

# =========================================================================
# Transaction Patterns
# =========================================================================

# Pattern 1: Single Transaction
pattern_single() {
    print_section "Pattern 1: Single Transaction"
    
    print_info "Sending single transaction to trigger active mode..."
    
    # Simple transfer: 0.01 ANDE
    if tx_hash=$(send_eth_transfer 0 1 "0x2386F26FC10000" 2>&1); then
        print_success "Transaction sent: $tx_hash"
    else
        print_error "Failed to send transaction"
        print_warning "Node may require unlocked accounts"
        print_info "Alternative: Use cast or ethers.js for signing"
    fi
    
    sleep 2
    check_mempool
}

# Pattern 2: Batch Transactions
pattern_batch() {
    local count=$1
    local pattern_name=$2
    
    print_section "Pattern: $pattern_name ($count transactions)"
    
    local success=0
    local failed=0
    
    for i in $(seq 1 $count); do
        local from_idx=$((i % 5))
        local to_idx=$(((i + 1) % 5))
        local amount="0x$(printf '%x' $((RANDOM * 1000000000000)))"
        
        if tx_hash=$(send_eth_transfer $from_idx $to_idx "$amount" 2>&1); then
            ((success++))
            echo -ne "${GREEN}.${NC}"
        else
            ((failed++))
            echo -ne "${RED}x${NC}"
        fi
        
        # Small delay between transactions
        sleep 0.1
    done
    
    echo ""
    print_info "Sent: $success successful, $failed failed"
    sleep 2
    check_mempool
}

# Pattern 3: Continuous load
pattern_continuous() {
    print_section "Continuous Transaction Load"
    
    print_info "Sending transactions continuously (Ctrl+C to stop)..."
    print_info "This will keep the chain in ACTIVE mode (1s blocks)"
    
    local count=0
    
    while true; do
        local from_idx=$((count % 5))
        local to_idx=$(((count + 1) % 5))
        local amount="0x$(printf '%x' $((RANDOM * 1000000000000)))"
        
        if tx_hash=$(send_eth_transfer $from_idx $to_idx "$amount" 2>&1); then
            ((count++))
            echo -ne "${GREEN}[$count]${NC} "
        else
            echo -ne "${RED}[FAIL]${NC} "
        fi
        
        # Check mempool every 10 transactions
        if [ $((count % 10)) -eq 0 ]; then
            echo ""
            check_mempool
        fi
        
        sleep 1
    done
}

# =========================================================================
# Alternative: Use cast (Foundry) for signing
# =========================================================================

try_cast_transaction() {
    print_section "Testing with Foundry Cast"
    
    if ! command -v cast &> /dev/null; then
        print_warning "Foundry cast not installed"
        print_info "Install: curl -L https://foundry.paradigm.xyz | bash"
        return 1
    fi
    
    print_info "Using cast to send signed transaction..."
    
    # Send using cast with private key
    local tx_hash=$(cast send "${ADDRESSES[1]}" \
        --value 0.01ether \
        --private-key "${PRIVATE_KEYS[0]}" \
        --rpc-url "$RPC_URL" \
        --legacy 2>&1 | grep -o '0x[a-fA-F0-9]\{64\}')
    
    if [ -n "$tx_hash" ]; then
        print_success "Transaction sent: $tx_hash"
        return 0
    else
        print_error "Failed to send transaction"
        return 1
    fi
}

# =========================================================================
# Python-based transaction generator (if Python available)
# =========================================================================

create_python_generator() {
    local script_path="/tmp/ande_tx_gen.py"
    
    cat > "$script_path" << 'EOF'
#!/usr/bin/env python3
import sys
import time
import json
from web3 import Web3
from eth_account import Account

# Configuration
RPC_URL = "http://localhost:8545"
CHAIN_ID = 6174

# Test accounts
PRIVATE_KEYS = [
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
]

def send_transaction(w3, from_key, to_address, amount_eth):
    """Send a signed transaction"""
    try:
        account = Account.from_key(from_key)
        nonce = w3.eth.get_transaction_count(account.address)
        
        tx = {
            'nonce': nonce,
            'to': to_address,
            'value': w3.to_wei(amount_eth, 'ether'),
            'gas': 21000,
            'gasPrice': w3.eth.gas_price,
            'chainId': CHAIN_ID
        }
        
        signed_tx = account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        
        return tx_hash.hex()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return None

def main():
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    
    if not w3.is_connected():
        print("Failed to connect to RPC")
        return 1
    
    print("✓ Connected to ANDE Chain")
    
    # Send test transactions
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    
    for i in range(count):
        from_key = PRIVATE_KEYS[i % 2]
        to_address = Account.from_key(PRIVATE_KEYS[(i + 1) % 2]).address
        
        tx_hash = send_transaction(w3, from_key, to_address, 0.001)
        
        if tx_hash:
            print(f"✓ Transaction {i+1}/{count}: {tx_hash}")
        else:
            print(f"✗ Transaction {i+1}/{count}: FAILED")
        
        time.sleep(0.5)
    
    # Check mempool
    pending = w3.eth.get_block('pending')['transactions']
    print(f"\n✓ Mempool: {len(pending)} pending transactions")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
EOF

    chmod +x "$script_path"
    echo "$script_path"
}

try_python_generator() {
    print_section "Testing with Python Web3"
    
    if ! command -v python3 &> /dev/null; then
        print_warning "Python3 not installed"
        return 1
    fi
    
    # Check if web3 is installed
    if ! python3 -c "import web3" 2>/dev/null; then
        print_warning "web3.py not installed"
        print_info "Install: pip install web3"
        return 1
    fi
    
    print_info "Creating Python transaction generator..."
    local script_path=$(create_python_generator)
    
    print_info "Sending 10 test transactions..."
    python3 "$script_path" 10
    
    return $?
}

# =========================================================================
# Menu System
# =========================================================================

show_menu() {
    echo ""
    echo -e "${CYAN}Select Transaction Pattern:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC} - Single Transaction (Test active mode trigger)"
    echo -e "  ${GREEN}2${NC} - Small Batch (10 transactions)"
    echo -e "  ${GREEN}3${NC} - Medium Batch (50 transactions)"
    echo -e "  ${GREEN}4${NC} - Large Batch (100 transactions)"
    echo -e "  ${GREEN}5${NC} - Continuous Load (Run until stopped)"
    echo ""
    echo -e "  ${YELLOW}Advanced Options:${NC}"
    echo -e "  ${GREEN}6${NC} - Try Foundry Cast (if installed)"
    echo -e "  ${GREEN}7${NC} - Try Python Web3 (if installed)"
    echo ""
    echo -e "  ${GREEN}0${NC} - Exit"
    echo ""
    echo -ne "${YELLOW}Enter choice: ${NC}"
}

# =========================================================================
# Main Function
# =========================================================================

main() {
    print_header
    
    # Check RPC connectivity
    if ! curl -sf -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        "$RPC_URL" >/dev/null 2>&1; then
        print_error "Cannot connect to RPC at $RPC_URL"
        exit 1
    fi
    
    print_success "Connected to ANDE Chain RPC"
    
    # Check current mempool
    echo ""
    print_info "Current mempool status:"
    check_mempool
    
    # Show warning about account unlocking
    echo ""
    print_warning "IMPORTANT: Transaction Generation Methods"
    echo ""
    echo -e "${CYAN}This script uses eth_sendTransaction which requires:${NC}"
    echo -e "  1. Unlocked accounts in the node, OR"
    echo -e "  2. Foundry cast for local signing, OR"
    echo -e "  3. Python web3 for local signing"
    echo ""
    echo -e "${YELLOW}Recommended: Use option 6 (cast) or 7 (python) for best results${NC}"
    echo ""
    
    # Interactive menu
    if [ $# -eq 0 ]; then
        while true; do
            show_menu
            read choice
            
            case $choice in
                1) pattern_single ;;
                2) pattern_batch 10 "Small Batch" ;;
                3) pattern_batch 50 "Medium Batch" ;;
                4) pattern_batch 100 "Large Batch" ;;
                5) pattern_continuous ;;
                6) try_cast_transaction ;;
                7) try_python_generator ;;
                0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
                *) print_error "Invalid choice" ;;
            esac
            
            echo ""
            read -p "Press Enter to continue..."
        done
    else
        # Command line mode
        case $1 in
            --single) pattern_single ;;
            --batch) pattern_batch ${2:-10} "Batch" ;;
            --continuous) pattern_continuous ;;
            --cast) try_cast_transaction ;;
            --python) try_python_generator ;;
            *)
                echo "Usage: $0 [--single|--batch N|--continuous|--cast|--python]"
                exit 1
                ;;
        esac
    fi
}

main "$@"
