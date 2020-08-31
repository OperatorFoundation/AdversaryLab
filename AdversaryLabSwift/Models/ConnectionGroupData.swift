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
    var aPacketsSeen = 0
    var aPacketsAnalyzed = 0
    var aConnectionData = ConnectionData()
    var bPacketsSeen = 0
    var bPacketsAnalyzed = 0
    var bConnectionData = ConnectionData()
}

struct ConnectionData
{
    var incomingPackets: [String: Data] = [:]
    var incomingDates: [String: Double] = [:]
    var outgoingPackets: [String: Data] = [:]
    var outgoingDates: [String: Double] = [:]
    var connections: [String] = []
}
