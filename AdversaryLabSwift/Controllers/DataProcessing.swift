//
//  DataProcessing.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 7/7/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn
import Symphony
import RawPacket

class DataProcessing
{
    func connectionData(forTransportA transportA:String, aRawPackets: ValueSequence<RawPacket>, transportB: String, bRawPackets: ValueSequence<RawPacket>) -> ConnectionGroupData
    {
        var packetStats = [String: Int]()
        
        var aIncoming = [String: Data]()
        var aOutgoing = [String: Data]()
        var aIncomingDates = [String: Double]()
        var aOutgoingDates = [String: Double]()
        var aConnections = [String]()
        
        (aIncoming, aIncomingDates, aOutgoing, aOutgoingDates, aConnections) = connectionDictionaries(fromRawPackets: aRawPackets)
        packetStats[allowedPacketsSeenKey] = aConnections.count
        
        var bIncoming = [String: Data]()
        var bOutgoing = [String: Data]()
        var bIncomingDates = [String: Double]()
        var bOutgoingDates = [String: Double]()
        var bConnections = [String]()
        
        (bIncoming, bIncomingDates, bOutgoing, bOutgoingDates, bConnections) = connectionDictionaries(fromRawPackets: bRawPackets)
        packetStats[blockedPacketsSeenKey] = bConnections.count
        
        let aConnectionData = ConnectionData(incomingPackets: aIncoming,
                                             incomingDates: aIncomingDates,
                                             outgoingPackets: aOutgoing,
                                             outgoingDates: aOutgoingDates,
                                             connections: aConnections)
        let bConnectionData = ConnectionData(incomingPackets: bIncoming,
                                             incomingDates: bIncomingDates,
                                             outgoingPackets: bOutgoing,
                                             outgoingDates: bOutgoingDates,
                                             connections: bConnections)
        return ConnectionGroupData(packetStats: packetStats, aConnectionData: aConnectionData, bConnectionData: bConnectionData)
    }
    
    func connectionDictionaries(fromRawPackets rawPackets: ValueSequence<RawPacket>) -> (incomingPackets: [String: Data], incomingDates:[String: Double],  outgoingPackets: [String: Data], outgoingDates: [String: Double], connections: [String])
    {
        var incomingPackets = [String: Data]()
        var incomingDates = [String: Double]()
        var outgoingPackets = [String: Data]()
        var outgoingDates = [String: Double]()
        var connections = [String]()
        
        for packet in rawPackets
        {
            // Handshake true indicates that the packet is contained in the pair of first request/response packets
            if packet.handshake == false
            {
                continue
            }
            
            // inOut == true means an incoming connection
            if packet.in_out
            {
                incomingPackets[packet.connection] = packet.payload
                incomingDates[packet.connection] = Double(packet.timestamp)
            }
            else
            {
                outgoingPackets[packet.connection] = packet.payload
                outgoingDates[packet.connection] = Double(packet.timestamp)
            }
            
            // Add this connection ID to the list if it is not already there
            if !connections.contains(packet.connection)
            {
                connections.append(packet.connection)
            }
        }
        
        return (incomingPackets, incomingDates, outgoingPackets, outgoingDates, connections)
    }
    
    func connectionData(fromARethinkPackets aRethinkPackets: [RethinkPacket], bRethinkPackets: [RethinkPacket]) -> ConnectionGroupData
    {
        var packetStats = [String: Int]()
        
        var aConnections = [String]()
        var aIncoming = [String: Data]()
        var aOutgoing = [String: Data]()
        var aIncomingDates = [String: Double]()
        var aOutgoingDates = [String: Double]()
        
        var bConnections = [String]()
        var bIncoming = [String: Data]()
        var bOutgoing = [String: Data]()
        var bIncomingDates = [String: Double]()
        var bOutgoingDates = [String: Double]()
        
        for aConnection in aRethinkPackets
        {
            // Handshake true indicates that the packet is contained in the pair of first request/response packets
            if aConnection.handshake == false
            {
                continue
            }
            
            // inOut == true means an incoming connection
            if aConnection.inOut
            {
                aIncoming[aConnection.connectionID] = aConnection.payload.packetData
                aIncomingDates[aConnection.connectionID] = aConnection.timestamp
            }
            else
            {
                aOutgoing[aConnection.connectionID] = aConnection.payload.packetData
                aOutgoingDates[aConnection.connectionID] = aConnection.timestamp
            }
            
            // Add this connection ID to the list if it is not already there
            if !aConnections.contains(aConnection.connectionID)
            {
                aConnections.append(aConnection.connectionID)
            }
        }
        
        packetStats[allowedPacketsSeenKey] = aConnections.count
        
        for bConnection in bRethinkPackets
        {
            // Handshake true indicates that the packet is contained in the pair of first request/response packets
            if bConnection.handshake == false
            {
                continue
            }
            
            // inOut == true means an incoming connection
            if bConnection.inOut
            {
                bIncoming[bConnection.connectionID] = bConnection.payload.packetData
                bIncomingDates[bConnection.connectionID] = bConnection.timestamp
            }
            else
            {
                bOutgoing[bConnection.connectionID] = bConnection.payload.packetData
                bOutgoingDates[bConnection.connectionID] = bConnection.timestamp
            }
            
            // Add this connection ID to the list if it is not already there
            if !bConnections.contains(bConnection.connectionID)
            {
                bConnections.append(bConnection.connectionID)
            }
        }
        
        packetStats[blockedPacketsSeenKey] = bConnections.count
        let aConnectionData = ConnectionData(incomingPackets: aIncoming,
                                             incomingDates: aIncomingDates,
                                             outgoingPackets: aOutgoing,
                                             outgoingDates: aOutgoingDates,
                                             connections: aConnections)
        let bConnectionData = ConnectionData(incomingPackets: bIncoming,
                                             incomingDates: bIncomingDates,
                                             outgoingPackets: bOutgoing,
                                             outgoingDates: bOutgoingDates,
                                             connections: bConnections)
        return ConnectionGroupData(packetStats: packetStats, aConnectionData: aConnectionData, bConnectionData: bConnectionData)
    }
    
    func merge(connectionData: ConnectionData, with newData: ConnectionData) -> ConnectionData
    {
        var mergedConnectionData = connectionData
        mergedConnectionData.incomingPackets = merge(primaryDictionary: connectionData.incomingPackets, with: newData.incomingPackets) as! [String : Data]
        mergedConnectionData.incomingDates = merge(primaryDictionary: connectionData.incomingDates, with: newData.incomingDates) as! [String: Double]
        mergedConnectionData.outgoingPackets = merge(primaryDictionary: connectionData.outgoingPackets, with: newData.outgoingPackets) as! [String : Data]
        mergedConnectionData.outgoingDates = merge(primaryDictionary: connectionData.outgoingDates, with: newData.outgoingDates) as! [String : Double]
        
        // Combine the arrays with no duplicates
        mergedConnectionData.connections = Array(Set(connectionData.connections + newData.connections))
        
        return mergedConnectionData
    }
    
    func merge(connectionGroupData: ConnectionGroupData, with newData: ConnectionGroupData) -> ConnectionGroupData
    {
        var mergedConnectionGroupData = connectionGroupData
        mergedConnectionGroupData.packetStats = merge(primaryDictionary: connectionGroupData.packetStats, with: newData.packetStats) as! [String : Int]
        mergedConnectionGroupData.aConnectionData = merge(connectionData: connectionGroupData.aConnectionData, with: newData.aConnectionData)
        mergedConnectionGroupData.bConnectionData = merge(connectionData: connectionGroupData.bConnectionData, with: newData.bConnectionData)
        
        return connectionGroupData
    }
    
    func saveToRedis(connectionData: ConnectionGroupData, completion: @escaping (Bool) -> Void)
    {
        redisQueue.async
        {
            let packetStatsMap = RMap<String, Int>(dictionary: connectionData.packetStats)
            packetStatsMap.key = packetStatsKey
            
            let allowedIncomingMap = RMap<String, Data>(dictionary: connectionData.aConnectionData.incomingPackets)
            allowedIncomingMap.key = allowedIncomingKey
            let allowedOutgoingMap = RMap<String, Data>(dictionary: connectionData.aConnectionData.outgoingPackets)
            allowedOutgoingMap.key = allowedOutgoingKey
            let allowedIncomingDatesMap = RMap<String, Double>(dictionary: connectionData.aConnectionData.incomingDates)
            allowedIncomingDatesMap.key = allowedIncomingDatesKey
            let allowedOutgoingDatesMap = RMap<String, Double>(dictionary: connectionData.aConnectionData.outgoingDates)
            allowedOutgoingDatesMap.key = allowedOutgoingDatesKey
            let allowedConnectionsList = RList<String>(array: connectionData.aConnectionData.connections)
            allowedConnectionsList.key = allowedConnectionsKey
            
            let blockedIncomingMap = RMap<String, Data>(dictionary: connectionData.bConnectionData.incomingPackets)
            blockedIncomingMap.key = blockedIncomingKey
            let blockedOutgoingMap = RMap<String, Data>(dictionary: connectionData.bConnectionData.outgoingPackets)
            blockedOutgoingMap.key = blockedOutgoingKey
            let blockedIncomingDatesMap = RMap<String, Double>(dictionary: connectionData.bConnectionData.incomingDates)
            blockedIncomingDatesMap.key = blockedIncomingDatesKey
            let blockedOutgoingDatesMap = RMap<String, Double>(dictionary: connectionData.bConnectionData.outgoingDates)
            blockedOutgoingDatesMap.key = blockedOutgoingDatesKey
            let blockedConnectionsList = RList<String>(array: connectionData.bConnectionData.connections)
            blockedConnectionsList.key = blockedConnectionsKey
            
            completion(true)
        }
    }
    
    func merge(primaryDictionary: Dictionary<String, Any>, with secondaryDictionary: Dictionary<String, Any>) -> Dictionary<String, Any>
    {
        var pDictionary = primaryDictionary
        pDictionary.merge(secondaryDictionary) { (primary, _) -> Any in
            primary
        }
        
        return pDictionary
    }
    
    func intDictionary(from key: String) -> [String: Int]
    {
        let intMap = RMap<String, Int>(key: key)
        var intDictionary = [String: Int]()
        
        let mapKeys: [String] = intMap.keys
        
        for mapKey in mapKeys
        {
            intDictionary[mapKey] = intMap[mapKey]
        }
        
        return intDictionary
    }
    
    func dataDictionary(from key: String) -> [String: Data]
    {
        let dataMap = RMap<String, Data>(key: key)
        var dataDictionary = [String: Data]()
        
        let mapKeys: [String] = dataMap.keys
        
        for mapKey in mapKeys
        {
            dataDictionary[mapKey] = dataMap[mapKey]
        }
        
        return dataDictionary
    }
    
    func doubleDictionary(from key: String) -> [String: Double]
    {
        let doubleMap = RMap<String, Double>(key: key)
        var doubleDictionary = [String: Double]()
        
        let mapKeys: [String] = doubleMap.keys
        
        for mapKey in mapKeys
        {
            doubleDictionary[mapKey] = doubleMap[mapKey]
        }
        
        return doubleDictionary
    }

}
