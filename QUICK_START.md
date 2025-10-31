# ANDE Chain Testnet - Quick Start Guide

## 🚀 Start Network (60 segundos)

```bash
cd /mnt/c/Users/sator/andelabs/ande
docker compose up -d
sleep 30
docker compose ps
```

## 📡 Test RPC

```bash
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

## 💰 ANDE Token Address

```
0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
Total Supply: 100,000,000 ANDE
```

## 📊 Dashboards

- Grafana: http://localhost:3000 (admin / andechain-admin-2025)
- Prometheus: http://localhost:9090
- Loki: http://localhost:3100

## 🛑 Stop Network

```bash
docker compose down
```

---

**Status**: Production Ready ✅
