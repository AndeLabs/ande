import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'

export const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000'

export let ZERO_BD = BigDecimal.fromString('0')
export let ONE_BD = BigDecimal.fromString('1')
export let BI_18 = BigInt.fromI32(18)

export let ZERO_BI = BigInt.fromI32(0)
export let ONE_BI = BigInt.fromI32(1)

export function convertTokenToDecimal(tokenAmount: BigInt, exchangeDecimals: BigInt): BigDecimal {
  if (exchangeDecimals == ZERO_BI) {
    return tokenAmount.toBigDecimal()
  }
  return tokenAmount.toBigDecimal().div(exponentToBigDecimal(exchangeDecimals))
}

export function exponentToBigDecimal(decimals: BigInt): BigDecimal {
  let bd = BigDecimal.fromString('1')
  for (let i = ZERO_BI; i.lt(decimals as BigInt); i = i.plus(ONE_BI)) {
    bd = bd.times(BigDecimal.fromString('10'))
  }
  return bd
}

export function calculatePercentage(part: BigDecimal, total: BigDecimal): BigDecimal {
  if (total.equals(ZERO_BD)) {
    return ZERO_BD
  }
  return part.div(total).times(BigDecimal.fromString('100'))
}

export function getTierFromStake(andeStaked: BigDecimal): string {
  const PLATINUM_THRESHOLD = BigDecimal.fromString('10000')
  const GOLD_THRESHOLD = BigDecimal.fromString('5000')
  const SILVER_THRESHOLD = BigDecimal.fromString('1000')
  
  if (andeStaked.ge(PLATINUM_THRESHOLD)) {
    return 'PLATINUM'
  } else if (andeStaked.ge(GOLD_THRESHOLD)) {
    return 'GOLD'
  } else if (andeStaked.ge(SILVER_THRESHOLD)) {
    return 'SILVER'
  } else {
    return 'BRONZE'
  }
}

export function getTierMultiplier(tier: string): i32 {
  if (tier == 'PLATINUM') {
    return 4
  } else if (tier == 'GOLD') {
    return 3
  } else if (tier == 'SILVER') {
    return 2
  } else {
    return 1
  }
}

export function getIDOStatus(statusCode: i32): string {
  if (statusCode == 0) {
    return 'UPCOMING'
  } else if (statusCode == 1) {
    return 'ACTIVE'
  } else if (statusCode == 2) {
    return 'ENDED_SUCCESS'
  } else if (statusCode == 3) {
    return 'ENDED_FAILED'
  } else if (statusCode == 4) {
    return 'CANCELLED'
  }
  return 'UPCOMING'
}

export function getRefundReason(reasonCode: i32): string {
  if (reasonCode == 0) {
    return 'SOFTCAP_NOT_REACHED'
  } else if (reasonCode == 1) {
    return 'IDO_CANCELLED'
  } else if (reasonCode == 2) {
    return 'EXCESS_CONTRIBUTION'
  }
  return 'SOFTCAP_NOT_REACHED'
}
