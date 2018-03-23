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
    let probabilities: [Double] = calculateProbabilities(for: packet)
    var entropy: Double = 0
    
    for probability in probabilities
    {
        if probability != 0 {
            let plog2 = log2(probability)
            entropy += (plog2 * probability)
        }
    }
    entropy = -entropy
    
    return entropy
}

/// Calculates the probability of each byte in the data packet
/// and returns them in an array where the index is the byte and value is the probability
private func calculateProbabilities(for packet: Data) -> [Double]
{
    let packetArray = [UInt8](packet)
    var countArray = Array(repeating: 0.0, count: 256)
 
    for byte in packetArray {
        let index = Int(byte)
        countArray[index] += 1
    }
    
    for (index, countValue) in countArray.enumerated()
    {
        if countValue != 0 {
            countArray[index] /= Double(packet.count)
        }
    }
    
    return countArray
}

func scoreAllEntropy()
{
    // Outgoing
    scoreEntropy(allowedEntropyKey: allowedOutgoingEntropyKey, allowedEntropyBinsKey: allowedOutgoingEntropyBinsKey, blockedEntropyKey: blockedOutgoingEntropyKey, blockedEntropyBinsKey: blockedOutgoingEntropyBinsKey, requiredEntropyKey: outgoingRequiredEntropyKey, forbiddenEntropyKey: outgoingForbiddenEntropyKey)
    
    // Incoming
    scoreEntropy(allowedEntropyKey: allowedIncomingEntropyKey, allowedEntropyBinsKey: allowedIncomingEntropyBinsKey, blockedEntropyKey: blockedIncomingEntropyKey, blockedEntropyBinsKey: blockedIncomingEntropyBinsKey, requiredEntropyKey: incomingRequiredEntropyKey, forbiddenEntropyKey: incomingForbiddenEntropyKey)
}

func scoreEntropy(allowedEntropyKey: String, allowedEntropyBinsKey: String, blockedEntropyKey: String, blockedEntropyBinsKey: String, requiredEntropyKey: String, forbiddenEntropyKey: String)
{
    let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
    
    /// |A| is the number of Allowed packets analyzed - Allowed:Connections:Analyzed
    var allowedPacketsAnalyzed = 0.0
    if let allowedConnectionsAnalyzedCount: Int = packetStatsDict[allowedPacketsAnalyzedKey]
    {
        allowedPacketsAnalyzed = Double(allowedConnectionsAnalyzedCount)
    }
    
    /// |B| is the number of Blocked packets analyzed - Blocked:Connections:Analyzed
    var blockedPacketsAnalyzed = 0.0
    if let blockedConnectionsAnalyzedCount: Int = packetStatsDict[blockedPacketsAnalyzedKey]
    {
        blockedPacketsAnalyzed = Double(blockedConnectionsAnalyzedCount)
    }
    
    /// A is the sorted set of Entropy for the Allowed traffic
    let allowedEntropyList: RList<Double> = RList(key: allowedEntropyKey)
    let allowedEntropyBinsRSet: RSortedSet<Int> = RSortedSet(key: allowedEntropyBinsKey)
    //let allowedEntropySet = newDoubletSet(from: [allowedEntropyRSet])
    //Sort into bins
    for entropyIndex in 0 ..< allowedEntropyList.count
    {
        guard let aEntropy = allowedEntropyList[entropyIndex]
        else
        {
            continue
        }
        
        for i in 0 ... 7
        {
            //Everything 7 or greater goes into this bin
            if i == 7
            {
                if  aEntropy >= Double(i)
                {
                    _ = allowedEntropyBinsRSet.incrementScore(ofField: i, byIncrement: 1.0)
                }
            }
            //Everything of value i up to but exclusive of i + 1 goes here
            else if aEntropy >= Double(i), aEntropy < Double(i + 1)
            {
                _ = allowedEntropyBinsRSet.incrementScore(ofField: i, byIncrement: 1.0)
            }
        }
    }
    
    /// B is the sorted set of Entropy for the Blocked traffic
    let blockedEntropyList: RList<Double> = RList(key: blockedEntropyKey)
    let blockedEntropyBinsRSet: RSortedSet<Int> = RSortedSet(key: blockedEntropyBinsKey)
    //let blockedEntropySet = newDoubletSet(from: [blockedEntropyRSet])
    //Sort into bins
    for entropyIndex in 0 ..< blockedEntropyList.count
    {
        guard let bEntropy = blockedEntropyList[entropyIndex]
        else
        {
            continue
        }
        
        for i in 0 ... 7
        {
            //Everything 7 or greater goes into this bin
            if i == 7
            {
                if bEntropy >= Double(i)
                {
                    _ = blockedEntropyBinsRSet.incrementScore(ofField: i, byIncrement: 1)
                }
            }
                //Everything of value i up to but exclusive of i + 1 goes here
            else if bEntropy >= Double(i) && bEntropy < Double(i + 1)
            {
                _ = blockedEntropyBinsRSet.incrementScore(ofField: i, byIncrement: 1)
            }
        }
    }
    
    /// L is the union of the keys for A and B (without the scores)
    let allEntropySet = newIntSet(from: [allowedEntropyBinsRSet, blockedEntropyBinsRSet])

    /// for entropy in L
    for entropy in allEntropySet
    {
        let aCount = Double(allowedEntropyBinsRSet[entropy] ?? 0.0)
        let bCount = Double(blockedEntropyBinsRSet[entropy] ?? 0.0)
        
        let aProb = aCount/allowedPacketsAnalyzed
        let bProb = bCount/blockedPacketsAnalyzed
        
        /// Required
        // True Positive
        let requiredTP = aProb
        // False Positive
        let requiredFP = bProb
        // True Negative
        let requiredTN = 1 - bProb
        // False Negative
        let requiredFN = 1 - aProb
        // Accuracy
        let requiredAccuracy = (requiredTP + requiredTN)/(requiredTP + requiredTN + requiredFP + requiredFN)
        
        /// Forbidden
        let forbiddenTP = 1 - aProb
        let forbiddenFP = 1 - bProb
        let forbiddenTN = bProb
        let forbiddenFN = aProb
        let forbiddenAccuracy: Double = (forbiddenTP + forbiddenTN)/(forbiddenTP + forbiddenTN + forbiddenFP + forbiddenFN)
        
        /// Save Scores
        let requiredEntropy: RSortedSet<Int> = RSortedSet(key: requiredEntropyKey)
        let _ = requiredEntropy.insert((entropy, Float(requiredAccuracy)))
        
        //TODO: RSortedSet.insert displays notes for Set as provided by apple, this is inaccurate for sorted set and is confusing.
        let forbiddenEntropy: RSortedSet<Int> = RSortedSet(key: forbiddenEntropyKey)
        let _ = forbiddenEntropy.insert((entropy, Float(forbiddenAccuracy)))
    }
}

func newDoubletSet(from redisSets:[RSortedSet<Double>]) -> Set<Double>
{
    var swiftSet = Set<Double>()
    for set in redisSets
    {
        for i in 0 ..< set.count
        {
            if let newMember: Double = set[i]
            {
                swiftSet.insert(newMember)
            }
        }
    }
    
    return swiftSet
}
