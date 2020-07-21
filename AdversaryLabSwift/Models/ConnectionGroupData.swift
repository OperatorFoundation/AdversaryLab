//
//  ConnectionData.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 11/6/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn

class ConnectionGroupData
{
    var packetStats: [String: Int]
    var aConnectionData: ConnectionData
    var bConnectionData: ConnectionData
    
    init(packetStats: [String: Int],
         aConnectionData: ConnectionData,
         bConnectionData: ConnectionData)
    {
        self.packetStats = packetStats
        self.aConnectionData = aConnectionData
        self.bConnectionData = bConnectionData
    }
    
    // TODO: Only needed until Redis is removed
    init()
    {
        let processor = DataProcessing()
        let allowedConnectionsList = RList<String>(key: allowedConnectionsKey)
        let blockedConnectionsList = RList<String>(key: blockedConnectionsKey)

        self.packetStats = processor.intDictionary(from: packetStatsKey)
        self.aConnectionData = ConnectionData(incomingPackets: processor.dataDictionary(from: allowedIncomingKey),
                                              incomingDates: processor.doubleDictionary(from: allowedIncomingDatesKey),
                                              outgoingPackets: processor.dataDictionary(from: allowedOutgoingKey),
                                              outgoingDates: processor.doubleDictionary(from: allowedOutgoingDatesKey),
                                              connections: allowedConnectionsList.array)
        self.bConnectionData = ConnectionData(incomingPackets: processor.dataDictionary(from: blockedIncomingKey),
                                              incomingDates: processor.doubleDictionary(from: blockedIncomingDatesKey),
                                              outgoingPackets: processor.dataDictionary(from: blockedOutgoingKey),
                                              outgoingDates: processor.doubleDictionary(from: blockedOutgoingDatesKey),
                                              connections: blockedConnectionsList.array)
    }
    
}

struct ConnectionData
{
    var incomingPackets: [String: Data]
    var incomingDates: [String: Double]
    var outgoingPackets: [String: Data]
    var outgoingDates: [String: Double]
    var connections: [String]
}
