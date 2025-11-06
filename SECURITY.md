# 🔒 AndeChain Security Documentation

**Version:** 1.0
**Last Updated:** October 9, 2025
**Status:** FASE 0 - Foundation

---

## 📋 Table of Contents

- [Security Overview](#security-overview)
- [Threat Model](#threat-model)
- [Smart Contract Security](#smart-contract-security)
- [Infrastructure Security](#infrastructure-security)
- [Pre-Production Checklist](#pre-production-checklist)
- [Audit Roadmap](#audit-roadmap)
- [Bug Bounty Program](#bug-bounty-program)
- [Incident Response](#incident-response)
- [Security Contact](#security-contact)

---

## 🎯 Security Overview

AndeChain is a sovereign EVM rollup on Celestia designed for maximum security and decentralization. This document outlines our security practices, threat models, and pre-production requirements.

### Security Philosophy

1. **Simplicity as Security** - Complexity is technical debt
2. **Fail-Safe Design** - Assume everything will fail
3. **Minimal Privileges** - Each component has exactly the permissions it needs
4. **Defense in Depth** - Multiple layers of security
5. **Transparency** - Open source, auditable, verifiable

### Current Security Status

**FASE 0: Foundation** (In Progress)

```
✅ Smart Contracts:
├─ ANDEToken.sol - Dual token (native + ERC20) [30 tests passing]
├─ Token Duality system implemented
├─ AccessControl with role-based permissions
└─ Pausable emergency mechanism

⏳ Infrastructure:
├─ Local development environment (Docker)
├─ ev-reth integration (custom fork)
├─ JWT-authenticated Engine API
└─ Celestia DA (local-da for development)

❌ Not Yet Production-Ready:
├─ External security audit (REQUIRED)
├─ Bug bounty program (REQUIRED)
├─ Celestia mainnet integration
├─ Multi-sig for admin operations
└─ Monitoring & alerting infrastructure
```

---

## 🎭 Threat Model

### Attack Surface Analysis

#### 1. Smart Contract Layer

**ANDEToken.sol - Dual Token System**

| Asset | Threat | Impact | Likelihood | Mitigation |
|-------|--------|--------|------------|------------|
| Token Supply | Unauthorized minting | **CRITICAL** | Low | MINTER_ROLE access control, MintController with hard cap |
| User Funds | Unauthorized transfers | **CRITICAL** | Low | OpenZeppelin ERC20, Pausable mechanism |
| Governance | Vote manipulation | **HIGH** | Medium | ERC20Votes checkpoints, delegation controls |
| Upgrades | Malicious upgrade | **CRITICAL** | Low | UUPS with DEFAULT_ADMIN_ROLE, timelock (planned) |
| Token Duality | Precompile desync | **HIGH** | Medium | ev-reth integration tests, balance reconciliation |

**Threat Scenarios:**

```
Scenario 1: Unauthorized Minting
├─ Attack: Compromised MINTER_ROLE private key
├─ Impact: Inflation, token devaluation
├─ Mitigation:
│   ├─ Multi-sig for MINTER_ROLE (5-of-9)
│   ├─ MintController with hard cap (1B ANDE)
│   ├─ Annual emission limits (governance-controlled)
│   └─ Monitoring & alerts for mint events

Scenario 2: Reentrancy Attack
├─ Attack: Malicious contract calls during transfers
├─ Impact: Token drainage
├─ Mitigation:
│   ├─ OpenZeppelin ERC20 (audited implementation)
│   ├─ Checks-Effects-Interactions pattern
│   └─ No external calls in _update hook

Scenario 3: Precompile Desync
├─ Attack: Native balance ≠ ERC20 balance
├─ Impact: Accounting errors, user fund loss
├─ Mitigation:
│   ├─ ev-reth integration tests
│   ├─ Balance reconciliation checks
│   ├─ Precompile address validation
│   └─ Comprehensive E2E tests

Scenario 4: Flash Loan Governance Attack
├─ Attack: Borrow voting power, pass malicious proposal
├─ Impact: Protocol compromise
├─ Mitigation:
│   ├─ Checkpointed voting (ERC20Votes)
│   ├─ Timelock on governance actions (planned)
│   ├─ Minimum proposal threshold
│   └─ Vote delegation tracking

Scenario 5: Upgrade Attack
├─ Attack: Malicious implementation upgrade
├─ Impact: Complete protocol takeover
├─ Mitigation:
│   ├─ UUPS with DEFAULT_ADMIN_ROLE
│   ├─ Multi-sig for admin (planned)
│   ├─ Timelock for upgrades (48h minimum)
│   └─ Transparent upgrade process
```

#### 2. Infrastructure Layer

**Rollup Stack**

| Component | Threat | Impact | Mitigation |
|-----------|--------|--------|------------|
| Sequencer | Censorship | HIGH | Based sequencing (future), forced inclusion |
| RPC | DDoS attack | MEDIUM | Rate limiting, load balancer, multiple nodes |
| DA Layer | Data unavailability | CRITICAL | Celestia mainnet with proofs, escape hatches |
| Bridge | Fund theft | CRITICAL | Blobstream proofs, multi-sig, rate limits |
| JWT Auth | Unauthorized access | HIGH | Secure key management, rotation policy |

**Threat Scenarios:**

```
Scenario 6: Sequencer Censorship
├─ Attack: Sequencer refuses to include transactions
├─ Impact: User fund lockup
├─ Mitigation:
│   ├─ Forced transaction inclusion (via Celestia)
│   ├─ Escape hatches to Ethereum
│   ├─ Multiple sequencers (FASE 3)
│   └─ Transparent mempool monitoring

Scenario 7: Data Withholding Attack
├─ Attack: Sequencer posts blocks without DA
├─ Impact: Users cannot reconstruct state
├─ Mitigation:
│   ├─ Celestia DA guarantees
│   ├─ Blobstream proofs on Ethereum
│   ├─ State root verification
│   └─ Challenge period (7 days)

Scenario 8: Bridge Exploit
├─ Attack: Fake withdrawal proofs
├─ Impact: Fund theft from bridge
├─ Mitigation:
│   ├─ Cryptographic DA proofs (Blobstream)
│   ├─ Rate limiting per bridge
│   ├─ Multi-sig for admin functions
│   ├─ Time delays on large withdrawals
│   └─ Circuit breakers

Scenario 9: RPC Endpoint DDoS
├─ Attack: Overwhelm RPC with requests
├─ Impact: Service unavailability
├─ Mitigation:
│   ├─ Rate limiting per IP
│   ├─ Load balancer with multiple nodes
│   ├─ DDoS protection (Cloudflare)
│   └─ API keys for authenticated access
```

#### 3. Operational Security

| Risk | Impact | Mitigation |
|------|--------|------------|
| Private key compromise | CRITICAL | Hardware wallets, multi-sig, key rotation |
| Social engineering | HIGH | Security training, 2FA, verification protocols |
| Insider threat | HIGH | Separation of duties, audit logs, multi-sig |
| Supply chain attack | MEDIUM | Dependency audits, lock files, checksum verification |

---

## 🛡️ Smart Contract Security

### Security Properties

**ANDEToken.sol**

```solidity
// INVARIANTS (must ALWAYS be true)

Invariant 1: Total Supply Consistency
    totalSupply() == precompile.totalSupply()

Invariant 2: Balance Consistency
    balanceOf(user) == precompile.balanceOf(user)

Invariant 3: Hard Cap Enforcement
    totalSupply() <= HARD_CAP (1B ANDE)

Invariant 4: Role-Based Access
    onlyRole(MINTER_ROLE) can mint()
    onlyRole(PAUSER_ROLE) can pause()
    onlyRole(DEFAULT_ADMIN_ROLE) can upgrade()

Invariant 5: Pausable Safety
    when paused: transfers MUST revert
    when paused: minting MUST revert

Invariant 6: Voting Power Conservation
    sum(votingPower) <= totalSupply()
```

### Security Patterns Used

```
✅ Checks-Effects-Interactions:
    - State changes before external calls
    - No reentrancy vulnerabilities

✅ Access Control:
    - OpenZeppelin AccessControl
    - Role-based permissions
    - Separate roles for separate functions

✅ Upgradeability:
    - UUPS pattern (user-controlled)
    - _disableInitializers() in constructor
    - _authorizeUpgrade() with admin check

✅ Emergency Stop:
    - Pausable mechanism
    - PAUSER_ROLE can pause/unpause
    - Protects against ongoing attacks

✅ SafeMath:
    - Solidity 0.8+ automatic overflow protection
    - No unchecked blocks in critical paths

✅ Event Emission:
    - All state changes emit events
    - Enables off-chain monitoring
    - Transparent audit trail
```

### Testing Requirements

**Coverage Target: >90% for production**

```bash
# Current Status
forge test --match-path "test/unit/ANDEToken.t.sol"     # 4 tests ✅
forge test --match-path "test/unit/TokenDuality.t.sol"  # 26 tests ✅

# Total: 30 tests passing

# Required Before Production:
├─ Unit tests: 90%+ line coverage
├─ Integration tests: Multi-contract interactions
├─ Fuzzing tests: Edge cases and overflow
├─ Invariant tests: Property-based testing
└─ Gas profiling: Optimize critical paths
```

**Test Checklist:**

```
ANDEToken.sol:
[ ] Deployment & Initialization
    [✅] Correct name and symbol
    [✅] Roles set correctly
    [ ] Cannot initialize twice
    [ ] Precompile address validation

[ ] Minting
    [✅] MINTER_ROLE can mint
    [✅] Non-minter cannot mint
    [ ] Cannot mint when paused
    [ ] Mint emits Transfer event
    [ ] Cannot exceed hard cap

[ ] Burning
    [ ] User can burn own tokens
    [ ] BURNER_ROLE can burn from any address
    [ ] Burn emits Transfer event
    [ ] Burn decreases total supply

[ ] Transfers
    [✅] Standard transfer works
    [✅] TransferFrom works with approval
    [✅] Cannot transfer insufficient balance
    [✅] Cannot transfer when paused
    [✅] Transfer emits event

[ ] Voting
    [✅] Delegation works
    [✅] Voting power updates on transfer
    [✅] Checkpoints created correctly
    [ ] Past votes are immutable

[ ] Pausing
    [✅] PAUSER_ROLE can pause
    [✅] Non-pauser cannot pause
    [✅] Pause blocks transfers
    [✅] Unpause resumes transfers

[ ] Upgrading
    [ ] Admin can upgrade
    [ ] Non-admin cannot upgrade
    [ ] Storage layout preserved
    [ ] Initialization protection

[ ] Token Duality
    [✅] Balance reads from precompile
    [✅] Total supply reads from precompile
    [✅] Native transfers sync with ERC20
    [ ] Precompile failure handling
    [ ] Balance reconciliation
```

---

## 🏗️ Infrastructure Security

### Network Architecture

```
┌─────────────────────────────────────────────┐
│  Public Internet                            │
└────────────┬────────────────────────────────┘
             │
     ┌───────▼────────┐
     │  Load Balancer  │ (DDoS protection, rate limiting)
     │  + Cloudflare   │
     └───────┬────────┘
             │
     ┌───────▼────────┐
     │   RPC Nodes     │ (Multiple, geographically distributed)
     │  (Port 8545)    │
     └───────┬────────┘
             │
     ┌───────▼─────────────────────┐
     │  ev-reth-sequencer          │ (JWT authenticated)
     │  (EVM execution)            │
     └───────┬─────────────────────┘
             │ (Engine API - JWT)
     ┌───────▼─────────────────────┐
     │  single-sequencer (ev-node) │ (Block production)
     └───────┬─────────────────────┘
             │
     ┌───────▼─────────────────────┐
     │  Celestia DA                │ (Data availability)
     └─────────────────────────────┘
```

### Infrastructure Hardening

**Docker Security:**
```yaml
Security Measures:
  - Non-root containers
  - Read-only root filesystem where possible
  - Resource limits (CPU, memory)
  - Network isolation
  - Minimal base images (distroless)
  - No secrets in images (use env vars)
  - Regular image updates
  - Vulnerability scanning (Trivy)
```

**JWT Authentication:**
```bash
# Engine API protection
- 32-byte random secret
- Rotation every 30 days
- Secure storage (secrets manager)
- No hardcoded secrets
- Audit logging
```

**Monitoring & Alerting:**
```
CRITICAL Alerts (PagerDuty):
├─ RPC endpoint down >30 seconds
├─ Block production stopped
├─ DA submission failed
├─ Unusual mint/burn events
├─ Unauthorized access attempts
└─ System resource exhaustion

HIGH Alerts (Slack):
├─ Block time >5 seconds
├─ Gas usage spike (>2x average)
├─ Large transfers (>$100k)
├─ Oracle price deviation (>5%)
└─ Failed transactions spike

Metrics to Track:
├─ Block production rate
├─ Transaction throughput (TPS)
├─ RPC response time
├─ DA confirmation time
├─ Gas usage
├─ Network peer count
└─ System resources (CPU, RAM, disk)
```

---

## ✅ Pre-Production Checklist

### FASE 0: Foundation (Current)

**Smart Contracts:**
```
[ ] ANDEToken.sol
    [✅] Implementation complete
    [✅] 30 tests passing
    [ ] Coverage >90% (current: TBD)
    [ ] Fuzzing tests added
    [ ] Invariant tests added
    [ ] Gas profiling complete
    [ ] External audit (REQUIRED)
    [ ] Bug fixes from audit implemented
    [ ] Bug bounty program active

[ ] Token Duality
    [✅] ev-reth integration working
    [✅] Balance sync tests passing
    [ ] E2E tests with real precompile
    [ ] Failure mode handling
    [ ] Reconciliation mechanism
```

**Infrastructure:**
```
[ ] Rollup Stack
    [✅] Docker setup complete
    [✅] Local DA working
    [ ] Celestia testnet integration (Mocha-4)
    [ ] Celestia mainnet integration
    [ ] Multiple sequencer nodes
    [ ] RPC load balancer
    [ ] Monitoring (Prometheus + Grafana)
    [ ] Alerting (PagerDuty)
    [ ] Logging (ELK stack)
    [ ] Backup & recovery procedures

[ ] Security
    [ ] Multi-sig setup (5-of-9 Gnosis Safe)
    [ ] Hardware wallets for signers
    [ ] Key management procedures
    [ ] Incident response playbook
    [ ] Security training for team
    [ ] Penetration testing
```

**Operations:**
```
[ ] Documentation
    [✅] SECURITY.md created
    [ ] Deployment guide
    [ ] Incident response plan
    [ ] Runbooks for common issues
    [ ] User documentation

[ ] Legal & Compliance
    [ ] Legal review (Bolivia jurisdiction)
    [ ] Terms of service
    [ ] Privacy policy
    [ ] Bug disclosure policy
    [ ] Responsible disclosure program
```

### Production Launch Requirements

**Must Have (Blockers):**
```
❗ External security audit by reputable firm (Trail of Bits, OpenZeppelin, ConsenSys Diligence)
❗ All critical & high severity issues resolved
❗ Bug bounty program active (min $100k pool)
❗ Multi-sig for all admin operations
❗ Monitoring & alerting infrastructure
❗ Incident response plan documented
❗ Celestia mainnet integration complete
❗ Escape hatches tested
❗ 6+ months on testnet without critical incidents
```

**Should Have (High Priority):**
```
⚠️ Coverage >95% for critical contracts
⚠️ Formal verification for core invariants
⚠️ Timelock for governance (48h minimum)
⚠️ Circuit breakers for emergency stop
⚠️ Rate limiting on all entry points
⚠️ Multiple geographically distributed nodes
⚠️ Automated backup & recovery
⚠️ Post-mortem process established
```

---

## 🔍 Audit Roadmap

### Audit Schedule (Conceptual)

```
FASE 0 Completion → Core Token Audit
├─ Scope: ANDEToken.sol, Token Duality, ev-reth integration
├─ Firm: Trail of Bits or OpenZeppelin
├─ Duration: 2-3 weeks
├─ Cost: $25k-$40k
└─ Deliverable: Audit report + recommendations

FASE 1 Completion → CDP System Audit
├─ Scope: AbobToken, CollateralManager, Oracle system, Liquidations
├─ Firm: Top-tier (Trail of Bits, ConsenSys)
├─ Duration: 4-6 weeks
├─ Cost: $50k-$80k
└─ Deliverable: Comprehensive security analysis

FASE 2 Completion → Bridge Infrastructure Audit
├─ Scope: AndeBridge, EthereumBridge, Relayer, Blobstream integration
├─ Firm: Bridge specialists (ConsenSys, Halborn)
├─ Duration: 4-6 weeks
├─ Cost: $60k-$100k
└─ Deliverable: Bridge security report

FASE 3+ → Ongoing Security
├─ Annual full system audits
├─ Code review for all major changes
├─ Continuous monitoring & testing
└─ Active bug bounty program
```

### Recommended Audit Firms

**Tier 1 (High Cost, High Quality):**
- Trail of Bits - https://www.trailofbits.com/
- OpenZeppelin - https://www.openzeppelin.com/security-audits
- ConsenSys Diligence - https://consensys.net/diligence/

**Tier 2 (Medium Cost, Good Quality):**
- Halborn - https://halborn.com/
- ChainSecurity - https://chainsecurity.com/
- Quantstamp - https://quantstamp.com/

**Tier 3 (Lower Cost, Specialized):**
- Hacken - https://hacken.io/
- CertiK - https://www.certik.com/
- PeckShield - https://peckshield.com/

---

## 🏆 Bug Bounty Program

### Scope (When Active)

```
In Scope:
├─ Smart contracts (all contracts in src/)
├─ Rollup infrastructure (ev-reth, ev-node)
├─ Bridge & relayer
├─ RPC endpoints
└─ Web interfaces (when launched)

Out of Scope:
├─ Third-party dependencies
├─ Known issues from audits (before fix)
├─ Social engineering
├─ DDoS attacks
└─ UI/UX bugs (non-security)
```

### Severity & Rewards

```
CRITICAL (Loss of funds, network halt)
├─ Reward: $50,000 - $100,000+
├─ Examples:
│   ├─ Unauthorized token minting
│   ├─ Bridge fund theft
│   ├─ Chain halt exploit
│   └─ Upgrade to malicious implementation

HIGH (Significant impact, requires multiple steps)
├─ Reward: $10,000 - $50,000
├─ Examples:
│   ├─ Governance manipulation
│   ├─ Oracle price manipulation
│   ├─ Sequencer censorship bypass failure
│   └─ Unauthorized privilege escalation

MEDIUM (Limited impact, complex conditions)
├─ Reward: $2,000 - $10,000
├─ Examples:
│   ├─ Gas griefing
│   ├─ DoS on specific functions
│   ├─ Information disclosure
│   └─ Economic exploits (limited scope)

LOW (Minimal impact)
├─ Reward: $500 - $2,000
├─ Examples:
│   ├─ Gas optimization
│   ├─ Best practice violations
│   └─ Code quality issues
```

### Submission Process

```
1. Discovery
   ├─ Identify vulnerability
   ├─ Create PoC (proof of concept)
   └─ Test on testnet (DO NOT exploit mainnet)

2. Submission
   ├─ Email: security@andelabs.io
   ├─ Encrypt with PGP (key on website)
   ├─ Include: Description, PoC, severity assessment
   └─ DO NOT publicly disclose before fix

3. Review
   ├─ Acknowledgment within 24 hours
   ├─ Initial assessment within 72 hours
   ├─ Severity confirmation
   └─ Fix timeline communicated

4. Resolution
   ├─ Fix developed and tested
   ├─ Deployed to production
   ├─ Reward paid (after fix confirmation)
   └─ Public disclosure (coordinated)
```

### Bug Bounty Platforms

**Recommended:**
- Immunefi - https://immunefi.com/ (crypto-native, high rewards)
- HackerOne - https://www.hackerone.com/
- Code4rena - https://code4rena.com/ (competitive audits)

---

## 🚨 Incident Response

### Severity Levels

```
P0 - CRITICAL (Active exploit, immediate risk)
├─ Response Time: <15 minutes
├─ Team: Full team + emergency council
├─ Actions:
│   ├─ Pause affected contracts (if possible)
│   ├─ Activate incident response team
│   ├─ Notify users via all channels
│   ├─ Coordinate with security partners
│   └─ Deploy fix ASAP (test in parallel)

P1 - HIGH (Significant vulnerability, not yet exploited)
├─ Response Time: <1 hour
├─ Team: Security team + on-call devs
├─ Actions:
│   ├─ Assess impact and attack vectors
│   ├─ Develop and test fix
│   ├─ Prepare emergency upgrade
│   └─ Notify stakeholders

P2 - MEDIUM (Limited vulnerability)
├─ Response Time: <24 hours
├─ Team: Security team
├─ Actions:
│   ├─ Document vulnerability
│   ├─ Develop fix for next release
│   └─ Monitor for exploitation

P3 - LOW (Informational, no immediate risk)
├─ Response Time: <7 days
├─ Team: Development team
├─ Actions:
│   ├─ Add to backlog
│   └─ Fix in regular cycle
```

### Emergency Contacts

```
Security Team:
├─ Email: security@andelabs.io
├─ PGP Key: [TBD - publish on website]
├─ Telegram: @AndeChainSecurity (emergency only)
└─ Phone: +591 [TBD] (24/7 on-call)

Emergency Council:
├─ Multi-sig: [TBD - 5-of-9 Gnosis Safe]
├─ Powers: Pause contracts, emergency upgrades
└─ Timelock: 72 hours maximum (then must go to governance)
```

### Incident Response Playbook

**Step 1: Detection & Triage (0-15 min)**
```bash
# Automated alerts trigger
# On-call engineer investigates
# Severity assessed
# Team mobilized if P0/P1
```

**Step 2: Containment (15 min - 1 hour)**
```solidity
// For smart contract exploits:
// 1. Pause affected contracts
contract.pause() // PAUSER_ROLE

// 2. Rate limit if bridge-related
bridgeContract.setRateLimit(0) // Temporarily halt

// 3. Coordinate with CEXs (if token-related)
// Notify: Binance, Coinbase, etc. to halt trading
```

**Step 3: Investigation (1-6 hours)**
```
- Identify root cause
- Assess total impact (funds at risk, users affected)
- Determine attack vector
- Check for ongoing exploitation
- Preserve evidence (logs, transactions)
```

**Step 4: Mitigation & Fix (6-24 hours)**
```
- Develop fix
- Test fix on fork/testnet
- Prepare emergency upgrade (if needed)
- Get multi-sig approvals
- Deploy fix to mainnet
- Verify fix effectiveness
```

**Step 5: Communication (Ongoing)**
```
Initial (within 1 hour):
├─ "We are investigating an incident"
├─ Channels: Twitter, Discord, Website banner
└─ Frequency: Every 30 minutes until resolved

During Fix (every 2-4 hours):
├─ Status updates
├─ No premature details (prevent copycats)
└─ Estimated resolution time

Post-Resolution (within 24 hours):
├─ Incident summary
├─ Root cause
├─ Actions taken
├─ User impact
├─ Compensation plan (if applicable)
└─ Prevention measures
```

**Step 6: Post-Mortem (within 7 days)**
```
Document:
├─ Timeline of events
├─ Root cause analysis
├─ What went well
├─ What went wrong
├─ Action items to prevent recurrence
└─ Publish public post-mortem (transparency)
```

---

## 📞 Security Contact

### Responsible Disclosure

We encourage responsible disclosure of security vulnerabilities.

**Contact:**
- Email: security@andelabs.io
- PGP Key: [TBD - publish on website]
- Response Time: 24 hours acknowledgment, 72 hours initial assessment

**Please DO NOT:**
- Exploit vulnerabilities on mainnet
- Publicly disclose before coordinated disclosure
- Share exploit details with third parties

**Please DO:**
- Provide detailed reproduction steps
- Include proof-of-concept code
- Suggest potential fixes (if known)
- Allow reasonable time for fix (90 days standard)

### Security Resources

**Documentation:**
- This document: `/andechain/SECURITY.md`
- Development philosophy: `/GEMINI.md`
- Git workflow: `/andechain/GIT_WORKFLOW.md`
- Onboarding: `/andechain/ONBOARDING.md`

**External Resources:**
- OWASP Smart Contract Security: https://owasp.org/www-project-smart-contract-top-10/
- ConsenSys Best Practices: https://consensys.github.io/smart-contract-best-practices/
- Trail of Bits Building Secure Contracts: https://github.com/crytic/building-secure-contracts

---

## 📜 Security Changelog

### Version 1.0 (October 9, 2025)
- Initial SECURITY.md creation
- Threat model for ANDEToken and infrastructure
- Pre-production checklist defined
- Audit roadmap outlined
- Incident response procedures documented

---

**Remember: Security is not a one-time effort, but a continuous process. This document should be updated with every major release and after every security incident.**

---

**Last Updated:** October 9, 2025
**Next Review:** FASE 1 Completion (ABOB CDP Launch)
