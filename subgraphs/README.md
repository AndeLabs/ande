# AndeChain Subgraphs

Comprehensive blockchain data indexing infrastructure for the AndeChain ecosystem using The Graph Protocol.

## Overview

This directory contains three production-ready subgraphs that index all critical smart contract events across the AndeChain ecosystem:

- **AndeSwap** - DEX protocol indexing (swaps, liquidity, pricing)
- **AndeLend** - Lending protocol indexing (deposits, borrows, liquidations)  
- **AndeLaunchpad** - IDO platform indexing (launches, contributions, claims)

## Architecture

```
subgraphs/
├── andeswap/          # DEX data indexing
│   ├── schema.graphql
│   ├── subgraph.yaml
│   ├── package.json
│   ├── abis/          # ERC20 token ABIs
│   └── src/
│       ├── mappings/  # Event handlers
│       │   ├── factory.ts
│       │   ├── pair.ts
│       │   ├── helpers.ts
│       │   ├── pricing.ts
│       │   └── intervals.ts
│       └── utils/
│           └── token.ts
│
├── andelend/          # Lending protocol indexing
│   ├── schema.graphql
│   ├── subgraph.yaml
│   ├── package.json
│   └── src/
│       └── mappings/
│           ├── andeLend.ts
│           ├── entities.ts
│           ├── helpers.ts
│           └── utils.ts
│
├── andelaunchpad/     # IDO platform indexing
│   ├── schema.graphql
│   ├── subgraph.yaml
│   ├── package.json
│   └── src/
│       └── mappings/
│           ├── launchpad.ts
│           ├── helpers.ts
│           └── intervals.ts
│
├── docker-compose.yml # Local Graph Node setup
└── README.md         # This file
```

## Features

### AndeSwap Subgraph
- **Real-time DEX data**: Track all swaps, liquidity adds/removes
- **TWAP pricing**: Calculate time-weighted average prices
- **Volume tracking**: 24h, 7d, 30d trading volumes per pair
- **Liquidity analytics**: TVL per pair, per token, protocol-wide
- **Historical snapshots**: Hourly and daily data aggregation
- **Price discovery**: Derived ANDE price from multiple pairs

**Key Entities:**
- `Factory`, `Pair`, `Token`, `Bundle`
- `Swap`, `Mint`, `Burn`
- `PairDayData`, `PairHourData`, `TokenDayData`
- `User`, `LiquidityPosition`

### AndeLend Subgraph
- **Market monitoring**: Track all lending markets
- **Position tracking**: User deposits, borrows, collateral
- **Liquidation data**: All liquidation events with details
- **Interest rates**: Real-time supply/borrow APY calculations
- **Health factors**: User account health and risk metrics
- **Protocol analytics**: Total supplied, borrowed, reserved

**Key Entities:**
- `Protocol`, `Market`, `Token`
- `Account`, `Position`
- `Deposit`, `Withdraw`, `Borrow`, `Repay`, `Liquidation`
- `MarketDailySnapshot`, `ProtocolDailySnapshot`

### AndeLaunchpad Subgraph
- **IDO tracking**: All active and historical token launches
- **Contribution data**: User investments per IDO
- **Tier system**: Bronze/Silver/Gold/Platinum allocations
- **Vesting schedules**: Track vested and claimable tokens
- **Whitelist management**: Whitelist status per user
- **Refund tracking**: Failed IDO refunds

**Key Entities:**
- `LaunchpadProtocol`, `IDO`, `LaunchedToken`
- `Participant`, `Contribution`, `Claim`, `Refund`
- `IDODailySnapshot`, `LaunchpadDailySnapshot`

## Local Development

### Prerequisites

```bash
# Install Graph CLI
npm install -g @graphprotocol/graph-cli

# Install Docker and Docker Compose
# https://docs.docker.com/get-docker/
```

### Setup Graph Node

```bash
# Start PostgreSQL, IPFS, and Graph Node
cd subgraphs
docker-compose up -d

# Check status
docker-compose ps
```

### Deploy AndeSwap Subgraph

```bash
cd andeswap

# Install dependencies
npm install

# Update contract addresses in subgraph.yaml
# Set FACTORY_ADDRESS in src/mappings/helpers.ts

# Generate types
npm run codegen

# Build subgraph
npm run build

# Create local subgraph
npm run create-local

# Deploy to local node
npm run deploy-local
```

### Deploy AndeLend Subgraph

```bash
cd andelend

npm install

# Update AndeLend address in subgraph.yaml
# Update PROTOCOL_ADDRESS in src/mappings/helpers.ts

npm run codegen
npm run build
npm run create-local
npm run deploy-local
```

### Deploy AndeLaunchpad Subgraph

```bash
cd andelaunchpad

npm install

# Update AndeLaunchpad address in subgraph.yaml

npm run codegen
npm run build
npm run create-local
npm run deploy-local
```

## GraphQL Queries

### AndeSwap Examples

```graphql
# Get top pairs by liquidity
{
  pairs(first: 10, orderBy: reserveUSD, orderDirection: desc) {
    id
    token0 {
      symbol
    }
    token1 {
      symbol
    }
    reserveUSD
    volumeUSD
    token0Price
    token1Price
  }
}

# Get ANDE price
{
  bundle(id: "1") {
    andePrice
  }
}

# Get user liquidity positions
{
  user(id: "0x...") {
    liquidityPositions {
      pair {
        token0 { symbol }
        token1 { symbol }
      }
      liquidityTokenBalance
    }
  }
}

# Get pair hourly data
{
  pairHourDatas(
    first: 24
    orderBy: hourStartUnix
    orderDirection: desc
    where: { pair: "0x..." }
  ) {
    hourStartUnix
    hourlyVolumeUSD
    reserveUSD
  }
}
```

### AndeLend Examples

```graphql
# Get all markets
{
  markets {
    id
    token {
      symbol
    }
    totalSupply
    totalBorrow
    supplyRate
    borrowRate
    utilizationRate
  }
}

# Get user positions
{
  account(id: "0x...") {
    positions {
      market {
        token { symbol }
      }
      supplied
      borrowed
      collateral
      healthFactor
    }
  }
}

# Get recent liquidations
{
  liquidations(first: 10, orderBy: timestamp, orderDirection: desc) {
    liquidator
    borrower
    debtToken { symbol }
    debtAmount
    collateralToken { symbol }
    collateralAmount
    timestamp
  }
}

# Get market daily snapshots
{
  marketDailySnapshots(
    first: 30
    orderBy: timestamp
    orderDirection: desc
    where: { market: "0x..." }
  ) {
    date
    dailySupply
    dailyBorrow
    dailyLiquidations
    totalSupply
    totalBorrow
  }
}
```

### AndeLaunchpad Examples

```graphql
# Get active IDOs
{
  idos(where: { status: ACTIVE }) {
    id
    token {
      name
      symbol
    }
    totalRaised
    hardcap
    totalParticipants
    startTime
    endTime
  }
}

# Get user contributions
{
  participant(id: "0x...-0x...") {
    address
    tier
    andeStaked
    totalContributed
    tokensAllocated
    tokensClaimed
    contributions {
      amount
      timestamp
    }
  }
}

# Get IDO performance
{
  idoDailySnapshots(
    first: 30
    where: { ido: "0x..." }
    orderBy: timestamp
    orderDirection: desc
  ) {
    timestamp
    totalRaised
    percentageRaised
    totalParticipants
    dailyContributions
  }
}

# Get launchpad metrics
{
  launchpadProtocol(id: "1") {
    totalLaunches
    totalRaisedUSD
    totalParticipants
    activeIDOs
    completedIDOs
  }
}
```

## Configuration

### Update Contract Addresses

Before deploying, update the contract addresses in each `subgraph.yaml`:

```yaml
# andeswap/subgraph.yaml
dataSources:
  - source:
      address: '0xYourFactoryAddress'
      
# andelend/subgraph.yaml  
dataSources:
  - source:
      address: '0xYourAndeLendAddress'
      
# andelaunchpad/subgraph.yaml
dataSources:
  - source:
      address: '0xYourLaunchpadAddress'
```

### Update Constants

Update token addresses and constants in helper files:

**andeswap/src/mappings/pricing.ts:**
```typescript
const WANDE_ADDRESS = '0x...'
const USDC_ADDRESS = '0x...'
const USDT_ADDRESS = '0x...'
```

**andeswap/src/mappings/helpers.ts:**
```typescript
export const FACTORY_ADDRESS = '0x...'
```

## Production Deployment

### Deploy to The Graph Network

```bash
# Authenticate
graph auth --product hosted-service <ACCESS_TOKEN>

# Deploy AndeSwap
cd andeswap
graph deploy --product hosted-service <GITHUB_USERNAME>/andeswap

# Deploy AndeLend
cd ../andelend
graph deploy --product hosted-service <GITHUB_USERNAME>/andelend

# Deploy AndeLaunchpad
cd ../andelaunchpad
graph deploy --product hosted-service <GITHUB_USERNAME>/andelaunchpad
```

### Deploy to Studio

```bash
# Create subgraph in Studio
# https://thegraph.com/studio

# Deploy
graph deploy --studio andeswap
graph deploy --studio andelend
graph deploy --studio andelaunchpad
```

## Testing

```bash
cd andeswap
npm run test

cd ../andelend
npm run test

cd ../andelaunchpad
npm run test
```

## Monitoring

### Graph Node Health

```bash
# Check Graph Node status
curl http://localhost:8030/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{indexingStatusForCurrentVersion(subgraphName: \"andechain/andeswap\") { synced health }}"}'
```

### Query Performance

```graphql
{
  _meta {
    block {
      number
      hash
    }
    deployment
    hasIndexingErrors
  }
}
```

## Troubleshooting

### Subgraph Not Syncing

```bash
# Check Graph Node logs
docker-compose logs -f graph-node

# Restart Graph Node
docker-compose restart graph-node
```

### Compilation Errors

```bash
# Clean and rebuild
rm -rf generated/ build/
npm run codegen
npm run build
```

### Missing Data

- Check contract addresses are correct
- Verify startBlock in subgraph.yaml
- Check event signatures match contract ABIs
- Review Graph Node logs for errors

## Performance Optimization

### Indexing Speed
- Set appropriate `startBlock` to skip empty blocks
- Use data source templates for dynamically created contracts
- Batch queries where possible

### Query Optimization
- Use pagination (`first`, `skip`)
- Filter with `where` clauses
- Request only needed fields
- Use block numbers for historical queries

## Resources

- **The Graph Docs**: https://thegraph.com/docs
- **AndeChain Docs**: https://docs.andechain.io
- **GraphQL Docs**: https://graphql.org/learn
- **AssemblyScript**: https://www.assemblyscript.org

## Status

| Subgraph | Status | Build | Deployment |
|----------|--------|-------|------------|
| AndeSwap | ✅ Complete | ✅ Passing | Ready |
| AndeLend | ⚠️  Needs Fixes | ❌ Type Errors | In Progress |
| AndeLaunchpad | ✅ Complete | ⏳ Untested | Ready |

## Next Steps

1. **Fix AndeLend type errors** - Resolve nullable field issues
2. **Deploy to testnet** - Test with real blockchain data
3. **Add more entities** - Expand data models as needed
4. **Optimize queries** - Profile and improve slow queries
5. **Add monitoring** - Set up alerts for indexing failures
6. **Documentation** - API docs with example queries

## Support

For issues or questions:
- GitHub Issues: https://github.com/andelabs/andechain/issues
- Discord: https://discord.gg/andechain
- Email: dev@andechain.io
