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
import Auburn

class SequencesCoreML
{
    func scoreFloatSequences(connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
    {
        if configModel.trainingMode
        {
            trainFloatModels(connectionDirection: connectionDirection, modelName: configModel.modelName)
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
            
            testFloatModel(floatSequences: allowedFloatSequences, connectionType: .allowed, connectionDirection: connectionDirection, configModel: configModel)
            testFloatModel(floatSequences: blockedFloatSequences, connectionType: .blocked, connectionDirection: connectionDirection, configModel: configModel)
        }
    }
    
    func scoreOffsetSequences(connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
    {
        if configModel.trainingMode
        {
            trainOffsetModels(connectionDirection: connectionDirection, modelName: configModel.modelName)
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
            
            testOffsetModel(offsetSequences: allowedOffsetSequences, connectionType: .allowed, connectionDirection: connectionDirection, configModel: configModel)
            testOffsetModel(offsetSequences: blockedOffsetSequences, connectionType: .blocked, connectionDirection: connectionDirection, configModel: configModel)
        }
    }
    
    func createFloatTable(connectionDirection: ConnectionDirection) -> MLDataTable
    {
        var floatTable = MLDataTable()
        let allowedTable = createFloatTable(forConnectionType: .allowed, andDirection: connectionDirection)
        let blockedTable = createFloatTable(forConnectionType: .blocked, andDirection: connectionDirection)
        
        floatTable.append(contentsOf: allowedTable)
        floatTable.append(contentsOf: blockedTable)
        
        return floatTable
    }
    
    func createOffsetTable(connectionDirection: ConnectionDirection) -> MLDataTable
    {
        var offsetTable = MLDataTable()
        let allowedTable = createOffsetTable(forConnectionType: .allowed, andDirection: connectionDirection)
        let blockedTable = createOffsetTable(forConnectionType: .blocked, andDirection: connectionDirection)
        
        offsetTable.append(contentsOf: allowedTable)
        offsetTable.append(contentsOf: blockedTable)
        
        return offsetTable
    }

    private func createFloatTable(forConnectionType connectionType: ClassificationLabel, andDirection connectionDirection: ConnectionDirection) -> MLDataTable
    {
        let connectionsList: RList<String>
        let packetsMap: RMap<String, Data>
        let trainingSequences: RList<Data>
        var dataTable = MLDataTable()
        
        switch connectionDirection
        {
        case .incoming:
            trainingSequences = RList(key: incomingFloatTrainingSequencesKey)
        case .outgoing:
            trainingSequences = RList(key: outgoingFloatTrainingSequencesKey)
        }
        
        switch connectionType
        {
        case .allowed:
            connectionsList = RList(key: allowedConnectionsKey)
            switch connectionDirection
            {
            case .incoming:
                packetsMap = RMap(key: allowedIncomingKey)
            case .outgoing:
                packetsMap = RMap(key: allowedOutgoingKey)
            }
        case .blocked:
            connectionsList = RList(key: blockedConnectionsKey)
            switch connectionDirection
            {
            case .incoming:
                packetsMap = RMap(key: blockedIncomingKey)
            case .outgoing:
                packetsMap = RMap(key: blockedOutgoingKey)
            }
        }
        
        for connectionID in connectionsList
        {
            guard let packet = packetsMap[connectionID] else { continue }
            
            var rowTable = MLDataTable()
            let classyColumn = MLDataColumn([connectionType.rawValue])
            rowTable.addColumn(classyColumn, named: ColumnLabel.classification.rawValue)
            
            for index in 0 ..< trainingSequences.count
            {
                guard let trainingSequence = trainingSequences[index] else { continue }
                guard packet.count >= trainingSequence.count else { continue }
                let sequenceColumn: MLDataColumn<Int>
                
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
    
    private func createOffsetTable(forConnectionType connectionType: ClassificationLabel, andDirection connectionDirection: ConnectionDirection) -> MLDataTable
    {
        let connectionsList: RList<String>
        let packetsMap: RMap<String, Data>
        let trainingSequences: RList<Data>
        let trainingSequenceOffsets: RList<Int>
        var dataTable = MLDataTable()
        
        switch connectionDirection
        {
        case .incoming:
            trainingSequences = RList(key: incomingOffsetTrainingSequencesKey)
            trainingSequenceOffsets = RList(key: incomingOffsetTrainingSequenceOffsetsKey)
        case .outgoing:
            trainingSequences = RList(key: outgoingOffsetTrainingSequencesKey)
            trainingSequenceOffsets = RList(key: outgoingOffsetTrainingSequenceOffsetsKey)
        }
        
        switch connectionType
        {
        case .allowed:
            connectionsList = RList(key: allowedConnectionsKey)
            switch connectionDirection
            {
            case .incoming:
                packetsMap = RMap(key: allowedIncomingKey)
            case .outgoing:
                packetsMap = RMap(key: allowedOutgoingKey)
            }
        case .blocked:
            connectionsList = RList(key: blockedConnectionsKey)
            switch connectionDirection
            {
            case .incoming:
                packetsMap = RMap(key: blockedIncomingKey)
            case .outgoing:
                packetsMap = RMap(key: blockedOutgoingKey)
            }
        }
        
        for connectionID in connectionsList
        {
            guard let packet = packetsMap[connectionID] else { continue }
            
            var rowTable = MLDataTable()
            let classyColumn = MLDataColumn([connectionType.rawValue])
            rowTable.addColumn(classyColumn, named: ColumnLabel.classification.rawValue)
            
            for index in 0 ..< trainingSequences.count
            {
                guard let offset = trainingSequenceOffsets[index] else { continue }
                guard let trainingSequence = trainingSequences[index] else { continue }
                guard packet.count >= offset + trainingSequence.count else { continue }
                let subsequence = packet[offset..<offset + trainingSequence.count]
                let sequenceColumn: MLDataColumn<Int>
                
                if subsequence == trainingSequence
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
            case .allowed:
                accuracyKey = allowedIncomingFloatAccuracyKey
            case .blocked:
                accuracyKey = blockedIncomingFloatAccuracyKey
            }
        case .outgoing:
            classifierName = outFloatClassifierName
            switch connectionType
            {
            case .allowed:
                accuracyKey = allowedOutgoingFloatAccuracyKey
            case .blocked:
                accuracyKey = blockedOutgoingFloatAccuracyKey
            }
        }
        
        do
        {
            let classifierFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.length.rawValue: floatSequences])
            
            guard let appDirectory = getAdversarySupportDirectory()
                else
            {
                print("\nFailed to test models. Unable to locate application document directory.")
                return
            }
            
            let temporaryDirURL = appDirectory.appendingPathComponent("\(configModel.modelName)/temp/\(configModel.modelName)", isDirectory: true)
            let classifierFileURL = temporaryDirURL.appendingPathComponent(classifierName, isDirectory: false).appendingPathExtension(modelFileExtension)
            
            // This is the dictionary where we will save our results
            let floatDictionary: RMap<String,Double> = RMap(key: testResultsKey)
            
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
                    
                    floatDictionary[accuracyKey] = accuracy
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
            case .allowed:
                accuracyKey = allowedIncomingOffsetAccuracyKey
            case .blocked:
                accuracyKey = blockedIncomingOffsetAccuracyKey
            }
        case .outgoing:
            classifierName = outOffsetClassifierName
            switch connectionType
            {
            case .allowed:
                accuracyKey = allowedOutgoingOffsetAccuracyKey
            case .blocked:
                accuracyKey = blockedOutgoingOffsetAccuracyKey
            }
        }
        
        do
        {
            let classifierFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.length.rawValue: offsetSequences])
            
            guard let appDirectory = getAdversarySupportDirectory()
                else
            {
                print("\nFailed to test models. Unable to locate application document directory.")
                return
            }
            
            let temporaryDirURL = appDirectory.appendingPathComponent("\(configModel.modelName)/temp/\(configModel.modelName)", isDirectory: true)
            let classifierFileURL = temporaryDirURL.appendingPathComponent(classifierName, isDirectory: false).appendingPathExtension(modelFileExtension)
            
            // This is the dictionary where we will save our results
            let offsetDictionary: RMap<String,Double> = RMap(key: testResultsKey)
            
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
                    
                    offsetDictionary[accuracyKey] = accuracy
                }
            }
        }
        catch
        {
            print("Unable to test float sequences: Failed to create the feature provider.")
        }
    }
    
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
        let allowedFloatsRSet: RSortedSet<Data> = RSortedSet(key: allowedFloatsKey)
        let allowedFloatsArray = newDataArray(from: [allowedFloatsRSet])
        
        /// B is the sorted set of lengths for the Blocked traffic
        let blockedFloatsRSet: RSortedSet<Data> = RSortedSet(key: blockedFloatsKey)
        let blockedFloatsArray = newDataArray(from: [blockedFloatsRSet])
        
        return (allowedFloatsArray, blockedFloatsArray)
    }
    
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
        let allowedOffsetsRSet: RSortedSet<Data> = RSortedSet(key: allowedOffsetsKey)
        let allowedOffsetsArray = newDataArray(from: [allowedOffsetsRSet])
        
        /// B is the sorted set of lengths for the Blocked traffic
        let blockedOffsetsRSet: RSortedSet<Data> = RSortedSet(key: blockedOffsetsKey)
        let blockedOffsetsArray = newDataArray(from: [blockedOffsetsRSet])
        
        return (allowedOffsetsArray, blockedOffsetsArray)
    }

    func trainFloatModels(connectionDirection: ConnectionDirection, modelName: String)
    {
        let sequencesTAccKey: String
        let sequencesVAccKey: String
        let sequencesEAccKey: String
        let classifierName: String
        let floatSequenceTable = createFloatTable(connectionDirection: connectionDirection)
        
        switch connectionDirection
        {
        case .incoming:
            sequencesTAccKey = incomingFloatSequencesTAccKey
            sequencesVAccKey = incomingFloatSequencesVAccKey
            sequencesEAccKey = incomingFloatSequencesEAccKey
            classifierName = inFloatClassifierName
        case .outgoing:
            sequencesTAccKey = outgoingFloatSequencesTAccKey
            sequencesVAccKey = outgoingFloatSequencesVAccKey
            sequencesEAccKey = outgoingFloatSequencesEAccKey
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
            
            // Save Scores
            let floatDictionary: RMap<String, Double> = RMap(key: floatSequencesTrainingResultsKey)
            floatDictionary[sequencesTAccKey] = trainingAccuracy
            floatDictionary[sequencesEAccKey] = evaluationAccuracy
            
            if validationAccuracy != nil
            {
                floatDictionary[sequencesVAccKey] = validationAccuracy!
            }
            
            // Save the models to a file
            MLModelController().save(classifier: classifier, classifierMetadata: floatClassifierMetadata, fileName: classifierName, groupName: modelName)
        }
        catch
        {
            print("\nError creating the classifier for float sequences:\(error)")
        }
    }
    
    func trainOffsetModels(connectionDirection: ConnectionDirection, modelName: String)
    {
        let sequencesTAccKey: String
        let sequencesVAccKey: String
        let sequencesEAccKey: String
        let classifierName: String
        let offsetSequenceTable = createOffsetTable(connectionDirection: connectionDirection)
        
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
            
            // Save Scores
            let offsetDictionary: RMap<String, Double> = RMap(key: offsetSequencesTrainingResultsKey)
            offsetDictionary[sequencesTAccKey] = trainingAccuracy
            offsetDictionary[sequencesEAccKey] = evaluationAccuracy
            
            if validationAccuracy != nil
            {
                offsetDictionary[sequencesVAccKey] = validationAccuracy!
            }
            
            // Save the models to a file
            MLModelController().save(classifier: classifier, classifierMetadata: offsetClassifierMetadata, fileName: classifierName, groupName: modelName)
        }
        catch let error
        {
            print("\nError creating the classifier for offsets:\(error)")
        }
    }
    
    func newDataArray(from redisSets:[RSortedSet<Data>]) -> [Data]
    {
        var newArray = [Data]()
        
        for set in redisSets
        {
            for i in 0 ..< set.count
            {
                if let newMember: Data = set[i]
                {
                    newArray.append(newMember)
                }
            }
        }
        
        return newArray
    }
}
