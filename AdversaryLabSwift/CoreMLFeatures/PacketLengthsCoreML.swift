//
//  PacketLengths.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn
import CreateML
import CoreML

class PacketLengthsCoreML
{
    func processPacketLengths(forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
    {
        let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
        let outgoingLengthSet: RSortedSet<Int> = RSortedSet(key: connection.outgoingLengthsKey)
        let inPacketHash: RMap<String, Data> = RMap(key: connection.incomingKey)
        let incomingLengthSet: RSortedSet<Int> = RSortedSet(key: connection.incomingLengthsKey)
        
        // Get the out packet that corresponds with this connection ID
        guard let outPacket: Data = outPacketHash[connection.connectionID]
            else
        {
            return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID))
        }
        
        /// DEBUG
        if outPacket.count < 10
        {
            print("\n### Outpacket count = \(String(outPacket.count))")
            print("\n⁉️  We got a weird out packet size... \(String(describing: String(data: outPacket, encoding: .utf8)))<----")
        }
        ///
        
        // Increment the score of this particular outgoing packet length
        let _ = outgoingLengthSet.incrementScore(ofField: outPacket.count, byIncrement: 1)
        
        // Get the in packet that corresponds with this connection ID
        guard let inPacket = inPacketHash[connection.connectionID]
            else
        {
            return(false, PacketLengthError.noInPacketForConnection(connection.connectionID))
        }
        
        /// DEBUG
        if inPacket.count < 10
        {
            print("\n### Inpacket count = \(String(inPacket.count))\n")
            print("\n⁉️  We got a weird in packet size... \(String(describing: String(data: outPacket, encoding: .utf8))) <---\n")
        }
        ///
        
        // Increment the score of this particular incoming packet length
        let newInScore = incomingLengthSet.incrementScore(ofField: inPacket.count, byIncrement: 1)
        if newInScore == nil
        {
            return(false, PacketLengthError.unableToIncremementScore(packetSize: inPacket.count, connectionID: connection.connectionID))
        }
        
        return(true, nil)
    }
    
    /**
     Train a model for packet lengths
     
     - Parameter modelName: A String that will be used to save the resulting mlm file.
     */
    func scoreAllPacketLengths(configModel: ProcessingConfigurationModel)
        //(modelName: String, trainingMode: Bool)
    {
        // Outgoing Lengths Scoring
        scorePacketLengths(connectionDirection: .outgoing, modelName: configModel.modelName, trainingMode: configModel.trainingMode)
        
        //Incoming Lengths Scoring
        scorePacketLengths(connectionDirection: .incoming, modelName: configModel.modelName, trainingMode: configModel.trainingMode)
    }
    
    func scorePacketLengths(connectionDirection: ConnectionDirection, modelName: String, trainingMode: Bool)
    {
        let (lengths, classificationLabels) = getLengthsAndClassificationsArrays(connectionDirection: connectionDirection)
        
        if trainingMode
        {
            let lengthsTable = createLengthTable(classificationLabels: classificationLabels, lengths: lengths)
            trainModels(lengthsTable: lengthsTable, connectionDirection: connectionDirection, modelName: modelName)
        }
        else
        {
            testModels(classificationLabels: classificationLabels, lengths: lengths, connectionDirection: connectionDirection, modelName: modelName)
        }
    }
    
    func testModels(classificationLabels: [String], lengths: [Int], connectionDirection: ConnectionDirection, modelName: String)
    {
        let classifierName: String
        let lengthClassificationKey: String
        let lengthClassificationProbabiltyKey: String
        
        switch connectionDirection
        {
        case .incoming:
            classifierName = inLengthClassifierName
            lengthClassificationKey = incomingLengthClassificationKey
            lengthClassificationProbabiltyKey = incomingLengthClassificationProbKey
        case .outgoing:
            classifierName = outLengthClassifierName
            lengthClassificationKey = outgoingLengthClassificationKey
            lengthClassificationProbabiltyKey = outgoingLengthClassificationProbKey
        }
        do
        {
            guard classificationLabels.count == lengths.count
            else
            {
                print("Cannot test the lengths model, lengths (\(lengths.count)), and classifications (\(classificationLabels.count)) do not have the same number of values.")
                return
            }

            let batchFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.length.rawValue: lengths, ColumnLabel.classification.rawValue: classificationLabels])
            
            guard let appDirectory = getAdversarySupportDirectory()
            else
            {
                print("\nFailed to test models. Unable to locate application document directory.")
                return
            }
            
            let temporaryDirURL = appDirectory.appendingPathComponent("\(modelName)/temp/\(modelName)", isDirectory: true)
            let classifierFileURL = temporaryDirURL.appendingPathComponent(classifierName, isDirectory: false).appendingPathExtension("mlmodel")
            
            if FileManager.default.fileExists(atPath: classifierFileURL.path)
            {
                if let classifierPrediction = MLModelController().prediction(fileURL: classifierFileURL, batchFeatureProvider: batchFeatureProvider)
                {
                    let firstFeature = classifierPrediction.features(at: 0)
                    let probability = firstFeature.featureValue(for: PredictionKey.classificationProbability.rawValue).debugDescription

                    guard let lengthClassification = firstFeature.featureValue(for: PredictionKey.classification.rawValue)
                    else
                    {
                        print("\nLength classification result was nil.")
                        return
                    }
                    
                    print("\n🔮  Created a length prediction from a model file. Feature at index 0 \(firstFeature)\nFeature Names:\n\(firstFeature.featureNames)\nClassification Probability:\n\(probability)\nClassification:\n\(lengthClassification)")
                    
                    let lengthClassificationDictionary: RMap<String, String> = RMap(key: lengthClassificationKey)
                    lengthClassificationDictionary[ColumnLabel.classification.rawValue] = lengthClassification.stringValue
                    
                    let lengthClassificationProbabilityDictionary: RMap<String, String> = RMap(key: lengthClassificationKey)
                    lengthClassificationProbabilityDictionary[PredictionKey.classificationProbability.rawValue] = probability
                }
            }
        }
        catch let featureProviderError
        {
            print("\nError creating lengths feature provider: \(featureProviderError)")
        }
    }
    
    func createLengthTable(classificationLabels: [String], lengths: [Int]) -> MLDataTable
    {
        // Create the Lengths Table
        var lengthsTable = MLDataTable()
        let lengthsColumn = MLDataColumn(lengths)
        let classyLabelColumn = MLDataColumn(classificationLabels)
        lengthsTable.addColumn(lengthsColumn, named: ColumnLabel.length.rawValue)
        lengthsTable.addColumn(classyLabelColumn, named: ColumnLabel.classification.rawValue)
        
        return lengthsTable
    }
    
    func trainModels(lengthsTable: MLDataTable, connectionDirection: ConnectionDirection, modelName: String)
    {
        let requiredLengthKey: String
        let forbiddenLengthKey: String
        let lengthsTAccKey: String
        let lengthsVAccKey: String
        let lengthsEAccKey: String
        let regressorName: String
        let classifierName: String
        
        switch connectionDirection
        {
        case .incoming:
            requiredLengthKey = incomingRequiredLengthKey
            forbiddenLengthKey = incomingForbiddenLengthKey
            lengthsTAccKey = incomingLengthsTAccKey
            lengthsVAccKey = incomingLengthsVAccKey
            lengthsEAccKey = incomingLengthsEAccKey
            regressorName = inLengthRegressorName
            classifierName = inLengthClassifierName
        case .outgoing:
            requiredLengthKey = outgoingRequiredLengthKey
            forbiddenLengthKey = outgoingForbiddenLengthKey
            lengthsTAccKey = outgoingLengthsTAccKey
            lengthsVAccKey = outgoingLengthsVAccKey
            lengthsEAccKey = outgoingLengthsEAccKey
            regressorName = outLengthRegressorName
            classifierName = outLengthClassifierName
        }
        
        // Set aside 20% of the model's data rows for evaluation, leaving the remaining 80% for training
        let (lengthsEvaluationTable, lengthsTrainingTable) = lengthsTable.randomSplit(by: 0.20)
        
        // Train the classifier
        do
        {
            let classifier = try MLClassifier(trainingData: lengthsTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
            let trainingAccuracy = (1.0 - classifier.trainingMetrics.classificationError) * 100
            let validationAccuracy = (1.0 - classifier.validationMetrics.classificationError) * 100
            let classifierEvaluation = classifier.evaluation(on: lengthsEvaluationTable)
            let evaluationAccuracy = (1.0 - classifierEvaluation.classificationError) * 100
            
            do
            {
                let regressor = try MLRegressor(trainingData: lengthsTrainingTable, targetColumn: ColumnLabel.length.rawValue)
                
                guard let (allowedTable, blockedTable) = MLModelController().createAllowedBlockedTables(fromTable: lengthsTable)
                    else
                {
                    print("\nUnable to get allowed/blocked tables from lengths data table.")
                    return
                }
                
                let allowedPredictionColumn = try regressor.predictions(from: allowedTable)
                let blockedPredictionColumn = try regressor.predictions(from: blockedTable)
                
                guard let allowedLengths = allowedPredictionColumn.doubles
                    else
                {
                    print("Failed to get allowed lengths from allowed column.")
                    return
                }
                
                guard let blockedLengths = blockedPredictionColumn.doubles
                    else
                {
                    print("Failed to get blocked lengths from blocked column.")
                    return
                }

                let predictedAllowedLength = allowedLengths[0]
                let predictedBlockedLength = blockedLengths[0]
                
                // Save Scores
                let lengthsDictionary: RMap<String, Double> = RMap(key: packetLengthsTrainingResultsKey)
                lengthsDictionary[requiredLengthKey] = predictedAllowedLength
                lengthsDictionary[forbiddenLengthKey] = predictedBlockedLength
                lengthsDictionary[lengthsTAccKey] = trainingAccuracy
                lengthsDictionary[lengthsVAccKey] = validationAccuracy
                lengthsDictionary[lengthsEAccKey] = evaluationAccuracy
                
                // Save the models to a file
                MLModelController().saveModel(classifier: classifier,
                                              classifierMetadata: lengthsClassifierMetadata,
                                              classifierFileName: classifierName,
                                              regressor: regressor,
                                              regressorMetadata: lengthsRegressorMetadata,
                                              regressorFileName: regressorName,
                                              groupName: modelName)
            }
            catch let regressorError
            {
                print("\nError creating lengths regressor: \(regressorError)")
            }
        }
        catch let error
        {
            print("\nError creating the classifier for lengths:\(error)")
        }
    }
    
    func getLengthsAndClassificationsArrays(connectionDirection: ConnectionDirection) -> (lengths: [Int], classifications: [String])
    {
        var lengths = [Int]()
        var classificationLabels = [String]()
        let allowedLengthsKey: String
        let blockedLengthsKey: String
        
        switch connectionDirection
        {
        case .incoming:
            allowedLengthsKey = allowedIncomingLengthsKey
            blockedLengthsKey = blockedIncomingLengthsKey
        case .outgoing:
            allowedLengthsKey = allowedOutgoingLengthsKey
            blockedLengthsKey = blockedOutgoingLengthsKey
        }
        
        /// A is the sorted set of lengths for the Allowed traffic
        let allowedLengthsRSet: RSortedSet<Int> = RSortedSet(key: allowedLengthsKey)
        let allowedLengthsArray = newIntArray(from: [allowedLengthsRSet])
        
        /// B is the sorted set of lengths for the Blocked traffic
        let blockedLengthsRSet: RSortedSet<Int> = RSortedSet(key: blockedLengthsKey)
        let blockedLengthsArray = newIntArray(from: [blockedLengthsRSet])
        
        for length in allowedLengthsArray
        {
            guard let score: Float = allowedLengthsRSet[length]
                else
            {
                continue
            }
            
            let count = Int(score)
            
            for _ in 0 ..< count
            {
                lengths.append(length)
                classificationLabels.append(ClassificationLabel.allowed.rawValue)
            }
        }
        
        for length in blockedLengthsArray
        {
            guard let score: Float = blockedLengthsRSet[length]
                else { continue }
            
            let count = Int(score)
            
            for _ in 0 ..< count
            {
                lengths.append(length)
                classificationLabels.append(ClassificationLabel.blocked.rawValue)
            }
        }
        
        return(lengths, classificationLabels)
    }
    
    func newIntSet(from redisSets:[RSortedSet<Int>]) -> Set<Int>
    {
        var swiftSet = Set<Int>()
        for set in redisSets
        {
            for i in 0 ..< set.count
            {
                if let newMember: Int = set[i]
                {
                    swiftSet.insert(newMember)
                }
            }
        }
        
        return swiftSet
    }
    
    func newIntArray(from redisSets:[RSortedSet<Int>]) -> [Int]
    {
        var newArray = [Int]()
        
        for set in redisSets
        {
            for i in 0 ..< set.count
            {
                if let newMember: Int = set[i]
                {
                    newArray.append(newMember)
                }
            }
        }
        
        return newArray
    }
}



