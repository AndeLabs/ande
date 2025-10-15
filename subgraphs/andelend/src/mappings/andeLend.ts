// AndeLend Protocol Mappings
// Handles deposit, withdraw, borrow, repay, and liquidation events

import { BigInt, Address, log } from '@graphprotocol/graph-ts'
import {
  Protocol,
  Market,
  Account,
  Position,
  Deposit,
  Withdraw,
  Borrow,
  Repay,
  Liquidation,
  Token,
  MarketDailySnapshot,
  ProtocolDailySnapshot
} from '../../generated/schema'
import {
  MarketCreated,
  Deposit as DepositEvent,
  Withdraw as WithdrawEvent,
  Borrow as BorrowEvent,
  Repay as RepayEvent,
  Liquidation as LiquidationEvent
} from '../../generated/AndeLend/AndeLend'
import { ZERO_BD, ZERO_BI, ONE_BI, convertTokenToDecimal } from './helpers'
import { getOrCreateToken, getOrCreateAccount, getOrCreatePosition } from './entities'
import { updateMarketRates, updateMarketSnapshots } from './utils'

const PROTOCOL_ID = '1'

/**
 * Initialize protocol entity
 */
function getOrCreateProtocol(): Protocol {
  let protocol = Protocol.load(PROTOCOL_ID)
  if (protocol == null) {
    protocol = new Protocol(PROTOCOL_ID)
    protocol.totalValueLockedUSD = ZERO_BD
    protocol.totalBorrowedUSD = ZERO_BD
    protocol.totalReservesUSD = ZERO_BD
    protocol.totalSupply = ZERO_BD
    protocol.totalBorrow = ZERO_BD
    protocol.marketCount = 0
    protocol.userCount = 0
    protocol.transactionCount = ZERO_BI
    protocol.save()
  }
  return protocol
}

/**
 * Handle market creation event
 */
export function handleMarketCreated(event: MarketCreated): void {
  let protocol = getOrCreateProtocol()
  
  // Create input token entity
  let inputToken = getOrCreateToken(event.params.token)
  
  // Create output token (aToken) entity
  let outputToken = getOrCreateToken(event.params.aToken)
  
  // Create market entity
  let market = new Market(event.params.token.toHex())
  market.protocol = protocol.id
  market.inputToken = inputToken.id
  market.outputToken = outputToken.id
  market.totalValueLockedUSD = ZERO_BD
  market.totalSupply = ZERO_BD
  market.totalBorrow = ZERO_BD
  market.totalReserves = ZERO_BD
  market.supplyRate = ZERO_BI
  market.borrowRate = ZERO_BI
  market.utilizationRate = ZERO_BD
  market.collateralFactor = event.params.collateralFactor
  market.liquidationThreshold = BigInt.fromI32(8000) // 80%
  market.liquidationPenalty = BigInt.fromI32(500) // 5%
  market.reserveFactor = BigInt.fromI32(1000) // 10%
  market.isActive = true
  market.createdTimestamp = event.block.timestamp
  market.createdBlockNumber = event.block.number
  market.save()
  
  // Update protocol
  protocol.marketCount = protocol.marketCount + 1
  protocol.save()
  
  log.info('Market created: {} with collateral factor {}', [
    inputToken.symbol,
    event.params.collateralFactor.toString()
  ])
}

/**
 * Handle deposit event
 */
export function handleDeposit(event: DepositEvent): void {
  let protocol = getOrCreateProtocol()
  let market = Market.load(event.params.token.toHex())
  if (market == null) {
    log.warning('Market not found for deposit: {}', [event.params.token.toHex()])
    return
  }
  
  let account = getOrCreateAccount(event.params.user)
  let position = getOrCreatePosition(account, market)
  let token = Token.load(market.inputToken)!
  
  // Convert amount to decimal
  let amount = convertTokenToDecimal(event.params.amount, token.decimals)
  let amountUSD = amount.times(token.lastPriceUSD || ZERO_BD)
  
  // Update position
  position.principal = position.principal.plus(amount)
  if (event.params.useAsCollateral) {
    position.isCollateral = true
  }
  position.save()
  
  // Update market
  market.totalSupply = market.totalSupply.plus(amount)
  market.totalValueLockedUSD = market.totalValueLockedUSD.plus(amountUSD)
  updateMarketRates(market)
  market.save()
  
  // Update account
  account.totalCollateralUSD = account.totalCollateralUSD.plus(amountUSD)
  account.depositCount = account.depositCount + 1
  account.save()
  
  // Update protocol
  protocol.totalValueLockedUSD = protocol.totalValueLockedUSD.plus(amountUSD)
  protocol.totalSupply = protocol.totalSupply.plus(amount)
  protocol.transactionCount = protocol.transactionCount.plus(ONE_BI)
  protocol.save()
  
  // Create deposit entity
  let deposit = new Deposit(
    event.transaction.hash.toHex() + '-' + event.logIndex.toString()
  )
  deposit.hash = event.transaction.hash
  deposit.logIndex = event.logIndex.toI32()
  deposit.protocol = protocol.id
  deposit.to = account.id
  deposit.from = account.id
  deposit.blockNumber = event.block.number
  deposit.timestamp = event.block.timestamp
  deposit.market = market.id
  deposit.asset = token.id
  deposit.amount = amount
  deposit.amountUSD = amountUSD
  deposit.account = account.id
  deposit.save()
  
  // Update snapshots
  updateMarketSnapshots(market, event)
  
  log.info('Deposit: {} {} by {}', [
    amount.toString(),
    token.symbol,
    account.id
  ])
}

/**
 * Handle withdraw event
 */
export function handleWithdraw(event: WithdrawEvent): void {
  let protocol = getOrCreateProtocol()
  let market = Market.load(event.params.token.toHex())
  if (market == null) {
    log.warning('Market not found for withdraw: {}', [event.params.token.toHex()])
    return
  }
  
  let account = getOrCreateAccount(event.params.user)
  let position = getOrCreatePosition(account, market)
  let token = Token.load(market.inputToken)!
  
  // Convert amount to decimal
  let amount = convertTokenToDecimal(event.params.amount, token.decimals)
  let amountUSD = amount.times(token.lastPriceUSD || ZERO_BD)
  
  // Update position
  position.principal = position.principal.minus(amount)
  position.save()
  
  // Update market
  market.totalSupply = market.totalSupply.minus(amount)
  market.totalValueLockedUSD = market.totalValueLockedUSD.minus(amountUSD)
  updateMarketRates(market)
  market.save()
  
  // Update account
  account.totalCollateralUSD = account.totalCollateralUSD.minus(amountUSD)
  account.withdrawCount = account.withdrawCount + 1
  account.save()
  
  // Update protocol
  protocol.totalValueLockedUSD = protocol.totalValueLockedUSD.minus(amountUSD)
  protocol.totalSupply = protocol.totalSupply.minus(amount)
  protocol.transactionCount = protocol.transactionCount.plus(ONE_BI)
  protocol.save()
  
  // Create withdraw entity
  let withdraw = new Withdraw(
    event.transaction.hash.toHex() + '-' + event.logIndex.toString()
  )
  withdraw.hash = event.transaction.hash
  withdraw.logIndex = event.logIndex.toI32()
  withdraw.protocol = protocol.id
  withdraw.to = account.id
  withdraw.from = account.id
  withdraw.blockNumber = event.block.number
  withdraw.timestamp = event.block.timestamp
  withdraw.market = market.id
  withdraw.asset = token.id
  withdraw.amount = amount
  withdraw.amountUSD = amountUSD
  withdraw.account = account.id
  withdraw.save()
  
  // Update snapshots
  updateMarketSnapshots(market, event)
  
  log.info('Withdraw: {} {} by {}', [
    amount.toString(),
    token.symbol,
    account.id
  ])
}

/**
 * Handle borrow event
 */
export function handleBorrow(event: BorrowEvent): void {
  let protocol = getOrCreateProtocol()
  let market = Market.load(event.params.token.toHex())
  if (market == null) {
    log.warning('Market not found for borrow: {}', [event.params.token.toHex()])
    return
  }
  
  let account = getOrCreateAccount(event.params.user)
  let position = getOrCreatePosition(account, market)
  let token = Token.load(market.inputToken)!
  
  // Convert amount to decimal
  let amount = convertTokenToDecimal(event.params.amount, token.decimals)
  let amountUSD = amount.times(token.lastPriceUSD || ZERO_BD)
  
  // Update position
  position.borrowBalance = position.borrowBalance.plus(amount)
  position.save()
  
  // Update market
  market.totalBorrow = market.totalBorrow.plus(amount)
  updateMarketRates(market)
  market.save()
  
  // Update account
  account.totalBorrowedUSD = account.totalBorrowedUSD.plus(amountUSD)
  account.borrowCount = account.borrowCount + 1
  account.save()
  
  // Update protocol
  protocol.totalBorrowedUSD = protocol.totalBorrowedUSD.plus(amountUSD)
  protocol.totalBorrow = protocol.totalBorrow.plus(amount)
  protocol.transactionCount = protocol.transactionCount.plus(ONE_BI)
  protocol.save()
  
  // Create borrow entity
  let borrow = new Borrow(
    event.transaction.hash.toHex() + '-' + event.logIndex.toString()
  )
  borrow.hash = event.transaction.hash
  borrow.logIndex = event.logIndex.toI32()
  borrow.protocol = protocol.id
  borrow.to = account.id
  borrow.from = account.id
  borrow.blockNumber = event.block.number
  borrow.timestamp = event.block.timestamp
  borrow.market = market.id
  borrow.asset = token.id
  borrow.amount = amount
  borrow.amountUSD = amountUSD
  borrow.account = account.id
  borrow.save()
  
  // Update snapshots
  updateMarketSnapshots(market, event)
  
  log.info('Borrow: {} {} by {}', [
    amount.toString(),
    token.symbol,
    account.id
  ])
}

/**
 * Handle repay event
 */
export function handleRepay(event: RepayEvent): void {
  let protocol = getOrCreateProtocol()
  let market = Market.load(event.params.token.toHex())
  if (market == null) {
    log.warning('Market not found for repay: {}', [event.params.token.toHex()])
    return
  }
  
  let account = getOrCreateAccount(event.params.user)
  let position = getOrCreatePosition(account, market)
  let token = Token.load(market.inputToken)!
  
  // Convert amount to decimal
  let amount = convertTokenToDecimal(event.params.amount, token.decimals)
  let amountUSD = amount.times(token.lastPriceUSD || ZERO_BD)
  
  // Update position
  position.borrowBalance = position.borrowBalance.minus(amount)
  position.save()
  
  // Update market
  market.totalBorrow = market.totalBorrow.minus(amount)
  updateMarketRates(market)
  market.save()
  
  // Update account
  account.totalBorrowedUSD = account.totalBorrowedUSD.minus(amountUSD)
  account.repayCount = account.repayCount + 1
  account.save()
  
  // Update protocol
  protocol.totalBorrowedUSD = protocol.totalBorrowedUSD.minus(amountUSD)
  protocol.totalBorrow = protocol.totalBorrow.minus(amount)
  protocol.transactionCount = protocol.transactionCount.plus(ONE_BI)
  protocol.save()
  
  // Create repay entity
  let repay = new Repay(
    event.transaction.hash.toHex() + '-' + event.logIndex.toString()
  )
  repay.hash = event.transaction.hash
  repay.logIndex = event.logIndex.toI32()
  repay.protocol = protocol.id
  repay.to = account.id
  repay.from = account.id
  repay.blockNumber = event.block.number
  repay.timestamp = event.block.timestamp
  repay.market = market.id
  repay.asset = token.id
  repay.amount = amount
  repay.amountUSD = amountUSD
  repay.account = account.id
  repay.save()
  
  // Update snapshots
  updateMarketSnapshots(market, event)
  
  log.info('Repay: {} {} by {}', [
    amount.toString(),
    token.symbol,
    account.id
  ])
}

/**
 * Handle liquidation event
 */
export function handleLiquidation(event: LiquidationEvent): void {
  let protocol = getOrCreateProtocol()
  let debtMarket = Market.load(event.params.debtToken.toHex())
  let collateralMarket = Market.load(event.params.collateralToken.toHex())
  
  if (debtMarket == null || collateralMarket == null) {
    log.warning('Market not found for liquidation', [])
    return
  }
  
  let borrower = getOrCreateAccount(event.params.borrower)
  let liquidator = getOrCreateAccount(event.params.liquidator)
  
  let debtToken = Token.load(debtMarket.inputToken)!
  let collateralToken = Token.load(collateralMarket.inputToken)!
  
  // Convert amounts
  let debtAmount = convertTokenToDecimal(event.params.debtAmount, debtToken.decimals)
  let collateralAmount = convertTokenToDecimal(
    event.params.collateralAmount,
    collateralToken.decimals
  )
  
  let debtUSD = debtAmount.times(debtToken.lastPriceUSD || ZERO_BD)
  let collateralUSD = collateralAmount.times(collateralToken.lastPriceUSD || ZERO_BD)
  let profitUSD = collateralUSD.minus(debtUSD)
  
  // Update borrower account
  borrower.liquidationCount = borrower.liquidationCount + 1
  borrower.save()
  
  // Update protocol
  protocol.transactionCount = protocol.transactionCount.plus(ONE_BI)
  protocol.save()
  
  // Create liquidation entity
  let liquidation = new Liquidation(
    event.transaction.hash.toHex() + '-' + event.logIndex.toString()
  )
  liquidation.hash = event.transaction.hash
  liquidation.logIndex = event.logIndex.toI32()
  liquidation.protocol = protocol.id
  liquidation.to = liquidator.id
  liquidation.from = borrower.id
  liquidation.blockNumber = event.block.number
  liquidation.timestamp = event.block.timestamp
  liquidation.market = debtMarket.id
  liquidation.asset = debtToken.id
  liquidation.amount = debtAmount
  liquidation.amountUSD = debtUSD
  liquidation.profitUSD = profitUSD
  liquidation.account = borrower.id
  liquidation.save()
  
  log.info('Liquidation: {} liquidated {} for profit {}', [
    borrower.id,
    debtUSD.toString(),
    profitUSD.toString()
  ])
}
