//
//  ConnectionData.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 11/6/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn

class ConnectionData
{
    var packetStats: [String: Int]
    var allowedConnections: [String]
    var blockedConnections: [String]
    
    var allowedIncoming: [String: Data]
    var allowedOutgoing: [String: Data]
    var blockedIncoming: [String: Data]
    var blockedOutgoing: [String: Data]
    var allowedIncomingDates: [String: Double]
    var allowedOutgoingDates: [String: Double]
    var blockedIncomingDates: [String: Double]
    var blockedOutgoingDates: [String: Double]
    
    /// Initializes Redis compatible connection data with Rethink connection data
    init(allowedRethinkPackets: [RethinkPacket], blockedRethinkPackets: [RethinkPacket])
    {
        packetStats = [String: Int]()
        
        allowedConnections = [String]()
        allowedIncoming = [String: Data]()
        allowedOutgoing = [String: Data]()
        allowedIncomingDates = [String: Double]()
        allowedOutgoingDates = [String: Double]()
        
        blockedConnections = [String]()
        blockedIncoming = [String: Data]()
        blockedOutgoing = [String: Data]()
        blockedIncomingDates = [String: Double]()
        blockedOutgoingDates = [String: Double]()
        
        for allowedConnection in allowedRethinkPackets
        {
            // Handshake true indicates that the packet is contained in the pair of first request/response packets
            if allowedConnection.handshake == false
            {
                continue
            }
            
            // inOut == true means an incoming connection
            if allowedConnection.inOut
            {
                allowedIncoming[allowedConnection.connectionID] = allowedConnection.payload.packetData
                allowedIncomingDates[allowedConnection.connectionID] = allowedConnection.timestamp
            }
            else
            {
                allowedOutgoing[allowedConnection.connectionID] = allowedConnection.payload.packetData
                allowedOutgoingDates[allowedConnection.connectionID] = allowedConnection.timestamp
            }
            
            // Add this connection ID to the list if it is not already there
            if !allowedConnections.contains(allowedConnection.connectionID)
            {
                allowedConnections.append(allowedConnection.connectionID)
            }
        }
        
        packetStats[allowedPacketsSeenKey] = allowedConnections.count
        
        for blockedConnection in blockedRethinkPackets
        {
            // Handshake true indicates that the packet is contained in the pair of first request/response packets
            if blockedConnection.handshake == false
            {
                continue
            }
            
            // inOut == true means an incoming connection
            if blockedConnection.inOut
            {
                blockedIncoming[blockedConnection.connectionID] = blockedConnection.payload.packetData
                blockedIncomingDates[blockedConnection.connectionID] = blockedConnection.timestamp
            }
            else
            {
                blockedOutgoing[blockedConnection.connectionID] = blockedConnection.payload.packetData
                blockedOutgoingDates[blockedConnection.connectionID] = blockedConnection.timestamp
            }
            
            // Add this connection ID to the list if it is not already there
            if !blockedConnections.contains(blockedConnection.connectionID)
            {
                blockedConnections.append(blockedConnection.connectionID)
            }
        }
        
        packetStats[blockedPacketsSeenKey] = blockedConnections.count
    }
    
    init()
    {
        let allowedConnectionsList = RList<String>(key: allowedConnectionsKey)
        let blockedConnectionsList = RList<String>(key: blockedConnectionsKey)
        
        self.packetStats = ConnectionData.intDictionary(from: packetStatsKey)
        self.allowedIncoming = ConnectionData.dataDictionary(from: allowedIncomingKey)
        self.allowedOutgoing = ConnectionData.dataDictionary(from: allowedOutgoingKey)
        self.blockedIncoming = ConnectionData.dataDictionary(from: blockedIncomingKey)
        self.blockedOutgoing = ConnectionData.dataDictionary(from: blockedOutgoingKey)
        self.allowedIncomingDates = ConnectionData.doubleDictionary(from: allowedIncomingDatesKey)
        self.allowedOutgoingDates = ConnectionData.doubleDictionary(from: allowedOutgoingDatesKey)
        self.blockedIncomingDates = ConnectionData.doubleDictionary(from: blockedIncomingDatesKey)
        self.blockedOutgoingDates = ConnectionData.doubleDictionary(from: blockedOutgoingDatesKey)
        self.allowedConnections = allowedConnectionsList.array
        self.blockedConnections = blockedConnectionsList.array        
    }
    
    func merge(with newData: ConnectionData) -> ConnectionData
    {
        packetStats = merge(primaryDictionary: packetStats, with: newData.packetStats) as! [String : Int]
        allowedIncoming = merge(primaryDictionary: allowedIncoming, with: newData.allowedIncoming) as! [String : Data]
        allowedOutgoing = merge(primaryDictionary: allowedOutgoing, with: newData.allowedOutgoing) as! [String : Data]
        blockedIncoming = merge(primaryDictionary: blockedIncoming, with: newData.blockedIncoming) as! [String: Data]
        blockedOutgoing = merge(primaryDictionary: blockedOutgoing, with: newData.blockedOutgoing) as! [String: Data]
        allowedIncomingDates = merge(primaryDictionary: allowedIncomingDates, with: newData.allowedIncomingDates) as! [String: Double]
        allowedOutgoingDates = merge(primaryDictionary: allowedOutgoingDates, with: newData.allowedOutgoingDates) as! [String : Double]
        blockedIncomingDates = merge(primaryDictionary: blockedIncomingDates, with: newData.blockedIncomingDates) as! [String : Double]
        blockedOutgoingDates = merge(primaryDictionary: blockedOutgoingDates, with: newData.blockedOutgoingDates) as! [String : Double]
        
        // Combine the arrays with no duplicates
        allowedConnections = Array(Set(allowedConnections + newData.allowedConnections))
        blockedConnections = Array(Set(blockedConnections + newData.blockedConnections))
        
        return self
    }
    
    func saveToRedis(completion: @escaping (Bool) -> Void)
    {
        redisQueue.async
        {
            let packetStatsMap = RMap<String, Int>(dictionary: self.packetStats)
            packetStatsMap.key = packetStatsKey
            let allowedIncomingMap = RMap<String, Data>(dictionary: self.allowedIncoming)
            allowedIncomingMap.key = allowedIncomingKey
            let allowedOutgoingMap = RMap<String, Data>(dictionary: self.allowedOutgoing)
            allowedOutgoingMap.key = allowedOutgoingKey
            let blockedIncomingMap = RMap<String, Data>(dictionary: self.blockedIncoming)
            blockedIncomingMap.key = blockedIncomingKey
            let blockedOutgoingMap = RMap<String, Data>(dictionary: self.blockedOutgoing)
            blockedOutgoingMap.key = blockedOutgoingKey
            let allowedIncomingDatesMap = RMap<String, Double>(dictionary: self.allowedIncomingDates)
            allowedIncomingDatesMap.key = allowedIncomingDatesKey
            let allowedOutgoingDatesMap = RMap<String, Double>(dictionary: self.allowedOutgoingDates)
            allowedOutgoingDatesMap.key = allowedOutgoingDatesKey
            let blockedIncomingDatesMap = RMap<String, Double>(dictionary: self.blockedIncomingDates)
            blockedIncomingDatesMap.key = blockedIncomingDatesKey
            let blockedOutgoingDatesMap = RMap<String, Double>(dictionary: self.blockedOutgoingDates)
            blockedOutgoingDatesMap.key = blockedOutgoingDatesKey
            let allowedConnectionsList = RList<String>(array: self.allowedConnections)
            allowedConnectionsList.key = allowedConnectionsKey
            let blockedConnectionsList = RList<String>(array: self.blockedConnections)
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
    
    static func intDictionary(from key: String) -> [String: Int]
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
    
    static func dataDictionary(from key: String) -> [String: Data]
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
    
    static func doubleDictionary(from key: String) -> [String: Double]
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
    
    static func floatDictionary(from key: String) -> [String: Float]
    {
        let floatMap = RMap<String, Float>(key: key)
        var floatDictionary = [String: Float]()
        
        let mapKeys: [String] = floatMap.keys
        
        for mapKey in mapKeys
        {
            floatDictionary[mapKey] = floatMap[mapKey]
        }
        
        return floatDictionary
    }
    
}
