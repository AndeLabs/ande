# 🗺️ ABOB - Roadmap de Próximos Pasos
**Del Estado Actual a Testnet Público en 4 Semanas**

---

## 🎯 Objetivo Inmediato

**MILESTONE:** Testnet público funcional con bridge xERC20 para ABOB
**DEADLINE:** 4 semanas desde hoy (6 de Noviembre, 2025)
**SUCCESS CRITERIA:**
- ✅ Bridge ABOB entre Ethereum Sepolia ↔ AndeChain Testnet
- ✅ Tests completos con >90% coverage
- ✅ Documentación de usuario completa
- ✅ Relayer funcionando 24/7
- ✅ Bug bounty de $10k activo

---

## 📅 SEMANA 1: Testing & Bridge Implementation

### Día 1-2: Tests del Bridge (PRIORIDAD MÁXIMA)

**Archivo:** `/contracts/test/bridge/AndeChainBridge.t.sol`

**Tests a Implementar:**

```solidity
// ✅ Ya existe: test_BridgeTokens_Success()

// ⏳ Agregar:
function test_BridgeTokens_RateLimitExceeded() external {
    // Setup: Configure rate limit de 1000 ABOB/hora
    // Action: Intentar bridge 2000 ABOB
    // Assert: Revert con IXERC20_NotHighEnoughLimits
}

function test_BridgeTokens_UnsupportedToken() external {
    // Action: Intentar bridge token no soportado
    // Assert: Revert con TokenNotSupported
}

function test_BridgeTokens_InvalidRecipient() external {
    // Action: Bridge a address(0)
    // Assert: Revert con InvalidRecipient
}

function test_BridgeTokens_DestinationChainNotConfigured() external {
    // Action: Bridge a chainId no configurado
    // Assert: Revert con DestinationChainNotConfigured
}

function test_ReceiveTokens_Success() external {
    // Setup: Mock Blobstream proof válido
    // Action: Relayer llama receiveTokens()
    // Assert: Tokens minted, evento emitido
}

function test_ReceiveTokens_InvalidProof() external {
    // Setup: Mock Blobstream proof inválido
    // Action: receiveTokens()
    // Assert: Revert con ProofVerificationFailed
}

function test_ReceiveTokens_ReplayAttack() external {
    // Setup: Procesar transacción una vez
    // Action: Intentar procesar misma transacción
    // Assert: Revert con TransactionAlreadyProcessed
}

function test_ForceTransaction_Success() external {
    // Setup: Wait forceInclusionPeriod
    // Action: Usuario llama forceTransaction()
    // Assert: Tokens received sin relayer
}

function test_ForceTransaction_PeriodNotElapsed() external {
    // Action: Llamar antes de period elapsed
    // Assert: Revert con ForcePeriodNotElapsed
}

function test_Pause_UnpauseFlow() external {
    // Action: Owner pausa bridge
    // Assert: bridgeTokens() revierte
    // Action: Owner despausa
    // Assert: bridgeTokens() funciona
}
```

**Comandos:**
```bash
cd contracts

# Ejecutar tests del bridge
forge test --match-path test/bridge/AndeChainBridge.t.sol -vvv

# Coverage específica del bridge
forge coverage --match-path src/bridge/AndeChainBridge.sol

# Gas report
forge test --match-path test/bridge/AndeChainBridge.t.sol --gas-report
```

**Deliverable Día 2:**
- [ ] 15+ tests del bridge
- [ ] >95% coverage de AndeChainBridge.sol
- [ ] Gas report optimizado (<100k gas por bridge operation)

---

### Día 3-4: xERC20ABOB Implementation

**Nuevo Archivo:** `/contracts/src/tokens/xERC20ABOB.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IXERC20} from "../interfaces/IXERC20.sol";

/**
 * @title xERC20ABOB
 * @notice xERC20 implementation for ABOB token with rate-limited bridging
 * @dev Implements ERC-7281 standard for sovereign cross-chain tokens
 */
contract xERC20ABOB is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IXERC20
{
    // ==================== ROLES ====================
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    // ==================== STATE ====================
    mapping(address => Bridge) public bridges;
    address public lockbox;

    // ==================== ERRORS ====================
    error IXERC20_NotHighEnoughLimits();
    error IXERC20_INVALID_0_VALUE();
    error NotBridge();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin) public initializer {
        __ERC20_init("Andean Boliviano xERC20", "ABOB");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    // ==================== XERC20 IMPLEMENTATION ====================

    function setLimits(
        address bridge,
        uint256 mintingLimit,
        uint256 burningLimit
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _changeMinterLimit(bridge, mintingLimit);
        _changeBurnerLimit(bridge, burningLimit);
        emit BridgeLimitsSet(mintingLimit, burningLimit, bridge);
    }

    function mint(address user, uint256 amount) external {
        if (!hasRole(BRIDGE_ROLE, msg.sender)) revert NotBridge();
        _useMinterLimits(msg.sender, amount);
        _mint(user, amount);
    }

    function burn(address user, uint256 amount) external {
        if (!hasRole(BRIDGE_ROLE, msg.sender)) revert NotBridge();
        _useBurnerLimits(msg.sender, amount);
        _burn(user, amount);
    }

    // ==================== VIEW FUNCTIONS ====================

    function mintingMaxLimitOf(address minter) external view returns (uint256) {
        return bridges[minter].minterParams.maxLimit;
    }

    function burningMaxLimitOf(address burner) external view returns (uint256) {
        return bridges[burner].burnerParams.maxLimit;
    }

    function mintingCurrentLimitOf(address minter) external view returns (uint256) {
        return _getCurrentLimit(bridges[minter].minterParams);
    }

    function burningCurrentLimitOf(address burner) external view returns (uint256) {
        return _getCurrentLimit(bridges[burner].burnerParams);
    }

    // ==================== INTERNAL FUNCTIONS ====================

    function _changeMinterLimit(address bridge, uint256 limit) internal {
        BridgeParameters storage params = bridges[bridge].minterParams;
        params.maxLimit = limit;
        params.currentLimit = limit;
        params.timestamp = block.timestamp;
        params.ratePerSecond = limit / 1 days; // Replenish over 1 day
    }

    function _changeBurnerLimit(address bridge, uint256 limit) internal {
        BridgeParameters storage params = bridges[bridge].burnerParams;
        params.maxLimit = limit;
        params.currentLimit = limit;
        params.timestamp = block.timestamp;
        params.ratePerSecond = limit / 1 days;
    }

    function _getCurrentLimit(BridgeParameters storage params) internal view returns (uint256) {
        uint256 elapsed = block.timestamp - params.timestamp;
        uint256 replenished = elapsed * params.ratePerSecond;
        uint256 newLimit = params.currentLimit + replenished;

        return newLimit > params.maxLimit ? params.maxLimit : newLimit;
    }

    function _useMinterLimits(address bridge, uint256 amount) internal {
        BridgeParameters storage params = bridges[bridge].minterParams;
        uint256 currentLimit = _getCurrentLimit(params);

        if (currentLimit < amount) revert IXERC20_NotHighEnoughLimits();

        params.currentLimit = currentLimit - amount;
        params.timestamp = block.timestamp;
    }

    function _useBurnerLimits(address bridge, uint256 amount) internal {
        BridgeParameters storage params = bridges[bridge].burnerParams;
        uint256 currentLimit = _getCurrentLimit(params);

        if (currentLimit < amount) revert IXERC20_NotHighEnoughLimits();

        params.currentLimit = currentLimit - amount;
        params.timestamp = block.timestamp;
    }

    function setLockbox(address _lockbox) external onlyRole(DEFAULT_ADMIN_ROLE) {
        lockbox = _lockbox;
        emit LockboxSet(_lockbox);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
```

**Test File:** `/contracts/test/tokens/xERC20ABOB.t.sol`

**Deliverable Día 4:**
- [ ] xERC20ABOB.sol implementado
- [ ] Tests completos (mint, burn, rate limits)
- [ ] Deploy script para testnet

---

### Día 5-7: Mock Blobstream & Integration

**Problema:** Blobstream real no está en testnet todavía.

**Solución:** Mock implementation para testing.

**Nuevo Archivo:** `/contracts/src/mocks/MockBlobstream.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IBlobstream} from "../bridge/IBlobstream.sol";

/**
 * @title MockBlobstream
 * @notice Mock implementation of Blobstream for testing
 * @dev In production, this will be replaced with actual Celestia Blobstream
 */
contract MockBlobstream is IBlobstream {
    // Owner can set verification results
    address public owner;

    // Mapping of txHash => valid
    mapping(bytes32 => bool) public validProofs;

    constructor() {
        owner = msg.sender;
    }

    function setProofValid(bytes32 txHash, bool valid) external {
        require(msg.sender == owner, "Only owner");
        validProofs[txHash] = valid;
    }

    function verifyAttestation(
        bytes32 txHash,
        uint256 /* sourceChain */,
        bytes calldata /* proof */,
        uint256 /* minConfirmations */
    ) external view override returns (bool) {
        return validProofs[txHash];
    }
}
```

**Integration Test:** `/contracts/test/integration/BridgeIntegration.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {xERC20ABOB} from "../../src/tokens/xERC20ABOB.sol";
import {AndeChainBridge} from "../../src/bridge/AndeChainBridge.sol";
import {MockBlobstream} from "../../src/mocks/MockBlobstream.sol";

contract BridgeIntegrationTest is Test {
    xERC20ABOB abobEthereum;
    xERC20ABOB abobAndeChain;
    AndeChainBridge bridgeEthereum;
    AndeChainBridge bridgeAndeChain;
    MockBlobstream blobstream;

    address user = address(0x1);
    uint256 constant ETHEREUM_CHAIN_ID = 1;
    uint256 constant ANDECHAIN_CHAIN_ID = 888;

    function setUp() public {
        // Deploy contracts
        blobstream = new MockBlobstream();

        abobEthereum = new xERC20ABOB();
        abobEthereum.initialize(address(this));

        abobAndeChain = new xERC20ABOB();
        abobAndeChain.initialize(address(this));

        bridgeEthereum = new AndeChainBridge(
            address(this),
            address(blobstream),
            1,
            1 hours
        );

        bridgeAndeChain = new AndeChainBridge(
            address(this),
            address(blobstream),
            1,
            1 hours
        );

        // Configure bridges
        abobEthereum.grantRole(abobEthereum.BRIDGE_ROLE(), address(bridgeEthereum));
        abobAndeChain.grantRole(abobAndeChain.BRIDGE_ROLE(), address(bridgeAndeChain));

        // Set limits: 10k ABOB per day
        abobEthereum.setLimits(address(bridgeEthereum), 10_000e18, 10_000e18);
        abobAndeChain.setLimits(address(bridgeAndeChain), 10_000e18, 10_000e18);

        // Add supported tokens
        bridgeEthereum.addSupportedToken(address(abobEthereum));
        bridgeAndeChain.addSupportedToken(address(abobAndeChain));

        // Set destination bridges
        bridgeEthereum.setDestinationBridge(ANDECHAIN_CHAIN_ID, address(bridgeAndeChain));
        bridgeAndeChain.setDestinationBridge(ETHEREUM_CHAIN_ID, address(bridgeEthereum));

        // Mint some ABOB to user on Ethereum
        abobEthereum.mint(user, 1000e18);
    }

    function test_FullBridgeFlow_EthereumToAndeChain() public {
        uint256 bridgeAmount = 500e18;

        // User bridges from Ethereum
        vm.startPrank(user);
        abobEthereum.approve(address(bridgeEthereum), bridgeAmount);

        vm.expectEmit(true, true, true, true);
        emit AndeChainBridge.TokensBridged(
            address(abobEthereum),
            user,
            user,
            bridgeAmount,
            ANDECHAIN_CHAIN_ID,
            0 // nonce
        );

        bridgeEthereum.bridgeTokens(
            address(abobEthereum),
            user,
            bridgeAmount,
            ANDECHAIN_CHAIN_ID
        );
        vm.stopPrank();

        // Verify tokens burned on Ethereum
        assertEq(abobEthereum.balanceOf(user), 500e18);

        // Simulate relayer processing
        bytes32 txHash = keccak256("ethereum_tx_hash");
        blobstream.setProofValid(txHash, true);

        // Relayer calls receiveTokens on AndeChain
        bridgeAndeChain.receiveTokens(
            address(abobAndeChain),
            user,
            bridgeAmount,
            ETHEREUM_CHAIN_ID,
            txHash,
            bytes("mock_proof")
        );

        // Verify tokens minted on AndeChain
        assertEq(abobAndeChain.balanceOf(user), bridgeAmount);
    }

    function test_RoundTripBridge() public {
        // Ethereum → AndeChain
        test_FullBridgeFlow_EthereumToAndeChain();

        // AndeChain → Ethereum
        uint256 returnAmount = 300e18;

        vm.startPrank(user);
        abobAndeChain.approve(address(bridgeAndeChain), returnAmount);

        bridgeAndeChain.bridgeTokens(
            address(abobAndeChain),
            user,
            returnAmount,
            ETHEREUM_CHAIN_ID
        );
        vm.stopPrank();

        // Relayer processes
        bytes32 txHash = keccak256("andechain_tx_hash");
        blobstream.setProofValid(txHash, true);

        bridgeEthereum.receiveTokens(
            address(abobEthereum),
            user,
            returnAmount,
            ANDECHAIN_CHAIN_ID,
            txHash,
            bytes("mock_proof")
        );

        // Final balances
        assertEq(abobEthereum.balanceOf(user), 800e18); // 500 + 300 returned
        assertEq(abobAndeChain.balanceOf(user), 200e18); // 500 - 300 bridged back
    }
}
```

**Deliverable Día 7:**
- [ ] MockBlobstream funcionando
- [ ] Integration tests completos
- [ ] Documentación de flujos

---

## 📅 SEMANA 2: Deployment Scripts & Relayer

### Día 8-10: Deployment Scripts

**Archivo:** `/contracts/script/DeployBridgeEcosystem.s.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {xERC20ABOB} from "../src/tokens/xERC20ABOB.sol";
import {AndeChainBridge} from "../src/bridge/AndeChainBridge.sol";
import {MockBlobstream} from "../src/mocks/MockBlobstream.sol";

contract DeployBridgeEcosystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying with account:", deployer);

        // 1. Deploy MockBlobstream
        MockBlobstream blobstream = new MockBlobstream();
        console.log("MockBlobstream deployed:", address(blobstream));

        // 2. Deploy xERC20ABOB
        xERC20ABOB abob = new xERC20ABOB();
        abob.initialize(deployer);
        console.log("xERC20ABOB deployed:", address(abob));

        // 3. Deploy Bridge
        AndeChainBridge bridge = new AndeChainBridge(
            deployer,
            address(blobstream),
            1, // minConfirmations
            6 hours // forceInclusionPeriod
        );
        console.log("AndeChainBridge deployed:", address(bridge));

        // 4. Configure
        abob.grantRole(abob.BRIDGE_ROLE(), address(bridge));
        console.log("Granted BRIDGE_ROLE to bridge");

        // Set rate limits: 100k ABOB per day
        abob.setLimits(address(bridge), 100_000e18, 100_000e18);
        console.log("Set bridge limits: 100k ABOB/day");

        // Add ABOB as supported token
        bridge.addSupportedToken(address(abob));
        console.log("Added ABOB as supported token");

        vm.stopBroadcast();

        // Save addresses to file
        string memory json = string.concat(
            '{\n',
            '  "blobstream": "', vm.toString(address(blobstream)), '",\n',
            '  "abob": "', vm.toString(address(abob)), '",\n',
            '  "bridge": "', vm.toString(address(bridge)), '"\n',
            '}'
        );

        vm.writeFile("deployments/testnet.json", json);
        console.log("\nDeployment addresses saved to deployments/testnet.json");
    }
}
```

**Ejecutar:**
```bash
# Ethereum Sepolia
forge script script/DeployBridgeEcosystem.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify

# AndeChain Testnet
forge script script/DeployBridgeEcosystem.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast
```

**Deliverable Día 10:**
- [ ] Scripts de deployment
- [ ] Contratos deployed en Sepolia
- [ ] Contratos deployed en AndeChain testnet
- [ ] addresses.json con direcciones

---

### Día 11-14: Relayer Implementation

**Archivo:** `/relayer/src/bridge-relayer.ts`

```typescript
import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

dotenv.config();

interface BridgeConfig {
  name: string;
  rpcUrl: string;
  bridgeAddress: string;
  chainId: number;
}

class BridgeRelayer {
  private sourceProvider: ethers.Provider;
  private destProvider: ethers.Provider;
  private sourceBridge: ethers.Contract;
  private destBridge: ethers.Contract;
  private relayerSigner: ethers.Wallet;
  private sourceChainId: number;
  private destChainId: number;

  constructor(
    sourceConfig: BridgeConfig,
    destConfig: BridgeConfig,
    relayerPrivateKey: string
  ) {
    // Setup providers
    this.sourceProvider = new ethers.JsonRpcProvider(sourceConfig.rpcUrl);
    this.destProvider = new ethers.JsonRpcProvider(destConfig.rpcUrl);

    // Setup signer
    this.relayerSigner = new ethers.Wallet(
      relayerPrivateKey,
      this.destProvider
    );

    // Setup contracts
    const bridgeABI = [
      'event TokensBridged(address indexed token, address indexed sender, address indexed recipient, uint256 amount, uint256 destinationChain, uint256 nonce)',
      'function receiveTokens(address token, address recipient, uint256 amount, uint256 sourceChain, bytes32 sourceTxHash, bytes proof) external'
    ];

    this.sourceBridge = new ethers.Contract(
      sourceConfig.bridgeAddress,
      bridgeABI,
      this.sourceProvider
    );

    this.destBridge = new ethers.Contract(
      destConfig.bridgeAddress,
      bridgeABI,
      this.relayerSigner
    );

    this.sourceChainId = sourceConfig.chainId;
    this.destChainId = destConfig.chainId;

    console.log(`🚀 Relayer initialized:`);
    console.log(`   Source: ${sourceConfig.name} (${sourceConfig.chainId})`);
    console.log(`   Dest: ${destConfig.name} (${destConfig.chainId})`);
  }

  async start() {
    console.log('👂 Listening for TokensBridged events...');

    // Listen to bridge events
    this.sourceBridge.on(
      'TokensBridged',
      async (token, sender, recipient, amount, destinationChain, nonce, event) => {
        if (destinationChain !== BigInt(this.destChainId)) {
          console.log(`⏭️  Skipping event for chain ${destinationChain}`);
          return;
        }

        console.log(`\n📩 New bridge event detected:`);
        console.log(`   Token: ${token}`);
        console.log(`   Sender: ${sender}`);
        console.log(`   Recipient: ${recipient}`);
        console.log(`   Amount: ${ethers.formatEther(amount)} ABOB`);
        console.log(`   Nonce: ${nonce}`);

        try {
          await this.processBridgeEvent(
            token,
            recipient,
            amount,
            event.log.transactionHash
          );
        } catch (error) {
          console.error(`❌ Error processing event:`, error);
        }
      }
    );
  }

  private async processBridgeEvent(
    token: string,
    recipient: string,
    amount: bigint,
    txHash: string
  ) {
    console.log(`🔄 Processing bridge transaction...`);

    // In production, fetch real Merkle proof from Celestia
    // For testnet, we use mock proof
    const proof = ethers.hexlify(ethers.randomBytes(32));

    console.log(`   TX Hash: ${txHash}`);
    console.log(`   Proof: ${proof.slice(0, 10)}...`);

    // Call receiveTokens on destination chain
    const tx = await this.destBridge.receiveTokens(
      token,
      recipient,
      amount,
      this.sourceChainId,
      txHash,
      proof
    );

    console.log(`📤 Submitted to destination chain: ${tx.hash}`);

    const receipt = await tx.wait();

    console.log(`✅ Bridge completed! Gas used: ${receipt.gasUsed.toString()}`);
    console.log(`   Recipient now has tokens on destination chain\n`);
  }

  // Graceful shutdown
  async stop() {
    console.log('🛑 Stopping relayer...');
    this.sourceBridge.removeAllListeners();
  }
}

// Main
async function main() {
  const relayer = new BridgeRelayer(
    {
      name: 'Ethereum Sepolia',
      rpcUrl: process.env.SEPOLIA_RPC_URL!,
      bridgeAddress: process.env.SEPOLIA_BRIDGE_ADDRESS!,
      chainId: 11155111
    },
    {
      name: 'AndeChain Testnet',
      rpcUrl: process.env.ANDECHAIN_RPC_URL!,
      bridgeAddress: process.env.ANDECHAIN_BRIDGE_ADDRESS!,
      chainId: 888
    },
    process.env.RELAYER_PRIVATE_KEY!
  );

  await relayer.start();

  // Handle graceful shutdown
  process.on('SIGINT', async () => {
    await relayer.stop();
    process.exit(0);
  });
}

main().catch(console.error);
```

**Package.json:**
```json
{
  "name": "ande-bridge-relayer",
  "version": "1.0.0",
  "scripts": {
    "start": "ts-node src/bridge-relayer.ts",
    "dev": "nodemon --exec ts-node src/bridge-relayer.ts"
  },
  "dependencies": {
    "ethers": "^6.9.0",
    "dotenv": "^16.0.3"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "ts-node": "^10.9.1",
    "typescript": "^5.0.0",
    "nodemon": "^3.0.0"
  }
}
```

**.env.example:**
```
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
ANDECHAIN_RPC_URL=http://localhost:8545

SEPOLIA_BRIDGE_ADDRESS=0x...
ANDECHAIN_BRIDGE_ADDRESS=0x...

RELAYER_PRIVATE_KEY=0x...
```

**Deliverable Día 14:**
- [ ] Relayer funcional
- [ ] Documentación de setup
- [ ] Monitoreo básico
- [ ] Error handling robusto

---

## 📅 SEMANA 3: End-to-End Testing

### Día 15-17: E2E Testing Flow

**Script de Test Manual:**

```bash
#!/bin/bash
# test-bridge-e2e.sh

echo "🧪 Testing ABOB Bridge E2E Flow"
echo "================================"

# Config
ETHEREUM_RPC="https://sepolia.infura.io/v3/YOUR_KEY"
ANDECHAIN_RPC="http://localhost:8545"
USER_ADDRESS="0xYourAddress"
BRIDGE_AMOUNT="100000000000000000000" # 100 ABOB

echo ""
echo "📍 Step 1: Check initial balances"
echo "-----------------------------------"

# Ethereum ABOB balance
ETH_BALANCE=$(cast call $ABOB_ETH_ADDRESS \
  "balanceOf(address)(uint256)" \
  $USER_ADDRESS \
  --rpc-url $ETHEREUM_RPC)

echo "Ethereum ABOB Balance: $(cast --to-unit $ETH_BALANCE ether) ABOB"

# AndeChain ABOB balance
ANDE_BALANCE=$(cast call $ABOB_ANDE_ADDRESS \
  "balanceOf(address)(uint256)" \
  $USER_ADDRESS \
  --rpc-url $ANDECHAIN_RPC)

echo "AndeChain ABOB Balance: $(cast --to-unit $ANDE_BALANCE ether) ABOB"

echo ""
echo "📍 Step 2: Approve bridge on Ethereum"
echo "---------------------------------------"

cast send $ABOB_ETH_ADDRESS \
  "approve(address,uint256)" \
  $BRIDGE_ETH_ADDRESS \
  $BRIDGE_AMOUNT \
  --private-key $PRIVATE_KEY \
  --rpc-url $ETHEREUM_RPC

echo "✅ Approval successful"

echo ""
echo "📍 Step 3: Bridge tokens from Ethereum to AndeChain"
echo "-----------------------------------------------------"

BRIDGE_TX=$(cast send $BRIDGE_ETH_ADDRESS \
  "bridgeTokens(address,address,uint256,uint256)" \
  $ABOB_ETH_ADDRESS \
  $USER_ADDRESS \
  $BRIDGE_AMOUNT \
  888 \
  --private-key $PRIVATE_KEY \
  --rpc-url $ETHEREUM_RPC)

echo "Bridge TX: $BRIDGE_TX"

echo ""
echo "⏳ Waiting for relayer to process (30 seconds)..."
sleep 30

echo ""
echo "📍 Step 4: Check final balances"
echo "---------------------------------"

# Ethereum ABOB balance
ETH_BALANCE_AFTER=$(cast call $ABOB_ETH_ADDRESS \
  "balanceOf(address)(uint256)" \
  $USER_ADDRESS \
  --rpc-url $ETHEREUM_RPC)

echo "Ethereum ABOB Balance: $(cast --to-unit $ETH_BALANCE_AFTER ether) ABOB"

# AndeChain ABOB balance
ANDE_BALANCE_AFTER=$(cast call $ABOB_ANDE_ADDRESS \
  "balanceOf(address)(uint256)" \
  $USER_ADDRESS \
  --rpc-url $ANDECHAIN_RPC)

echo "AndeChain ABOB Balance: $(cast --to-unit $ANDE_BALANCE_AFTER ether) ABOB"

echo ""
echo "✅ E2E Test Complete!"
```

**Checklist de Testing:**
- [ ] Bridge 100 ABOB: Ethereum → AndeChain
- [ ] Bridge 50 ABOB: AndeChain → Ethereum
- [ ] Test rate limits (exceder límite)
- [ ] Test forced transaction flow
- [ ] Test pause/unpause
- [ ] Medir tiempos de bridging

---

### Día 18-21: Security Review Interno

**Checklist de Seguridad:**

**Smart Contracts:**
- [ ] Reentrancy: Verificar todos los external calls
- [ ] Access Control: Roles configurados correctamente
- [ ] Rate Limits: Funcionan como esperado
- [ ] Replay Attacks: processedTransactions working
- [ ] Integer Overflow: Usar Math.mulDiv everywhere
- [ ] Gas Optimization: <100k gas por operación

**Bridge:**
- [ ] Proof verification funciona
- [ ] Can't mint without burning on source
- [ ] Can't double-process same transaction
- [ ] Emergency pause works
- [ ] Forced transaction works

**Relayer:**
- [ ] Error handling robusto
- [ ] Retry logic para failures
- [ ] No memory leaks
- [ ] Graceful shutdown
- [ ] Monitoring & alerting

**Tools:**
```bash
# Slither analysis
cd contracts
slither src/bridge/AndeChainBridge.sol

# Mythril (symbolic execution)
myth analyze src/bridge/AndeChainBridge.sol

# Gas snapshot
forge snapshot
```

---

## 📅 SEMANA 4: Documentation & Launch

### Día 22-24: Documentation

**Documentos a Crear:**

#### 1. User Guide: `/docs/user-guide/BRIDGE_TUTORIAL.md`
```markdown
# Cómo Hacer Bridge de ABOB

## Requisitos Previos
- Wallet con Metamask
- ABOB tokens en Ethereum o AndeChain
- ETH/ANDE para gas

## Paso a Paso

### Ethereum → AndeChain

1. Conecta tu wallet a https://bridge.andechain.io
2. Selecciona "From: Ethereum" y "To: AndeChain"
3. Ingresa cantidad de ABOB
4. Aprueba el contrato (transacción 1)
5. Confirma bridge (transacción 2)
6. Espera ~5 minutos
7. ¡Tus ABOB estarán en AndeChain!

### Troubleshooting
...
```

#### 2. Developer Guide: `/docs/developer-guide/INTEGRATE_BRIDGE.md`
```markdown
# Integrar el Bridge ABOB en tu dApp

## Instalación

\`\`\`bash
npm install @andechain/sdk
\`\`\`

## Código Ejemplo

\`\`\`typescript
import { AndeBridge } from '@andechain/sdk';

const bridge = new AndeBridge({
  network: 'testnet'
});

await bridge.bridgeTokens({
  from: 'ethereum',
  to: 'andechain',
  amount: '100',
  token: 'ABOB'
});
\`\`\`
...
```

#### 3. Architecture Doc: `/docs/architecture/BRIDGE_DESIGN.md`
(Ya creado en ABOB_TECHNICAL_ARCHITECTURE.md)

---

### Día 25-28: Testnet Launch

**Pre-Launch Checklist:**
- [ ] Todos los contratos auditados internamente
- [ ] Tests passing al 100%
- [ ] Relayer corriendo en servidor con uptime monitoring
- [ ] Documentation completa
- [ ] Blockscout configurado para ambas chains
- [ ] Faucet funcionando

**Launch Day:**

1. **Deploy Final en Testnets**
   ```bash
   # Sepolia
   forge script script/DeployBridgeEcosystem.s.sol \
     --rpc-url $SEPOLIA_RPC \
     --broadcast --verify

   # AndeChain
   forge script script/DeployBridgeEcosystem.s.sol \
     --rpc-url $ANDECHAIN_RPC \
     --broadcast
   ```

2. **Start Relayer en Servidor**
   ```bash
   # En servidor de producción
   cd relayer
   pm2 start npm --name "bridge-relayer" -- start
   pm2 save
   ```

3. **Announce en Comunidad**
   - Tweet con demo video
   - Discord announcement
   - Documentación link

4. **Monitor Primeras 24h**
   - Dashboard con métricas
   - Alert si relayer down
   - Community support en Discord

**Bug Bounty Launch:**
```markdown
# ABOB Bridge Bug Bounty

**Total Pool:** $10,000

**Severities:**
- Critical (system compromise): $5,000
- High (funds at risk): $3,000
- Medium (degraded service): $1,500
- Low (minor issues): $500

**Scope:**
- xERC20ABOB.sol
- AndeChainBridge.sol
- Bridge Relayer

**Out of Scope:**
- Known issues in documentation
- Gas optimization
- UI bugs

**How to Submit:**
Submit to security@andelabs.io with:
- Description
- Steps to reproduce
- Impact assessment
- Proposed fix (optional)
```

---

## 📊 Success Metrics (Week 4 End)

### Technical Metrics
- ✅ >95% test coverage en bridge contracts
- ✅ <100k gas per bridge operation
- ✅ <5 minute average bridge time
- ✅ 99.9% relayer uptime
- ✅ 0 critical bugs en primera semana

### Adoption Metrics
- 🎯 50+ unique users bridging
- 🎯 $10k+ volume bridged
- 🎯 100+ transactions processed
- 🎯 5+ developers testing integration

### Community Metrics
- 🎯 Documentation viewed 500+ times
- 🎯 10+ Github stars
- 🎯 Active discussions en Discord

---

## 🚨 Risk Mitigation

### High Priority Risks

**1. Relayer Goes Down**
- **Mitigation:** Forced transaction mechanism
- **Action:** Document clearly cómo usuarios usan forceTransaction()
- **Backup:** Secondary relayer standby

**2. Oracle Price Manipulation**
- **Mitigation:** Multiple oracle sources
- **Action:** Circuit breakers si precio diverge >5%

**3. Smart Contract Bug**
- **Mitigation:** Extensive testing + audits
- **Action:** Emergency pause mechanism
- **Backup:** Insurance fund

**4. Low Adoption**
- **Mitigation:** Incentives para early users
- **Action:** Liquidity mining rewards
- **Marketing:** Educational content

---

## 🎯 Post-Launch Priorities (Week 5+)

### Immediate (Week 5-6)
1. Monitor & Fix Issues
2. Community Support
3. Collect Feedback
4. Minor Improvements

### Short Term (Week 7-12)
1. Auditoría Externa (OpenZeppelin / Trail of Bits)
2. Mainnet Preparation
3. Additional Chain Support (Arbitrum, Polygon)
4. Advanced Features (batch bridging, meta-transactions)

### Medium Term (Q1 2026)
1. Integration con LayerZero / Axelar
2. Real Celestia Blobstream integration
3. Lazy Bridging research
4. L3 toolkit preparation

---

## 📞 Support & Resources

**Durante Development:**
- Daily standups: Review progreso
- Blockers: Documentar en GitHub Issues
- Questions: Discord #dev-chat

**Post-Launch:**
- User Support: Discord #support
- Bug Reports: GitHub Issues
- Feature Requests: Discord #feedback

**Emergency:**
- Security issues: security@andelabs.io
- Critical bugs: Page on-call engineer

---

## ✅ Final Pre-Launch Checklist

**Week 1:**
- [ ] 15+ bridge tests implemented
- [ ] >95% coverage
- [ ] xERC20ABOB.sol complete
- [ ] MockBlobstream working
- [ ] Integration tests passing

**Week 2:**
- [ ] Deployment scripts ready
- [ ] Deployed en Sepolia
- [ ] Deployed en AndeChain testnet
- [ ] Relayer implementation complete
- [ ] Relayer tested end-to-end

**Week 3:**
- [ ] E2E manual testing done
- [ ] Rate limits tested
- [ ] Force transaction tested
- [ ] Security review complete
- [ ] Gas optimization done

**Week 4:**
- [ ] User documentation complete
- [ ] Developer documentation complete
- [ ] Architecture diagrams ready
- [ ] Testnet announcement ready
- [ ] Bug bounty program live
- [ ] Monitoring & alerts configured

---

**¡Éxito en el desarrollo! 🚀**

**Próximo Update:** Semana 1 - Viernes (10 de Octubre, 2025)
**Contacto:** team@andelabs.io
