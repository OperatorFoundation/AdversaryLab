//
//  ConnectionInspector.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation

class ConnectionInspector: ObservableObject
{
    func analyzeConnections(labData: LabData, configModel: ProcessingConfigurationModel, resetTrainingData: Bool, resetTestingData: Bool) async -> Bool
    {
        self.resetAnalysisData(labData: labData, resetTrainingData: resetTrainingData, resetTestingData: resetTestingData)
        
        // Allowed Connections
        let aConnections = labData.connectionGroupData.aConnectionData.connections
        var aConnectionsAnalyzed = 0
        
        for aConnectionID in aConnections
        {
            if "\(type(of: aConnectionID))" == "NSNull"
            { continue }

            // Analyze the connection
            let aConnection = ObservedConnection(connectionType: .transportA, connectionID: aConnectionID)
            self.analyze(labData: labData, connection: aConnection, configModel: configModel)
            aConnectionsAnalyzed += 1
            
            labData.connectionGroupData.aConnectionData.packetsAnalyzed = aConnectionsAnalyzed
        }
        print("Finished analyzing A connections")
        
        // Blocked Connections
        let bConnections = labData.connectionGroupData.bConnectionData.connections
        var bConnectionsAnalyzed = 0
        
        for bConnectionID in bConnections
        {
            if "\(type(of: bConnectionID))" == "NSNull"
            { continue }

            // Analyze the connection
            let bConnection = ObservedConnection(connectionType: .transportB, connectionID: bConnectionID)
            self.analyze(labData: labData, connection: bConnection, configModel: configModel)
            bConnectionsAnalyzed += 1

            labData.connectionGroupData.bConnectionData.packetsAnalyzed = bConnectionsAnalyzed
            
        }
        print("Finished analyzing B connections")
        
        let handler = Task
        {
            await self.scoreConnections(labData: labData, configModel: configModel)
        }
        
        let result = await handler.value
        print("Finished scoring connections")
        return result
    }

    func scoreConnections(labData: LabData, configModel: ProcessingConfigurationModel) async -> Bool
    {
        // TODO: Implement TLS
//        if configModel.enableTLSAnalysis
//        {
//            TLS12CoreML().scoreTLS12(configModel: configModel)
//            //sleep(1)
//        }

        PacketLengthsCoreML().scoreAllPacketLengths(labData: labData, configModel: configModel)
        //sleep(1)

        EntropyCoreML().scoreAllEntropyInDatabase(labData: labData, configModel: configModel)
        //sleep(1)

        TimingCoreML().scoreTiming(labData: labData, configModel: configModel)
        //sleep(1)

//        AllFeatures().scoreAllFeatures(labData: labData, configModel: configModel)
        //sleep(1)

        if configModel.trainingMode
        {
            if configModel.enableSequenceAnalysis
            {
//                scoreAllFloatSequences(configModel: configModel)
//                scoreAllOffsetSequences(configModel: configModel)
            }

            let fileController = FileController()
            
            // Save TrainingData to a file
            fileController.saveTrainingData(trainingData: labData.trainingData, groupName: configModel.modelName)
            
            // ZIP All Saved Models
            fileController.bundle(modelGroup: configModel.modelName)
        }
        else
        {
//            OperatorReportController().createReportTextFile(labData: labData, forModel: configModel.modelName)
        }
        
        deleteTemporaryModelDirectory(named: configModel.modelName)
        
        return true
    }

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

    func analyze(labData: LabData, connection: ObservedConnection, configModel: ProcessingConfigurationModel)
    {
        // Process Packet Lengths
        let (packetLengthProcessed, maybePacketlengthError) = PacketLengthsCoreML().processPacketLengths(labData: labData, forConnection: connection)
        
        if let packetLengthError = maybePacketlengthError
        {
            print("Packet length error: \(packetLengthError.localizedDescription)")
        }

        // Process Packet Timing
        let (timingProcessed, maybePacketTimingError) = TimingCoreML().processTiming(labData: labData, forConnection: connection)
        
        if let packetTimingError = maybePacketTimingError
        {
            print("Packet timing error: \(packetTimingError)")
        }

        // Process Offset and Float Sequences
        var subsequenceNoErrors = true
        var maybeSubsequenceError: Error? = nil
        if configModel.enableSequenceAnalysis
        {
            let (subsequenceProcessed, maybeSubsequenceErrorResponse) = processSequences(labData: labData, forConnection: connection)
            subsequenceNoErrors = subsequenceProcessed
            maybeSubsequenceError = maybeSubsequenceErrorResponse
        }
        
        if let offsetError = maybeSubsequenceError
        {
            print("Offset error: \(offsetError)")
        }

        // Process Entropy
        let (entropyProcessed, _, _, maybeEntropyError) = EntropyCoreML().processEntropy(labData: labData, forConnection: connection)
        
        if let entropyError = maybeEntropyError
        {
            print("Entropy error: \(entropyError)")
        }
        
        // Process All Features
//        let allFeaturesProcessed = AllFeatures().processData(labData: labData, forConnection: connection)

        // Increment Packets Analyzed Field as we are done analyzing this connection
        if packetLengthProcessed || timingProcessed || subsequenceNoErrors || entropyProcessed //|| allFeaturesProcessed
        {
            switch connection.connectionType
            {
            case .transportA:
                    labData.connectionGroupData.aConnectionData.packetsAnalyzed += 1
            case .transportB:
                    labData.connectionGroupData.bConnectionData.packetsAnalyzed += 1
            }
        }

        // TODO: Implement TLS
//        if configModel.enableTLSAnalysis
//        {
//            if let knownProtocol = detectKnownProtocol(connection: connection)
//            {
//                processKnownProtocol(knownProtocol, connection)
//            }
//        }
    }

    func resetAnalysisData(labData: LabData, resetTrainingData: Bool, resetTestingData: Bool)
    {
        if resetTrainingData
        {
            labData.connectionGroupData.aConnectionData.packetsAnalyzed = 0
            labData.connectionGroupData.aConnectionData.totalPayloadBytes = 0
            
            labData.connectionGroupData.bConnectionData.packetsAnalyzed = 0
            labData.connectionGroupData.bConnectionData.totalPayloadBytes = 0

            labData.trainingData.incomingEntropyTrainingResults = nil
            labData.trainingData.outgoingEntropyTrainingResults = nil
            labData.trainingData.outgoingLengthsTrainingResults = nil
            labData.trainingData.incomingLengthsTrainingResults = nil
            labData.trainingData.timingTrainingResults = nil
        }

        if resetTestingData
        {
            labData.connectionGroupData.aConnectionData.packetsAnalyzed = 0
            labData.connectionGroupData.bConnectionData.packetsAnalyzed = 0

            labData.packetEntropies.incomingATestResults = nil
            labData.packetEntropies.incomingBTestResults = nil
            labData.packetEntropies.outgoingATestResults = nil
            labData.packetEntropies.outgoingBTestResults = nil
            labData.packetLengths.incomingATestResults = nil
            labData.packetLengths.incomingBTestResults = nil
            labData.packetLengths.outgoingATestResults = nil
            labData.packetLengths.outgoingBTestResults = nil
            labData.packetTimings.transportATestResults = nil
            labData.packetTimings.transportBTestResults = nil
        }
    }

}
