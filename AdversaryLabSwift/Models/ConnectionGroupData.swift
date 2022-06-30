//
//  ConnectionData.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 11/6/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation

struct ConnectionGroupData
{
    var aConnectionData = ConnectionData()
    var bConnectionData = ConnectionData()
}

struct ConnectionViewGroupData
{
    var aConnectionData = ConnectionViewData()
    var bConnectionData = ConnectionViewData()
    
    func copyLabConnectionData(connectionGroupData: ConnectionGroupData)
    {
        aConnectionData.copyLabConnectionData(connectionData: connectionGroupData.aConnectionData)
        bConnectionData.copyLabConnectionData(connectionData: connectionGroupData.bConnectionData)
    }
}

struct ConnectionData: Codable
{
    var incomingPackets: [String: Data] = [:]
    var incomingDates: [String: Double] = [:]
    var outgoingPackets: [String: Data] = [:]
    var outgoingDates: [String: Double] = [:]
    var connections: [String] = []
    var totalPayloadBytes: Int = 0
    var packetsAnalyzed = 0
}

class ConnectionViewData: Codable
{
    var incomingPacketsCount = 0
    var outgoingPacketsCount = 0
    var connectionsCount = 0
    var totalPayloadBytes = 0
    var packetsAnalyzed = 0
    
    func copyLabConnectionData(connectionData: ConnectionData)
    {
        incomingPacketsCount = connectionData.incomingPackets.count
        outgoingPacketsCount = connectionData.outgoingPackets.count
        connectionsCount = connectionData.connections.count
        totalPayloadBytes = connectionData.totalPayloadBytes
        packetsAnalyzed = connectionData.packetsAnalyzed
    }
}
