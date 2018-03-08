//
//  Sequences.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn

func processOffsetSequences(forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
{
    // Get the out packet that corresponds with this connection ID
    let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
    guard let outPacket: Data = outPacketHash[connection.connectionID]
        else
    {
        return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID))
    }
    
    for (index, _) in outPacket.enumerated()
    {
        let outOffsetSequenceSetKey = "\(connection.outgoingOffsetSequencesKey)\(index)"
        let outOffsetSequenceSet: RSortedSet<Data> = RSortedSet(key: outOffsetSequenceSetKey)
        let outFloatingSequenceSet: RSortedSet<Data> = RSortedSet(key: connection.outgoingFloatingSequencesKey)
        
        for x in index..<outPacket.count
        {
            let sequence = outPacket[index...x]
            let _ = outOffsetSequenceSet.incrementScore(ofField:sequence, byIncrement: 1)
            let _ = outFloatingSequenceSet.incrementScore(ofField: sequence, byIncrement: 1)
        }
    }
    
    // Get the in packet that corresponds with this connection ID
    let inPacketHash: RMap<String, Data> = RMap(key: connection.incomingKey)
    guard let inPacket = inPacketHash[connection.connectionID]
        else
    {
        return(false, PacketLengthError.noInPacketForConnection(connection.connectionID))
    }
    
    for (index, _) in inPacket.enumerated()
    {
        let inOffsetSequenceKey = "\(connection.incomingOffsetSequencesKey)\(index)"
        let inOffsetSequenceSet: RSortedSet<Data> = RSortedSet(key: inOffsetSequenceKey)
        let inFloatingSequenceSet: RSortedSet<Data> = RSortedSet(key: connection.incomingFloatingSequencesKey)
        
        for x in index ..< inPacket.count
        {
            let sequence = inPacket[index...x]
            let _ = inOffsetSequenceSet.incrementScore(ofField: sequence, byIncrement: 1)
            let _ = inFloatingSequenceSet.incrementScore(ofField: sequence, byIncrement: 1)
        }
    }
    
    return (true, nil)
}

func scoreAllFloatSequences()
{
    // Outgoing
    scoreSequences(allowedFloatSequenceKey: allowedOutgoingFloatingSequencesKey, blockedFloatSequenceKey: blockedOutgoingFloatingSequencesKey, requiredSequencesKey: outgoingRequiredSequencesKey, forbiddenSequencesKey: outgoingForbiddenLengthsKey)
    
    //Incoming
    scoreSequences(allowedFloatSequenceKey: allowedIncomingFloatingSequencesKey, blockedFloatSequenceKey: blockedIncomingFloatingSequencesKey, requiredSequencesKey: incomingRequiredSequencesKey, forbiddenSequencesKey: incomingForbiddenSequencesKey)
}


func scoreSequences(allowedFloatSequenceKey: String, blockedFloatSequenceKey: String, requiredSequencesKey: String, forbiddenSequencesKey: String)
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
    let allowedSequencesSet: RSortedSet<Data> = RSortedSet(key: allowedFloatSequenceKey)
    /// B is the sorted set of lengths for the Blocked traffic
    let blockedSequencesSet: RSortedSet<Data> = RSortedSet(key: blockedFloatSequenceKey)
    /// L is the union of the keys for A and B (without the scores)
    let allSequencesSet = newDataSet(from: [allowedSequencesSet, blockedSequencesSet])
    
    /// for len in L
    for sequence in allSequencesSet
    {
        let aCount = Double(allowedSequencesSet[sequence] ?? 0.0)
        let bCount = Double(blockedSequencesSet[sequence] ?? 0.0)
        
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
        let requiredSequences: RSortedSet<Data> = RSortedSet(key: requiredSequencesKey)
        let requiredScore = requiredSequences.incrementScore(ofField: sequence, byIncrement: requiredAccuracy)
        print("\nSaved required accuracy of |\(String(describing: requiredScore))| for sequence \(String(describing: sequence))")
        
        let forbiddenSequences: RSortedSet<Data> = RSortedSet(key: forbiddenSequencesKey)
        let forbiddenScore = forbiddenSequences.incrementScore(ofField: sequence, byIncrement: forbiddenAccuracy)
        print("Saved forbidden accuracy of |\(String(describing: forbiddenScore))| for sequence \(String(describing: sequence))")
    }
}

func newDataSet(from redisSets:[RSortedSet<Data>]) -> Set<Data>
{
    var swiftSet = Set<Data>()
    for set in redisSets
    {
        for i in 0 ..< set.count
        {
            if let newMember: Data = set[i]
            {
                swiftSet.insert(newMember)
            }
        }
    }
    
    return swiftSet
}
