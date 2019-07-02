//
//  ObservedConnections.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/1/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation

struct ObservedConnection
{
    let connectionsKey: String
    let incomingKey: String
    let outgoingKey: String
    let incomingDateKey: String
    let outgoingDateKey: String
    let incomingLengthsKey: String
    let outgoingLengthsKey: String
    let packetsSeenKey: String
    let packetsAnalyzedKey: String
    let timeDifferenceKey: String
    let incomingOffsetSequencesKey: String
    let outgoingOffsetSequencesKey: String
    let incomingFloatingSequencesKey: String
    let outgoingFloatingSequencesKey: String
    let incomingEntropyKey: String
    let outgoingEntropyKey: String
    let outgoingTlsCommonNameKey: String
    let connectionType: ClassificationLabel
    let connectionID: String
    
    init(connectionType: ClassificationLabel, connectionID: String)
    {
        self.connectionID = connectionID
        self.connectionType = connectionType
        switch connectionType
        {
            case .allowed:
                connectionsKey = allowedConnectionsKey
                incomingKey = allowedIncomingKey
                outgoingKey = allowedOutgoingKey
                incomingDateKey = allowedIncomingDatesKey
                outgoingDateKey = allowedOutgoingDatesKey
                incomingLengthsKey = allowedIncomingLengthKey
                outgoingLengthsKey = allowedOutgoingLengthKey
                packetsSeenKey = allowedPacketsSeenKey
                packetsAnalyzedKey = allowedPacketsAnalyzedKey
                timeDifferenceKey = allowedConnectionsTimeDiffKey
                incomingOffsetSequencesKey = allowedIncomingOffsetSequencesKey
                outgoingOffsetSequencesKey = allowedOutgoingOffsetSequencesKey
                incomingFloatingSequencesKey = allowedIncomingFloatingSequencesKey
                outgoingFloatingSequencesKey = allowedOutgoingFloatingSequencesKey
                incomingEntropyKey = allowedIncomingEntropyKey
                outgoingEntropyKey = allowedOutgoingEntropyKey
                outgoingTlsCommonNameKey = allowedTlsCommonNameKey
            case .blocked:
                connectionsKey = blockedConnectionsKey
                incomingKey = blockedIncomingKey
                outgoingKey = blockedOutgoingKey
                incomingDateKey = blockedIncomingDatesKey
                outgoingDateKey = blockedOutgoingDatesKey
                incomingLengthsKey = blockedIncomingLengthKey
                outgoingLengthsKey = blockedOutgoingLengthKey
                packetsSeenKey = blockedPacketsSeenKey
                packetsAnalyzedKey = blockedPacketsAnalyzedKey
                timeDifferenceKey = blockedConnectionsTimeDiffKey
                incomingOffsetSequencesKey = blockedIncomingOffsetSequencesKey
                outgoingOffsetSequencesKey = blockedOutgoingOffsetSequencesKey
                incomingFloatingSequencesKey = blockedIncomingFloatingSequencesKey
                outgoingFloatingSequencesKey = blockedOutgoingFloatingSequencesKey
                incomingEntropyKey = blockedIncomingEntropyKey
                outgoingEntropyKey = blockedOutgoingEntropyKey
                outgoingTlsCommonNameKey = blockedTlsCommonNameKey
        }
    }
}

//enum ConnectionType: String
//{
//    case allowed = ClassificationLabel.allowed.rawValue
//    case blocked
//}

enum ConnectionDirection
{
    case incoming
    case outgoing
}
