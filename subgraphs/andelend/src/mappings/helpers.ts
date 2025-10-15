// Helper functions for AndeLend subgraph

import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'

// Constants
export const ZERO_BD = BigDecimal.fromString('0')
export const ONE_BD = BigDecimal.fromString('1')
export const ZERO_BI = BigInt.fromI32(0)
export const ONE_BI = BigInt.fromI32(1)

export const SECONDS_PER_YEAR = BigInt.fromI32(31536000)
export const PRECISION = BigInt.fromI32(10000)

/**
 * Convert token amount to decimal with proper decimals
 */
export function convertTokenToDecimal(
  tokenAmount: BigInt,
  decimals: i32
): BigDecimal {
  if (decimals == 0) {
    return tokenAmount.toBigDecimal()
  }
  return tokenAmount.toBigDecimal().div(exponentToBigDecimal(decimals))
}

/**
 * Calculate exponent for decimal conversion
 */
export function exponentToBigDecimal(decimals: i32): BigDecimal {
  let bd = BigDecimal.fromString('1')
  for (let i = 0; i < decimals; i++) {
    bd = bd.times(BigDecimal.fromString('10'))
  }
  return bd
}

/**
 * Calculate APR from rate (basis points to percentage)
 */
export function calculateAPR(rate: BigInt): BigDecimal {
  return rate.toBigDecimal().div(BigDecimal.fromString('100'))
}

/**
 * Calculate utilization rate
 */
export function calculateUtilizationRate(
  totalBorrow: BigDecimal,
  totalSupply: BigDecimal
): BigDecimal {
  if (totalSupply.equals(ZERO_BD)) {
    return ZERO_BD
  }
  return totalBorrow.div(totalSupply).times(BigDecimal.fromString('100'))
}
