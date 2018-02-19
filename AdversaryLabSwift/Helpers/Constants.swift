//
//  Constants.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 1/23/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation

let packetStatsKey = "Packet:Stats"
let newConnectionsChannel = "New:Connections:Channel"

/// Allowed Connections
let allowedConnectionsKey = "Allowed:Connections"
let allowedIncomingKey = "Allowed:Incoming:Packets"
let allowedOutgoingKey = "Allowed:Outgoing:Packets"

let allowedIncomingDatesKey = "Allowed:Incoming:Dates"
let allowedOutgoingDatesKey = "Allowed:Outgoing:Dates"
let allowedConnectionsTimeDiffKey = "Allowed:Connections:TimeDifference"

let allowedIncomingLengthsKey = "Allowed:Incoming:Lengths"
let allowedOutgoingLengthsKey = "Allowed:Outgoing:Lengths"

let allowedIncomingOffsetSequencesKey = "Allowed:Incoming:OffsetSequence:"
let allowedOutgoingOffsetSequencesKey = "Allowed:Outgoing:OffsetSequence"
let allowedIncomingFloatingSequencesKey = "Allowed:Incoming:FloatingSequence"
let allowedOutgoingFloatingSequencesKey = "Allowed:Outgoing:FloatingSequence"

let allowedIncomingEntropyKey = "Allowed:Incoming:Entropy"
let allowedOutgoingEntropyKey = "Allowed:Outgoing:Entropy"

let allowedPacketsSeenKey = "Allowed:Connections:Seen"
let allowedPacketsAnalyzedKey = "Allowed:Connections:Analyzed"

/// Blocked Connections
let blockedConnectionsKey = "Blocked:Connections"
let blockedIncomingKey = "Blocked:Incoming:Packets"
let blockedOutgoingKey = "Blocked:Outgoing:Packets"

let blockedIncomingDatesKey = "Blocked:Incoming:Dates"
let blockedOutgoingDatesKey = "Blocked:Outgoing:Dates"
let blockedConnectionsTimeDiffKey = "Blocked:Connections:TimeDifference"

let blockedIncomingLengthsKey = "Blocked:Incoming:Lengths"
let blockedOutgoingLengthsKey = "Blocked:Outgoing:Lengths"

let blockedIncomingOffsetSequencesKey = "Blocked:Incoming:OffsetSequence:"
let blockedOutgoingOffsetSequencesKey = "Blocked:Outgoing:OffsetSequence"
let blockedIncomingFloatingSequencesKey = "Blocked:Incoming:FloatingSequence"
let blockedOutgoingFloatingSequencesKey = "Blocked:Outgoing:FloatingSequence"

let blockedIncomingEntropyKey = "Blocked:Incoming:Entropy"
let blockedOutgoingEntropyKey = "Blocked:Outgoing:Entropy"

let blockedPacketsSeenKey = "Blocked:Connections:Seen"
let blockedPacketsAnalyzedKey = "Blocked:Connections:Analyzed"

///
let newConnectionMessage = "NewConnectionAdded"

let analysisQueue = DispatchQueue(label: "AnalysisQueue")

extension Notification.Name
{
    static let updateStats = Notification.Name("UpdatedConnectionStats")
}

enum PacketLengthError: Error
{
    case noOutPacketForConnection(String)
    case noInPacketForConnection(String)
    case unableToIncremementScore(packetSize: Int, connectionID: String)
}

enum PacketTimingError: Error
{
    case noOutPacketDateForConnection(String)
    case noInPacketDateForConnection(String)
    case unableToAddTimeDifference(timeDifference: TimeInterval, connectionID: String)
}
