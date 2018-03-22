//
//  ConnectionInspector.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn

class ConnectionInspector
{
    func analyzeConnections(enableSequenceAnalysis: Bool)
    {
        analysisQueue.async
        {
            // Allowed Connections
            let allowedConnectionList: RList<String> = RList(key: allowedConnectionsKey)
            while allowedConnectionList.count != 0
            {
                print("Analyzing an allowed connection async. Allowed connections left:\(allowedConnectionList.count)")
                // Get the first connection ID from the list
                guard let allowedConnectionID = allowedConnectionList.removeFirst()
                    else
                {
                    continue
                }
                
                print("\nPopped Allowed Connection: \(allowedConnectionID)")
                
                if "\(type(of: allowedConnectionID))" == "NSNull"
                {
                    continue
                }
                
                let allowedConnection = ObservedConnection(connectionType: .allowed, connectionID: allowedConnectionID)
                
                self.analyze(connection: allowedConnection, enableSequenceAnalysis: enableSequenceAnalysis)
            }
            
            // Blocked Connections
            let blockedConnectionList: RList<String> = RList(key: blockedConnectionsKey)
            while blockedConnectionList.count != 0
            {
                print("Analyzing a blocked connection async. Blocked connections left: \(blockedConnectionList.count)")
                // Get the first connection ID from the list
                guard let blockedConnectionID = blockedConnectionList.removeFirst()
                    else
                {
                    continue
                }
                print("\nPopped Blocked Connection: \(blockedConnectionID)")
                
                if "\(type(of: blockedConnectionID))" == "NSNull"
                {
                    continue
                }
                
                let blockedConnection = ObservedConnection(connectionType: .blocked, connectionID: blockedConnectionID)
                
                self.analyze(connection: blockedConnection, enableSequenceAnalysis: enableSequenceAnalysis)
            }
            
            self.scoreConnections()
        }

        // New Data Available for UI
        print("Analysis loop complete: SENDING UI UPDATE NOTIFICATION")
        NotificationCenter.default.post(name: .updateStats, object: nil)
    }
    
    func scoreConnections()
    {
        sleep(1)
        scoreAllPacketLengths()
        sleep(1)
        scoreAllFloatSequences()
        sleep(1)
        scoreAllEntropy()
        sleep(1)
        scoreAllTiming()
        sleep(1)
        NotificationCenter.default.post(name: .updateStats, object: nil)
    }
    
    func analyze(connection: ObservedConnection, enableSequenceAnalysis: Bool)
    {
        print("Analyzing a new connection: \(connection.connectionID)")
        // Process Packet Lengths
        let (packetLengthProcessed, maybePacketlengthError) =  processPacketLengths(forConnection: connection)
        
        // Process Packet Timing
        let (timingProcessed, maybePacketTimingError) = processTiming(forConnection: connection)
        
        // Process Offset Sequences
        var offsetSequenceNoErrors = true
        var maybeOffsetError: Error? = nil
        if enableSequenceAnalysis
        {
            let (offsetSequenceProcessed, maybeOffsetErrorResponse) = processOffsetSequences(forConnection: connection)
            offsetSequenceNoErrors = offsetSequenceProcessed
            maybeOffsetError = maybeOffsetErrorResponse
        }
        
        // Process Entropy
        let (entropyProcessed, maybeEntropyError) = processEntropy(forConnection: connection)
        
        // Increment Packets Analyzed Field as we are done analyzing this connection
        if packetLengthProcessed, timingProcessed, offsetSequenceNoErrors, entropyProcessed
        {
            let packetsAnalyzedDictionary: RMap<String, Int> = RMap(key: packetStatsKey)
            let _ = packetsAnalyzedDictionary.increment(field: connection.packetsAnalyzedKey)
        }
        else
        {
            if let packetLengthError = maybePacketlengthError
            {
                print(packetLengthError)
            }

            if let packetTimingError = maybePacketTimingError
            {
                print(packetTimingError)
            }

            if let offsetError = maybeOffsetError
            {
                print(offsetError)
            }

            if let entropyError = maybeEntropyError
            {
                print(entropyError)
            }
        }
        
        // New Data Available for UI
        NotificationCenter.default.post(name: .updateStats, object: nil)
    }
    
}
