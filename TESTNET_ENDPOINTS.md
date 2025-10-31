# ANDE Chain Testnet - Endpoints & Configuration

## 🚀 Network Information

**Chain Name:** AndeChain
**Chain ID:** 6174
**Network:** Testnet (Celestia Mocha-4)
**Block Time:** 2 seconds
**Consensus:** Evolve Sequencer
**Data Availability:** Celestia Mocha-4

---

## 📡 Public RPC Endpoints

### HTTP RPC Endpoint
```
http://<YOUR_IP>/rpc
```

**Methods Supported:**
- `eth_blockNumber`
- `eth_getBalance`
- `eth_getBlockByNumber`
- `eth_getBlockByHash`
- `eth_getTransactionByHash`
- `eth_sendTransaction`
- `eth_sendRawTransaction`
- `eth_call`
- `eth_estimateGas`
- `eth_gasPrice`
- `net_version`
- `web3_clientVersion`
- And more...

**Example Request:**
```bash
curl -X POST http://localhost/rpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"eth_blockNumber",
    "params":[],
    "id":1
  }'
```

### WebSocket RPC Endpoint
```
ws://<YOUR_IP>/ws
```

**For subscribing to events:**
```bash
wscat -c ws://localhost/ws
```

---

## 🔄 Evolve Sequencer RPC
```
http://<YOUR_IP>/evolve
```

**Used for:**
- Sequencer status
- Block production info
- DA submission status

---

## 📊 Monitoring & Dashboards

### Prometheus Metrics
```
http://<YOUR_IP>/metrics
```
**Authentication:** Required (Username: `admin`, Password: configured in nginx)

**Available Metrics:**
- `ev_reth_*` - EV-Reth metrics
- `evolve_*` - Evolve Sequencer metrics
- `celestia_*` - Celestia Light Node metrics
- `process_*` - System process metrics

### Grafana Dashboard
```
http://<YOUR_IP>/grafana
```
**Default Credentials:**
- Username: `admin`
- Password: `andechain-admin-2025`

**Pre-configured Dashboards:**
- ANDE Chain Overview
- EV-Reth Metrics
- Evolve Consensus Metrics
- Celestia DA Status
- System Resources

### cAdvisor (Container Monitoring)
```
http://<YOUR_IP>/cadvisor
```
**Authentication:** Required

---

## 🔧 Network Configuration Examples

### MetaMask / Web3 Connection

**Network Settings:**
```
Network Name: AndeChain Testnet
RPC URL: http://<YOUR_IP>/rpc
Chain ID: 6174
Currency Symbol: ANDE
Block Explorer URL: (optional, if available)
```

### Ethers.js
```javascript
const { ethers } = require('ethers');

const provider = new ethers.JsonRpcProvider('http://<YOUR_IP>/rpc');

// Get latest block
provider.getBlockNumber().then(blockNum => {
  console.log('Latest block:', blockNum);
});

// Get balance
const balance = await provider.getBalance('0x...');
console.log('Balance:', ethers.formatEther(balance));
```

### Web3.py
```python
from web3 import Web3

w3 = Web3(Web3.HTTPProvider('http://<YOUR_IP>/rpc'))

# Check connection
if w3.is_connected():
    print(f'Connected! Latest block: {w3.eth.block_number}')

# Get balance
balance = w3.eth.get_balance('0x...')
print(f'Balance: {w3.from_wei(balance, "ether")} ANDE')
```

### Hardhat Configuration
```javascript
module.exports = {
  networks: {
    andechain: {
      url: 'http://<YOUR_IP>/rpc',
      chainId: 6174,
      accounts: ['YOUR_PRIVATE_KEY'],
    },
  },
};
```

---

## 💰 Getting Test Tokens

### Using Faucet API (if available)
```bash
curl -X POST http://<YOUR_IP>/faucet \
  -H "Content-Type: application/json" \
  -d '{
    "address": "0x...",
    "amount": "1"
  }'
```

### Manual Distribution
Contact the ANDE Chain team to request test tokens.

**Initial Funded Accounts:**
```
0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266  (10M ANDE)
0x70997970C51812dc3A010C7d01b50e0d17dc79C8
0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
```

---

## 🔐 Security Features

### Rate Limiting
- **RPC endpoints:** 10 requests/second per IP
- **Burst:** Up to 20 requests allowed
- **API endpoints:** 100 requests/second per IP

### Authentication
- Metrics endpoints require basic authentication
- cAdvisor requires authentication
- Public RPC endpoints are rate-limited but not authenticated

### SSL/TLS (if configured)
```
https://<YOUR_IP>/rpc  (if SSL is enabled)
wss://<YOUR_IP>/ws     (if SSL is enabled)
```

---

## 🛠️ Troubleshooting

### Connection Issues
1. Check if nginx is running:
   ```bash
   docker compose ps nginx-proxy
   ```

2. Test direct connection to ev-reth:
   ```bash
   curl -X POST http://localhost:8545 \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
   ```

3. Check logs:
   ```bash
   docker compose logs -f ev-reth-sequencer
   docker compose logs -f evolve-sequencer
   docker compose logs -f nginx-proxy
   ```

### RPC Errors
- **"Method not supported"** - Method not available in ev-reth
- **"Rate limit exceeded"** - Too many requests, wait and retry
- **"Service unavailable"** - Check if services are healthy

### Performance Issues
1. Check resource usage:
   ```bash
   docker stats
   ```

2. Check disk space:
   ```bash
   df -h
   ```

3. Review logs for errors:
   ```bash
   docker compose logs --tail=100
   ```

---

## 📈 Performance Metrics

**Expected Performance:**
- **Block Time:** 2 seconds
- **Max TPS:** ~1000 (depends on contract complexity)
- **Finality:** ~30 seconds (after Celestia inclusion)
- **Gas Limit:** 30M per block

**Typical RPC Response Time:**
- Simple queries: <100ms
- Complex queries: <500ms
- Transactions: <1s confirmation

---

## 🔗 Related Links

- **Frontend Testnet:** https://testnet.andelabs.io (if available)
- **Celestia Mocha-4 Explorer:** https://mocha-4.celenium.io/
- **Documentation:** https://docs.andelabs.io
- **GitHub:** https://github.com/andelabs

---

## 📝 Notes

- This is a testnet environment. Data may be reset periodically.
- Do NOT use private keys for production accounts.
- Report issues to: support@andelabs.io
- The network is monitored 24/7 for stability.

---

**Last Updated:** $(date '+%Y-%m-%d')
**Network Status:** [Check Grafana Dashboard](/grafana)
