# Manual Deployment Guide - ANDE Chain Contracts

## Status ✅
- **ANDETokenDuality**: ✅ DEPLOYED
- **Governance**: ⏳ Ready to Deploy
- **Staking**: ⏳ Ready to Deploy

---

## Deployed Contracts

### 1. ANDE Token Duality (Chain ID: 6174)
```
Precompile Address:       0x5FbDB2315678afecb367f032d93F642f64180aa3
Implementation Address:   0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
Proxy Address (USE THIS): 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0

Initial Supply: 100,000,000 ANDE
Decimals: 18
Faucet: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

**Features:**
- ✅ Token Duality (Native + ERC-20)
- ✅ ERC1967 Proxy Pattern
- ✅ Access Control (Admin, Minter)
- ✅ Precompile Integration at 0xFD

---

## Next Steps

### Deploy Governance (Manual)

```bash
# Set variables
export RPC_URL="http://localhost:8545"
export ANDE_TOKEN="0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"

# Deploy AndeTimelockController
forge create src/governance/AndeTimelockController.sol:AndeTimelockController \
  --rpc-url $RPC_URL \
  --constructor-args \
    "2592000" \
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" \
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" \
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" \
  --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f02d45b19e8bfb81"

# Deploy AndeGovernor
forge create src/governance/AndeGovernor.sol:AndeGovernor \
  --rpc-url $RPC_URL \
  --constructor-args \
    "$ANDE_TOKEN" \
    "TIMELOCK_ADDRESS" \
  --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f02d45b19e8bfb81"
```

### Deploy Staking (VotingEscrow + Gauges)

```bash
# Deploy VotingEscrow
forge create src/gauges/VotingEscrow.sol:VotingEscrow \
  --rpc-url http://localhost:8545 \
  --constructor-args \
    "$ANDE_TOKEN" \
    "veANDE" \
    "veANDE" \
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" \
  --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f02d45b19e8bfb81"

# Deploy GaugeController
forge create src/gauges/GaugeController.sol:GaugeController \
  --rpc-url http://localhost:8545 \
  --constructor-args \
    "VE_ADDRESS" \
    "GOVERNANCE_ADDRESS" \
  --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f02d45b19e8bfb81"
```

---

## Quick Test Transaction

```bash
# Test ANDE Transfer
cast send 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 \
  "transfer(address,uint256)" \
  "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" \
  "1000000000000000000" \
  --rpc-url http://localhost:8545 \
  --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f02d45b19e8bfb81"

# Check Balance
cast call 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 \
  "balanceOf(address)" \
  "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" \
  --rpc-url http://localhost:8545
```

---

## Environment Setup

```bash
# Add to .env in contracts directory
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f02d45b19e8bfb81
RPC_URL=http://localhost:8545
CHAIN_ID=6174
```

---

## Deployment Notes

- **Default Account**: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` (Hardhat Account #0)
- **Private Key**: `0xac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f02d45b19e8bfb81`
- **Initial Balance**: 10,000 ETH (test tokens)

---

## Verification Commands

```bash
# Check token details
cast call 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 "name()" --rpc-url http://localhost:8545
cast call 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 "symbol()" --rpc-url http://localhost:8545
cast call 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 "totalSupply()" --rpc-url http://localhost:8545
cast call 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 "decimals()" --rpc-url http://localhost:8545

# Check balance
cast call 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 \
  "balanceOf(address)" \
  "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" \
  --rpc-url http://localhost:8545
```

---

**Last Updated**: 2025-10-30
**Status**: ANDE Token Duality Live on Testnet ✅
