////
////  Sequences.swift
////  AdversaryLabSwift
////
////  Created by Adelita Schule on 2/8/18.
////  Copyright © 2018 Operator Foundation. All rights reserved.
////
//
//import Foundation
//
//import Abacus
//import Datable
//
//func processSequences(labData: LabData, forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
//{
//    // TODO: Correct sequence implementation
//    let sequenceCounter = SequenceCounter()
//    
//    switch connection.connectionType
//    {
//        case .transportA:
//            // Get the out packet that corresponds with this connection ID
//                guard let outPacket = labData.connectionGroupData.aConnectionData.outgoingPackets[connection.connectionID]
//            else { return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID)) }
//            
//            // Get the in packet that corresponds with this connection ID
//                guard let inPacket = labData.connectionGroupData.aConnectionData.incomingPackets[connection.connectionID]
//            else { return(false, PacketLengthError.noInPacketForConnection(connection.connectionID)) }
//            
//            /// Sanity Check
//            if outPacket.count < 10 || inPacket.count < 10
//            {
//                print("\n### packet count = \(String(outPacket.count))")
//                print("\n⁉️  We got a weird out packet size... \(String(describing: String(data: outPacket, encoding: .utf8)))<----")
//            }
//            
//            sequenceCounter.add(sequence: outPacket, aOrB: true)
//            sequenceCounter.add(sequence: inPacket, aOrB: true)
//
//        case .transportB:
//                guard let outPacket = labData.connectionGroupData.bConnectionData.outgoingPackets[connection.connectionID]
//            else
//            { return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID)) }
//            
//                guard let inPacket = labData.connectionGroupData.bConnectionData.incomingPackets[connection.connectionID]
//            else
//            { return (false, PacketLengthError.noInPacketForConnection(connection.connectionID)) }
//            
//            /// Sanity Check
//            if outPacket.count < 10 || inPacket.count < 10
//            {
//                print("\n### packet count = \(String(outPacket.count))")
//                print("\n⁉️  We got a weird out packet size... \(String(describing: String(data: outPacket, encoding: .utf8)))<----")
//            }
//            
//            sequenceCounter.add(sequence: outPacket, aOrB: false)
//            sequenceCounter.add(sequence: inPacket, aOrB: false)
//        
//    }
//    
//    return (true, nil)
//}
//
//func scoreAllFloatSequences(configModel: ProcessingConfigurationModel)
//{
//    // Outgoing
//    scoreFloatSequences(connectionDirection: .outgoing, configModel: configModel)
//    
//    // Incoming
//    scoreFloatSequences(connectionDirection: .incoming, configModel: configModel)
//}
//
//func scoreAllOffsetSequences(configModel: ProcessingConfigurationModel)
//{
//    // Outgoing
//    scoreOffsetSequences(connectionDirection: .outgoing, configModel: configModel)
//    
//    // Incoming
//    scoreOffsetSequences(connectionDirection: .incoming, configModel: configModel)
//}
//
//// TODO: Sequence Scoring
//func scoreOffsetSequences(connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
//{
////    let allowedOffsetKey: String
////    let blockedOffsetKey: String
////    let requiredOffsetKey: String
////    let forbiddenOffsetKey: String
////    let trainingSequencesKey: String
////    let trainingSequenceOffsetsKey: String
////
////    // These arrays will be saved to the DB after the loop to be used for training a model
////    var topSequences = [OffsetSequenceRecord]()
////    var bottomSequences = [OffsetSequenceRecord]()
////
////    switch connectionDirection
////    {
////    case .incoming:
////        allowedOffsetKey = allowedIncomingOffsetSequencesKey
////        blockedOffsetKey = blockedIncomingOffsetSequencesKey
////        requiredOffsetKey = incomingRequiredOffsetKey
////        forbiddenOffsetKey = incomingForbiddenOffsetKey
////        trainingSequencesKey = incomingOffsetTrainingSequencesKey
////        trainingSequenceOffsetsKey = incomingOffsetTrainingSequenceOffsetsKey
////    case .outgoing:
////        allowedOffsetKey = allowedOutgoingOffsetSequencesKey
////        blockedOffsetKey = blockedOutgoingOffsetSequencesKey
////        requiredOffsetKey = outgoingRequiredOffsetKey
////        forbiddenOffsetKey = outgoingForbiddenOffsetKey
////        trainingSequencesKey = outgoingOffsetTrainingSequencesKey
////        trainingSequenceOffsetsKey = outgoingOffsetTrainingSequenceOffsetsKey
////    }
////
////    let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
////
////    /// Ta is the number of Allowed connections analyzed (Allowed:Connections:Analyzed)
////    var allowedConnectionsAnalyzed = 0.0
////    if let allowedConnectionsAnalyzedCount: Int = packetStatsDict[allowedPacketsAnalyzedKey]
////    {
////        allowedConnectionsAnalyzed = Double(allowedConnectionsAnalyzedCount)
////    }
////
////    /// Tb is the number of Blocked connections analyzed (Blocked:Connections:Analyzed)
////    var blockedConnectionsAnalyzed = 0.0
////    if let blockedConnectionsAnalyzedCount: Int = packetStatsDict[blockedPacketsAnalyzedKey]
////    {
////        blockedConnectionsAnalyzed = Double(blockedConnectionsAnalyzedCount)
////    }
////
////    /// A is the sorted set of sequences for the Allowed traffic (key: allowedFloatSequenceKey)
////    /// B is the sorted set of sequences for the Blocked traffic (key: blockedFloatSequenceKey)
////
////    //Form union for each float:index and add to one big set before moving on with scoring
////    var offsetIndex = 0
////    var topOffsetScore: Float?
////    var topOffsetIndex: Int?
////    var topOffsetSequence: Data?
////
////    var bottomOffsetIndex: Int?
////    var bottomOffsetSequence: Data?
////    var bottomOffsetScore: Float?
////
////    while true
////    {
////        let tempOffsetScoresKey = "tempOffsetScores"
////
////        /// Returns a new sorted set with the correct scoring
////        let tempOffsetScores: RSortedSet<Data> = RSortedSet(
////            unionOf: allowedOffsetKey + ":\(offsetIndex)",
////            scoresMultipliedBy: blockedConnectionsAnalyzed,
////            secondSetKey: blockedOffsetKey + ":\(offsetIndex)",
////            scoresMultipliedBy: -allowedConnectionsAnalyzed,
////            newSetKey: tempOffsetScoresKey)
////
////        if tempOffsetScores.count < 1
////        {
////            print("\n-------->Offset union returned empty list, breaking list.<--------------\n")
////            break
////        }
////
////        guard let (_, thisTopOffsetScore) = tempOffsetScores.first
////            else
////        {
////            break
////        }
////
////        guard let longestTopSequence: Data = tempOffsetScores.getLongestSequence(withScore: Double(thisTopOffsetScore))
////            else
////        {
////            print("\nFailed to find the longest top offset sequence.")
////            break
////        }
////
////        // Save the top scoring, longest offset
////        if topOffsetScore != nil
////        {
////            if thisTopOffsetScore > topOffsetScore!
////            {
////                topOffsetScore = thisTopOffsetScore
////                topOffsetSequence = longestTopSequence
////                topOffsetIndex = offsetIndex
////            }
////        }
////        else
////        {
////            topOffsetScore = thisTopOffsetScore
////            topOffsetSequence = longestTopSequence
////            topOffsetIndex = offsetIndex
////        }
////
////        // Get the bottom scoring sequence and score
////        guard let (_, thisBottomOffsetScore) = tempOffsetScores.last
////            else
////        {
////            break
////        }
////
////        // Use this bottom score to fetch all results with this score and choose the longest
////        guard let longestBottomSequence: Data = tempOffsetScores.getLongestSequence(withScore: Double(thisBottomOffsetScore))
////        else
////        {
////            print("\nFailed to find the longest bottom offset sequence.")
////            break
////        }
////
////        // Save the lowest scoring, longest, offset sequence
////        if bottomOffsetScore != nil
////        {
////            if thisBottomOffsetScore < bottomOffsetScore!
////            {
////                bottomOffsetScore = thisBottomOffsetScore
////                bottomOffsetIndex = offsetIndex
////                bottomOffsetSequence = longestBottomSequence
////            }
////        }
////        else
////        {
////            bottomOffsetScore = thisBottomOffsetScore
////            bottomOffsetIndex = offsetIndex
////            bottomOffsetSequence = longestBottomSequence
////        }
////
////        offsetIndex += 1
////
////        // Let's gather some training data
////        let topOffset = OffsetSequenceRecord(offset: offsetIndex, sequence: longestTopSequence, score: thisTopOffsetScore)
////        topSequences.append(topOffset)
////        let bottomOffset = OffsetSequenceRecord(offset: offsetIndex, sequence: longestBottomSequence, score: thisBottomOffsetScore)
////        bottomSequences.append(bottomOffset)
////
////        tempOffsetScores.delete()
////    }
////
////    /// Top score is the required rule
////    /// Divide the score by Ta * Tb to get the accuracy
////    let requiredOffsetRuleAccuracy = abs(topOffsetScore!)/Float(allowedConnectionsAnalyzed * blockedConnectionsAnalyzed)
////
////    let requiredOffsetHash: RMap = [requiredOffsetSequenceKey: topOffsetSequence!.hexEncodedString(), requiredOffsetAccuracyKey: "\(requiredOffsetRuleAccuracy)", requiredOffsetIndexKey: topOffsetIndex!.string, requiredOffsetByteCountKey: String(describing: topOffsetSequence!)]
////    requiredOffsetHash.key = requiredOffsetKey
////
////    /// Bottom score is the forbidden rule
////
////    /// Divide the score by Ta * Tb to get the accuracy
////    let forbiddenOffsetRuleAccuracy = abs(bottomOffsetScore!)/Float(allowedConnectionsAnalyzed * blockedConnectionsAnalyzed)
////    let forbiddenOffsetHash: RMap = [forbiddenOffsetSequenceKey: bottomOffsetSequence!.hexEncodedString(), forbiddenOffsetAccuracyKey: "\(forbiddenOffsetRuleAccuracy)", forbiddenOffsetIndexKey: bottomOffsetIndex!.string, forbiddenOffsetByteCountKey: String(describing: bottomOffsetSequence!)]
////    forbiddenOffsetHash.key = forbiddenOffsetKey
////
////    // Sort top sequences high to low
////    topSequences.sort
////    {
////        (firstRecord, secondRecord) -> Bool in
////
////        if firstRecord.score > secondRecord.score
////        {
////            return true
////        }
////        else if firstRecord.score == secondRecord.score
////        {
////            if firstRecord.sequence.count >= secondRecord.sequence.count
////            {
////                return true
////            }
////            else
////            {
////                return false
////            }
////        }
////        else
////        {
////            return false
////        }
////    }
////
////    // Sort bottom sequences low to high
////    bottomSequences.sort
////    {
////        (firstRecord, secondRecord) -> Bool in
////
////        if firstRecord.score < secondRecord.score
////        {
////            return true
////        }
////        else if firstRecord.score == secondRecord.score
////        {
////            if firstRecord.sequence.count <= secondRecord.sequence.count
////            {
////                return true
////            }
////            else
////            {
////                return false
////            }
////        }
////        else
////        {
////            return false
////        }
////    }
////
////    // Narrow training data to top and bottom ten
////    let topTenSequences = [OffsetSequenceRecord](topSequences[0..<10])
////    let bottomTenSequences = [OffsetSequenceRecord](bottomSequences[0..<10])
////
////    // Save them to Redis in one list of 20
////    // Also save their offsets in parallel
////    let trainingSequences: RList<Data> = RList(key: trainingSequencesKey)
////    let trainingSequenceOffsets: RList<Int> = RList(key: trainingSequenceOffsetsKey)
////    for topRecord in topTenSequences
////    {
////        trainingSequences.append(topRecord.sequence)
////        trainingSequenceOffsets.append(topRecord.offset)
////    }
////
////    for bottomRecord in bottomTenSequences
////    {
////        trainingSequences.append(bottomRecord.sequence)
////        trainingSequenceOffsets.append(bottomRecord.offset)
////    }
////
////    SequencesCoreML().scoreOffsetSequences(connectionDirection: connectionDirection, configModel: configModel)
//}
//
//// TODO: Sequence Scoring
//func scoreFloatSequences(connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
//{
////    let allowedFloatKey: String
////    let blockedFloatKey: String
////    let requiredFloatKey: String
////    let forbiddenFloatKey: String
////    let floatScoresKey: String
////    let trainingSequencesKey: String
////
////    switch connectionDirection
////    {
////    case .outgoing:
////        allowedFloatKey = allowedOutgoingFloatingSequencesKey
////        blockedFloatKey = blockedOutgoingFloatingSequencesKey
////        requiredFloatKey = outgoingRequiredFloatSequencesKey
////        forbiddenFloatKey = outgoingForbiddenFloatSequencesKey
////        floatScoresKey = outgoingFloatSequenceScoresKey
////        trainingSequencesKey = outgoingFloatTrainingSequencesKey
////    case .incoming:
////        allowedFloatKey = allowedIncomingFloatingSequencesKey
////        blockedFloatKey = blockedIncomingFloatingSequencesKey
////        requiredFloatKey = incomingRequiredFloatSequencesKey
////        forbiddenFloatKey = incomingForbiddenFloatSequencesKey
////        floatScoresKey = incomingFloatSequenceScoresKey
////        trainingSequencesKey = incomingFloatTrainingSequencesKey
////    }
////
////    let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
////
////    /// Ta is the number of Allowed connections analyzed (Allowed:Connections:Analyzed)
////    var allowedConnectionsAnalyzed = 0.0
////    if let allowedConnectionsAnalyzedCount: Int = packetStatsDict[allowedPacketsAnalyzedKey]
////    {
////        allowedConnectionsAnalyzed = Double(allowedConnectionsAnalyzedCount)
////    }
////
////    /// Tb is the number of Blocked connections analyzed (Blocked:Connections:Analyzed)
////    var blockedConnectionsAnalyzed = 0.0
////    if let blockedConnectionsAnalyzedCount: Int = packetStatsDict[blockedPacketsAnalyzedKey]
////    {
////        blockedConnectionsAnalyzed = Double(blockedConnectionsAnalyzedCount)
////    }
////
////    /// A is the sorted set of sequences for the Allowed traffic (key: allowedFloatSequenceKey)
////    /// B is the sorted set of sequences for the Blocked traffic (key: blockedFloatSequenceKey)
////
////    /// Returns a new sorted set with the correct scoring (key: sequenceScoresKey)
////    let oldSequenceScoresSet: RSortedSet<Data> = RSortedSet(key: floatScoresKey)
////    oldSequenceScoresSet.delete()
////
////    let sequenceScoresSet: RSortedSet<Data> = RSortedSet(unionOf: allowedFloatKey, scoresMultipliedBy: blockedConnectionsAnalyzed, secondSetKey: blockedFloatKey, scoresMultipliedBy: -allowedConnectionsAnalyzed, newSetKey: floatScoresKey)
////
////    /// Top score is the required rule
////    guard let (_, requiredSequenceScore) = sequenceScoresSet.first
////    else
////    {
////        print("😮  Unable to get a required rule for float sequences.")
////        return
////    }
////
////    // Get all sequences with this top score
////    guard let longestTopSequence: Data = sequenceScoresSet.getLongestSequence(withScore: Double(requiredSequenceScore))
////    else
////    {
////        print("Unable to find the longest top float sequence.")
////        return
////    }
////
////    /// Divide the score by Ta * Tb to get the accuracy
////    let requiredSequenceRuleAccuracy = abs(requiredSequenceScore)/Float(allowedConnectionsAnalyzed * blockedConnectionsAnalyzed)
////    let requiredSequenceSet: RSortedSet<Data> = RSortedSet(key: requiredFloatKey)
////    requiredSequenceSet.delete()
////    _ = requiredSequenceSet.insert((longestTopSequence, requiredSequenceRuleAccuracy))
////
////    /// Bottom score is the forbidden rule
////    guard let (_, forbiddenSequenceScore) = sequenceScoresSet.last
////    else
////    {
////        print("😮  Unable to get a forbidden rule for float sequences.")
////        return
////    }
////
////    guard let longestBottomSequence: Data = sequenceScoresSet.getLongestSequence(withScore: Double(forbiddenSequenceScore))
////    else
////    {
////        print("\nFailed to get the longest forbidden float sequence.")
////        return
////    }
////
////    /// Divide the score by Ta * Tb to get the accuracy
////    let forbiddenSequenceRuleAccuracy = abs(forbiddenSequenceScore)/Float(allowedConnectionsAnalyzed * blockedConnectionsAnalyzed)
////    let forbiddenSequenceSet: RSortedSet<Data> = RSortedSet(key: forbiddenFloatKey)
////    forbiddenSequenceSet.delete()
////    _ = forbiddenSequenceSet.insert((longestBottomSequence, forbiddenSequenceRuleAccuracy))
////
////    // Save top 10 and bottom 10 to the DB to use later for model training
////    let trainingSequences: RList<Data> = RList(key: trainingSequencesKey)
////    if sequenceScoresSet.count == 20
////    {
////        for index in 0 ..< sequenceScoresSet.count
////        {
////            if let sequence = sequenceScoresSet[index]
////            {
////                trainingSequences.append(sequence)
////            }
////        }
////    }
////    else if sequenceScoresSet.count > 20
////    {
////        //ZPOPMAX
////        guard let highestResults = sequenceScoresSet.removeHighest(numberToRemove: 10)
////        else
////        {
////            sequenceScoresSet.delete()
////            return
////        }
////
////        for highResult in highestResults
////        {
////            trainingSequences.append(highResult.value)
////        }
////
////        //ZPOPMIN
////        guard let lowestResults = sequenceScoresSet.removeLowest(numberToRemove: 10)
////        else
////        {
////            sequenceScoresSet.delete()
////            return
////        }
////
////        for lowResult in lowestResults
////        {
////            trainingSequences.append(lowResult.value)
////        }
////    }
////
////    sequenceScoresSet.delete()
////
////    //Train or Test depending on UI
////    SequencesCoreML().scoreFloatSequences(connectionDirection: connectionDirection, configModel: configModel)
//}
//
//
//struct OffsetSequenceRecord
//{
//    var offset: Int
//    var sequence: Data
//    var score: Float
//}
