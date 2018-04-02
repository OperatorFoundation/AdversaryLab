//
//  Sequences.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn
import Datable

let tlsRequestStart=Data(bytes: [0x16, 0x03])
let tlsResponseStart=Data(bytes: [0x16, 0x03])
let commonNameStart=Data(bytes: [0x55, 0x04, 0x03])
let commonNameEnd=Data(bytes: [0x30])

func isTls12(forConnection connection: ObservedConnection) -> Bool
{
    // Get the in packet that corresponds with this connection ID
    let inPacketHash: RMap<String, Data> = RMap(key: connection.incomingKey)
    guard let inPacket: Data = inPacketHash[connection.connectionID] else {
        NSLog("Error, connection has no incoming packet")
        return false
    }

    let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
    guard let outPacket: Data = outPacketHash[connection.connectionID] else {
        NSLog("Error, connection has no outgoing packet")
        return false
    }

    let maybeRequestRange = inPacket.range(of: tlsRequestStart, options: .anchored, in: nil)
    let maybeResponseRange = outPacket.range(of: tlsResponseStart, options: .anchored, in: nil)

    guard maybeRequestRange != nil
    else
    {
        NSLog("TLS request not found \(inPacket as NSData)")
        return false
    }
    
    guard maybeResponseRange != nil else {
        NSLog("TLS response not found \(outPacket as NSData)")
        return false
    }
        
    return true
}

func processTls12(_ connection: ObservedConnection)
{
    let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
    let tlsCommonNameSet: RSortedSet<String> = RSortedSet(key: connection.outgoingTlsCommonNameKey)

    // Get the out packet that corresponds with this connection ID
    guard let outPacket: Data = outPacketHash[connection.connectionID]
        else
    {
        NSLog("No TLS outgoing packet found")
        return
    }
    
    let maybeBegin = findCommonNameStart(outPacket)
    guard let begin = maybeBegin else {
        NSLog("No common name beginning found")
        NSLog("\(connection.outgoingKey) \(connection.connectionID) \(outPacket.count)")
        return
    }
    
    let maybeEnd = findCommonNameEnd(outPacket, begin+commonNameStart.count)
    guard let end = maybeEnd else {
        NSLog("No common name beginning end")
        return
    }
    
    let commonData = extract(outPacket, begin+commonNameStart.count, end-1)
    let commonName = commonData.string
    NSLog("Found TLS 1.2 common name: \(commonName) \(commonName.count) \(begin) \(end)")
    
    let _ = tlsCommonNameSet.incrementScore(ofField: commonName, byIncrement: 1)
}

func scoreTls12()
{
    let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
    
    /// |A| is the number of Allowed TLS Names analyzed - Allowed:Outgoing:TLS:CommonName
    var allowedPacketsAnalyzed = 0.0
    if let allowedConnectionsAnalyzedCount: Int = packetStatsDict[allowedPacketsAnalyzedKey]
    {
        allowedPacketsAnalyzed = Double(allowedConnectionsAnalyzedCount)
    }
    
    /// |B| is the number of Blocked TLS Names analyzed - Blocked:Outgoing:TLS:CommonName
    var blockedPacketsAnalyzed = 0.0
    if let blockedConnectionsAnalyzedCount: Int = packetStatsDict[blockedPacketsAnalyzedKey]
    {
        blockedPacketsAnalyzed = Double(blockedConnectionsAnalyzedCount)
    }
    
    /// A is the sorted set of TLS names for the Allowed traffic
    let allowedTLSNamesSet: RSortedSet<String> = RSortedSet(key: allowedTlsCommonNameKey)
    /// B is the sorted set of TLS names for the Blocked traffic
    let blockedTLSNamesSet: RSortedSet<String> = RSortedSet(key: blockedTlsCommonNameKey)
    /// L is the union of the keys for A and B (without the scores)
    let allTLSNamesSet = newStringSet(from: [allowedTLSNamesSet, blockedTLSNamesSet])
    
    /// for name in Names
    for tlsName in allTLSNamesSet
    {
        let aCount = Double(allowedTLSNamesSet[tlsName] ?? 0.0)
        let bCount = Double(blockedTLSNamesSet[tlsName] ?? 0.0)
        
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
        let requiredTLSNames: RSortedSet<String> = RSortedSet(key: allowedTlsScoreKey)
        let (newRSInserted, returnedRS) = requiredTLSNames.insert((tlsName, Float(requiredAccuracy)))
        print("\nSaved required accuracy \(requiredAccuracy) for TLS name \(tlsName)")
        print("\(newRSInserted): \(returnedRS)")
        
        let forbiddenTLSNames: RSortedSet<String> = RSortedSet(key: blockedTlsScoreKey)
        let (newFSInserted, returnedFS) = forbiddenTLSNames.insert((tlsName, Float(forbiddenAccuracy)))
        print("Saved forbidden accuracy \(forbiddenAccuracy) for TLS name \(tlsName) to \(blockedTlsCommonNameKey)")
        print("\(newFSInserted): \(returnedFS)")
    }
}

private func findCommonNameStart(_ outPacket: Data) -> Int? {
    let maybeRange = outPacket.range(of: commonNameStart)
    guard let range = maybeRange else {
        return nil
    }
    
    let maybeNextRange = outPacket.range(of: commonNameStart, options: [], in: range.upperBound..<outPacket.count)
    guard let nextRange = maybeNextRange else {
        return nil
    }
    
    return nextRange.lowerBound
}

private func findCommonNameEnd(_ outPacket: Data, _ begin: Int) -> Int? {
    let maybeRange = outPacket.range(of: commonNameEnd, options: [], in: begin..<outPacket.count)
    guard let range = maybeRange else {
        return nil
    }
    
    return range.lowerBound
}

func newStringSet(from redisSets:[RSortedSet<String>]) -> Set<String>
{
    var swiftSet = Set<String>()
    for set in redisSets
    {
        for i in 0 ..< set.count
        {
            if let newMember: String = set[i]
            {
                swiftSet.insert(newMember)
            }
        }
    }
    
    return swiftSet
}

private func extract(_ outPacket: Data, _ begin: Int, _ end: Int) -> Data {
    return outPacket[begin+2...end]
}
