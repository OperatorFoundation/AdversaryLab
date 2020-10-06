//
//  DataProcessing.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 7/7/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation

import Abacus
import Auburn
import Symphony
import RawPacket

class DataProcessing
{
    func updateConnectionGroupData(forTransportA transportA:String, aRawPackets: ValueSequence<RawPacket>, transportB: String, bRawPackets: ValueSequence<RawPacket>)
    {
        updateConnectionGroupData(forConnectionType: .transportA, fromRawPackets: aRawPackets)
        updateConnectionGroupData(forConnectionType: .transportB, fromRawPackets: bRawPackets)
    }
    
    func updateConnectionGroupData(forConnectionType connectionType: ClassificationLabel, fromRawPackets rawPackets: ValueSequence<RawPacket>)
    {
        for packet in rawPackets
        {
            // Handshake true indicates that the packet is contained in the pair of first request/response packets
            if packet.handshake == false
            {
                continue
            }
            
            switch connectionType
            {
            case .transportA:
                
                // inOut == true means an incoming connection
                if packet.in_out
                {
                    connectionGroupData.aConnectionData.incomingPackets[packet.connection] = packet.payload
                    connectionGroupData.aConnectionData.incomingDates[packet.connection] = Double(packet.timestamp)
                }
                else
                {
                    connectionGroupData.aConnectionData.outgoingPackets[packet.connection] = packet.payload
                    connectionGroupData.aConnectionData.outgoingDates[packet.connection] = Double(packet.timestamp)
                }
                
                // Add this connection ID to the list if it is not already there
                if !connectionGroupData.aConnectionData.connections.contains(packet.connection)
                {
                    connectionGroupData.aConnectionData.connections.append(packet.connection)
                }
            case .transportB:
                
                // inOut == true means an incoming connection
                if packet.in_out
                {
                    connectionGroupData.bConnectionData.incomingPackets[packet.connection] = packet.payload
                    connectionGroupData.bConnectionData.incomingDates[packet.connection] = Double(packet.timestamp)
                }
                else
                {                    
                    connectionGroupData.bConnectionData.outgoingPackets[packet.connection] = packet.payload
                    connectionGroupData.bConnectionData.outgoingDates[packet.connection] = Double(packet.timestamp)
                }
                
                // Add this connection ID to the list if it is not already there
                if !connectionGroupData.bConnectionData.connections.contains(packet.connection)
                {
                    connectionGroupData.bConnectionData.connections.append(packet.connection)
                }
            }
        }
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
