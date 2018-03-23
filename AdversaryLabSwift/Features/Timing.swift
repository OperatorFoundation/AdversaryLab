//
//  Timing.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn

func processTiming(forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
{
    let outPacketDateHash: RMap<String, Double> = RMap(key: connection.outgoingDateKey)
    let inPacketDateHash: RMap<String, Double> = RMap(key: connection.incomingDateKey)
    let timeDifferenceList: RList<Double> = RList(key: connection.timeDifferenceKey)
    
    // Get the out packet time stamp
    guard let outTimeInterval = outPacketDateHash[connection.connectionID]
        else
    {
        return (false, PacketTimingError.noOutPacketDateForConnection(connection.connectionID))
    }
    
    // Get the in packet time stamp
    guard let inTimeInterval = inPacketDateHash[connection.connectionID]
        else
    {
        return (false, PacketTimingError.noInPacketDateForConnection(connection.connectionID))
    }
    
    // Add the time difference for this connection to the database
    let timeDifference = (outTimeInterval - inTimeInterval)
    timeDifferenceList.append(timeDifference)
    
    return (true, nil)
}

func scoreAllTiming()
{
    scoreTiming(allowedTimeDifferenceKey: allowedConnectionsTimeDiffKey, allowedTimeDifferenceBinsKey: allowedConnectionsTimeDiffBinsKey, blockedTimeDifferenceKey: blockedConnectionsTimeDiffKey, blockedTimeDifferenceBinsKey: blockedConnectionsTimeDiffBinsKey, requiredTimeDifferenceKey: requiredTimeDiffKey, forbiddenTimeDifferenceKey: forbiddenTimeDiffKey)
}


func scoreTiming(allowedTimeDifferenceKey: String, allowedTimeDifferenceBinsKey: String, blockedTimeDifferenceKey: String, blockedTimeDifferenceBinsKey: String, requiredTimeDifferenceKey: String, forbiddenTimeDifferenceKey: String)
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
    
    /// A is the sorted set of TimeDifference for the Allowed traffic
    let allowedTimeDifferenceList: RList<Double> = RList(key: allowedTimeDifferenceKey)
    let allowedTimeDifferenceBinsRSet: RSortedSet<Int> = RSortedSet(key: allowedTimeDifferenceBinsKey)

    //Sort into bins
    for timeDifferenceIndex in 0 ..< allowedTimeDifferenceList.count
    {
        guard let aTimeDifference = allowedTimeDifferenceList[timeDifferenceIndex]
            else
        {
            continue
        }
        
        for i in 0 ... 1000
        {
            //Everything 1000 or greater goes into this bin
            if i == 1000
            {
                if  aTimeDifference >= Double(i)
                {
                    _ = allowedTimeDifferenceBinsRSet.incrementScore(ofField: i, byIncrement: 1.0)
                }
            }
            //Everything of value i up to but exclusive of i + 1 goes here
            else if aTimeDifference >= Double(i), aTimeDifference < Double(i + 1)
            {
                _ = allowedTimeDifferenceBinsRSet.incrementScore(ofField: i, byIncrement: 1.0)
            }
        }
    }
    
    /// B is the sorted set of TimeDifference for the Blocked traffic
    let blockedTimeDifferenceList: RList<Double> = RList(key: blockedTimeDifferenceKey)
    let blockedTimeDifferenceBinsRSet: RSortedSet<Int> = RSortedSet(key: blockedTimeDifferenceBinsKey)

    //Sort into bins
    for timeDifferenceIndex in 0 ..< blockedTimeDifferenceList.count
    {
        guard let bTimeDifference = blockedTimeDifferenceList[timeDifferenceIndex]
            else
        {
            continue
        }
        
        for i in 0 ... 1000
        {
            //Everything 7 or greater goes into this bin
            if i == 1000
            {
                if bTimeDifference >= Double(i)
                {
                    _ = blockedTimeDifferenceBinsRSet.incrementScore(ofField: i, byIncrement: 1)
                }
            }
                //Everything of value i up to but exclusive of i + 1 goes here
            else if bTimeDifference >= Double(i) && bTimeDifference < Double(i + 1)
            {
                _ = blockedTimeDifferenceBinsRSet.incrementScore(ofField: i, byIncrement: 1)
            }
        }
    }
    
    /// L is the union of the keys for A and B (without the scores)
    let allTimeDifferencesSet = newIntSet(from: [allowedTimeDifferenceBinsRSet, blockedTimeDifferenceBinsRSet])
    
    /// for TimeDifference in L
    for timeDifference in allTimeDifferencesSet
    {
        let aCount = Double(allowedTimeDifferenceBinsRSet[timeDifference] ?? 0.0)
        let bCount = Double(blockedTimeDifferenceBinsRSet[timeDifference] ?? 0.0)
        
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
        let requiredTiming: RSortedSet<Int> = RSortedSet(key: requiredTimeDifferenceKey)
        let _ = requiredTiming.insert((timeDifference, Float(requiredAccuracy)))
        
        let forbiddenTiming: RSortedSet<Int> = RSortedSet(key: forbiddenTimeDifferenceKey)
        let _ = forbiddenTiming.insert((timeDifference, Float(forbiddenAccuracy)))
    }
}
