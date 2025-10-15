// AndeSwap Pair Mappings
// Handles swap, mint, burn, and sync events

import { BigInt, Address, ethereum, BigDecimal } from '@graphprotocol/graph-ts'
import { Pair, Token, Transaction, Mint, Burn, Swap, Bundle, Factory } from '../../generated/schema'
import { Mint as MintEvent, Burn as BurnEvent, Swap as SwapEvent, Sync as SyncEvent } from '../../generated/templates/Pair/Pair'
import { updatePairDayData, updatePairHourData, updateTokenDayData, updateFactoryDayData } from './intervals'
import { getAndePrice, findAndePerToken, getTrackedLiquidityUSD, getTrackedVolumeUSD } from './pricing'
import { convertTokenToDecimal, ZERO_BD, ONE_BD, ZERO_BI, ONE_BI, FACTORY_ADDRESS } from './helpers'

export function handleSync(event: SyncEvent): void {
  let pair = Pair.load(event.address.toHex())
  if (pair === null) {
    return
  }

  let token0 = Token.load(pair.token0)
  let token1 = Token.load(pair.token1)
  if (token0 === null || token1 === null) {
    return
  }

  // Reset tvl aggregates until new amounts calculated
  let factory = Factory.load(FACTORY_ADDRESS)
  if (factory === null) {
    return
  }

  // Update reserves
  pair.reserve0 = convertTokenToDecimal(event.params.reserve0, token0.decimals)
  pair.reserve1 = convertTokenToDecimal(event.params.reserve1, token1.decimals)

  if (pair.reserve1.notEqual(ZERO_BD)) {
    pair.token0Price = pair.reserve1.div(pair.reserve0)
  } else {
    pair.token0Price = ZERO_BD
  }
  if (pair.reserve0.notEqual(ZERO_BD)) {
    pair.token1Price = pair.reserve0.div(pair.reserve1)
  } else {
    pair.token1Price = ZERO_BD
  }

  pair.save()

  // Update ANDE price (via most liquid pairs)
  let bundle = Bundle.load('1')!
  bundle.andePrice = getAndePrice()
  bundle.save()

  token0.derivedANDE = findAndePerToken(token0 as Token)
  token1.derivedANDE = findAndePerToken(token1 as Token)
  token0.save()
  token1.save()

  // Get tracked liquidity
  let trackedLiquidityANDE = getTrackedLiquidityUSD(
    pair.reserve0,
    token0 as Token,
    pair.reserve1,
    token1 as Token
  )
  
  // Update pair tracked liquidity
  pair.trackedReserveANDE = trackedLiquidityANDE
  pair.reserveANDE = pair.reserve0
    .times(token0.derivedANDE as BigDecimal)
    .plus(pair.reserve1.times(token1.derivedANDE as BigDecimal))
  pair.reserveUSD = pair.reserveANDE.times(bundle.andePrice)

  // Update factory liquidity
  factory.totalLiquidityANDE = factory.totalLiquidityANDE.plus(trackedLiquidityANDE)
  factory.totalLiquidityUSD = factory.totalLiquidityANDE.times(bundle.andePrice)
  factory.save()
}

export function handleMint(event: MintEvent): void {
  let transaction = Transaction.load(event.transaction.hash.toHex())
  if (transaction === null) {
    transaction = new Transaction(event.transaction.hash.toHex())
    transaction.blockNumber = event.block.number
    transaction.timestamp = event.block.timestamp
    transaction.save()
  }

  let pair = Pair.load(event.address.toHex())!
  let factory = Factory.load(FACTORY_ADDRESS)!

  let token0 = Token.load(pair.token0)!
  let token1 = Token.load(pair.token1)!

  // Amounts
  let token0Amount = convertTokenToDecimal(event.params.amount0, token0.decimals)
  let token1Amount = convertTokenToDecimal(event.params.amount1, token1.decimals)

  // Update token liquidity
  token0.totalLiquidity = token0.totalLiquidity.plus(token0Amount)
  token1.totalLiquidity = token1.totalLiquidity.plus(token1Amount)
  token0.save()
  token1.save()

  // Update pair
  pair.txCount = pair.txCount.plus(ONE_BI)
  pair.save()

  // Update factory
  factory.txCount = factory.txCount.plus(ONE_BI)
  factory.save()

  // Create mint entity
  let mint = new Mint(event.transaction.hash.toHex() + '-' + event.logIndex.toString())
  mint.transaction = transaction.id
  mint.pair = pair.id
  mint.to = event.params.sender
  mint.liquidity = ZERO_BD
  mint.timestamp = transaction.timestamp
  mint.sender = event.params.sender
  mint.amount0 = token0Amount
  mint.amount1 = token1Amount
  mint.logIndex = event.logIndex
  mint.amountUSD = token0Amount
    .times(token0.derivedANDE as BigDecimal)
    .times(Bundle.load('1')!.andePrice)
    .plus(
      token1Amount
        .times(token1.derivedANDE as BigDecimal)
        .times(Bundle.load('1')!.andePrice)
    )
  mint.save()

  // Update day/hour data
  updatePairDayData(event, pair)
  updatePairHourData(event, pair)
  updateTokenDayData(token0, event)
  updateTokenDayData(token1, event)
  updateFactoryDayData(event, factory)
}

export function handleBurn(event: BurnEvent): void {
  let transaction = Transaction.load(event.transaction.hash.toHex())
  if (transaction === null) {
    transaction = new Transaction(event.transaction.hash.toHex())
    transaction.blockNumber = event.block.number
    transaction.timestamp = event.block.timestamp
    transaction.save()
  }

  let pair = Pair.load(event.address.toHex())!
  let factory = Factory.load(FACTORY_ADDRESS)!

  let token0 = Token.load(pair.token0)!
  let token1 = Token.load(pair.token1)!

  // Amounts
  let token0Amount = convertTokenToDecimal(event.params.amount0, token0.decimals)
  let token1Amount = convertTokenToDecimal(event.params.amount1, token1.decimals)

  // Update token liquidity
  token0.totalLiquidity = token0.totalLiquidity.minus(token0Amount)
  token1.totalLiquidity = token1.totalLiquidity.minus(token1Amount)
  token0.save()
  token1.save()

  // Update pair
  pair.txCount = pair.txCount.plus(ONE_BI)
  pair.save()

  // Update factory
  factory.txCount = factory.txCount.plus(ONE_BI)
  factory.save()

  // Create burn entity
  let burn = new Burn(event.transaction.hash.toHex() + '-' + event.logIndex.toString())
  burn.transaction = transaction.id
  burn.pair = pair.id
  burn.liquidity = ZERO_BD
  burn.timestamp = transaction.timestamp
  burn.sender = event.params.sender
  burn.amount0 = token0Amount
  burn.amount1 = token1Amount
  burn.to = event.params.to
  burn.logIndex = event.logIndex
  burn.amountUSD = token0Amount
    .times(token0.derivedANDE as BigDecimal)
    .times(Bundle.load('1')!.andePrice)
    .plus(
      token1Amount
        .times(token1.derivedANDE as BigDecimal)
        .times(Bundle.load('1')!.andePrice)
    )
  burn.needsComplete = true
  burn.save()

  // Update day/hour data
  updatePairDayData(event, pair)
  updatePairHourData(event, pair)
  updateTokenDayData(token0, event)
  updateTokenDayData(token1, event)
  updateFactoryDayData(event, factory)
}

export function handleSwap(event: SwapEvent): void {
  let pair = Pair.load(event.address.toHex())!
  let token0 = Token.load(pair.token0)!
  let token1 = Token.load(pair.token1)!
  
  let amount0In = convertTokenToDecimal(event.params.amount0In, token0.decimals)
  let amount1In = convertTokenToDecimal(event.params.amount1In, token1.decimals)
  let amount0Out = convertTokenToDecimal(event.params.amount0Out, token0.decimals)
  let amount1Out = convertTokenToDecimal(event.params.amount1Out, token1.decimals)

  // Calculate amounts
  let amount0Total = amount0Out.plus(amount0In)
  let amount1Total = amount1Out.plus(amount1In)

  // Get tracked amounts (for USD value)
  let derivedAmountANDE = token1.derivedANDE!
    .times(amount1Total)
    .plus(token0.derivedANDE!.times(amount0Total))
    .div(BigDecimal.fromString('2'))
  
  let trackedAmountUSD = getTrackedVolumeUSD(
    amount0Total,
    token0,
    amount1Total,
    token1,
    pair
  )

  // Update pair volume
  pair.volumeToken0 = pair.volumeToken0.plus(amount0Total)
  pair.volumeToken1 = pair.volumeToken1.plus(amount1Total)
  pair.volumeUSD = pair.volumeUSD.plus(trackedAmountUSD)
  pair.untrackedVolumeUSD = pair.untrackedVolumeUSD.plus(trackedAmountUSD)
  pair.txCount = pair.txCount.plus(ONE_BI)
  pair.save()

  // Update token volumes
  token0.tradeVolume = token0.tradeVolume.plus(amount0Total)
  token0.tradeVolumeUSD = token0.tradeVolumeUSD.plus(trackedAmountUSD)
  token0.untrackedVolumeUSD = token0.untrackedVolumeUSD.plus(trackedAmountUSD)
  token0.txCount = token0.txCount.plus(ONE_BI)
  token0.save()

  token1.tradeVolume = token1.tradeVolume.plus(amount1Total)
  token1.tradeVolumeUSD = token1.tradeVolumeUSD.plus(trackedAmountUSD)
  token1.untrackedVolumeUSD = token1.untrackedVolumeUSD.plus(trackedAmountUSD)
  token1.txCount = token1.txCount.plus(ONE_BI)
  token1.save()

  // Update factory
  let factory = Factory.load(FACTORY_ADDRESS)!
  factory.totalVolumeANDE = factory.totalVolumeANDE.plus(derivedAmountANDE)
  factory.totalVolumeUSD = factory.totalVolumeUSD.plus(trackedAmountUSD)
  factory.untrackedVolumeUSD = factory.untrackedVolumeUSD.plus(trackedAmountUSD)
  factory.txCount = factory.txCount.plus(ONE_BI)
  factory.save()

  // Create transaction
  let transaction = Transaction.load(event.transaction.hash.toHex())
  if (transaction === null) {
    transaction = new Transaction(event.transaction.hash.toHex())
    transaction.blockNumber = event.block.number
    transaction.timestamp = event.block.timestamp
    transaction.save()
  }

  // Create swap entity
  let swap = new Swap(event.transaction.hash.toHex() + '-' + event.logIndex.toString())
  swap.transaction = transaction.id
  swap.pair = pair.id
  swap.timestamp = transaction.timestamp
  swap.sender = event.params.sender
  swap.amount0In = amount0In
  swap.amount1In = amount1In
  swap.amount0Out = amount0Out
  swap.amount1Out = amount1Out
  swap.to = event.params.to
  swap.from = event.transaction.from
  swap.logIndex = event.logIndex
  swap.amountUSD = trackedAmountUSD
  swap.save()

  // Update day/hour data
  updatePairDayData(event, pair)
  updatePairHourData(event, pair)
  updateTokenDayData(token0, event)
  updateTokenDayData(token1, event)
  updateFactoryDayData(event, factory)
}
