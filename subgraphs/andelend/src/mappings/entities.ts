// Entity creation helpers for AndeLend

import { Address, BigInt } from '@graphprotocol/graph-ts'
import { Token, Account, Position, Market } from '../../generated/schema'
import { ERC20 } from '../../generated/AndeLend/ERC20'
import { ZERO_BD, ZERO_BI } from './helpers'

/**
 * Get or create token entity
 */
export function getOrCreateToken(address: Address): Token {
  let token = Token.load(address.toHex())
  
  if (token == null) {
    token = new Token(address.toHex())
    
    let tokenContract = ERC20.bind(address)
    
    // Try to get token info
    let nameResult = tokenContract.try_name()
    token.name = nameResult.reverted ? 'Unknown' : nameResult.value
    
    let symbolResult = tokenContract.try_symbol()
    token.symbol = symbolResult.reverted ? 'UNKNOWN' : symbolResult.value
    
    let decimalsResult = tokenContract.try_decimals()
    token.decimals = decimalsResult.reverted ? 18 : decimalsResult.value
    
    token.lastPriceUSD = ZERO_BD
    token.lastPriceBlockNumber = ZERO_BI
    
    token.save()
  }
  
  return token
}

/**
 * Get or create account entity
 */
export function getOrCreateAccount(address: Address): Account {
  let account = Account.load(address.toHex())
  
  if (account == null) {
    account = new Account(address.toHex())
    account.totalCollateralUSD = ZERO_BD
    account.totalBorrowedUSD = ZERO_BD
    account.healthFactor = null
    account.positionCount = 0
    account.depositCount = 0
    account.withdrawCount = 0
    account.borrowCount = 0
    account.repayCount = 0
    account.liquidationCount = 0
    account.save()
  }
  
  return account
}

/**
 * Get or create position entity
 */
export function getOrCreatePosition(account: Account, market: Market): Position {
  let id = account.id + '-' + market.id
  let position = Position.load(id)
  
  if (position == null) {
    position = new Position(id)
    position.account = account.id
    position.market = market.id
    position.principal = ZERO_BD
    position.borrowBalance = ZERO_BD
    position.borrowIndex = ZERO_BI
    position.isCollateral = false
    position.openedTimestamp = ZERO_BI
    position.closedTimestamp = null
    
    account.positionCount = account.positionCount + 1
    account.save()
    
    position.save()
  }
  
  return position
}
