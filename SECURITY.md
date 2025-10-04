# Security Policy

## Reporting a Vulnerability

🔒 **DO NOT open public issues for security vulnerabilities.**

We take the security of our smart contracts seriously. If you discover a security vulnerability, we appreciate your help in disclosing it to us responsibly. Please report it privately to **security@andechain.io**.

We will coordinate with you to assess the issue, work on a fix, and plan for a responsible disclosure.

### What to Include

Please include as much information as possible in your report:
- A description of the vulnerability and its potential impact.
- Steps to reproduce the issue or a proof-of-concept.
- A suggested fix, if you have one.

### Bug Bounty Program

We offer rewards for security researchers who help us keep the protocol safe. Bounties are awarded based on the severity of the vulnerability, at the discretion of the team.

| Severity | Bounty Range (USD) |
|-----------|--------------|
| **Critical** | $50,000 - $100,000 |
| **High** | $10,000 - $50,000 |
| **Medium** | $2,000 - $10,000 |
| **Low** | $500 - $2,000 |

**In Scope:**
- Smart contracts in `contracts/src/`.
- Economic exploits and logic errors.
- Scenarios leading to a direct loss of user funds.

**Out of Scope:**
- Gas optimization suggestions.
- Issues related to test contracts.
- General best-practice recommendations without a specific vulnerability.

### Our Security Process

- **Development:** We follow a test-driven development process with Foundry, aiming for high test coverage. All code is reviewed before merging.
- **CI/CD:** Our CI pipeline includes static analysis and security scanning on every pull request.
- **Audits:** We plan to conduct professional third-party audits before any mainnet deployment.

---
*This policy is a living document and may be updated over time.*
