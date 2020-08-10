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
                        { continue }
                        
                        if "\(type(of: allowedConnectionID))" == "NSNull"
                        { continue }
                        
                        // Progress Indicator Stuff
                        let totalAllowedConnections = allowedConnectionList.count
                        DispatchQueue.main.async
                        {
                            ProgressBot.sharedInstance.update(progressMessage: "\(analyzingAllowedConnectionsString) \(index + 1) of \(totalAllowedConnections)", totalToAnalyze: totalAllowedConnections, currentProgress: index + 1)
                        }
                        
                        // Analyze the connection
                        let allowedConnection = ObservedConnection(connectionType: .transportA, connectionID: allowedConnectionID)
                        self.analyze(connection: allowedConnection, configModel: configModel)
                        
                        DispatchQueue.main.async
                        {
                            //NotificationCenter.default.post(name: .updateStats, object: nil)
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
                        else { continue }
                    
                    if "\(type(of: blockedConnectionID))" == "NSNull"
                    { continue }
                    
                    // Progress Indicator Stuff
                    let totalBlockedConnections = blockedConnectionList.count
                    DispatchQueue.main.async
                    {
                        ProgressBot.sharedInstance.update(progressMessage: "\(analyzingBlockedConnectionString) \(index + 1) of \(totalBlockedConnections)", totalToAnalyze: totalBlockedConnections, currentProgress: index + 1)
                    }
                    
                    // Analyze the connection
                    let blockedConnection = ObservedConnection(connectionType: .transportB, connectionID: blockedConnectionID)
                    self.analyze(connection: blockedConnection, configModel: configModel)
                    
                    // Let the UI know it needs an update
                    //NotificationCenter.default.post(name: .updateStats, object: nil)
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
        ProgressBot.sharedInstance.analysisComplete = false
        var totalToScore = 4
        var currentProgress = 0
        var actionString = "Scoring"
        sleep(1)
        
        if configModel.trainingMode
        {
            actionString = "Training"
            if configModel.enableSequenceAnalysis
            {
                totalToScore += 1
            }
        }
        else
        {
            actionString = "Testing"
        }
        
        if configModel.enableTLSAnalysis
        {
            totalToScore += 1
            currentProgress += 1
            
            ProgressBot.sharedInstance.update(progressMessage: "\(actionString) TLS names.", totalToAnalyze: totalToScore, currentProgress: currentProgress)
            
            TLS12CoreML().scoreTLS12(configModel: configModel)
            sleep(1)
        }
        
        currentProgress += 1
        ProgressBot.sharedInstance.update(progressMessage: "\(actionString) packet lengths.", totalToAnalyze: totalToScore, currentProgress: currentProgress)
        PacketLengthsCoreML().scoreAllPacketLengths(configModel: configModel)
        sleep(1)
        
        currentProgress += 1
        ProgressBot.sharedInstance.update(progressMessage: "\(actionString) entropy.", totalToAnalyze: totalToScore, currentProgress: currentProgress)
        EntropyCoreML().scoreAllEntropyInDatabase(configModel: configModel)
        sleep(1)
        
        currentProgress += 1
        ProgressBot.sharedInstance.update(progressMessage: "\(actionString) time differences.", totalToAnalyze: totalToScore, currentProgress: currentProgress)
        TimingCoreML().scoreTiming(configModel: configModel)
        sleep(1)
        
        currentProgress += 1
        ProgressBot.sharedInstance.update(progressMessage: "\(actionString) all features.", totalToAnalyze: totalToScore, currentProgress: currentProgress)
        AllFeatures.sharedInstance.scoreAllFeatures(configModel: configModel)
        sleep(1)        
        
        if configModel.trainingMode
        {
            if configModel.enableSequenceAnalysis
            {
                currentProgress += 1
                ProgressBot.sharedInstance.update(progressMessage: "\(actionString) sequences.", totalToAnalyze: totalToScore, currentProgress: currentProgress)
                scoreAllFloatSequences(configModel: configModel)
                scoreAllOffsetSequences(configModel: configModel)
                sleep(1)
            }
            
            // ZIP All Saved Models
            MLModelController().bundle(modelGroup: configModel.modelName)
        }
        else
        {
            OperatorReportController.sharedInstance.createReportTextFile(forModel: configModel.modelName)
        }

        DispatchQueue.main.async
        {
            ProgressBot.sharedInstance.analysisComplete = true
            //NotificationCenter.default.post(name: .updateStats, object: nil)
        }
        
        deleteTemporaryModelDirectory(named: configModel.modelName)
    }
    
    // TODO: Decide when we should use this
    func deleteTemporaryModelDirectory(named modelName: String)
    {
        guard let appDirectory = getAdversarySupportDirectory()
            else
        {
            print("\nFailed to test models. Unable to locate application document directory.")
            return
        }

        // Delete the temp directory with the unzipped adversary files (keep the .adversary zip file)
        let temporaryDirURL = appDirectory.appendingPathComponent("\(modelName)", isDirectory: true)
        if FileManager.default.fileExists(atPath: temporaryDirURL.path)
        {
            try? FileManager.default.removeItem(at: temporaryDirURL)
        }
    }
    
    func analyze(connection: ObservedConnection, configModel: ProcessingConfigurationModel)
    {
        // Process Packet Lengths
        DispatchQueue.main.async{
            ProgressBot.sharedInstance.progressMessage = "Analyzing packet lengths for connection \(ProgressBot.sharedInstance.currentProgress) of \(ProgressBot.sharedInstance.totalToAnalyze)"
        }
        let (packetLengthProcessed, maybePacketlengthError) =  PacketLengthsCoreML().processPacketLengths(forConnection: connection)
        
        // Process Packet Timing
        DispatchQueue.main.async{
            ProgressBot.sharedInstance.progressMessage = "Analyzing Packet Timing for connection \(ProgressBot.sharedInstance.currentProgress) of \(ProgressBot.sharedInstance.totalToAnalyze)"
        }
        let (timingProcessed, maybePacketTimingError) = TimingCoreML().processTiming(forConnection: connection)
        if let packetLengthError = maybePacketlengthError
        {
            print("Packet length error: \(packetLengthError.localizedDescription)")
        }
        if let packetTimingError = maybePacketTimingError
        {
            print("Packet timing error: \(packetTimingError)")
        }
        
        // Process Offset and Float Sequences
        DispatchQueue.main.async
        {
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
        if let offsetError = maybeSubsequenceError
        {
            print("Offset error: \(offsetError)")
        }
        
        // Process Entropy
        DispatchQueue.main.async{
            ProgressBot.sharedInstance.progressMessage = "Analyzing Entropy for connection \(ProgressBot.sharedInstance.currentProgress) of \(ProgressBot.sharedInstance.totalToAnalyze)"
        }
        let (entropyProcessed,_, _, maybeEntropyError) = EntropyCoreML().processEntropy(forConnection: connection)
        if let entropyError = maybeEntropyError
        {
            print("Entropy error: \(entropyError)")
        }
        
        // Process All Features
        DispatchQueue.main.async
        {
            ProgressBot.sharedInstance.progressMessage = "Analyzing All Features for connection \(ProgressBot.sharedInstance.currentProgress) of \(ProgressBot.sharedInstance.totalToAnalyze)"
        }
        let allFeaturesProcessed = AllFeatures.sharedInstance.processData(forConnection: connection)
        
        // Increment Packets Analyzed Field as we are done analyzing this connection
        if packetLengthProcessed || timingProcessed || subsequenceNoErrors || entropyProcessed || allFeaturesProcessed
        {
            let packetsAnalyzedDictionary: RMap<String, Int> = RMap(key: packetStatsKey)
            let _ = packetsAnalyzedDictionary.increment(field: connection.packetsAnalyzedKey)
        }

        if configModel.enableTLSAnalysis
        {
            DispatchQueue.main.async
            {
                ProgressBot.sharedInstance.progressMessage = "Analyzing TLS Names for connection \(ProgressBot.sharedInstance.currentProgress) of \(ProgressBot.sharedInstance.totalToAnalyze)"
            }
            
            if let knownProtocol = detectKnownProtocol(connection: connection)
            {
                //NSLog("It's TLS!")
                processKnownProtocol(knownProtocol, connection)
            }
            //else { NSLog("Not TLS.") }
        }
    }
    
    func resetTrainingResults()
    {
        let packetLengthsTrainingResults: RMap<String, Double> = RMap(key: packetLengthsTrainingResultsKey)
        packetLengthsTrainingResults.delete()
        
        let allFeaturesTrainingDictionary: RMap<String, Double> = RMap(key: allFeaturesTrainingAccuracyKey)
        allFeaturesTrainingDictionary.delete()

        let timingTrainingDictionary: RMap<String, Double> = RMap(key: allFeaturesTimeTrainingResultsKey)
        timingTrainingDictionary.delete()

        let entropyTrainingDictionary: RMap<String, Double> = RMap(key: allFeaturesEntropyTrainingResultsKey)
        entropyTrainingDictionary.delete()
        
        let lengthTrainingDictionary: RMap<String, Double> = RMap(key: allFeaturesLengthTrainingResultsKey)
        lengthTrainingDictionary.delete()
        
        let tlsTrainingDictionary: RMap<String, String> = RMap(key: allFeaturesTLSTraininResultsKey)
        tlsTrainingDictionary.delete()
        
        let entropyResults: RMap <String, Double> = RMap(key: entropyTrainingResultsKey)
        entropyResults.delete()
        
        let timeDifferenceTrainingResults: RMap<String, Double> = RMap(key: timeDifferenceTrainingResultsKey)
        timeDifferenceTrainingResults.delete()
        
        let tlsTrainingResults: RMap <String, String> = RMap(key: tlsTrainingResultsKey)
        tlsTrainingResults.delete()
        
        let tlsTrainingAccuracy: RMap <String, Double> = RMap(key: tlsTrainingAccuracyKey)
        tlsTrainingAccuracy.delete()
        
    }
    
    func resetTestResults()
    {
        let testResults: RMap<String,Double> = RMap(key: testResultsKey)
        testResults.delete()
        
        let tlsTestResults: RMap <String, String> = RMap(key: tlsTestResultsKey)
        tlsTestResults.delete()
        let tlsTestAccuracy: RMap <String, Double> = RMap(key: tlsTestAccuracyKey)
        tlsTestAccuracy.delete()
        
        let allFeaturesTLSTestResultsDictionary: RMap<String,String> = RMap(key: tlsTestResultsKey)
        allFeaturesTLSTestResultsDictionary.delete()
        
        let timeDifferenceTestResults: RMap<String, Double> = RMap(key: timeDifferenceTestResultsKey)
        timeDifferenceTestResults.delete()
    }
    
    func resetAnalysisData()
    {
        pauseBuddy = PauseBot()
        let packetsAnalyzedDictionary: RMap<String, Int> = RMap(key: packetStatsKey)
        packetsAnalyzedDictionary[allowedPacketsAnalyzedKey] = 0
        packetsAnalyzedDictionary[blockedPacketsAnalyzedKey] = 0
        
        // Delete all current scores
        let outTrainingSequences: RList<Data> = RList(key: outgoingOffsetTrainingSequencesKey)
        outTrainingSequences.delete()
        let outTrainingSequenceOffsets: RList<Int> = RList(key: outgoingOffsetTrainingSequenceOffsetsKey)
        outTrainingSequenceOffsets.delete()
        
        let inTrainingSequences: RList<Data> = RList(key: incomingOffsetTrainingSequencesKey)
        inTrainingSequences.delete()
        let inTrainingSequenceOffsets: RList<Int> = RList(key: incomingOffsetTrainingSequenceOffsetsKey)
        inTrainingSequenceOffsets.delete()

        let allowedOutLengthsSet: RSortedSet<Int> = RSortedSet(key: allowedOutgoingLengthKey)
        allowedOutLengthsSet.delete()
        let allowedInLengthsSet: RSortedSet<Int> = RSortedSet(key: allowedIncomingLengthKey)
        allowedInLengthsSet.delete()
        let blockedOutLengthsSet: RSortedSet<Int> = RSortedSet(key: blockedOutgoingLengthKey)
        blockedOutLengthsSet.delete()
        let blockedInLengthsSet: RSortedSet<Int> = RSortedSet(key: blockedIncomingLengthKey)
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

        let allowedInEntropyList: RList<Double> = RList(key: allowedIncomingEntropyKey)
        allowedInEntropyList.delete()
        let allowedOutEntropyList: RList<Double> = RList(key: allowedOutgoingEntropyKey)
        allowedOutEntropyList.delete()
        let blockedInEntropyList: RList<Double> = RList(key: blockedIncomingEntropyKey)
        blockedInEntropyList.delete()
        let blockedOutEntropyList: RList<Double> = RList(key: blockedOutgoingEntropyKey)
        blockedOutEntropyList.delete()

        let allowedTimeDifferenceList: RList<Double> = RList(key: allowedConnectionsTimeDiffKey)
        allowedTimeDifferenceList.delete()
        let blockedTimeDifferenceList: RList<Double> = RList(key: blockedConnectionsTimeDiffKey)
        blockedTimeDifferenceList.delete()
        
        let allowedTlsCommonNames: RSortedSet<String> = RSortedSet(key: allowedTlsCommonNameKey)
        allowedTlsCommonNames.delete()
        let blockedTlsCommonNames: RSortedSet<String> = RSortedSet(key: blockedTlsCommonNameKey)
        blockedTlsCommonNames.delete()
        
        NotificationCenter.default.post(name: .updateStats, object: nil)
    }
    
}
