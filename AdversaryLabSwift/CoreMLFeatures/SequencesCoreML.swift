//
//  SequencesCoreML.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 4/4/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import CreateML
import Auburn
import RedShot
import Datable

class SequencesCoreML
{
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
        
        // Get the in packet that corresponds with this connection ID
        let inPacketHash: RMap<String, Data> = RMap(key: connection.incomingKey)
        guard let inPacket = inPacketHash[connection.connectionID]
            else
        {
            return(false, PacketLengthError.noInPacketForConnection(connection.connectionID))
        }
        
        let inFloatingSequenceSet: RSortedSet<Data> = RSortedSet(key: connection.incomingFloatingSequencesKey)
        let _ = inFloatingSequenceSet.addSubsequences(offsetPrefix: connection.incomingOffsetSequencesKey, sequence: inPacket)
        
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
            let tempOffsetScores: RSortedSet<Data> = RSortedSet(
                unionOf: allowedOffsetKey + ":\(offsetIndex)",
                scoresMultipliedBy: blockedConnectionsAnalyzed,
                secondSetKey: blockedOffsetKey + ":\(offsetIndex)",
                scoresMultipliedBy: -allowedConnectionsAnalyzed,
                newSetKey: tempOffsetScoresKey)
            
            if tempOffsetScores.count < 1
            {
                print("\n-------->Offset union returned empty list, breaking list.<--------------\n")
                break
            }
            
            guard let (_, thisTopOffsetScore) = tempOffsetScores.first
                else
            {
                break
            }
            
            guard let longestTopSequence: Data = tempOffsetScores.getLongestSequence(withScore: Double(thisTopOffsetScore))
                else
            {
                print("\nFailed to find the longest top offset sequence.")
                break
            }
            
            
            // Save the top scoring, longest offset
            if topOffsetScore != nil
            {
                if thisTopOffsetScore > topOffsetScore!
                {
                    topOffsetScore = thisTopOffsetScore
                    topOffsetSequence = longestTopSequence
                    topOffsetIndex = offsetIndex
                }
            }
            else
            {
                topOffsetScore = thisTopOffsetScore
                topOffsetSequence = longestTopSequence
                topOffsetIndex = offsetIndex
            }
            
            // Get the bottom scoring sequence and score
            guard let (_, thisBottomOffsetScore) = tempOffsetScores.last
                else
            {
                break
            }
            
            // Use this bottom score to fetch all results with this score and choose the longest
            guard let longestBottomSequence: Data = tempOffsetScores.getLongestSequence(withScore: Double(thisBottomOffsetScore))
                else
            {
                print("\nFailed to find the longest bottom offset sequence.")
                break
            }
            
            // Save the lowest scoring, longest, offset sequence
            if bottomOffsetScore != nil
            {
                if thisBottomOffsetScore < bottomOffsetScore!
                {
                    bottomOffsetScore = thisBottomOffsetScore
                    bottomOffsetIndex = offsetIndex
                    bottomOffsetSequence = longestBottomSequence
                }
            }
            else
            {
                bottomOffsetScore = thisBottomOffsetScore
                bottomOffsetIndex = offsetIndex
                bottomOffsetSequence = longestBottomSequence
            }
            
            offsetIndex += 1
            
            // Progress Indicator Info
            DispatchQueue.main.async {
                ProgressBot.sharedInstance.currentProgress = offsetIndex
                ProgressBot.sharedInstance.totalToAnalyze = tempOffsetScores.count
                ProgressBot.sharedInstance.progressMessage = "\(scoringOffsetsString) \(offsetIndex)"
            }
            //
            tempOffsetScores.delete()
        }
        
        /// Top score is the required rule
        /// Divide the score by Ta * Tb to get the accuracy
        let requiredOffsetRuleAccuracy = abs(topOffsetScore!)/Float(allowedConnectionsAnalyzed * blockedConnectionsAnalyzed)
        
        let requiredOffsetHash: RMap = [requiredOffsetSequenceKey: topOffsetSequence!.hexEncodedString(), requiredOffsetAccuracyKey: "\(requiredOffsetRuleAccuracy)", requiredOffsetIndexKey: topOffsetIndex!.string, requiredOffsetByteCountKey: String(describing: topOffsetSequence!)]
        requiredOffsetHash.key = requiredOffsetKey
        
        /// Bottom score is the forbidden rule
        
        /// Divide the score by Ta * Tb to get the accuracy
        let forbiddenOffsetRuleAccuracy = abs(bottomOffsetScore!)/Float(allowedConnectionsAnalyzed * blockedConnectionsAnalyzed)
        let forbiddenOffsetHash: RMap = [forbiddenOffsetSequenceKey: bottomOffsetSequence!.hexEncodedString(), forbiddenOffsetAccuracyKey: "\(forbiddenOffsetRuleAccuracy)", forbiddenOffsetIndexKey: bottomOffsetIndex!.string, forbiddenOffsetByteCountKey: String(describing: bottomOffsetSequence!)]
        forbiddenOffsetHash.key = forbiddenOffsetKey
    }
    
    
    func scoreFloatSequences(allowedFloatKey: String, blockedFloatKey: String, requiredFloatKey: String, forbiddenFloatKey: String, floatScoresKey: String)
    {
        ProgressBot.sharedInstance.currentProgress = 0
        ProgressBot.sharedInstance.totalToAnalyze = 3
        ProgressBot.sharedInstance.progressMessage = "\(scoringFloatSequencesString) \(0) of \(3)"
        
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
        
        /// Top score is the required rule
        guard let (_, requiredSequenceScore) = sequenceScoresSet.first
            else
        {
            print("😮  Unable to get a required rule for float sequences.")
            return
        }
        
        // Get all sequences with this top score
        guard let longestTopSequence: Data = sequenceScoresSet.getLongestSequence(withScore: Double(requiredSequenceScore))
            else
        {
            print("Unable to find the longest top float sequence.")
            return
        }
        
        ProgressBot.sharedInstance.currentProgress = 1
        ProgressBot.sharedInstance.progressMessage = "\(scoringFloatSequencesString) \(1) of \(3)"
        
        //TODO: There's some hopping around between float and double that could be cleaned up
        /// Divide the score by Ta * Tb to get the accuracy
        let requiredSequenceRuleAccuracy = abs(requiredSequenceScore)/Float(allowedConnectionsAnalyzed * blockedConnectionsAnalyzed)
        let requiredSequenceSet: RSortedSet<Data> = RSortedSet(key: requiredFloatKey)
        requiredSequenceSet.delete()
        _ = requiredSequenceSet.insert((longestTopSequence, requiredSequenceRuleAccuracy))
        
        /// Bottom score is the forbidden rule
        guard let (_, forbiddenSequenceScore) = sequenceScoresSet.last
            else
        {
            print("😮  Unable to get a forbidden rule for float sequences.")
            return
        }
        
        guard let longestBottomSequence: Data = sequenceScoresSet.getLongestSequence(withScore: Double(forbiddenSequenceScore))
            else
        {
            print("\nFailed to get the longest forbidden float sequence.")
            return
        }
        
        ProgressBot.sharedInstance.currentProgress = 2
        ProgressBot.sharedInstance.progressMessage = "\(scoringFloatSequencesString) \(2) of \(3)"
        
        //TODO: There's some hopping around between float and double that could be cleaned up
        /// Divide the score by Ta * Tb to get the accuracy
        let forbiddenSequenceRuleAccuracy = abs(forbiddenSequenceScore)/Float(allowedConnectionsAnalyzed * blockedConnectionsAnalyzed)
        let forbiddenSequenceSet: RSortedSet<Data> = RSortedSet(key: forbiddenFloatKey)
        forbiddenSequenceSet.delete()
        _ = forbiddenSequenceSet.insert((longestBottomSequence, forbiddenSequenceRuleAccuracy))
        
        ProgressBot.sharedInstance.currentProgress = 3
        ProgressBot.sharedInstance.progressMessage = "\(scoringFloatSequencesString) \(3) of \(3)"
    }
}
