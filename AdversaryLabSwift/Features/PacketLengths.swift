//
//  PacketLengths.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn

func processPacketLengths(forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
{
    let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
    let outgoingLengthSet: RSortedSet<Int> = RSortedSet(key: connection.outgoingLengthsKey)
    let inPacketHash: RMap<String, Data> = RMap(key: connection.incomingKey)
    let incomingLengthSet: RSortedSet<Int> = RSortedSet(key: connection.incomingLengthsKey)
    
    // Get the out packet that corresponds with this connection ID
    guard let outPacket: Data = outPacketHash[connection.connectionID]
        else
    {
        return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID))
    }
    
    /// DEBUG
    if outPacket.count < 10
    {
        print("\n### Outpacket count = \(String(outPacket.count))")
        print("\n⁉️  We got a weird out packet size... \(String(describing: String(data: outPacket, encoding: .utf8)))<----")
    }
    ///
    
    // Increment the score of this particular outgoing packet length
    let _ = outgoingLengthSet.incrementScore(ofField: outPacket.count, byIncrement: 1)
    
    // Get the in packet that corresponds with this connection ID
    guard let inPacket = inPacketHash[connection.connectionID]
        else
    {
        return(false, PacketLengthError.noInPacketForConnection(connection.connectionID))
    }
    
    /// DEBUG
    if inPacket.count < 10
    {
        print("\n### Inpacket count = \(String(inPacket.count))\n")
        print("\n⁉️  We got a weird in packet size... \(String(describing: String(data: outPacket, encoding: .utf8))) <---\n")
    }
    ///
    
    // Increment the score of this particular incoming packet length
    let newInScore = incomingLengthSet.incrementScore(ofField: inPacket.count, byIncrement: 1)
    if newInScore == nil
    {
        return(false, PacketLengthError.unableToIncremementScore(packetSize: inPacket.count, connectionID: connection.connectionID))
    }
    
    return(true, nil)
}

func scoreAllPacketLengths()
{
    // Outgoing Lengths Scoring
    scorePacketLengths(allowedLengthsKey: allowedOutgoingLengthsKey, blockedLengthsKey: blockedOutgoingLengthsKey, requiredLengthsKey: outgoingRequiredLengthsKey, forbiddenLengthsKey: outgoingForbiddenLengthsKey)
    
    //Incoming Lengths Scoring
    scorePacketLengths(allowedLengthsKey: allowedIncomingLengthsKey, blockedLengthsKey: blockedIncomingLengthsKey, requiredLengthsKey: incomingRequiredLengthsKey, forbiddenLengthsKey: incomingForbiddenLengthsKey)
}

func scorePacketLengths(allowedLengthsKey: String, blockedLengthsKey: String, requiredLengthsKey: String, forbiddenLengthsKey: String)
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
    
    /// A is the sorted set of lengths for the Allowed traffic
    let allowedLengthsSet: RSortedSet<Int> = RSortedSet(key: allowedLengthsKey)
    /// B is the sorted set of lengths for the Blocked traffic
    let blockedLengthsSet: RSortedSet<Int> = RSortedSet(key: blockedLengthsKey)
    /// L is the union of the keys for A and B (without the scores)
    let allLengthsSet = newIntSet(from: [allowedLengthsSet, blockedLengthsSet])
    
    /// for len in L
    for length in allLengthsSet
    {
        let aCount = Double(allowedLengthsSet[length] ?? 0.0)
        let bCount = Double(blockedLengthsSet[length] ?? 0.0)
        
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
        let requiredLengths: RSortedSet<Int> = RSortedSet(key: requiredLengthsKey)
        let requiredScore = requiredLengths.incrementScore(ofField: length, byIncrement: requiredAccuracy)
        print("\nSaved required accuracy of |\(String(describing: requiredScore))| for length \(length)")
        
        let forbiddenLengths: RSortedSet<Int> = RSortedSet(key: forbiddenLengthsKey)
        let forbiddenScore = forbiddenLengths.incrementScore(ofField: length, byIncrement: forbiddenAccuracy)
        print("Saved forbidden accuracy of |\(String(describing: forbiddenScore))| for length \(length)")
    }
}

func newIntSet(from redisSets:[RSortedSet<Int>]) -> Set<Int>
{
    var swiftSet = Set<Int>()
    for set in redisSets
    {
        for i in 0 ..< set.count
        {
            if let newMember: Int = set[i]
            {
                swiftSet.insert(newMember)
            }
        }
    }
    
    return swiftSet
}

