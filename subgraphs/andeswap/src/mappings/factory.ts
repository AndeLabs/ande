// AndeSwap Factory Mappings
// Handles pair creation events

import { PairCreated } from '../../generated/Factory/Factory'
import { Pair as PairTemplate } from '../../generated/templates'
import { Factory, Pair, Token, Bundle } from '../../generated/schema'
import { BigDecimal, BigInt, Address } from '@graphprotocol/graph-ts'
import { ZERO_BD, ZERO_BI, ONE_BI, FACTORY_ADDRESS } from './helpers'
import { fetchTokenSymbol, fetchTokenName, fetchTokenDecimals, fetchTokenTotalSupply } from '../utils/token'

export function handlePairCreated(event: PairCreated): void {
  // Load factory
  let factory = Factory.load(FACTORY_ADDRESS)
  if (factory === null) {
    factory = new Factory(FACTORY_ADDRESS)
    factory.pairCount = 0
    factory.totalVolumeUSD = ZERO_BD
    factory.totalVolumeANDE = ZERO_BD
    factory.untrackedVolumeUSD = ZERO_BD
    factory.totalLiquidityUSD = ZERO_BD
    factory.totalLiquidityANDE = ZERO_BD
    factory.txCount = ZERO_BI
    
    // Create bundle for ANDE price tracking
    let bundle = new Bundle('1')
    bundle.andePrice = ZERO_BD
    bundle.save()
  }
  factory.pairCount = factory.pairCount + 1
  factory.save()

  // Create tokens if they don't exist
  let token0 = Token.load(event.params.token0.toHexString())
  if (token0 === null) {
    token0 = new Token(event.params.token0.toHexString())
    token0.symbol = fetchTokenSymbol(event.params.token0)
    token0.name = fetchTokenName(event.params.token0)
    token0.decimals = fetchTokenDecimals(event.params.token0)
    token0.totalSupply = fetchTokenTotalSupply(event.params.token0)
    token0.tradeVolume = ZERO_BD
    token0.tradeVolumeUSD = ZERO_BD
    token0.untrackedVolumeUSD = ZERO_BD
    token0.totalLiquidity = ZERO_BD
    token0.txCount = ZERO_BI
  }
  token0.save()

  let token1 = Token.load(event.params.token1.toHexString())
  if (token1 === null) {
    token1 = new Token(event.params.token1.toHexString())
    token1.symbol = fetchTokenSymbol(event.params.token1)
    token1.name = fetchTokenName(event.params.token1)
    token1.decimals = fetchTokenDecimals(event.params.token1)
    token1.totalSupply = fetchTokenTotalSupply(event.params.token1)
    token1.tradeVolume = ZERO_BD
    token1.tradeVolumeUSD = ZERO_BD
    token1.untrackedVolumeUSD = ZERO_BD
    token1.totalLiquidity = ZERO_BD
    token1.txCount = ZERO_BI
  }
  token1.save()

  // Create pair entity
  let pair = new Pair(event.params.pair.toHexString())
  pair.factory = factory.id
  pair.token0 = token0.id
  pair.token1 = token1.id
  pair.reserve0 = ZERO_BD
  pair.reserve1 = ZERO_BD
  pair.totalSupply = ZERO_BD
  pair.reserveANDE = ZERO_BD
  pair.reserveUSD = ZERO_BD
  pair.trackedReserveANDE = ZERO_BD
  pair.token0Price = ZERO_BD
  pair.token1Price = ZERO_BD
  pair.volumeToken0 = ZERO_BD
  pair.volumeToken1 = ZERO_BD
  pair.volumeUSD = ZERO_BD
  pair.untrackedVolumeUSD = ZERO_BD
  pair.txCount = ZERO_BI
  pair.createdAtTimestamp = event.block.timestamp
  pair.createdAtBlockNumber = event.block.number
  pair.save()

  // Create tracked contract based on the template
  PairTemplate.create(event.params.pair)
}
