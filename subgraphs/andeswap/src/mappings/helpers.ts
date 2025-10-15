// Helper constants and functions for AndeSwap subgraph

import { BigDecimal, BigInt, Address } from '@graphprotocol/graph-ts'

// Constants
export const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000'
export const FACTORY_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3' // Update with actual factory address

// BigDecimal constants
export let ZERO_BD = BigDecimal.fromString('0')
export let ONE_BD = BigDecimal.fromString('1')
export let BI_18 = BigInt.fromI32(18)

// BigInt constants
export let ZERO_BI = BigInt.fromI32(0)
export let ONE_BI = BigInt.fromI32(1)

/**
 * Convert token amount to decimal with proper decimal places
 */
export function convertTokenToDecimal(tokenAmount: BigInt, exchangeDecimals: BigInt): BigDecimal {
  if (exchangeDecimals == ZERO_BI) {
    return tokenAmount.toBigDecimal()
  }
  return tokenAmount.toBigDecimal().div(exponentToBigDecimal(exchangeDecimals))
}

/**
 * Calculate exponent for decimal conversion
 */
export function exponentToBigDecimal(decimals: BigInt): BigDecimal {
  let bd = BigDecimal.fromString('1')
  for (let i = ZERO_BI; i.lt(decimals as BigInt); i = i.plus(ONE_BI)) {
    bd = bd.times(BigDecimal.fromString('10'))
  }
  return bd
}

/**
 * Calculate square root using Babylonian method
 */
export function sqrt(y: BigDecimal): BigDecimal {
  if (y.gt(BigDecimal.fromString('3'))) {
    let z = y
    let x = y.div(BigDecimal.fromString('2')).plus(ONE_BD)
    while (x.lt(z)) {
      z = x
      x = y.div(x).plus(x).div(BigDecimal.fromString('2'))
    }
    return z
  } else if (y.notEqual(ZERO_BD)) {
    return ONE_BD
  } else {
    return ZERO_BD
  }
}

/**
 * Check if address is in whitelist (for price tracking)
 */
export function isCompletePair(pair: string, tokenAddresses: string[]): boolean {
  for (let i = 0; i < tokenAddresses.length; i++) {
    if (pair == tokenAddresses[i]) {
      return true
    }
  }
  return false
}
