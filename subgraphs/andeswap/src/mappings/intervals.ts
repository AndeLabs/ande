import { BigInt, BigDecimal, ethereum } from '@graphprotocol/graph-ts'
import {
  Pair,
  Token,
  Factory,
  PairHourData,
  PairDayData,
  TokenDayData,
  FactoryDayData
} from '../../generated/schema'
import { ZERO_BD, ZERO_BI, ONE_BI } from './helpers'

export function updatePairDayData(event: ethereum.Event, pair: Pair): PairDayData {
  let timestamp = event.block.timestamp.toI32()
  let dayID = timestamp / 86400
  let dayStartTimestamp = dayID * 86400
  let dayPairID = event.address.toHexString().concat('-').concat(BigInt.fromI32(dayID).toString())

  let pairDayData = PairDayData.load(dayPairID)
  
  if (pairDayData === null) {
    pairDayData = new PairDayData(dayPairID)
    pairDayData.date = dayStartTimestamp
    pairDayData.pairAddress = event.address
    pairDayData.pair = pair.id
    pairDayData.token0 = pair.token0
    pairDayData.token1 = pair.token1
    pairDayData.dailyVolumeToken0 = ZERO_BD
    pairDayData.dailyVolumeToken1 = ZERO_BD
    pairDayData.dailyVolumeUSD = ZERO_BD
    pairDayData.dailyTxns = ZERO_BI
  }

  pairDayData.totalSupply = pair.totalSupply
  pairDayData.reserve0 = pair.reserve0
  pairDayData.reserve1 = pair.reserve1
  pairDayData.reserveUSD = pair.reserveUSD
  pairDayData.dailyTxns = pairDayData.dailyTxns.plus(ONE_BI)
  pairDayData.save()

  return pairDayData as PairDayData
}

export function updatePairHourData(event: ethereum.Event, pair: Pair): PairHourData {
  let timestamp = event.block.timestamp.toI32()
  let hourIndex = timestamp / 3600
  let hourStartUnix = hourIndex * 3600
  let hourPairID = event.address.toHexString().concat('-').concat(BigInt.fromI32(hourIndex).toString())

  let pairHourData = PairHourData.load(hourPairID)
  
  if (pairHourData === null) {
    pairHourData = new PairHourData(hourPairID)
    pairHourData.hourStartUnix = hourStartUnix
    pairHourData.pair = pair.id
    pairHourData.hourlyVolumeToken0 = ZERO_BD
    pairHourData.hourlyVolumeToken1 = ZERO_BD
    pairHourData.hourlyVolumeUSD = ZERO_BD
    pairHourData.hourlyTxns = ZERO_BI
  }

  pairHourData.totalSupply = pair.totalSupply
  pairHourData.reserve0 = pair.reserve0
  pairHourData.reserve1 = pair.reserve1
  pairHourData.reserveUSD = pair.reserveUSD
  pairHourData.hourlyTxns = pairHourData.hourlyTxns.plus(ONE_BI)
  pairHourData.save()

  return pairHourData as PairHourData
}

export function updateTokenDayData(token: Token, event: ethereum.Event): TokenDayData {
  let timestamp = event.block.timestamp.toI32()
  let dayID = timestamp / 86400
  let dayStartTimestamp = dayID * 86400
  let tokenDayID = token.id.toString().concat('-').concat(BigInt.fromI32(dayID).toString())

  let tokenDayData = TokenDayData.load(tokenDayID)
  
  if (tokenDayData === null) {
    tokenDayData = new TokenDayData(tokenDayID)
    tokenDayData.date = dayStartTimestamp
    tokenDayData.token = token.id
    tokenDayData.priceUSD = token.derivedUSD !== null ? token.derivedUSD as BigDecimal : ZERO_BD
    tokenDayData.dailyVolumeToken = ZERO_BD
    tokenDayData.dailyVolumeANDE = ZERO_BD
    tokenDayData.dailyVolumeUSD = ZERO_BD
    tokenDayData.dailyTxns = ZERO_BI
    tokenDayData.totalLiquidityToken = ZERO_BD
    tokenDayData.totalLiquidityANDE = ZERO_BD
    tokenDayData.totalLiquidityUSD = ZERO_BD
  }

  tokenDayData.priceUSD = token.derivedUSD !== null ? token.derivedUSD as BigDecimal : ZERO_BD
  tokenDayData.totalLiquidityToken = token.totalLiquidity
  tokenDayData.totalLiquidityANDE = token.totalLiquidity.times(
    token.derivedANDE !== null ? token.derivedANDE as BigDecimal : ZERO_BD
  )
  tokenDayData.totalLiquidityUSD = tokenDayData.totalLiquidityANDE.times(
    token.derivedUSD !== null ? token.derivedUSD as BigDecimal : ZERO_BD
  )
  tokenDayData.dailyTxns = tokenDayData.dailyTxns.plus(ONE_BI)
  tokenDayData.save()

  return tokenDayData as TokenDayData
}

export function updateFactoryDayData(event: ethereum.Event, factory: Factory): FactoryDayData {
  let timestamp = event.block.timestamp.toI32()
  let dayID = timestamp / 86400
  let dayStartTimestamp = dayID * 86400
  let factoryDayDataID = BigInt.fromI32(dayID).toString()

  let factoryDayData = FactoryDayData.load(factoryDayDataID)
  
  if (factoryDayData === null) {
    factoryDayData = new FactoryDayData(factoryDayDataID)
    factoryDayData.date = dayStartTimestamp
    factoryDayData.dailyVolumeUSD = ZERO_BD
    factoryDayData.dailyVolumeANDE = ZERO_BD
    factoryDayData.dailyVolumeUntracked = ZERO_BD
  }

  factoryDayData.totalLiquidityUSD = factory.totalLiquidityUSD
  factoryDayData.totalLiquidityANDE = factory.totalLiquidityANDE
  factoryDayData.totalVolumeUSD = factory.totalVolumeUSD
  factoryDayData.totalVolumeANDE = factory.totalVolumeANDE
  factoryDayData.txCount = factory.txCount
  factoryDayData.save()

  return factoryDayData as FactoryDayData
}
