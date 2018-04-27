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
    var pauseBuddy = PauseBot()

    func analyzeConnections(configModel: ProcessingConfigurationModel)
    {
        ProgressBot.sharedInstance.analysisComplete = false
        
        analysisQueue.async
        {
            // Allowed Connections
            if configModel.removePackets
            {
                let allowedConnectionList: RList<String> = RList(key: allowedConnectionsKey)
                var numberOfAllowedAnalyzed = 0
                while allowedConnectionList.count != 0, configModel.processingEnabled
                {
                    // Get the first connection ID from the list
                    guard let allowedConnectionID = allowedConnectionList.removeFirst()
                        else
                    {
                        continue
                    }
                    
                    if "\(type(of: allowedConnectionID))" == "NSNull"
                    {
                        continue
                    }
                    
                    // Progress Indicator Info
                    numberOfAllowedAnalyzed += 1
                    let totalAllowedConnections = allowedConnectionList.count
                    
                    DispatchQueue.main.async
                    {
                        ProgressBot.sharedInstance.totalToAnalyze = totalAllowedConnections
                        ProgressBot.sharedInstance.currentProgress = numberOfAllowedAnalyzed
                        ProgressBot.sharedInstance.progressMessage = "\(analyzingAllowedConnectionsString) \(numberOfAllowedAnalyzed) of \(totalAllowedConnections)"
                    }
                    
                    // Analyze this connection
                    let allowedConnection = ObservedConnection(connectionType: .allowed, connectionID: allowedConnectionID)
                    
                    self.analyze(connection: allowedConnection, configModel: configModel)
                }
                
                // Blocked Connections
                let blockedConnectionList: RList<String> = RList(key: blockedConnectionsKey)
                var numberOfBlockedAnalyzed = 0
                while blockedConnectionList.count != 0, configModel.processingEnabled
                {
                    // Get the first connection ID from the list
                    guard let blockedConnectionID = blockedConnectionList.removeFirst()
                        else
                    {
                        continue
                    }
                    
                    if "\(type(of: blockedConnectionID))" == "NSNull"
                    {
                        continue
                    }
                    
                    // Progress Indicator Info
                    numberOfBlockedAnalyzed += 1
                    let totalBlockedConnections = blockedConnectionList.count
                    
                    DispatchQueue.main.async {
                        ProgressBot.sharedInstance.totalToAnalyze = totalBlockedConnections
                        ProgressBot.sharedInstance.currentProgress = numberOfBlockedAnalyzed
                        ProgressBot.sharedInstance.progressMessage = "\(analyzingBlockedConnectionString) \(numberOfBlockedAnalyzed) of \(totalBlockedConnections)"
                    }
                    
                    let blockedConnection = ObservedConnection(connectionType: .blocked, connectionID: blockedConnectionID)
                    
                    self.analyze(connection: blockedConnection, configModel: configModel)
                }
            }
            else
            {
                if self.pauseBuddy.processingComplete
                {
                    self.resetAnalysisData()
                    self.pauseBuddy.processingComplete = false
                }

                // Allowed Connections
                if self.pauseBuddy.processingAllowedConnections
                {
                    let allowedConnectionList: RList<String> = RList(key: allowedConnectionsKey)
                    
                    for index in self.pauseBuddy.currentIndex ..< allowedConnectionList.count
                    {
                        if configModel.processingEnabled
                        {
                            // Get the first connection ID from the list
                            guard let allowedConnectionID = allowedConnectionList[index]
                                else
                            {
                                continue
                            }
                            
                            if "\(type(of: allowedConnectionID))" == "NSNull"
                            {
                                continue
                            }
                            
                            // Progress Indicator Stuff
                            let totalAllowedConnections = allowedConnectionList.count
                            DispatchQueue.main.async
                            {
                                ProgressBot.sharedInstance.totalToAnalyze = totalAllowedConnections
                                ProgressBot.sharedInstance.currentProgress = index + 1
                                ProgressBot.sharedInstance.progressMessage = "\(analyzingAllowedConnectionsString) \(index + 1) of \(totalAllowedConnections)"
                            }
                            
                            // Analyze the connection
                            let allowedConnection = ObservedConnection(connectionType: .allowed, connectionID: allowedConnectionID)
                            self.analyze(connection: allowedConnection, configModel: configModel)
                            
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .updateStats, object: nil)
                                self.pauseBuddy.currentIndex = index + 1
                            }
                        }
                        else
                        {
                            print("\nI can't process this allowed connection. I'm paused! 🧐\n")
                            break
                        }
                    }
                    
                    self.pauseBuddy.processingAllowedConnections = false
                    self.pauseBuddy.currentIndex = 0
                }
                
                // Blocked Connections
                let blockedConnectionList: RList<String> = RList(key: blockedConnectionsKey)
                for index in self.pauseBuddy.currentIndex ..< blockedConnectionList.count
                {
                    if configModel.processingEnabled
                    {
                        // Get the first connection ID from the list
                        guard let blockedConnectionID = blockedConnectionList[index]
                            else
                        {
                            continue
                        }
                        
                        if "\(type(of: blockedConnectionID))" == "NSNull"
                        {
                            continue
                        }
                        
                        // Progress Indicator Stuff
                        let totalBlockedConnections = blockedConnectionList.count
                        DispatchQueue.main.async
                        {
                            ProgressBot.sharedInstance.totalToAnalyze = totalBlockedConnections
                            ProgressBot.sharedInstance.currentProgress = index + 1
                            ProgressBot.sharedInstance.progressMessage = "\(analyzingBlockedConnectionString) \(index + 1) of \(totalBlockedConnections)"
                        }
                        
                        // Analyze the connection
                        let blockedConnection = ObservedConnection(connectionType: .blocked, connectionID: blockedConnectionID)
                        self.analyze(connection: blockedConnection, configModel: configModel)
                        
                        // Let the UI know it needs an update
                        NotificationCenter.default.post(name: .updateStats, object: nil)
                        self.pauseBuddy.currentIndex = index + 1
                    }
                    else
                    {
                        print("\nI can't process this blocked connection. I'm paused! 🧐\n")
                        break
                    }
                    self.pauseBuddy.processingAllowedConnections = true
                    self.pauseBuddy.currentIndex = 0
                }
            }
            
            if configModel.processingEnabled
            {
                self.scoreConnections(configModel: configModel)
            }
            
            self.pauseBuddy.processingComplete = true
            DispatchQueue.main.async
            {
                ProgressBot.sharedInstance.analysisComplete = true
                NotificationCenter.default.post(name: .updateStats, object: nil)
            }
        }
    }
    
    func scoreConnections(configModel: ProcessingConfigurationModel)
    {
        sleep(1)
        scoreAllPacketLengths()
        sleep(1)
        scoreAllEntropy()
        sleep(1)
        scoreAllTiming()
        sleep(1)
        
        if configModel.enableSequenceAnalysis
        {
            scoreAllFloatSequences()
            scoreAllOffsetSequenes()
            sleep(1)
        }
        
        if configModel.enableTLSAnalysis
        {
            scoreTls12()
            sleep(1)
        }
        
        NotificationCenter.default.post(name: .updateStats, object: nil)
    }
    
    func analyze(connection: ObservedConnection, configModel: ProcessingConfigurationModel)
    {
        // Process Packet Lengths
        DispatchQueue.main.async{
            ProgressBot.sharedInstance.progressMessage = "Analyzing packet lengths for connection \(ProgressBot.sharedInstance.currentProgress) of \(ProgressBot.sharedInstance.totalToAnalyze)"
        }
        let (packetLengthProcessed, maybePacketlengthError) =  processPacketLengths(forConnection: connection)
        
        // Process Packet Timing
        DispatchQueue.main.async{
            ProgressBot.sharedInstance.progressMessage = "Analyzing Packet Timing for connection \(ProgressBot.sharedInstance.currentProgress) of \(ProgressBot.sharedInstance.totalToAnalyze)"
        }
        let (timingProcessed, maybePacketTimingError) = processTiming(forConnection: connection)
        
        // Process Offset and Float Sequences
        DispatchQueue.main.async{
            ProgressBot.sharedInstance.progressMessage = "Analyzing Subsequences for connection \(ProgressBot.sharedInstance.currentProgress) of \(ProgressBot.sharedInstance.totalToAnalyze)"
        }
        var subsequenceNoErrors = true
        var maybeSubsequenceError: Error? = nil
        if configModel.enableSequenceAnalysis
        {
            let (subsequenceProcessed, maybeSubsequenceErrorResponse) = processSequences(forConnection: connection)
            subsequenceNoErrors = subsequenceProcessed
            maybeSubsequenceError = maybeSubsequenceErrorResponse
        }
        
        // Process Entropy
        DispatchQueue.main.async{
            ProgressBot.sharedInstance.progressMessage = "Analyzing Entropy for connection \(ProgressBot.sharedInstance.currentProgress) of \(ProgressBot.sharedInstance.totalToAnalyze)"
        }
        let (entropyProcessed, _) = processEntropy(forConnection: connection)
        
        // Increment Packets Analyzed Field as we are done analyzing this connection
        if packetLengthProcessed, timingProcessed, subsequenceNoErrors, entropyProcessed
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

            if let offsetError = maybeSubsequenceError
            {
                print(offsetError)
            }
        }
        
        if configModel.enableTLSAnalysis {
            DispatchQueue.main.async{
                ProgressBot.sharedInstance.progressMessage = "Analyzing TLS Names for connection \(ProgressBot.sharedInstance.currentProgress) of \(ProgressBot.sharedInstance.totalToAnalyze)"
            }
            if let knownProtocol = detectKnownProtocol(connection: connection) {
                NSLog("It's TLS!")
                processKnownProtocol(knownProtocol, connection)
            } else {
                NSLog("Not TLS.")
            }
        }
    }
    
    func resetAnalysisData()
    {
        pauseBuddy = PauseBot()
        let packetsAnalyzedDictionary: RMap<String, Int> = RMap(key: packetStatsKey)
        packetsAnalyzedDictionary[allowedPacketsAnalyzedKey] = 0
        packetsAnalyzedDictionary[blockedPacketsAnalyzedKey] = 0
        
        // Delete all current scores
        let incomingRequiredLengths: RSortedSet<Int> = RSortedSet(key: incomingRequiredLengthsKey)
        incomingRequiredLengths.delete()
        let incomingForbiddenLengths: RSortedSet<Int> = RSortedSet(key: incomingForbiddenLengthsKey)
        incomingForbiddenLengths.delete()
        let outgoingRequiredLengths: RSortedSet<Int> = RSortedSet(key: outgoingRequiredLengthsKey)
        outgoingRequiredLengths.delete()
        let outgoingForbiddenLengths: RSortedSet<Int> = RSortedSet(key: outgoingForbiddenLengthsKey)
        outgoingForbiddenLengths.delete()
        let allowedOutLengthsSet: RSortedSet<Int> = RSortedSet(key: allowedOutgoingLengthsKey)
        allowedOutLengthsSet.delete()
        let allowedInLengthsSet: RSortedSet<Int> = RSortedSet(key: allowedIncomingLengthsKey)
        allowedInLengthsSet.delete()
        let blockedOutLengthsSet: RSortedSet<Int> = RSortedSet(key: blockedOutgoingLengthsKey)
        blockedOutLengthsSet.delete()
        let blockedInLengthsSet: RSortedSet<Int> = RSortedSet(key: blockedIncomingLengthsKey)
        blockedInLengthsSet.delete()
        
        let inRequiredFloats: RSortedSet<Data> = RSortedSet(key: incomingRequiredFloatSequencesKey)
        inRequiredFloats.delete()
        let inForbiddenFloats: RSortedSet<Data> = RSortedSet(key: incomingForbiddenFloatSequencesKey)
        inForbiddenFloats.delete()
        let outRequiredFloats: RSortedSet<Data> = RSortedSet(key: outgoingRequiredFloatSequencesKey)
        outRequiredFloats.delete()
        let outForbiddenFloats: RSortedSet<Data> = RSortedSet(key: outgoingForbiddenFloatSequencesKey)
        outForbiddenFloats.delete()
        let allowedInFloats: RSortedSet<Data> = RSortedSet(key: allowedIncomingFloatingSequencesKey)
        allowedInFloats.delete()
        let blockedInFloats: RSortedSet<Data> = RSortedSet(key: blockedIncomingFloatingSequencesKey)
        blockedInFloats.delete()
        let allowedOutFloats: RSortedSet<Data> = RSortedSet(key: allowedOutgoingFloatingSequencesKey)
        allowedOutFloats.delete()
        let blockedOutFloats: RSortedSet<Data> = RSortedSet(key: blockedOutgoingFloatingSequencesKey)
        blockedOutFloats.delete()
        
        let outRequiredOffsetHash: RMap<String, String> = RMap(key: outgoingRequiredOffsetKey)
        outRequiredOffsetHash.delete()
        let inRequiredOffsetHash: RMap<String, String> = RMap(key: incomingRequiredOffsetKey)
        inRequiredOffsetHash.delete()
        let outForbiddenOffsetHash: RMap<String, String> = RMap(key: outgoingForbiddenOffsetKey)
        outForbiddenOffsetHash.delete()
        let inForbiddenOffsetHash: RMap<String, String> = RMap(key: incomingForbiddenOffsetKey)
        inForbiddenOffsetHash.delete()
        
        let allowedInOffsets: RSortedSet<Data> = RSortedSet(key: allowedIncomingOffsetSequencesKey)
        allowedInOffsets.delete()
        let blockedInOffsets: RSortedSet<Data> = RSortedSet(key: blockedIncomingOffsetSequencesKey)
        blockedInOffsets.delete()
        let allowedOutOffsets: RSortedSet<Data> = RSortedSet(key: allowedOutgoingOffsetSequencesKey)
        allowedOutOffsets.delete()
        let blockedOutOffsets: RSortedSet<Data> = RSortedSet(key: blockedOutgoingOffsetSequencesKey)
        blockedOutOffsets.delete()
        
        let incomingRequiredEntropy: RSortedSet<Int> = RSortedSet(key: incomingRequiredEntropyKey)
        incomingRequiredEntropy.delete()
        let incomingForbiddenEntropy: RSortedSet<Int> = RSortedSet(key: incomingForbiddenEntropyKey)
        incomingForbiddenEntropy.delete()
        let outgoingRequiredEntropy: RSortedSet<Int> = RSortedSet(key: outgoingRequiredEntropyKey)
        outgoingRequiredEntropy.delete()
        let outgoingForbiddenEntropy: RSortedSet<Int> = RSortedSet(key: outgoingForbiddenEntropyKey)
        outgoingForbiddenEntropy.delete()
        let allowedInEntropyList: RList<Double> = RList(key: allowedIncomingEntropyKey)
        allowedInEntropyList.delete()
        let allowedOutEntropyList: RList<Double> = RList(key: allowedOutgoingEntropyKey)
        allowedOutEntropyList.delete()
        let blockedInEntropyList: RList<Double> = RList(key: blockedIncomingEntropyKey)
        blockedInEntropyList.delete()
        let blockedOutEntropyList: RList<Double> = RList(key: blockedOutgoingEntropyKey)
        blockedOutEntropyList.delete()
        let allowedInEntropyBinsRSet: RSortedSet<Int> = RSortedSet(key: allowedIncomingEntropyBinsKey)
        allowedInEntropyBinsRSet.delete()
        let allowedOutEntropyBinsRSet: RSortedSet<Int> = RSortedSet(key: allowedOutgoingEntropyBinsKey)
        allowedOutEntropyBinsRSet.delete()
        let blockedInEntropyBinsRSet: RSortedSet<Int> = RSortedSet(key: blockedIncomingEntropyBinsKey)
        blockedInEntropyBinsRSet.delete()
        let blockedOutEntropyBinsRSet: RSortedSet<Int> = RSortedSet(key: blockedOutgoingEntropyBinsKey)
        blockedOutEntropyBinsRSet.delete()
        
        let requiredTimeDiff: RSortedSet<Int> = RSortedSet(key: requiredTimeDiffKey)
        requiredTimeDiff.delete()
        let forbiddenTimeDiff: RSortedSet<Int> = RSortedSet(key: forbiddenTimeDiffKey)
        forbiddenTimeDiff.delete()
        let allowedTimeDifferenceList: RList<Double> = RList(key: allowedConnectionsTimeDiffKey)
        allowedTimeDifferenceList.delete()
        let blockedTimeDifferenceList: RList<Double> = RList(key: blockedConnectionsTimeDiffKey)
        blockedTimeDifferenceList.delete()
        let allowedTimeDifferenceBinsRSet: RSortedSet<Int> = RSortedSet(key: allowedConnectionsTimeDiffBinsKey)
        allowedTimeDifferenceBinsRSet.delete()
        let blockedTimeDifferenceBinsRSet: RSortedSet<Int> = RSortedSet(key: blockedConnectionsTimeDiffBinsKey)
        blockedTimeDifferenceBinsRSet.delete()
        
        let allowedTlsCommonNames: RSortedSet<String> = RSortedSet(key: allowedTlsCommonNameKey)
        allowedTlsCommonNames.delete()
        let blockedTlsCommonNames: RSortedSet<String> = RSortedSet(key: blockedTlsCommonNameKey)
        blockedTlsCommonNames.delete()
        
        NotificationCenter.default.post(name: .updateStats, object: nil)
    }
    
}
