//
//  Sequences.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn
import RedShot
import Datable

func processOffsetSequences(forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
{
    // Get the out packet that corresponds with this connection ID
    let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
    guard let outPacket: Data = outPacketHash[connection.connectionID]
        else
    {
        return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID))
    }

    let outFloatingSequenceSet: RSortedSet<Data> = RSortedSet(key: connection.outgoingFloatingSequencesKey)
    let outCount = outFloatingSequenceSet.addSubsequences(sequence: outPacket)
    NSLog("Added \(String(describing: outCount)) outgoing subsequences")
    for offset in 0..<outPacket.count {
        let offsetKey = connection.outgoingOffsetSequencesKey + ":" + offset.string
        let outOffsetSequenceSet: RSortedSet<Data> = RSortedSet(key: offsetKey)
        let outOffCount = outOffsetSequenceSet.addSubsequences(sequence: outPacket)
        NSLog("Added \(String(describing: outOffCount)) outgoing subsequences for offset \(offset)")
    }
    
    // Get the in packet that corresponds with this connection ID
    let inPacketHash: RMap<String, Data> = RMap(key: connection.incomingKey)
    guard let inPacket = inPacketHash[connection.connectionID]
        else
    {
        return(false, PacketLengthError.noInPacketForConnection(connection.connectionID))
    }

    let inFloatingSequenceSet: RSortedSet<Data> = RSortedSet(key: connection.incomingFloatingSequencesKey)
    let inCount = inFloatingSequenceSet.addSubsequences(sequence: inPacket)
    NSLog("Added \(String(describing: inCount)) incoming subsequences")
    for offset in 0..<inPacket.count {
        let offsetKey = connection.incomingOffsetSequencesKey + ":" + offset.string
        let inOffsetSequenceSet: RSortedSet<Data> = RSortedSet(key: offsetKey)
        let inOffCount = inOffsetSequenceSet.addSubsequences(sequence: inPacket)
        NSLog("Added \(String(describing: inOffCount)) incoming subsequences for offset \(offset)")
    }
    
    return (true, nil)
}

func scoreAllFloatSequences()
{
    // Outgoing
    scoreSequences(allowedFloatSequenceKey: allowedOutgoingFloatingSequencesKey, blockedFloatSequenceKey: blockedOutgoingFloatingSequencesKey, requiredSequencesKey: outgoingRequiredSequencesKey, forbiddenSequencesKey: outgoingForbiddenSequencesKey)
    
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
        let _ = requiredSequences.insert((sequence, Float(requiredAccuracy)))
        
        let forbiddenSequences: RSortedSet<Data> = RSortedSet(key: forbiddenSequencesKey)
        let _ = forbiddenSequences.insert((sequence, Float(forbiddenAccuracy)))
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
