//
//  Entropy.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn

func processEntropy(forConnection connection: ObservedConnection) -> (processsed: Bool, error: Error?)
{
    let inPacketsEntropyList: RList<Double> = RList(key: connection.incomingEntropyKey)
    let outPacketsEntropyList: RList<Double> = RList(key: connection.outgoingEntropyKey)
    
    // Get the outgoing packet that corresponds with this connection ID
    let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
    guard let outPacket: Data = outPacketHash[connection.connectionID]
        else
    {
        return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID))
    }
    
    let outPacketEntropy = calculateEntropy(for: outPacket)
    outPacketsEntropyList.append(outPacketEntropy)
    
    // Get the incoming packet that corresponds with this connection ID
    let inPacketHash: RMap<String, Data> = RMap(key: connection.incomingKey)
    guard let inPacket = inPacketHash[connection.connectionID]
        else
    {
        return(false, PacketLengthError.noInPacketForConnection(connection.connectionID))
    }
    
    let inPacketEntropy = calculateEntropy(for: inPacket)
    inPacketsEntropyList.append(inPacketEntropy)
    
    return (true, nil)
}

func calculateEntropy(for packet: Data) -> Double
{
    let probabilityDictionary: [UInt8: Double] = calculateProbabilities(for: packet)
    var entropy: Double = 0
    
    for probability in probabilityDictionary
    {
        let plog2 = log2(probability.value)
        entropy += -1 * (plog2 * probability.value)
    }
    
    return entropy
}

/// Calculates the probability of each byte in the data packet
/// and returns them in a dictionary where key is the byte and value is the probability
private func calculateProbabilities(for packet: Data) -> [UInt8: Double]
{
    let packetArray = [UInt8](packet)
    let packetSet = Set(packetArray)
    var countDictionary = [UInt8: Int]()
    var probabilityDictionary = [UInt8: Double]()
    
    for uniqueByte in packetSet
    {
        countDictionary[uniqueByte] = 0
        
        for value in packetArray
        {
            if value == uniqueByte
            {
                countDictionary[uniqueByte] = countDictionary[uniqueByte]!+1
            }
        }
    }
    
    for (key, countValue) in countDictionary
    {
//        print("Probability of \(key) is \(countValue)/\(packetArray.count)")
//        let probability = Double(countValue)/Double(packetArray.count)
        let probability = Double(countValue)/Double(256)
        probabilityDictionary[key] = probability
    }
    
    
    return probabilityDictionary
}
