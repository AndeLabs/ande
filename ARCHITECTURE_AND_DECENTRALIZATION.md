# 🏗️ ANDE Chain - Arquitectura Mejorada y Estrategia de Descentralización

**Versión:** 2.0
**Fecha:** Enero 2025
**Estado:** Diseño de Producción
**Audiencia:** Architects, DevOps, Core Developers

---

## 📋 Tabla de Contenidos

1. [Arquitectura Actual vs Objetivo](#arquitectura-actual-vs-objetivo)
2. [Componentes Detallados](#componentes-detallados)
3. [Flujo de Transacciones](#flujo-de-transacciones)
4. [Descentralización: Roadmap](#descentralización-roadmap)
5. [Seguridad en Capas](#seguridad-en-capas)
6. [Deployment Architecture](#deployment-architecture)
7. [Performance Targets](#performance-targets)

---

## 🎯 Arquitectura Actual vs Objetivo

### Arquitectura Actual (Fase 1 - Alpha)

```
┌──────────────────────────────────────────────────────────────┐
│                    Users & Applications                       │
│         (Wallets, DeFi, Gaming, etc)                        │
└────────────────────┬─────────────────────────────────────────┘
                     │ JSON-RPC
                     ↓
        ┌────────────────────────────┐
        │   RPC Server (single)      │
        │   localhost:8545           │
        └────────┬───────────────────┘
                 │
    ┌────────────┴────────────┐
    ↓                         ↓
┌─────────────────┐    ┌──────────────────┐
│ Sequencer       │    │ Full Nodes       │
│ (Producer)      │    │ (Validators)     │
│ Port: 7676      │    │ Ports: 7677-8   │
│ Single instance │    │ 2-3 instances   │
└────────┬────────┘    └──────┬───────────┘
         │                    │
         └────────┬───────────┘
                  │
         ┌────────▼────────────┐
         │  P2P Gossip         │
         │  (LibP2P)           │
         └────────┬────────────┘
                  │
         ┌────────▼────────────┐
         │  Celestia DA        │
         │  (Mocha-4)          │
         │  Light Client       │
         └─────────────────────┘
```

**Problemas:**
- ❌ Sequencer centralizado = single point of failure
- ❌ Sin liveness sin sequencer
- ❌ Sin slashing conditions
- ❌ Sin incentivos para validadores

---

### Arquitectura Objetivo (Fase 4 - Mainnet)

```
┌──────────────────────────────────────────────────────────────┐
│                    Users & Applications                       │
│    (Wallets, DeFi, Gaming, Institutional)                   │
└───────────────────┬────────────────────────────────────────────┘
                    │ JSON-RPC (load-balanced)
    ┌───────────────┼───────────────┐
    │               │               │
    ↓               ↓               ↓
┌─────────┐   ┌─────────┐   ┌─────────┐
│RPC LB 1 │   │RPC LB 2 │   │RPC LB 3 │ ← Load Balancers (Geographic)
└────┬────┘   └────┬────┘   └────┬────┘
     │             │             │
     └─────────────┼─────────────┘
                   │
        ┌──────────▼──────────┐
        │   Full Node Cluster  │
        │   (50-100 nodes)     │
        │   ├─ Sequencers: 5   │
        │   ├─ Validators: 50  │
        │   ├─ Archival: 2     │
        │   └─ Light: many     │
        └──────────┬──────────┘
                   │
        ┌──────────▼──────────┐
        │  Consensus Layer     │
        │  (Tendermint/PBFT)   │
        │  ├─ Leader election  │
        │  ├─ Vote aggregation │
        │  ├─ Block finality   │
        │  └─ Slashing logic   │
        └──────────┬──────────┘
                   │
        ┌──────────▼──────────┐
        │  State Commitment    │
        │  ├─ State root       │
        │  ├─ DA proof         │
        │  └─ Validity proof   │
        └──────────┬──────────┘
                   │
        ┌──────────▼──────────┐
        │  Celestia DA Layer   │
        │  ├─ Main node: 1     │
        │  ├─ Light clients: 5 │
        │  ├─ Blob submission  │
        │  └─ Data sampling    │
        └──────────┬──────────┘
                   │
        ┌──────────▼──────────┐
        │  Bridges (Outbound)  │
        │  ├─ Wormhole        │
        │  ├─ Connext         │
        │  ├─ LayerZero       │
        │  └─ IBC (Cosmos)    │
        └──────────────────────┘
```

**Mejoras:**
- ✅ 5+ Validadores con staking
- ✅ Consenso Byzantine-Fault-Tolerant
- ✅ Slashing conditions definidas
- ✅ Incentivos económicos claros
- ✅ Geographic distribution
- ✅ Cross-chain bridges

---

## 🔧 Componentes Detallados

### 1. Execution Layer: ev-reth

#### Modificaciones Críticas

```rust
// ACTUAL: Secuencial
Block {
  transactions: [tx1, tx2, tx3, tx4, tx5]
  execution: Sequential (3.5s)
}

// MEJORADO: Parallel + Speculative
Block {
  transactions: [tx1, tx2, tx3, tx4, tx5]
  
  execution: {
    // Speculative execution
    tx1_spec: execute(tx1, state_v0)  // thread 1
    tx2_spec: execute(tx2, state_v0)  // thread 2
    tx3_spec: execute(tx3, state_v0)  // thread 3
    tx4_spec: execute(tx4, state_v0)  // thread 4
    tx5_spec: execute(tx5, state_v0)  // thread 5
    
    // Conflict resolution
    conflicts = detect_conflicts([tx1_spec, tx2_spec, ...])
    
    if conflicts.empty() {
      // Fast path: all good
      results = [tx1_spec, tx2_spec, tx3_spec, tx4_spec, tx5_spec]
    } else {
      // Retry with sequential
      results = execute_sequential([tx1, tx2, tx3, tx4, tx5])
    }
  }
  
  time: ~0.8s (4-5x faster)
}
```

#### Optimizaciones Implementar

```toml
[ev-reth-improvements]

# 1. Compression Pipeline
blob_compression = {
  algorithm = "zstandard",  # vs Brotli, LZ4
  level = 10,               # balance speed/ratio
  target_ratio = 0.6        # 40% reduction target
}

# 2. State Pruning
state_pruning = {
  mode = "block_level",
  blocks_retained = 128,
  gc_frequency = "every_1000_blocks"
}

# 3. Memory Management
memory = {
  cache_size = "16GB",
  preload_historical = false,
  mmap_for_overflow = true
}

# 4. Proof Generation
proof_pipeline = {
  parallelism = 8,
  incremental = true,
  streaming = true
}
```

#### Performance Benchmarks

```
Current State:
├─ TPS: 250-350 (avg: 300)
├─ Block time: 2-3s
├─ Finality: ~2s (local commitment)
├─ Memory: ~2GB per node
└─ CPU: ~40% (4 cores utilized)

Target (Post-Optimization):
├─ TPS: 500-1000+ (avg: 750)
├─ Block time: 1-2s
├─ Finality: ~4s (DA confirmation)
├─ Memory: ~1GB per node (pruned)
└─ CPU: ~60% (8 cores utilized)
```

---

### 2. Consensus Layer: Tendermint PBFT

#### Fases de Implementación

**Phase 2a: Multi-Sequencer (Months 1-2)**

```rust
pub enum SequencerRole {
    Leader(u64),           // Current block producer
    Validator,             // Can participate in voting
    Fallback(u64),         // Next in line
}

struct SequencerSet {
    validators: Vec<ValidatorInfo>,
    active_set: VecDeque<ValidatorInfo>,  // 5 validators
    epoch: u64,
    next_rotation: BlockNumber,
}

struct ValidatorInfo {
    address: Address,
    stake: U256,
    voting_power: u64,
    commission: Percentage,
    last_block_proposed: BlockNumber,
    consecutive_misses: u32,
}

// Round-robin with weighted voting
impl SequencerSet {
    pub fn get_proposer(&self, block_number: u64) -> Address {
        let index = (block_number % self.validators.len() as u64) as usize;
        self.validators[index].address
    }
    
    pub fn get_voting_power(&self, validator: &Address) -> u64 {
        self.validators.iter()
            .find(|v| v.address == validator)
            .map(|v| v.voting_power)
            .unwrap_or(0)
    }
}
```

**Phase 2b: PBFT Consensus (Months 3-4)**

```
Tendermint BFT Protocol:

Propose Phase:
  Leader proposes block B
    ↓
  Validators validate B (signatures, state)
    ↓
  If valid, pre-vote for B

Prevote Phase:
  If 2/3 pre-vote for B, go to precommit
    ↓
  If timeout (3s), enter propose again

Precommit Phase:
  Validators precommit for B
    ↓
  If 2/3 precommit for B, commit!

Commit Phase:
  B is committed to blockchain
  State root finalized
  Height incremented


Key Properties:
├─ Safety: <1/3 validators Byzantine → still safe
├─ Liveness: >2/3 honest validators → keeps progressing
├─ Finality: Instant (no forks)
└─ Latency: ~3-5 seconds per block
```

**Phase 2c: Slashing Conditions (Months 5-6)**

```solidity
// Smart contract: ValidatorSet.sol

enum SlashingReason {
    DoubleSigning,           // Signed two different blocks at same height
    DowntimeConsecutive,     // Missed >34 consecutive blocks
    InvalidStateRoot,        // Produced invalid state root
    NonResponsive            // Didn't respond to 10+ RPC calls
}

struct SlashingEvent {
    validator: address,
    amount: uint256,
    reason: SlashingReason,
    evidence_block: uint256,
    slash_percentage: uint256  // 5% for downtime, 50% for double-sign
}

// Automatic slashing on-chain
function reportSlash(address validator, SlashingEvent evidence) public {
    require(validateEvidence(evidence));
    
    uint256 penalty = validator.stake * evidence.slash_percentage / 100;
    validator.stake -= penalty;
    treasury.balance += penalty;
    
    emit Slashed(validator, penalty, evidence.reason);
    
    if (validator.stake < MIN_STAKE) {
        removeValidator(validator);
    }
}
```

---

### 3. Data Availability: Celestia Integration

#### Current Integration

```rust
// Current: Basic blob publishing

pub struct CelestiaDA {
    node: CelestiaRpcClient,
    namespace: Namespace,  // ANDE-specific namespace
}

impl CelestiaDA {
    pub async fn submit_block(&self, block: Block) -> Result<Commitment> {
        let blob = encode_block_to_blob(&block)?;
        
        let commitment = self.node
            .submit_blob(self.namespace, &blob)
            .await?;
        
        Ok(commitment)
    }
    
    pub async fn verify_availability(&self, commitment: &Commitment) -> Result<bool> {
        self.node.verify_blob(commitment).await
    }
}
```

#### Mejorado: Redundancia y Fallback

```rust
// Improved: Multi-node with fallback

pub struct CelestiaDARedundant {
    primary: CelestiaRpcClient,
    backup_1: CelestiaRpcClient,
    backup_2: CelestiaRpcClient,
    ipfs_fallback: IpfsClient,  // Fallback DA
}

impl CelestiaDARedundant {
    pub async fn submit_block_redundant(&self, block: Block) -> Result<MultiCommitment> {
        let blob = encode_block_to_blob(&block)?;
        
        // Parallel submissions
        let (primary, backup_1, backup_2) = tokio::join3!(
            self.primary.submit_blob(namespace, &blob),
            self.backup_1.submit_blob(namespace, &blob),
            self.backup_2.submit_blob(namespace, &blob),
        );
        
        let commitments = vec![
            primary?,
            backup_1?,
            backup_2?,
        ];
        
        // If any two succeed, we're good
        if commitments.iter().filter(|c| c.is_ok()).count() >= 2 {
            Ok(MultiCommitment::new(commitments))
        } else {
            // Fallback to IPFS
            self.ipfs_fallback.submit(&blob).await
        }
    }
}
```

#### Network Architecture

```
ANDE Celestia Infrastructure:

Main Consensus Chain:
├─ RPC Endpoint: rpc.celestia.org
├─ DA Namespace: 0xANDE... (fixed)
└─ Target latency: <30s from submission to DA

Light Client Nodes (Per Validator):
├─ Location: Same as validator
├─ Purpose: Verify DA availability locally
├─ Bandwidth: ~50MB/day
└─ Hardware: Minimal (Raspberry Pi capable)

Backup DA (Fallback):
├─ IPFS Network (fallback only)
├─ Filecoin for archival
└─ Trigger: Celestia down >10 min

Monitoring:
├─ Celestia light client sync status
├─ DA submission latency
├─ Network participation rate
└─ Fallback activation events
```

---

### 4. Smart Contracts: Tokenomics & Governance

#### Token Duality Evolution

```solidity
// Phase 1 (Current): Basic duality
contract ANDEToken {
    // Native balance (optimized)
    mapping(address => uint256) balances;
    
    // ERC20 interface
    function transfer(address to, uint256 amount) public {
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }
}

// Phase 2 (Next): Liquid staking
contract LiquidANDE {
    // Stake ANDE, get stANDE
    mapping(address => uint256) stakes;
    mapping(address => uint256) rewards;
    
    function stake(uint256 amount) public {
        require(amount > 0);
        stakes[msg.sender] += amount;
        emit Staked(msg.sender, amount);
    }
    
    function claimRewards() public returns (uint256) {
        uint256 reward = calculateReward(msg.sender);
        rewards[msg.sender] = 0;
        ANDEToken.transfer(msg.sender, reward);
        return reward;
    }
}

// Phase 3 (Future): Vote escrow + governance
contract veANDE {
    // ANDE locked for 4 years = max voting power
    mapping(address => LockInfo) locks;
    
    struct LockInfo {
        uint256 amount;
        uint256 unlock_time;
        uint256 voting_power;  // Decays linearly to 0 at unlock
    }
    
    function lock(uint256 amount, uint256 weeks) public {
        require(weeks <= 208); // 4 years max
        locks[msg.sender] = LockInfo({
            amount: amount,
            unlock_time: block.timestamp + (weeks * 1 weeks),
            voting_power: calculateVotingPower(amount, weeks)
        });
    }
}
```

#### Governance Architecture

```
AndeGovernor V1 (Phase 2):

Proposal Creation:
  Requires: 10k ANDE
  Min voting power: 50k ANDE
  Cost: None (on-chain governance)

Voting:
  Period: 1 week
  Voting power: 1 ANDE = 1 vote (snapshot at proposal block)
  Quorum: 4% (400k ANDE)
  Threshold: 50% + 1

Timelock:
  Delay: 2 days (for upgrades)
  Can be cancelled within window
  Emergency override: Multi-sig (5-of-9)

Execution:
  Automatic via Timelock
  Upgrade contracts (UUPS)
  Adjust protocol parameters
  Manage treasury

Treasury:
  Receives: Protocol fees, slashed amounts
  Management: DAO governance
  Allocation: Grants, incentives, audits
```

---

## 📊 Flujo de Transacciones (End-to-End)

### Flujo Completo en Mainnet

```
1. USER INITIATES TRANSACTION
   ├─ Wallet: creates tx with nonce
   ├─ Signature: signs with private key
   └─ Broadcasting: sends to RPC node
         ↓
2. RPC LAYER RECEIVES
   ├─ Validation: schema, signature, gas
   ├─ Rate limiting: check quota
   ├─ Gossip: broadcast to all nodes
   └─ Mempool: Add to local mempool
         ↓
3. SEQUENCER RECEIVES (via P2P)
   ├─ Propagation: ~500ms from broadcast
   ├─ Ordering: based on fee + time
   ├─ Bundle: group with other transactions
   └─ Queue: for block production
         ↓
4. BLOCK PRODUCTION (Tendermint Round)
   ├─ Propose phase:
   │   ├─ Leader selected (round-robin)
   │   ├─ Builds block with ~100-500 txs
   │   ├─ Executes transactions (parallel!)
   │   ├─ Computes state root
   │   └─ Signs & broadcasts block
   │       ↓ (~500ms elapsed)
   │
   ├─ Prevote phase:
   │   ├─ Validators receive block
   │   ├─ Validate signatures & state root
   │   ├─ Vote for block (if valid)
   │   └─ Broadcast votes to all validators
   │       ↓ (~500ms elapsed)
   │
   ├─ Precommit phase:
   │   ├─ If 2/3 prevotes received:
   │   ├─ Precommit for block
   │   ├─ Broadcast precommit votes
   │   └─ If 2/3 precommit: COMMIT!
   │       ↓ (~1s elapsed, ~2s total)
   │
   └─ Commit phase:
       ├─ Block is finalized
       ├─ State committed
       └─ Block height incremented
           ↓ (Total: ~2 seconds from broadcast)

5. STATE EXECUTION (ev-reth)
   ├─ Parallel execution:
   │   ├─ Thread 1: Execute tx[0], tx[5], tx[10]...
   │   ├─ Thread 2: Execute tx[1], tx[6], tx[11]...
   │   ├─ Thread 3: Execute tx[2], tx[7], tx[12]...
   │   └─ Thread 4: Execute tx[3], tx[8], tx[13]...
   │
   ├─ Conflict resolution:
   │   ├─ Detect read-write conflicts
   │   ├─ If conflicts: retry sequentially
   │   └─ If none: accept parallel results
   │
   └─ State commitment:
       ├─ Compute new state root
       └─ Include in block header
           ↓

6. DATA AVAILABILITY (Celestia)
   ├─ Batch: ~10-50 blocks per batch
   ├─ Encode: into DA blob
   ├─ Submit to Celestia:
   │   ├─ Primary: rpc.celestia.org
   │   ├─ Backup 1: secondary node
   │   └─ Backup 2: tertiary node
   │
   ├─ DA Confirmation:
   │   ├─ Awaiting Celestia block inclusion
   │   ├─ Typically 10-30 seconds
   │   └─ Proof included in next ANDE block
   │
   └─ Final confirmation:
       ├─ DA proof committed on-chain
       ├─ Transaction is now finalized
       └─ Cannot be reverted (DA backed)
           ↓ (Total: ~30-45 seconds from broadcast)

7. USER RECEIVES CONFIRMATION
   ├─ Step 5 (~2s): Block included (local finality)
   ├─ Step 6 (~30s): DA confirmed (global finality)
   ├─ RPC returns:
   │   ├─ tx_hash
   │   ├─ block_hash
   │   ├─ block_number
   │   └─ status (success/failed)
   │
   └─ Client updates UI:
       ├─ Shows confirmed transaction
       ├─ Updates account balance
       └─ Ready for next interaction

LATENCY BREAKDOWN:
├─ Broadcast to sequencer: ~500ms (p99)
├─ Block production: ~1-2s
├─ DA submission: ~10-30s
├─ Total finality: ~15-35s (p99)
└─ RPC response: ~2-3s (immediate)
```

---

## 🚀 Descentralización: Roadmap Detallado

### Phase 1: Sequencer Centralizado (Current ✅)

```
Duration: Enero - Marzo 2025
Status: ✅ Complete

Architecture:
├─ 1 Sequencer (ANDE Labs)
├─ 2-3 Full nodes (validators)
├─ Celestia DA (Mocha-4)

Pros:
✅ Simple to operate
✅ Fast deployment
✅ Easy to debug

Cons:
❌ Single point of failure
❌ Censorship risk
❌ No liveness guarantees
❌ Not decentralized
```

### Phase 2: Multi-Sequencer with Voting (Q2 2025)

```
Duration: Abril - Junio 2025
Effort: 4-6 PM

Architecture:
├─ 3-5 Sequencers
├─ Round-robin block production
├─ Simple voting for ties
├─ 50+ Full nodes

Implementation:
1. Multi-sequencer config
   - Sequencer registry SC
   - Round-robin scheduling
   - Heartbeat monitoring

2. Voting mechanism
   - 1 node = 1 vote (simple)
   - Used for leader selection
   - Not for finality yet

3. Health checks
   - Automated failover
   - Liveness monitoring
   - Alert system

Pros:
✅ Improved availability
✅ No single sequencer failure
✅ Testable consensus logic

Cons:
⚠️ Still not Byzantine-resistant
⚠️ No economic incentives yet
⚠️ Simple voting not robust
```

### Phase 3: PBFT Consensus (Q3 2025)

```
Duration: Julio - Septiembre 2025
Effort: 6-8 PM

Architecture:
├─ 15-21 Validators (odd number for PBFT)
├─ Tendermint consensus
├─ Stake-weighted voting
├─ Byzantine Fault Tolerance

Implementation:
1. Tendermint integration
   - Propose-prevote-precommit
   - Vote aggregation
   - Instant finality

2. Staking system
   - Min stake: 10k ANDE
   - Locking period: 21 days
   - Delegation support

3. Slashing conditions
   - Double-signing: 50% slash
   - Downtime: 5% slash
   - Invalid state root: 100% slash

4. Block production
   - Proposer selected via algorithm
   - Probabilistic based on stake
   - Automatic rotation

Pros:
✅ Byzantine-Fault-Tolerant (1/3 can fail)
✅ Instant finality
✅ Economic incentives
✅ Cryptographic proofs

Cons:
⚠️ More complex to operate
⚠️ Needs 15+ validators
⚠️ Higher latency (3-5s per block)
```

### Phase 4: Permissionless Validators (Q4 2025)

```
Duration: Octubre - Diciembre 2025
Effort: 4-6 PM

Architecture:
├─ 100+ Validators (permissionless)
├─ Liquid staking
├─ On-chain governance
├─ Fully decentralized

Implementation:
1. Validator onboarding
   - Public documentation
   - Incentive program
   - Community validators

2. Liquid staking pools
   - Stake ANDE → get stANDE
   - Earn commission
   - Instant unstaking (via DEX)

3. Governance integration
   - Parameter changes via voting
   - Validator set changes
   - Treasury management

4. Community participation
   - Anyone can run a validator
   - Support infrastructure
   - Monitoring tools

Pros:
✅ Truly decentralized
✅ Community participation
✅ Censorship-resistant
✅ Optimal security (many validators)

Cons:
⚠️ Harder to coordinate
⚠️ Requires mature tooling
⚠️ Geographic distribution challenges
```

---

## 🔒 Seguridad en Capas

### Capa 1: Smart Contracts

```
Mitigations:
├─ OpenZeppelin audited code ✅
├─ Pause mechanism (role-based) ✅
├─ Access control (ACL) ✅
├─ External audits (Q2 2025) ⏳
├─ Formal verification (future)
└─ Multi-sig for critical functions (Q2)

Test Coverage:
├─ Unit tests: >95% ✅
├─ Integration: comprehensive ✅
├─ Fuzzing: Echidna (planned)
├─ Property-based: Foundry (planned)
└─ Mainnet fork tests (monthly)

Attack Surface:
├─ Reentrancy: Mitigated (OpenZeppelin)
├─ Integer overflow: Mitigated (Solidity 0.8.x)
├─ State inconsistency: Monitored
├─ Flash loans: No external calls
└─ Price oracles: Not used
```

### Capa 2: Execution Layer (ev-reth)

```
Mitigations:
├─ State validation ✅
├─ Transaction signature verification ✅
├─ Gas limit enforcement ✅
├─ EVM opcode safety ✅
├─ Fork safety (Celestia DA) ✅
├─ Parallel execution tests ✅
└─ External audit (Q3 2025) ⏳

Threat Model:
├─ Non-deterministic execution: Mitigated
├─ Race conditions: Mutex-protected
├─ Memory corruption: Rust memory safety
├─ Consensus bypass: Not possible (DA-backed)
└─ State root mismatch: Detected and alerted

Monitoring:
├─ Block validation errors
├─ State inconsistencies
├─ Memory usage spikes
├─ CPU throttling events
└─ Peer synchronization issues
```

### Capa 3: Consensus (Tendermint)

```
Mitigations:
├─ Cryptographic signatures ✅
├─ Vote validation ✅
├─ Byzantine Fault Tolerance ✅
├─ Slashing conditions ✅
├─ Double-sign detection ✅
└─ Timelock for upgrades ✅

Safety Properties:
├─ If <1/3 Byzantine: Chain remains safe ✅
├─ If >2/3 online: Chain remains live ✅
├─ No forks possible: Instant finality ✅
├─ Previous blocks immutable: DA-backed ✅
└─ Validator set immutable: Slashing enforces

Attack Prevention:
├─ Nothing-at-stake: Economic slashing
├─ Long-range attack: Checkpointed state
├─ Finney attack: Not possible (BFT)
└─ 51% attack: Requires >2/3 stake
```

### Capa 4: Data Availability (Celestia)

```
Mitigations:
├─ Celestia network security ✅
├─ Multiple light clients ✅
├─ Data sampling (DAS) ✅
├─ Redundant submission ✅
├─ IPFS fallback (planned)
└─ Archive nodes (long-term)

Properties:
├─ Availability guarantee: DAS verified
├─ No censorship: Namespace separation
├─ Impossible to corrupt: Content-addressed
├─ Verifiable: Merkle proofs
└─ Long-term storage: Celestia incentives

Network Redundancy:
├─ Primary DA: Celestia mainnet
├─ Backup 1: Secondary Celestia node
├─ Backup 2: Tertiary Celestia node
├─ Fallback: IPFS + Filecoin
└─ Archive: BitTorrent (community)
```

---

## 🌐 Deployment Architecture

### Production Infrastructure Layout

```
┌─────────────────────────────────────────────────────────┐
│                      CDN / Load Balancer                │
│            (Cloudflare / AWS CloudFront)                │
│           Auto-scaling, DDoS protection                 │
└────────────────┬────────────────────────────────────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
    ↓            ↓            ↓
┌──────────┐ ┌──────────┐ ┌──────────┐
│Region: N │ │Region: US│ │Region: EU│
│(Miami)   │ │(Oregon)  │ │(Ireland) │
│ ┌──────┐