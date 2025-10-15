import { BigDecimal, Address } from '@graphprotocol/graph-ts'
import { Pair, Token, Bundle } from '../../generated/schema'
import { ZERO_BD, ONE_BD, convertTokenToDecimal } from './helpers'

const WANDE_ADDRESS = '0x1234567890123456789012345678901234567890'
const USDC_ADDRESS = '0x2345678901234567890123456789012345678901'
const USDT_ADDRESS = '0x3456789012345678901234567890123456789012'
const DAI_ADDRESS = '0x4567890123456789012345678901234567890123'

const MINIMUM_USD_THRESHOLD_NEW_PAIRS = BigDecimal.fromString('3000')
const MINIMUM_LIQUIDITY_THRESHOLD_ANDE = BigDecimal.fromString('5')

const WHITELIST: string[] = [
  WANDE_ADDRESS,
  USDC_ADDRESS,
  USDT_ADDRESS,
  DAI_ADDRESS,
]

export function getAndePrice(): BigDecimal {
  let bundle = Bundle.load('1')
  
  if (bundle === null) {
    bundle = new Bundle('1')
    bundle.andePrice = ZERO_BD
    bundle.save()
  }
  
  return bundle.andePrice
}

export function setAndePrice(price: BigDecimal): void {
  let bundle = Bundle.load('1')
  
  if (bundle === null) {
    bundle = new Bundle('1')
  }
  
  bundle.andePrice = price
  bundle.save()
}

export function findAndePerToken(token: Token): BigDecimal {
  if (token.id == WANDE_ADDRESS) {
    return ONE_BD
  }

  let whiteList = token.id == WANDE_ADDRESS ? WHITELIST : [WANDE_ADDRESS]
  
  for (let i = 0; i < whiteList.length; ++i) {
    let pairAddress = generatePairAddress(token.id, whiteList[i])
    let pair = Pair.load(pairAddress)
    
    if (pair !== null) {
      if (pair.token0 == token.id && pair.reserveANDE.gt(MINIMUM_LIQUIDITY_THRESHOLD_ANDE)) {
        let token1 = Token.load(pair.token1)
        if (token1 !== null && token1.derivedANDE !== null) {
          return pair.token1Price.times(token1.derivedANDE as BigDecimal)
        }
      }
      if (pair.token1 == token.id && pair.reserveANDE.gt(MINIMUM_LIQUIDITY_THRESHOLD_ANDE)) {
        let token0 = Token.load(pair.token0)
        if (token0 !== null && token0.derivedANDE !== null) {
          return pair.token0Price.times(token0.derivedANDE as BigDecimal)
        }
      }
    }
  }
  
  return ZERO_BD
}

export function getTrackedVolumeUSD(
  tokenAmount0: BigDecimal,
  token0: Token,
  tokenAmount1: BigDecimal,
  token1: Token,
  pair: Pair
): BigDecimal {
  let bundle = Bundle.load('1')!
  let price0 = token0.derivedANDE !== null ? (token0.derivedANDE as BigDecimal).times(bundle.andePrice) : ZERO_BD
  let price1 = token1.derivedANDE !== null ? (token1.derivedANDE as BigDecimal).times(bundle.andePrice) : ZERO_BD

  if (pair.reserveUSD.lt(MINIMUM_USD_THRESHOLD_NEW_PAIRS)) {
    return ZERO_BD
  }

  if (isInWhitelist(token0.id) && isInWhitelist(token1.id)) {
    return tokenAmount0.times(price0).plus(tokenAmount1.times(price1)).div(BigDecimal.fromString('2'))
  }

  if (isInWhitelist(token0.id) && !isInWhitelist(token1.id)) {
    return tokenAmount0.times(price0)
  }

  if (!isInWhitelist(token0.id) && isInWhitelist(token1.id)) {
    return tokenAmount1.times(price1)
  }

  return ZERO_BD
}

export function getTrackedLiquidityUSD(
  tokenAmount0: BigDecimal,
  token0: Token,
  tokenAmount1: BigDecimal,
  token1: Token
): BigDecimal {
  let bundle = Bundle.load('1')!
  let price0 = token0.derivedANDE !== null ? (token0.derivedANDE as BigDecimal).times(bundle.andePrice) : ZERO_BD
  let price1 = token1.derivedANDE !== null ? (token1.derivedANDE as BigDecimal).times(bundle.andePrice) : ZERO_BD

  if (isInWhitelist(token0.id) && isInWhitelist(token1.id)) {
    return tokenAmount0.times(price0).plus(tokenAmount1.times(price1))
  }

  if (isInWhitelist(token0.id) && !isInWhitelist(token1.id)) {
    return tokenAmount0.times(price0).times(BigDecimal.fromString('2'))
  }

  if (!isInWhitelist(token0.id) && isInWhitelist(token1.id)) {
    return tokenAmount1.times(price1).times(BigDecimal.fromString('2'))
  }

  return ZERO_BD
}

function isInWhitelist(tokenAddress: string): boolean {
  for (let i = 0; i < WHITELIST.length; i++) {
    if (WHITELIST[i] == tokenAddress) {
      return true
    }
  }
  return false
}

function generatePairAddress(token0: string, token1: string): string {
  return token0 < token1 
    ? token0.concat('-').concat(token1)
    : token1.concat('-').concat(token0)
}
