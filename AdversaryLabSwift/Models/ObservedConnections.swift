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
    let channel: String
    let connectionsKey: String
    let incomingKey: String
    let outgoingKey: String
    let incomingLengthsKey: String
    let outgoingLengthsKey: String
    let packetsSeenKey: String
    let packetsAnalyzedKey: String
    let connectionID: String
    
    init(connectionType: ConnectionType, connectionID: String)
    {
        self.connectionID = connectionID
        
        switch connectionType
        {
            case .allowed:
                channel = allowedChannel
                connectionsKey = allowedConnectionsKey
                incomingKey = allowedIncomingKey
                outgoingKey = allowedOutgoingKey
                incomingLengthsKey = allowedIncomingLengthsKey
                outgoingLengthsKey = allowedOutgoingLengthsKey
                packetsSeenKey = allowedPacketsSeenKey
                packetsAnalyzedKey = allowedPacketsAnalyzedKey
            case .blocked:
                channel = blockedChannel
                connectionsKey = blockedConnectionsKey
                incomingKey = blockedIncomingKey
                outgoingKey = blockedOutgoingKey
                incomingLengthsKey = blockedIncomingLengthsKey
                outgoingLengthsKey = blockedOutgoingLengthsKey
                packetsSeenKey = blockedPacketsSeenKey
                packetsAnalyzedKey = blockedPacketsAnalyzedKey
        }
    }
}

enum ConnectionType
{
    case allowed
    case blocked
}
