//
//  ConnectionInspector.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation

class ConnectionInspector
{
    var pauseBuddy = PauseBot()

    func analyzeConnections(configModel: ProcessingConfigurationModel, resetTrainingData: Bool, resetTestingData: Bool)
    {
        ProgressBot.sharedInstance.analysisComplete = false

        analysisQueue.async
        {
            if self.pauseBuddy.processingComplete
            {
                self.resetAnalysisData(resetTrainingData: resetTrainingData, resetTestingData: resetTestingData)
                self.pauseBuddy.processingComplete = false
            }

            // Allowed Connections
            if self.pauseBuddy.processingAllowedConnections
            {
                let aConnections = connectionGroupData.aConnectionData.connections
                for index in self.pauseBuddy.currentIndex ..< aConnections.count
                {
                    if configModel.processingEnabled
                    {
                        // Get the connection ID
                        let allowedConnectionID = aConnections[index]

                        if "\(type(of: allowedConnectionID))" == "NSNull"
                        { continue }

                        // Progress Indicator Stuff
                        let totalAllowedConnections = aConnections.count
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
            let bConnections = connectionGroupData.bConnectionData.connections
            for index in self.pauseBuddy.currentIndex ..< bConnections.count
            {
                if configModel.processingEnabled
                {
                    // Get the first connection ID from the list
                    let blockedConnectionID = bConnections[index]

                    if "\(type(of: blockedConnectionID))" == "NSNull"
                    { continue }

                    // Progress Indicator Stuff
                    let totalBlockedConnections = bConnections.count
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

            // Save TrainingData to a file
            FileController().saveTrainingData(groupName: configModel.modelName)
            
            // ZIP All Saved Models
            FileController().bundle(modelGroup: configModel.modelName)
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
        DispatchQueue.main.async {
            ProgressBot.sharedInstance.progressMessage = "Analyzing packet lengths for connection \(ProgressBot.sharedInstance.currentProgress) of \(ProgressBot.sharedInstance.totalToAnalyze)"
        }
        let (packetLengthProcessed, maybePacketlengthError) = PacketLengthsCoreML().processPacketLengths(forConnection: connection)

        // Process Packet Timing
        DispatchQueue.main.async {
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
        DispatchQueue.main.async {
            ProgressBot.sharedInstance.progressMessage = "Analyzing Entropy for connection \(ProgressBot.sharedInstance.currentProgress) of \(ProgressBot.sharedInstance.totalToAnalyze)"
        }
        let (entropyProcessed, _, _, maybeEntropyError) = EntropyCoreML().processEntropy(forConnection: connection)
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
            switch connection.connectionType
            {
            case .transportA:
                connectionGroupData.aPacketsAnalyzed += 1
            case .transportB:
                connectionGroupData.bPacketsAnalyzed += 1
            }
        }

        if configModel.enableTLSAnalysis
        {
            DispatchQueue.main.async
            {
                ProgressBot.sharedInstance.progressMessage = "Analyzing TLS Names for connection \(ProgressBot.sharedInstance.currentProgress) of \(ProgressBot.sharedInstance.totalToAnalyze)"
            }

            if let knownProtocol = detectKnownProtocol(connection: connection)
            {
                processKnownProtocol(knownProtocol, connection)
            }
        }
    }

    func resetAnalysisData(resetTrainingData: Bool, resetTestingData: Bool)
    {
        if resetTrainingData
        {
            connectionGroupData.aPacketsAnalyzed = 0
            connectionGroupData.bPacketsAnalyzed = 0

            trainingData.incomingEntropyTrainingResults = nil
            trainingData.outgoingEntropyTrainingResults = nil
            trainingData.outgoingLengthsTrainingResults = nil
            trainingData.incomingLengthsTrainingResults = nil
            trainingData.timingTrainingResults = nil
        }

        if resetTestingData
        {
            connectionGroupData.aPacketsAnalyzed = 0
            connectionGroupData.bPacketsAnalyzed = 0

            packetEntropies.incomingATestResults = nil
            packetEntropies.incomingBTestResults = nil
            packetEntropies.outgoingATestResults = nil
            packetEntropies.outgoingBTestResults = nil
            packetLengths.incomingATestResults = nil
            packetLengths.incomingBTestResults = nil
            packetLengths.outgoingATestResults = nil
            packetLengths.outgoingBTestResults = nil
            packetTimings.transportATestResults = nil
            packetTimings.transportBTestResults = nil
        }
    }

}
