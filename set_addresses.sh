#!/bin/bash
# ============================================
# AndeChain - Variables de Entorno
# ============================================
# Generado automáticamente: Sun Oct  5 16:03:58 -04 2025

export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export DEPLOYER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# Core Tokens
export ANDE_TOKEN=0x5eb3Bc0a489C5A8288765d2336659EbCA68FCd00
export AUSD_TOKEN=0x809d550fca64d94Bd9F66E60752A544199cfAC3D
export ABOB_TOKEN=0x1291Be112d480055DaFd8a610b7d1e203891C274
0xb7278A61aa25c888815aFC32Ad3cC52fF24fE575
export SABOB_TOKEN=0xb7278A61aa25c888815aFC32Ad3cC52fF24fE575

# Governance
export VEANDE=0x82e01223d51Eb87e16A03E24687EDF0F294da6f1
export MINT_CONTROLLER=0x7969c5eD335650692Bc04293B07F5BF2e7A673C0
export BURN_ENGINE=0xc351628EB244ec633d5f21fBD6621e1a683B1181

# Stability
export STABILITY_ENGINE=0x1fA02b2d6A771842690194Cf62D91bdd92BfE28d

# Bridge
export ANDE_BRIDGE=0xdbC43Ba45381e02825b14322cDdd15eC4B3164E6
0xdbC43Ba45381e02825b14322cDdd15eC4B3164E6
export ETH_BRIDGE=0x04C89607413713Ec9775E14b954286519d836FEf
0x04C89607413713Ec9775E14b954286519d836FEf

# Mocks
export MOCK_USDC=0xf5059a5D33d5853360D16C683c16e67980206f36
0xf5059a5D33d5853360D16C683c16e67980206f36

echo "✅ Variables de entorno configuradas para AndeChain"
echo ""
echo "CORE TOKENS:"
echo "  🔹 ANDE Token:    $ANDE_TOKEN"
echo "  🔹 aUSD Token:    $AUSD_TOKEN"
echo "  🔹 ABOB Token:    $ABOB_TOKEN"
echo "  🔹 sABOB Token:   $SABOB_TOKEN"
echo ""
echo "GOVERNANCE:"
echo "  🔹 VeANDE:        $VEANDE"
echo "  🔹 MintController: $MINT_CONTROLLER"
echo ""
echo "STABILITY:"
echo "  🔹 StabilityEngine: $STABILITY_ENGINE"
echo ""
echo "BRIDGE:"
echo "  🔹 AndeBridge:    $ANDE_BRIDGE"
echo "  🔹 EthBridge:     $ETH_BRIDGE"
echo ""
echo "Uso: source set_addresses.sh"
