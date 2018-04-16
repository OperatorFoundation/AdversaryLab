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

func processSequences(forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
{
    // Get the out packet that corresponds with this connection ID
    let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
    guard let outPacket: Data = outPacketHash[connection.connectionID]
        else
    {
        return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID))
    }

    let outFloatingSequenceSet: RSortedSet<Data> = RSortedSet(key: connection.outgoingFloatingSequencesKey)
    let _ = outFloatingSequenceSet.addSubsequences(offsetPrefix: connection.outgoingOffsetSequencesKey, sequence: outPacket)
    
//    //NSLog("Added \(String(describing: outCount)) outgoing subsequences")
//    for offset in 0..<outPacket.count {
//        let offsetKey = connection.outgoingOffsetSequencesKey + ":" + offset.string
//        let outOffsetSequenceSet: RSortedSet<Data> = RSortedSet(key: offsetKey)
//        let outOffCount = outOffsetSequenceSet.addSubsequences(sequence: outPacket)
//        //NSLog("Added \(outOffCount!) outgoing subsequences for offset \(offset)")
//    }
//
    // Get the in packet that corresponds with this connection ID
    let inPacketHash: RMap<String, Data> = RMap(key: connection.incomingKey)
    guard let inPacket = inPacketHash[connection.connectionID]
        else
    {
        return(false, PacketLengthError.noInPacketForConnection(connection.connectionID))
    }

    let inFloatingSequenceSet: RSortedSet<Data> = RSortedSet(key: connection.incomingFloatingSequencesKey)
    let _ = inFloatingSequenceSet.addSubsequences(offsetPrefix: connection.incomingOffsetSequencesKey, sequence: inPacket)
    
//    //NSLog("Added \(inCount!) incoming subsequences")
//    for offset in 0..<inPacket.count {
//        let offsetKey = connection.incomingOffsetSequencesKey + ":" + offset.string
//        let inOffsetSequenceSet: RSortedSet<Data> = RSortedSet(key: offsetKey)
//        let inOffCount = inOffsetSequenceSet.addSubsequences(sequence: inPacket)
//        //NSLog("Added \(inOffCount!) incoming subsequences for offset \(offset)")
//    }
    
    return (true, nil)
}

func scoreAllFloatSequences()
{
    // Outgoing
    scoreFloatSequences(allowedFloatKey: allowedOutgoingFloatingSequencesKey,
                        blockedFloatKey: blockedOutgoingFloatingSequencesKey,
                        requiredFloatKey: outgoingRequiredFloatSequencesKey,
                        forbiddenFloatKey: outgoingForbiddenFloatSequencesKey,
                        floatScoresKey: outgoingFloatSequenceScoresKey)
    
    // Incoming
    scoreFloatSequences(allowedFloatKey: allowedIncomingFloatingSequencesKey,
                        blockedFloatKey: blockedIncomingFloatingSequencesKey,
                        requiredFloatKey: incomingRequiredFloatSequencesKey,
                        forbiddenFloatKey: incomingForbiddenFloatSequencesKey,
                        floatScoresKey: incomingFloatSequenceScoresKey)
}

func scoreAllOffsetSequenes()
{
    // Outgoing
    scoreOffsetSequences(allowedOffsetKey: allowedOutgoingOffsetSequencesKey, blockedOffsetKey: blockedOutgoingOffsetSequencesKey, requiredOffsetKey: outgoingRequiredOffsetKey, forbiddenOffsetKey: outgoingForbiddenOffsetKey)
    
    // Incoming
    scoreOffsetSequences(allowedOffsetKey: allowedIncomingOffsetSequencesKey, blockedOffsetKey: blockedIncomingOffsetSequencesKey, requiredOffsetKey: incomingRequiredOffsetKey, forbiddenOffsetKey: incomingForbiddenOffsetKey)
}

func scoreOffsetSequences(allowedOffsetKey: String, blockedOffsetKey: String, requiredOffsetKey: String, forbiddenOffsetKey: String)
{
    let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
    
    /// Ta is the number of Allowed connections analyzed (Allowed:Connections:Analyzed)
    var allowedConnectionsAnalyzed = 0.0
    if let allowedConnectionsAnalyzedCount: Int = packetStatsDict[allowedPacketsAnalyzedKey]
    {
        allowedConnectionsAnalyzed = Double(allowedConnectionsAnalyzedCount)
    }
    
    /// Tb is the number of Blocked connections analyzed (Blocked:Connections:Analyzed)
    var blockedConnectionsAnalyzed = 0.0
    if let blockedConnectionsAnalyzedCount: Int = packetStatsDict[blockedPacketsAnalyzedKey]
    {
        blockedConnectionsAnalyzed = Double(blockedConnectionsAnalyzedCount)
    }
    
    /// A is the sorted set of sequences for the Allowed traffic (key: allowedFloatSequenceKey)
    /// B is the sorted set of sequences for the Blocked traffic (key: blockedFloatSequenceKey)
    
    //Form union for each float:index and add to one big set before moving on with scoring
    var offsetIndex = 0
    var topOffsetScore: Float?
    var topOffsetIndex: Int?
    var topOffsetSequence: Data?
    
    var bottomOffsetIndex: Int?
    var bottomOffsetSequence: Data?
    var bottomOffsetScore: Float?
    
    while true
    {
        let tempOffsetScoresKey = "tempOffsetScores"
        /// Returns a new sorted set with the correct scoring
        let tempOffsetScores: RSortedSet<Data> = RSortedSet(unionOf: allowedOffsetKey + ":\(offsetIndex)", scoresMultipliedBy: blockedConnectionsAnalyzed, secondSetKey: blockedOffsetKey + ":\(offsetIndex)", scoresMultipliedBy: -allowedConnectionsAnalyzed, newSetKey: tempOffsetScoresKey)
        
        if tempOffsetScores.count < 1
        {
            print("\n-------->Offset union returned empty list, breaking list.<--------------\n")
            break
        }

        guard let (thisTopOffsetSequence, thisTopOffsetScore) = tempOffsetScores.first
            else
        {
            break
        }
        
        guard let (thisBottomOffsetSequence, thisBottomOffsetScore) = tempOffsetScores.last
            else
        {
            break
        }

        
        if let (thisTopOffsetSequence, thisTopOffsetScore) = tempOffsetScores.first
        {
            if topOffsetScore != nil
            {
                if thisTopOffsetScore > topOffsetScore!
                {
                    topOffsetScore = thisTopOffsetScore
                    topOffsetSequence = thisTopOffsetSequence
                    topOffsetIndex = offsetIndex
                }
            }
            else
            {
                topOffsetScore = thisTopOffsetScore
                topOffsetSequence = thisTopOffsetSequence
                topOffsetIndex = offsetIndex
            }
        }
        
        if let (thisBottomOffsetSequence, thisBottomOffsetScore) = tempOffsetScores.last
        {
            if bottomOffsetScore != nil
            {
                if thisBottomOffsetScore < bottomOffsetScore!
                {
                    bottomOffsetScore = thisBottomOffsetScore
                    bottomOffsetIndex = offsetIndex
                    bottomOffsetSequence = thisBottomOffsetSequence
                }
            }
            else
            {
                bottomOffsetScore = thisBottomOffsetScore
                bottomOffsetIndex = offsetIndex
                bottomOffsetSequence = thisBottomOffsetSequence
            }
        }

        tempOffsetScores.delete()
        offsetIndex += 1
    }

    /// Top score is the required rule
    /// Divide the score by Ta * Tb to get the accuracy
    let requiredOffsetRuleAccuracy = abs(topOffsetScore!)/Float(allowedConnectionsAnalyzed * blockedConnectionsAnalyzed)
    
    let requiredOffsetHash: RMap = [requiredOffsetSequenceKey: topOffsetSequence!.hexEncodedString(), requiredOffsetAccuracyKey: "\(requiredOffsetRuleAccuracy)", requiredOffsetIndexKey: topOffsetIndex!.string]
    requiredOffsetHash.key = requiredOffsetKey

    /// Bottom score is the forbidden rule
    
    /// Divide the score by Ta * Tb to get the accuracy
    let forbiddenOffsetRuleAccuracy = abs(bottomOffsetScore!)/Float(allowedConnectionsAnalyzed * blockedConnectionsAnalyzed)
    let forbiddenOffsetHash: RMap = [forbiddenOffsetSequenceKey: bottomOffsetSequence!.hexEncodedString(), forbiddenOffsetAccuracyKey: "\(forbiddenOffsetRuleAccuracy)", forbiddenOffsetIndexKey: bottomOffsetIndex!.string]
    forbiddenOffsetHash.key = forbiddenOffsetKey
}


func scoreFloatSequences(allowedFloatKey: String, blockedFloatKey: String, requiredFloatKey: String, forbiddenFloatKey: String, floatScoresKey: String)
{
    let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
    
    /// Ta is the number of Allowed connections analyzed (Allowed:Connections:Analyzed)
    var allowedConnectionsAnalyzed = 0.0
    if let allowedConnectionsAnalyzedCount: Int = packetStatsDict[allowedPacketsAnalyzedKey]
    {
        allowedConnectionsAnalyzed = Double(allowedConnectionsAnalyzedCount)
    }
    
    /// Tb is the number of Blocked connections analyzed (Blocked:Connections:Analyzed)
    var blockedConnectionsAnalyzed = 0.0
    if let blockedConnectionsAnalyzedCount: Int = packetStatsDict[blockedPacketsAnalyzedKey]
    {
        blockedConnectionsAnalyzed = Double(blockedConnectionsAnalyzedCount)
    }
    
    /// A is the sorted set of sequences for the Allowed traffic (key: allowedFloatSequenceKey)
    /// B is the sorted set of sequences for the Blocked traffic (key: blockedFloatSequenceKey)
    
    /// Returns a new sorted set with the correct scoring (key: sequenceScoresKey)
    let oldSequenceScoresSet: RSortedSet<Data> = RSortedSet(key: floatScoresKey)
    oldSequenceScoresSet.delete()
    let sequenceScoresSet: RSortedSet<Data> = RSortedSet(unionOf: allowedFloatKey, scoresMultipliedBy: blockedConnectionsAnalyzed, secondSetKey: blockedFloatKey, scoresMultipliedBy: -allowedConnectionsAnalyzed, newSetKey: floatScoresKey)
    
    /// Bottom score is the required rule
    guard let (requiredSequence, requiredSequenceScore) = sequenceScoresSet.last
    else
    {
        print("😮  Unable to get a required rule for float sequences.")
        return
    }
    
    //TODO: There's some hopping around between float and double that could be cleaned up
    /// Divide the score by Ta * Tb to get the accuracy
    let requiredSequenceRuleAccuracy = abs(requiredSequenceScore)/Float(allowedConnectionsAnalyzed * blockedConnectionsAnalyzed)
    let requiredSequenceSet: RSortedSet<Data> = RSortedSet(key: requiredFloatKey)
    requiredSequenceSet.delete()
    _ = requiredSequenceSet.insert((requiredSequence, requiredSequenceRuleAccuracy))
    
    /// Top score is the forbidden rule
    guard let (forbiddenSequence, forbiddenSequenceScore) = sequenceScoresSet.first
    else
    {
        print("😮  Unable to get a forbidden rule for float sequences.")
        return
    }
    
    //TODO: There's some hopping around between float and double that could be cleaned up
    /// Divide the score by Ta * Tb to get the accuracy
    let forbiddenSequenceRuleAccuracy = abs(forbiddenSequenceScore)/Float(allowedConnectionsAnalyzed * blockedConnectionsAnalyzed)
    let forbiddenSequenceSet: RSortedSet<Data> = RSortedSet(key: forbiddenFloatKey)
    forbiddenSequenceSet.delete()
    _ = forbiddenSequenceSet.insert((forbiddenSequence, forbiddenSequenceRuleAccuracy))
    
}

