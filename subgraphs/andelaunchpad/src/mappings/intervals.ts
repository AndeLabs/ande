import { BigInt, ethereum } from '@graphprotocol/graph-ts'
import {
  IDO,
  IDODailySnapshot,
  LaunchpadDailySnapshot,
  LaunchpadProtocol
} from '../../generated/schema'
import { ZERO_BD, ZERO_BI, calculatePercentage } from './helpers'

export function updateIDODailySnapshot(event: ethereum.Event, ido: IDO): IDODailySnapshot {
  let timestamp = event.block.timestamp.toI32()
  let dayID = timestamp / 86400
  let dayStartTimestamp = dayID * 86400
  let snapshotID = ido.id.concat('-').concat(BigInt.fromI32(dayID).toString())

  let snapshot = IDODailySnapshot.load(snapshotID)
  
  if (snapshot === null) {
    snapshot = new IDODailySnapshot(snapshotID)
    snapshot.ido = ido.id
    snapshot.timestamp = BigInt.fromI32(dayStartTimestamp)
    snapshot.blockNumber = event.block.number
    snapshot.dailyContributions = ZERO_BD
    snapshot.dailyContributionsUSD = ZERO_BD
    snapshot.dailyParticipants = 0
  }

  snapshot.totalRaised = ido.totalRaised
  snapshot.totalRaisedUSD = ido.totalRaisedUSD
  snapshot.totalParticipants = ido.totalParticipants
  snapshot.percentageRaised = calculatePercentage(ido.totalRaised, ido.hardcap)
  snapshot.save()

  return snapshot as IDODailySnapshot
}

export function updateLaunchpadDailySnapshot(
  event: ethereum.Event, 
  protocol: LaunchpadProtocol
): LaunchpadDailySnapshot {
  let timestamp = event.block.timestamp.toI32()
  let dayID = timestamp / 86400
  let dayStartTimestamp = dayID * 86400
  let snapshotID = BigInt.fromI32(dayID).toString()

  let snapshot = LaunchpadDailySnapshot.load(snapshotID)
  
  if (snapshot === null) {
    snapshot = new LaunchpadDailySnapshot(snapshotID)
    snapshot.protocol = protocol.id
    snapshot.timestamp = BigInt.fromI32(dayStartTimestamp)
    snapshot.blockNumber = event.block.number
    snapshot.dailyLaunches = 0
    snapshot.dailyRaisedUSD = ZERO_BD
    snapshot.dailyParticipants = 0
  }

  snapshot.totalLaunches = protocol.totalLaunches
  snapshot.totalRaisedUSD = protocol.totalRaisedUSD
  snapshot.totalParticipants = protocol.totalParticipants
  snapshot.save()

  return snapshot as LaunchpadDailySnapshot
}
