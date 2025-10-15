// Utility functions for AndeLend

import { ethereum, BigInt, BigDecimal } from '@graphprotocol/graph-ts'
import { Market, MarketDailySnapshot, MarketHourlySnapshot } from '../../generated/schema'
import { ZERO_BD, ZERO_BI, calculateUtilizationRate, PRECISION } from './helpers'

/**
 * Update market interest rates
 */
export function updateMarketRates(market: Market): void {
  // Calculate utilization rate
  market.utilizationRate = calculateUtilizationRate(
    market.totalBorrow,
    market.totalSupply
  )
  
  // Calculate borrow APR (simplified linear model)
  // borrowRate = baseRate + (utilizationRate * slope)
  let baseRate = BigInt.fromI32(200) // 2%
  let slope = BigInt.fromI32(400) // 4%
  
  let utilization = market.utilizationRate
    .times(BigDecimal.fromString('100'))
    .truncate(0)
    .digits
  
  market.borrowRate = baseRate.plus(
    slope.times(BigInt.fromString(utilization.toString())).div(BigInt.fromI32(100))
  )
  
  // Calculate supply APR
  // supplyRate = borrowRate * utilizationRate * (1 - reserveFactor)
  let reserveFactor = market.reserveFactor.toBigDecimal().div(PRECISION.toBigDecimal())
  market.supplyRate = market.borrowRate
    .toBigDecimal()
    .times(market.utilizationRate.div(BigDecimal.fromString('100')))
    .times(BigDecimal.fromString('1').minus(reserveFactor))
    .truncate(0)
    .digits
    .let(d => BigInt.fromString(d.toString()))
}

/**
 * Update market snapshots (daily and hourly)
 */
export function updateMarketSnapshots(market: Market, event: ethereum.Event): void {
  updateMarketDailySnapshot(market, event)
  updateMarketHourlySnapshot(market, event)
}

/**
 * Update market daily snapshot
 */
function updateMarketDailySnapshot(market: Market, event: ethereum.Event): void {
  let timestamp = event.block.timestamp.toI32()
  let dayID = timestamp / 86400
  let dayStartTimestamp = dayID * 86400
  
  let snapshotID = market.id + '-' + dayID.toString()
  let snapshot = MarketDailySnapshot.load(snapshotID)
  
  if (snapshot == null) {
    snapshot = new MarketDailySnapshot(snapshotID)
    snapshot.protocol = market.protocol
    snapshot.market = market.id
    snapshot.blockNumber = event.block.number
    snapshot.timestamp = BigInt.fromI32(dayStartTimestamp)
    snapshot.totalValueLockedUSD = market.totalValueLockedUSD
    snapshot.totalSupply = market.totalSupply
    snapshot.totalBorrow = market.totalBorrow
    snapshot.dailySupplyUSD = ZERO_BD
    snapshot.dailyBorrowUSD = ZERO_BD
    snapshot.dailyLiquidateUSD = ZERO_BD
    snapshot.dailyWithdrawUSD = ZERO_BD
    snapshot.dailyRepayUSD = ZERO_BD
    snapshot.dailyProtocolRevenueUSD = ZERO_BD
    snapshot.cumulativeProtocolRevenueUSD = ZERO_BD
    snapshot.rates = []
  }
  
  // Update current state
  snapshot.totalValueLockedUSD = market.totalValueLockedUSD
  snapshot.totalSupply = market.totalSupply
  snapshot.totalBorrow = market.totalBorrow
  
  snapshot.save()
}

/**
 * Update market hourly snapshot
 */
function updateMarketHourlySnapshot(market: Market, event: ethereum.Event): void {
  let timestamp = event.block.timestamp.toI32()
  let hourID = timestamp / 3600
  let hourStartTimestamp = hourID * 3600
  
  let snapshotID = market.id + '-' + hourID.toString()
  let snapshot = MarketHourlySnapshot.load(snapshotID)
  
  if (snapshot == null) {
    snapshot = new MarketHourlySnapshot(snapshotID)
    snapshot.protocol = market.protocol
    snapshot.market = market.id
    snapshot.blockNumber = event.block.number
    snapshot.timestamp = BigInt.fromI32(hourStartTimestamp)
    snapshot.totalValueLockedUSD = market.totalValueLockedUSD
    snapshot.totalSupply = market.totalSupply
    snapshot.totalBorrow = market.totalBorrow
    snapshot.hourlySupplyUSD = ZERO_BD
    snapshot.hourlyBorrowUSD = ZERO_BD
    snapshot.hourlyLiquidateUSD = ZERO_BD
    snapshot.rates = []
  }
  
  // Update current state
  snapshot.totalValueLockedUSD = market.totalValueLockedUSD
  snapshot.totalSupply = market.totalSupply
  snapshot.totalBorrow = market.totalBorrow
  
  snapshot.save()
}
