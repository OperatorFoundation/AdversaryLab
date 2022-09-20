//
//  SequencesCoreML.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 7/2/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import CreateML
import CoreML

import Abacus

class SequencesCoreML
{
    let outSequenceCounter = SequenceCounter()
    let inSequenceCounter = SequenceCounter()
    
    let outPositionalSequenceCounter = PositionalSequenceCounter()
    let inPositionalSequenceCounter = PositionalSequenceCounter()
    
    func processSequences(labData: LabData, forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
    {
        switch connection.connectionType
        {
            case .transportA:
                // Get the out packet that corresponds with this connection ID
                    guard let outPacket = labData.connectionGroupData.aConnectionData.outgoingPackets[connection.connectionID]
                else { return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID)) }
                
                // Get the in packet that corresponds with this connection ID
                    guard let inPacket = labData.connectionGroupData.aConnectionData.incomingPackets[connection.connectionID]
                else { return(false, PacketLengthError.noInPacketForConnection(connection.connectionID)) }
                
                /// Sanity Check
                if outPacket.count < 10 || inPacket.count < 10
                {
                    print("\n### packet count = \(String(outPacket.count))")
                    print("\n⁉️  We got a weird out packet size... \(String(describing: String(data: outPacket, encoding: .utf8)))<----")
                }
                
                outSequenceCounter.add(sequence: outPacket, aOrB: true)
                inSequenceCounter.add(sequence: inPacket, aOrB: true)
                
                outPositionalSequenceCounter.add(sequence: outPacket, aOrB: true)
                inPositionalSequenceCounter.add(sequence: inPacket, aOrB: true)

            case .transportB:
                    guard let outPacket = labData.connectionGroupData.bConnectionData.outgoingPackets[connection.connectionID]
                else
                { return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID)) }
                
                    guard let inPacket = labData.connectionGroupData.bConnectionData.incomingPackets[connection.connectionID]
                else
                { return (false, PacketLengthError.noInPacketForConnection(connection.connectionID)) }
                
                /// Sanity Check
                if outPacket.count < 10 || inPacket.count < 10
                {
                    print("\n### packet count = \(String(outPacket.count))")
                    print("\n⁉️  We got a weird out packet size... \(String(describing: String(data: outPacket, encoding: .utf8)))<----")
                }
                
                outSequenceCounter.add(sequence: outPacket, aOrB: false)
                inSequenceCounter.add(sequence: inPacket, aOrB: false)
                
                outPositionalSequenceCounter.add(sequence: outPacket, aOrB: false)
                inPositionalSequenceCounter.add(sequence: inPacket, aOrB: false)
        }
        
        return (true, nil)
    }
    
    func scoreFloatSequences(connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel, labData: LabData)
    {
        if configModel.trainingMode
        {
            trainFloatModels(connectionDirection: connectionDirection, modelName: configModel.modelName, labData: labData)
        }
        else
        {
            let (allowedFloatSequences, blockedFloatSequences) = getFloats(forConnectionDirection: connectionDirection)
            guard blockedFloatSequences.count > 0
                else
            {
                print("\nUnable to test float sequences. The blocked lengths list is empty.")
                return
            }

            testFloatModel(floatSequences: allowedFloatSequences, connectionType: .transportA, connectionDirection: connectionDirection, configModel: configModel)
            testFloatModel(floatSequences: blockedFloatSequences, connectionType: .transportB, connectionDirection: connectionDirection, configModel: configModel)
        }
    }

    func scoreOffsetSequences(connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel, labData: LabData)
    {
        if configModel.trainingMode
        {
            trainOffsetModels(connectionDirection: connectionDirection, modelName: configModel.modelName, labData: labData)
        }
        else
        {
            let (allowedOffsetSequences, blockedOffsetSequences) = getOffsets(forConnectionDirection: connectionDirection)
            guard blockedOffsetSequences.count > 0
                else
            {
                print("\nUnable to test float sequences. The blocked lengths list is empty.")
                return
            }

            testOffsetModel(offsetSequences: allowedOffsetSequences, connectionType: .transportA, connectionDirection: connectionDirection, configModel: configModel)
            testOffsetModel(offsetSequences: blockedOffsetSequences, connectionType: .transportB, connectionDirection: connectionDirection, configModel: configModel)
        }
    }

    func createFloatTable(connectionDirection: ConnectionDirection, labData: LabData) -> MLDataTable
    {
        var floatTable = MLDataTable()
        let allowedTable = createFloatTable(forConnectionType: .transportA, andDirection: connectionDirection, labData: labData)
        let blockedTable = createFloatTable(forConnectionType: .transportB, andDirection: connectionDirection, labData: labData)

        floatTable.append(contentsOf: allowedTable)
        floatTable.append(contentsOf: blockedTable)

        return floatTable
    }

    func createOffsetTable(connectionDirection: ConnectionDirection, labData: LabData) -> MLDataTable
    {
        var offsetTable = MLDataTable()
        let allowedTable = createOffsetTable(forConnectionType: .transportA, andDirection: connectionDirection, labData: labData)
        let blockedTable = createOffsetTable(forConnectionType: .transportB, andDirection: connectionDirection, labData: labData)

        offsetTable.append(contentsOf: allowedTable)
        offsetTable.append(contentsOf: blockedTable)

        return offsetTable
    }

    private func createFloatTable(forConnectionType connectionType: ClassificationLabel, andDirection connectionDirection: ConnectionDirection, labData: LabData) -> MLDataTable
    {
        let connectionsList: [String]
        let packets: [String: Data]
        let trainingSequences: [Data]
        var dataTable = MLDataTable()
        
        switch connectionDirection
        {
            case .incoming:
                trainingSequences = inSequenceCounter.extractData()
            case .outgoing:
                trainingSequences = outSequenceCounter.extractData()
        }
        
        switch connectionType
        {
            case .transportA:
                connectionsList = labData.connectionGroupData.aConnectionData.connections
                switch connectionDirection
                {
                    case .incoming:
                        packets = labData.connectionGroupData.aConnectionData.incomingPackets
                    case .outgoing:
                        packets = labData.connectionGroupData.aConnectionData.outgoingPackets
                }
            case .transportB:
                connectionsList = labData.connectionGroupData.bConnectionData.connections
                switch connectionDirection
                {
                    case .incoming:
                        packets = labData.connectionGroupData.bConnectionData.incomingPackets
                    case .outgoing:
                        packets = labData.connectionGroupData.bConnectionData.outgoingPackets
                }
        }

        for connectionID in connectionsList
        {
            guard let packet = packets[connectionID] else { continue }

            var rowTable = MLDataTable()
            let classyColumn = MLDataColumn([connectionType.rawValue])
            rowTable.addColumn(classyColumn, named: ColumnLabel.classification.rawValue)

            for index in 0 ..< trainingSequences.count
            {
                let sequenceColumn: MLDataColumn<Int>
                let trainingSequence = trainingSequences[index]
                
                guard packet.count >= trainingSequence.count else { continue }

                if let _ = packet.range(of: trainingSequence)
                {
                    sequenceColumn = MLDataColumn([1])
                }
                else
                {
                    sequenceColumn = MLDataColumn([0])
                }

                rowTable.addColumn(sequenceColumn, named: "sequence\(index)")
                print("\n📊  Created a sequence column: \(sequenceColumn) named: sequence\(index)")
            }

            dataTable.append(contentsOf: rowTable)
        }

        return dataTable
    }

    private func createOffsetTable(forConnectionType connectionType: ClassificationLabel, andDirection connectionDirection: ConnectionDirection, labData: LabData) -> MLDataTable
    {
        let connectionsList: [String]
        let packets: [String: Data]
        let trainingSequences: [OffsetSequence]
        var dataTable = MLDataTable()

        switch connectionDirection
        {
            case .incoming:
                trainingSequences = inPositionalSequenceCounter.extract()
            case .outgoing:
                trainingSequences = outPositionalSequenceCounter.extract()
        }

        switch connectionType
        {
            case .transportA:
                connectionsList = labData.connectionGroupData.aConnectionData.connections
                switch connectionDirection
                {
                    case .incoming:
                        packets = labData.connectionGroupData.aConnectionData.incomingPackets
                    case .outgoing:
                        packets = labData.connectionGroupData.aConnectionData.outgoingPackets
                }
            case .transportB:
                connectionsList = labData.connectionGroupData.bConnectionData.connections
                switch connectionDirection
                {
                    case .incoming:
                        packets = labData.connectionGroupData.bConnectionData.incomingPackets
                    case .outgoing:
                        packets = labData.connectionGroupData.bConnectionData.outgoingPackets
                }
        }

        for connectionID in connectionsList
        {
            guard let packet = packets[connectionID] else { continue }

            var rowTable = MLDataTable()
            let classyColumn = MLDataColumn([connectionType.rawValue])
            rowTable.addColumn(classyColumn, named: ColumnLabel.classification.rawValue)

            for index in 0 ..< trainingSequences.count
            {
                let offsetSequence = trainingSequences[index]
                guard packet.count >= offsetSequence.offset + offsetSequence.sequence.count else { continue }
                let subsequence = packet[offsetSequence.offset..<offsetSequence.offset + offsetSequence.sequence.count]
                let sequenceColumn: MLDataColumn<Int>

                if subsequence == offsetSequence.sequence
                {
                    sequenceColumn = MLDataColumn([1])
                }
                else
                {
                    sequenceColumn = MLDataColumn([0])
                }

                rowTable.addColumn(sequenceColumn, named: "sequence\(index)")
            }

            dataTable.append(contentsOf: rowTable)
        }

        return dataTable
    }

    func testFloatModel(floatSequences: [Data], connectionType: ClassificationLabel, connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
    {
        let classifierName: String
        let accuracyKey: String

        switch connectionDirection
        {
        case .incoming:
            classifierName = inFloatClassifierName
            switch connectionType
            {
            case .transportA:
                accuracyKey = allowedIncomingFloatAccuracyKey
            case .transportB:
                accuracyKey = blockedIncomingFloatAccuracyKey
            }
        case .outgoing:
            classifierName = outFloatClassifierName
            switch connectionType
            {
            case .transportA:
                accuracyKey = allowedOutgoingFloatAccuracyKey
            case .transportB:
                accuracyKey = blockedOutgoingFloatAccuracyKey
            }
        }

        do
        {
            let classifierFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.length.rawValue: floatSequences])

            guard let tempDirURL = getAdversaryTempDirectory()
                else
            {
                print("\nFailed to test models. Unable to locate application document directory.")
                return
            }

            let temporaryDirURL = tempDirURL.appendingPathComponent("\(configModel.modelName)", isDirectory: true)
            let classifierFileURL = temporaryDirURL.appendingPathComponent(classifierName, isDirectory: false).appendingPathExtension(modelFileExtension)

            // FIXME: This is the dictionary where we will save our results
//            let floatDictionary: RMap<String,Double> = RMap(key: testResultsKey)

            // Classifier
            if FileManager.default.fileExists(atPath: classifierFileURL.path)
            {
                if let classifierPrediction = MLModelController().prediction(fileURL: classifierFileURL, batchFeatureProvider: classifierFeatureProvider)
                {
                    guard classifierPrediction.count > 0
                        else
                    {
                        print("\nFloat Sequence classifier prediction has no values.")
                        return
                    }

                    let featureCount = classifierPrediction.count

                    guard featureCount > 0
                        else
                    {
                        print("/nFloat Sequence prediction had no values.")
                        return
                    }

                    var allowedBlockedCount: Double = 0.0
                    for index in 0 ..< featureCount
                    {
                        let thisFeature = classifierPrediction.features(at: index)
                        guard let lengthClassification = thisFeature.featureValue(for: "classification")
                            else { continue }
                        if lengthClassification.stringValue == connectionType.rawValue
                        {
                            allowedBlockedCount += 1
                        }
                    }

                    let accuracy = allowedBlockedCount/Double(featureCount)
                    print("\n🔮 Float Sequence prediction: \(accuracy * 100) \(connectionType.rawValue).")
                    // FIXME: Save results
//                    floatDictionary[accuracyKey] = accuracy
                }
            }
        }
        catch
        {
            print("Unable to test float sequences: Failed to create the feature provider.")
        }
    }

    func testOffsetModel(offsetSequences: [Data], connectionType: ClassificationLabel, connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
    {
        let classifierName: String
        let accuracyKey: String

        switch connectionDirection
        {
        case .incoming:
            classifierName = inOffsetClassifierName
            switch connectionType
            {
            case .transportA:
                accuracyKey = allowedIncomingOffsetAccuracyKey
            case .transportB:
                accuracyKey = blockedIncomingOffsetAccuracyKey
            }
        case .outgoing:
            classifierName = outOffsetClassifierName
            switch connectionType
            {
            case .transportA:
                accuracyKey = allowedOutgoingOffsetAccuracyKey
            case .transportB:
                accuracyKey = blockedOutgoingOffsetAccuracyKey
            }
        }

        do
        {
            let classifierFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.length.rawValue: offsetSequences])

            guard let tempDirURL = getAdversaryTempDirectory()
                else
            {
                print("\nFailed to test models. Unable to locate application document directory.")
                return
            }

            let temporaryDirURL = tempDirURL.appendingPathComponent("\(configModel.modelName)", isDirectory: true)
            let classifierFileURL = temporaryDirURL.appendingPathComponent(classifierName, isDirectory: false).appendingPathExtension(modelFileExtension)

            // FIXME: This is the dictionary where we will save our results
//            let offsetDictionary: RMap<String,Double> = RMap(key: testResultsKey)

            // Classifier
            if FileManager.default.fileExists(atPath: classifierFileURL.path)
            {
                if let classifierPrediction = MLModelController().prediction(fileURL: classifierFileURL, batchFeatureProvider: classifierFeatureProvider)
                {
                    guard classifierPrediction.count > 0
                        else
                    {
                        print("\nOffset Sequence classifier prediction has no values.")
                        return
                    }

                    let featureCount = classifierPrediction.count

                    guard featureCount > 0
                        else
                    {
                        print("/nFloat Sequence prediction had no values.")
                        return
                    }

                    var allowedBlockedCount: Double = 0.0
                    for index in 0 ..< featureCount
                    {
                        let thisFeature = classifierPrediction.features(at: index)
                        guard let lengthClassification = thisFeature.featureValue(for: "classification")
                            else { continue }
                        if lengthClassification.stringValue == connectionType.rawValue
                        {
                            allowedBlockedCount += 1
                        }
                    }

                    let accuracy = allowedBlockedCount/Double(featureCount)
                    print("\n🔮 Float Sequence prediction: \(accuracy * 100) \(connectionType.rawValue).")

                    // FIXME: Save results
//                    if accuracy > 0
//                    {
//                        offsetDictionary[accuracyKey] = accuracy
//                    }
                }
            }
        }
        catch
        {
            print("Unable to test float sequences: Failed to create the feature provider.")
        }
    }

    // FIXME: Not implemented
    func getFloats(forConnectionDirection connectionDirection: ConnectionDirection) -> (allowedFloats:[Data], blockedFloats: [Data])
    {
        let allowedFloatsKey: String
        let blockedFloatsKey: String

        switch connectionDirection
        {
        case .incoming:
            allowedFloatsKey = allowedIncomingFloatingSequencesKey
            blockedFloatsKey = blockedIncomingFloatingSequencesKey
        case .outgoing:
            allowedFloatsKey = allowedOutgoingFloatingSequencesKey
            blockedFloatsKey = blockedOutgoingFloatingSequencesKey
        }

        /// A is the sorted set of lengths for the Allowed traffic
//        let allowedFloatsRSet: RSortedSet<Data> = RSortedSet(key: allowedFloatsKey)
//        let allowedFloatsArray = newDataArray(from: [allowedFloatsRSet])

        let allowedFloatsArray = [Data]()

        /// B is the sorted set of lengths for the Blocked traffic
//        let blockedFloatsRSet: RSortedSet<Data> = RSortedSet(key: blockedFloatsKey)
//        let blockedFloatsArray = newDataArray(from: [blockedFloatsRSet])

        let blockedFloatsArray = [Data]()

        return (allowedFloatsArray, blockedFloatsArray)
    }

    // FIXME: Not implemented
    func getOffsets(forConnectionDirection connectionDirection: ConnectionDirection) -> (allowedFloats:[Data], blockedFloats: [Data])
    {
        let allowedOffsetsKey: String
        let blockedOffsetsKey: String

        switch connectionDirection
        {
        case .incoming:
            allowedOffsetsKey = allowedIncomingOffsetSequencesKey
            blockedOffsetsKey = blockedIncomingOffsetSequencesKey
        case .outgoing:
            allowedOffsetsKey = allowedOutgoingOffsetSequencesKey
            blockedOffsetsKey = blockedOutgoingOffsetSequencesKey
        }

        /// A is the sorted set of lengths for the Allowed traffic
//        let allowedOffsetsRSet: RSortedSet<Data> = RSortedSet(key: allowedOffsetsKey)
//        let allowedOffsetsArray = newDataArray(from: [allowedOffsetsRSet])

        let allowedOffsetsArray = [Data]()

        /// B is the sorted set of lengths for the Blocked traffic
//        let blockedOffsetsRSet: RSortedSet<Data> = RSortedSet(key: blockedOffsetsKey)
//        let blockedOffsetsArray = newDataArray(from: [blockedOffsetsRSet])

        let blockedOffsetsArray = [Data]()

        return (allowedOffsetsArray, blockedOffsetsArray)
    }

    func trainFloatModels(connectionDirection: ConnectionDirection, modelName: String, labData: LabData)
    {
        let classifierName: String
        let floatSequenceTable = createFloatTable(connectionDirection: connectionDirection, labData: labData)

        switch connectionDirection
        {
        case .incoming:
            classifierName = inFloatClassifierName
        case .outgoing:
            classifierName = outFloatClassifierName
        }

        let (floatEvaluationTable, floatTrainingTable) = floatSequenceTable.randomSplit(by: 0.20)

        // Train the Classifier
        do
        {
            let classifier = try MLClassifier(trainingData: floatTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
            let trainingAccuracy = (1.0 - classifier.trainingMetrics.classificationError) * 100
            let classifierEvaluation = classifier.evaluation(on: floatEvaluationTable)
            let evaluationAccuracy = (1.0 - classifierEvaluation.classificationError) * 100

            let validationError = classifier.validationMetrics.classificationError
            let validationAccuracy: Double?

            // Sometimes we get a negative number, this is not valid for our purposes
            if validationError < 0
            {
                validationAccuracy = nil
            }
            else
            {
                validationAccuracy = (1.0 - validationError) * 100
            }
            
            // Regressor
            let regressor = try MLRegressor(trainingData: floatTrainingTable, targetColumn: ColumnLabel.floatSequences.rawValue)
            guard let (aSequencesTable, bSequencesTable) = MLModelController().createAandBTables(fromTable: floatSequenceTable) else
            {
                print("Failed to create A and B tables for float sequences.")
                return
            }
            
            // Transport A
            let aFloatColumn = try regressor.predictions(from: aSequencesTable)
            
            guard let aFloatSequences = aFloatColumn.ints else
            {
                print("Failed to identify transport A float sequence.")
                return
            }
            
            let predicatedTransportAFloatSequence = aFloatSequences[0]
            print("Predicted transport A sequence = \(predicatedTransportAFloatSequence)")
            
            // Transport B
            let bFloatColumn = try regressor.predictions(from: bSequencesTable)
            
            guard let bFloatSequences = bFloatColumn.ints else
            {
                print("Failed to identify transport B float sequence.")
                return
            }
            
            let predicatedTransportBFloatSequence = bFloatSequences[0]
            print("Predicted transport B sequence = \(predicatedTransportBFloatSequence)")

            // TODO: Save Scores
//            switch connectionDirection
//            {
//                case .incoming:
//                    labData.trainingData.incomingFloatSequencesTrainingResults = FloatSequenceTrainingResults(
//                        predictionForA: predicatedTransportAFloatSequence,
//                        predictionForB: predicatedTransportBFloatSequence,
//                        trainingAccuracy: trainingAccuracy,
//                        validationAccuracy: validationAccuracy,
//                        evaluationAccuracy: evaluationAccuracy)
//                case .outgoing:
//                    labData.trainingData.outgoingFloatSequencesTrainingResults = FloatSequenceTrainingResults(
//                        predictionForA: predicatedTransportAFloatSequence,
//                        predictionForB: predicatedTransportBFloatSequence,
//                        trainingAccuracy: trainingAccuracy,
//                        validationAccuracy: validationAccuracy,
//                        evaluationAccuracy: evaluationAccuracy)
//            }
//            
//            let floatDictionary: RMap<String, Double> = RMap(key: floatSequencesTrainingResultsKey)
//            floatDictionary[sequencesTAccKey] = trainingAccuracy
//            floatDictionary[sequencesEAccKey] = evaluationAccuracy
//
//            if validationAccuracy != nil
//            {
//                floatDictionary[sequencesVAccKey] = validationAccuracy!
//            }

            // Save the models to a file
            FileController().save(classifier: classifier,
                                  classifierMetadata: floatClassifierMetadata,
                                  fileName: classifierName,
                                  groupName: modelName)
        }
        catch
        {
            print("\nError creating the classifier for float sequences:\(error)")
        }
    }

    func trainOffsetModels(connectionDirection: ConnectionDirection, modelName: String, labData: LabData)
    {
        let sequencesTAccKey: String
        let sequencesVAccKey: String
        let sequencesEAccKey: String
        let classifierName: String
        let offsetSequenceTable = createOffsetTable(connectionDirection: connectionDirection, labData: labData)

        switch connectionDirection
        {
        case .incoming:
            sequencesTAccKey = incomingOffsetSequencesTAccKey
            sequencesVAccKey = incomingOffsetSequencesVAccKey
            sequencesEAccKey = incomingOffsetSequencesEAccKey
            classifierName = inOffsetClassifierName
        case .outgoing:
            sequencesTAccKey = outgoingOffsetSequencesTAccKey
            sequencesVAccKey = outgoingOffsetSequencesVAccKey
            sequencesEAccKey = outgoingOffsetSequencesEAccKey
            classifierName = outOffsetClassifierName
        }

        // Set aside 20% of the model's data rows for evaluation, leaving the remaining 80% for training
        let (offsetEvaluationTable, offsetTrainingTable) = offsetSequenceTable.randomSplit(by: 0.20)

        // Train the classifier
        do
        {
            let classifier = try MLClassifier(trainingData: offsetTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
            let trainingAccuracy = (1.0 - classifier.trainingMetrics.classificationError) * 100
            let classifierEvaluation = classifier.evaluation(on: offsetEvaluationTable)
            let evaluationAccuracy = (1.0 - classifierEvaluation.classificationError) * 100

            let validationError = classifier.validationMetrics.classificationError
            let validationAccuracy: Double?

            // Sometimes we get a negative number, this is not valid for our purposes
            if validationError < 0
            {
                validationAccuracy = nil
            }
            else
            {
                validationAccuracy = (1.0 - validationError) * 100
            }

            // TODO: Save Scores
//            let offsetDictionary: RMap<String, Double> = RMap(key: offsetSequencesTrainingResultsKey)
//            offsetDictionary[sequencesTAccKey] = trainingAccuracy
//            offsetDictionary[sequencesEAccKey] = evaluationAccuracy
//
//            if validationAccuracy != nil
//            {
//                offsetDictionary[sequencesVAccKey] = validationAccuracy!
//            }

            // Save the models to a file
            FileController().save(classifier: classifier, classifierMetadata: offsetClassifierMetadata, fileName: classifierName, groupName: modelName)
        }
        catch let error
        {
            print("\nError creating the classifier for offsets:\(error)")
        }
    }
}
