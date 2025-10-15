// AndeLaunchpad Mappings
// Handles IDO creation, contributions, claims, and refunds

import { BigInt, Address, log, Bytes } from '@graphprotocol/graph-ts'
import {
  LaunchpadProtocol,
  IDO,
  LaunchedToken,
  Participant,
  Contribution,
  Claim,
  Refund,
  IDODailySnapshot
} from '../generated/schema'
import {
  IDOCreated,
  Contribution as ContributionEvent,
  TokensClaimed,
  RefundIssued
} from '../generated/AndeLaunchpad/AndeLaunchpad'
import { TokenCreated as TokenCreatedEvent } from '../generated/AndeTokenFactory/AndeTokenFactory'
import { ZERO_BD, ZERO_BI, ONE_BI, convertTokenToDecimal } from './helpers'
import { getOrCreateToken } from './entities'

const PROTOCOL_ID = '1'

/**
 * Get or create launchpad protocol
 */
function getOrCreateProtocol(): LaunchpadProtocol {
  let protocol = LaunchpadProtocol.load(PROTOCOL_ID)
  if (protocol == null) {
    protocol = new LaunchpadProtocol(PROTOCOL_ID)
    protocol.totalLaunches = 0
    protocol.totalRaisedUSD = ZERO_BD
    protocol.totalParticipants = 0
    protocol.activeIDOs = 0
    protocol.completedIDOs = 0
    protocol.save()
  }
  return protocol
}

/**
 * Handle IDO creation event
 */
export function handleIDOCreated(event: IDOCreated): void {
  let protocol = getOrCreateProtocol()
  
  // Get or create token
  let token = getOrCreateToken(event.params.token, event.params.tokenAddress)
  
  // Create IDO entity
  let ido = new IDO(event.params.idoId.toHex())
  ido.protocol = protocol.id
  ido.token = token.id
  ido.hardcap = convertTokenToDecimal(event.params.hardcap, 18)
  ido.softcap = convertTokenToDecimal(event.params.softcap, 18)
  ido.maxContribution = convertTokenToDecimal(event.params.maxContribution, 18)
  ido.minContribution = convertTokenToDecimal(event.params.minContribution, 18)
  ido.pricePerToken = convertTokenToDecimal(event.params.pricePerToken, 18)
  ido.startTime = event.params.startTime
  ido.endTime = event.params.endTime
  ido.claimTime = null
  ido.status = determineIDOStatus(event.params.startTime, event.params.endTime, event.block.timestamp)
  ido.whitelistEnabled = event.params.whitelistEnabled
  ido.totalRaised = ZERO_BD
  ido.totalRaisedUSD = ZERO_BD
  ido.totalTokensSold = ZERO_BD
  ido.totalParticipants = 0
  ido.vestingEnabled = event.params.vestingEnabled
  ido.vestingDuration = event.params.vestingDuration
  ido.vestingCliff = event.params.vestingCliff
  ido.projectName = event.params.projectName
  ido.projectDescription = event.params.projectDescription
  ido.projectWebsite = event.params.projectWebsite
  ido.projectTwitter = event.params.projectTwitter
  ido.projectTelegram = event.params.projectTelegram
  ido.creator = event.params.creator
  ido.createdTimestamp = event.block.timestamp
  ido.createdBlockNumber = event.block.number
  ido.save()
  
  // Update protocol
  protocol.totalLaunches = protocol.totalLaunches + 1
  if (ido.status == 'ACTIVE') {
    protocol.activeIDOs = protocol.activeIDOs + 1
  }
  protocol.save()
  
  log.info('IDO created: {} for project {}', [ido.id, ido.projectName])
}

/**
 * Handle contribution event
 */
export function handleContribution(event: ContributionEvent): void {
  let ido = IDO.load(event.params.idoId.toHex())
  if (ido == null) {
    log.warning('IDO not found for contribution: {}', [event.params.idoId.toHex()])
    return
  }
  
  let protocol = getOrCreateProtocol()
  
  // Get or create participant
  let participantId = event.params.contributor.toHex() + '-' + ido.id
  let participant = Participant.load(participantId)
  let isNewParticipant = participant == null
  
  if (participant == null) {
    participant = new Participant(participantId)
    participant.address = event.params.contributor
    participant.ido = ido.id
    participant.tier = determineTier(event.params.andeStaked)
    participant.andeStaked = convertTokenToDecimal(event.params.andeStaked, 18)
    participant.allocationMultiplier = calculateMultiplier(participant.tier)
    participant.totalContributed = ZERO_BD
    participant.totalContributedUSD = ZERO_BD
    participant.tokensAllocated = ZERO_BD
    participant.tokensClaimed = ZERO_BD
    participant.isWhitelisted = event.params.isWhitelisted
    participant.whitelistProof = []
    participant.firstContributionTimestamp = event.block.timestamp
    participant.lastClaimTimestamp = null
  }
  
  // Convert contribution amount
  let amount = convertTokenToDecimal(event.params.amount, 18)
  let amountUSD = amount // Assuming 1:1 with USD stablecoin
  let tokensReceived = amount.div(ido.pricePerToken)
  
  // Update participant
  participant.totalContributed = participant.totalContributed.plus(amount)
  participant.totalContributedUSD = participant.totalContributedUSD.plus(amountUSD)
  participant.tokensAllocated = participant.tokensAllocated.plus(tokensReceived)
  participant.save()
  
  // Update IDO
  ido.totalRaised = ido.totalRaised.plus(amount)
  ido.totalRaisedUSD = ido.totalRaisedUSD.plus(amountUSD)
  ido.totalTokensSold = ido.totalTokensSold.plus(tokensReceived)
  if (isNewParticipant) {
    ido.totalParticipants = ido.totalParticipants + 1
  }
  ido.save()
  
  // Update protocol
  protocol.totalRaisedUSD = protocol.totalRaisedUSD.plus(amountUSD)
  if (isNewParticipant) {
    protocol.totalParticipants = protocol.totalParticipants + 1
  }
  protocol.save()
  
  // Create contribution entity
  let contribution = new Contribution(
    event.transaction.hash.toHex() + '-' + event.logIndex.toString()
  )
  contribution.hash = event.transaction.hash
  contribution.logIndex = event.logIndex.toI32()
  contribution.ido = ido.id
  contribution.participant = participant.id
  contribution.amount = amount
  contribution.amountUSD = amountUSD
  contribution.tokensReceived = tokensReceived
  contribution.timestamp = event.block.timestamp
  contribution.blockNumber = event.block.number
  contribution.save()
  
  log.info('Contribution: {} contributed {} to {}', [
    participant.address.toHex(),
    amount.toString(),
    ido.projectName
  ])
}

/**
 * Handle tokens claimed event
 */
export function handleTokensClaimed(event: TokensClaimed): void {
  let ido = IDO.load(event.params.idoId.toHex())
  if (ido == null) {
    log.warning('IDO not found for claim: {}', [event.params.idoId.toHex()])
    return
  }
  
  let participantId = event.params.contributor.toHex() + '-' + ido.id
  let participant = Participant.load(participantId)
  if (participant == null) {
    log.warning('Participant not found for claim: {}', [participantId])
    return
  }
  
  // Convert amount
  let amount = convertTokenToDecimal(event.params.amount, 18)
  let token = LaunchedToken.load(ido.token)!
  let amountUSD = amount.times(ido.pricePerToken)
  
  // Update participant
  participant.tokensClaimed = participant.tokensClaimed.plus(amount)
  participant.lastClaimTimestamp = event.block.timestamp
  participant.save()
  
  // Create claim entity
  let claim = new Claim(
    event.transaction.hash.toHex() + '-' + event.logIndex.toString()
  )
  claim.hash = event.transaction.hash
  claim.logIndex = event.logIndex.toI32()
  claim.ido = ido.id
  claim.participant = participant.id
  claim.amount = amount
  claim.amountUSD = amountUSD
  claim.timestamp = event.block.timestamp
  claim.blockNumber = event.block.number
  claim.save()
  
  log.info('Claim: {} claimed {} tokens', [
    participant.address.toHex(),
    amount.toString()
  ])
}

/**
 * Handle refund event
 */
export function handleRefund(event: RefundIssued): void {
  let ido = IDO.load(event.params.idoId.toHex())
  if (ido == null) {
    log.warning('IDO not found for refund: {}', [event.params.idoId.toHex()])
    return
  }
  
  let participantId = event.params.contributor.toHex() + '-' + ido.id
  let participant = Participant.load(participantId)
  if (participant == null) {
    log.warning('Participant not found for refund: {}', [participantId])
    return
  }
  
  // Convert amount
  let amount = convertTokenToDecimal(event.params.amount, 18)
  let amountUSD = amount
  
  // Create refund entity
  let refund = new Refund(
    event.transaction.hash.toHex() + '-' + event.logIndex.toString()
  )
  refund.hash = event.transaction.hash
  refund.logIndex = event.logIndex.toI32()
  refund.ido = ido.id
  refund.participant = participant.id
  refund.amount = amount
  refund.amountUSD = amountUSD
  refund.reason = event.params.reason
  refund.timestamp = event.block.timestamp
  refund.blockNumber = event.block.number
  refund.save()
  
  log.info('Refund: {} refunded {} due to {}', [
    participant.address.toHex(),
    amount.toString(),
    refund.reason
  ])
}

/**
 * Handle token created event from factory
 */
export function handleTokenCreated(event: TokenCreatedEvent): void {
  let protocol = getOrCreateProtocol()
  
  // Create launched token entity
  let token = new LaunchedToken(event.params.token.toHex())
  token.protocol = protocol.id
  token.name = event.params.name
  token.symbol = event.params.symbol
  token.decimals = 18 // Default
  token.totalSupply = convertTokenToDecimal(event.params.totalSupply, 18)
  token.mintable = event.params.mintable
  token.burnable = event.params.burnable
  token.pausable = event.params.pausable
  token.taxRate = event.params.taxRate
  token.ido = null
  token.creator = event.params.creator
  token.createdTimestamp = event.block.timestamp
  token.createdBlockNumber = event.block.number
  token.save()
  
  log.info('Token created: {} ({})', [token.name, token.symbol])
}

// Helper functions

function determineIDOStatus(startTime: BigInt, endTime: BigInt, currentTime: BigInt): string {
  if (currentTime.lt(startTime)) {
    return 'UPCOMING'
  } else if (currentTime.lt(endTime)) {
    return 'ACTIVE'
  } else {
    return 'ENDED_SUCCESS' // Will be updated based on softcap
  }
}

function determineTier(andeStaked: BigInt): string {
  let staked = convertTokenToDecimal(andeStaked, 18)
  
  if (staked.ge(BigDecimal.fromString('5000'))) {
    return 'PLATINUM'
  } else if (staked.ge(BigDecimal.fromString('1000'))) {
    return 'GOLD'
  } else if (staked.ge(BigDecimal.fromString('500'))) {
    return 'SILVER'
  } else {
    return 'BRONZE'
  }
}

function calculateMultiplier(tier: string): i32 {
  if (tier == 'PLATINUM') return 50
  if (tier == 'GOLD') return 15
  if (tier == 'SILVER') return 5
  return 1
}
