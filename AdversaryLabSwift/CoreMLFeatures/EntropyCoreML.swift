//
//  Entropy.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn
import CreateML
import CoreML

class EntropyCoreML
{
    func processEntropy(forConnection connection: ObservedConnection) -> (processsed: Bool, inEntropy: Double?, outEntropy: Double?, error: Error?)
    {
        let inPacketsEntropyList: RList<Double> = RList(key: connection.incomingEntropyKey)
        let outPacketsEntropyList: RList<Double> = RList(key: connection.outgoingEntropyKey)
        
        // Get the outgoing packet that corresponds with this connection ID
        let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
        guard let outPacket: Data = outPacketHash[connection.connectionID]
            else
        {
            return (false, nil, nil, PacketLengthError.noOutPacketForConnection(connection.connectionID))
        }
        
        let outPacketEntropy = calculateEntropy(for: outPacket)
        outPacketsEntropyList.append(outPacketEntropy)
        
        // Get the incoming packet that corresponds with this connection ID
        let inPacketHash: RMap<String, Data> = RMap(key: connection.incomingKey)
        guard let inPacket = inPacketHash[connection.connectionID]
            else
        {
            return(false, nil, nil, PacketLengthError.noInPacketForConnection(connection.connectionID))
        }
        
        let inPacketEntropy = calculateEntropy(for: inPacket)
        inPacketsEntropyList.append(inPacketEntropy)
        
        return (true, inPacketEntropy, outPacketEntropy, nil)
    }
    
    func calculateEntropy(for packet: Data) -> Double
    {
        let probabilities: [Double] = calculateProbabilities(for: packet)
        var entropy: Double = 0
        
        for probability in probabilities
        {
            if probability != 0 {
                let plog2 = log2(probability)
                entropy += (plog2 * probability)
            }
        }
        entropy = -entropy
        
        return entropy
    }
    
    /// Calculates the probability of each byte in the data packet
    /// and returns them in an array where the index is the byte and value is the probability
    private func calculateProbabilities(for packet: Data) -> [Double]
    {
        let packetArray = [UInt8](packet)
        var countArray = Array(repeating: 0.0, count: 256)
        
        for byte in packetArray {
            let index = Int(byte)
            countArray[index] += 1
        }
        
        for (index, countValue) in countArray.enumerated()
        {
            if countValue != 0 {
                countArray[index] /= Double(packet.count)
            }
        }
        
        return countArray
    }
    
    func scoreAllEntropyInDatabase(configModel: ProcessingConfigurationModel)
    {
        if configModel.trainingMode
        {
            // Outgoing
            let outEntropyTable = createEntropyTable(connectionDirection: .outgoing)
            trainEntropy(table: outEntropyTable, connectionDirection: .outgoing, modelName: configModel.modelName)
            
            // Incoming
            let inEntropyTable = createEntropyTable(connectionDirection: .incoming)
            trainEntropy(table: inEntropyTable, connectionDirection: .incoming, modelName: configModel.modelName)
        }
        else
        {
            testModel(connectionDirection: .incoming, configModel: configModel)
            testModel(connectionDirection: .outgoing, configModel: configModel)
        }
        
    }
    
    func createEntropyTable(connectionDirection: ConnectionDirection) -> MLDataTable
    {
        let (entropyList, classificationLabels) = getEntropyAndClassificationLists(connectionDirection: connectionDirection)
        
        var entropyTable = MLDataTable()
        let entropyColumn = MLDataColumn(entropyList)
        let classificationColumn = MLDataColumn(classificationLabels)
        entropyTable.addColumn(entropyColumn, named: ColumnLabel.entropy.rawValue)
        entropyTable.addColumn(classificationColumn, named: ColumnLabel.classification.rawValue)
        
        return entropyTable
    }
    
    func getAllowedBlockedEntropyLists(connectionDirection: ConnectionDirection) -> (allowedEntropy:[Double], blockedEntropy: [Double])
    {
        var allowedEntropyList = [Double]()
        var blockedEntropyList = [Double]()
        
        let allowedEntropyKey: String
        let blockedEntropyKey: String
        
        switch connectionDirection
        {
        case .outgoing:
            allowedEntropyKey = allowedOutgoingEntropyKey
            blockedEntropyKey = blockedOutgoingEntropyKey
        case .incoming:
            allowedEntropyKey = allowedIncomingEntropyKey
            blockedEntropyKey = blockedIncomingEntropyKey
        }
        
        // Allowed Traffic
        allowedEntropyList = RList(key: allowedEntropyKey).list
        blockedEntropyList = RList(key: blockedEntropyKey).list
        
        return (allowedEntropyList, blockedEntropyList)
    }
    
    func getEntropyAndClassificationLists(connectionDirection: ConnectionDirection) -> (entropyList: [Double], classificationLabels: [String])
    {
        var entropyList = [Double]()
        var classificationLabels = [String]()
        let (allowedEntropyList, blockedEntropyList) = getAllowedBlockedEntropyLists(connectionDirection: connectionDirection)
        
        // Allowed Traffic
        
        for entropyIndex in 0 ..< allowedEntropyList.count
        {
            let aEntropy = allowedEntropyList[entropyIndex]
            entropyList.append(aEntropy)
            classificationLabels.append(ClassificationLabel.transportA.rawValue)
        }
        
        /// Blocked traffic
        
        for entropyIndex in 0 ..< blockedEntropyList.count
        {
            let bEntropy = blockedEntropyList[entropyIndex]
            entropyList.append(bEntropy)
            classificationLabels.append(ClassificationLabel.transportB.rawValue)
        }
        
        return (entropyList, classificationLabels)
    }
    
    func testModel(connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
    {
        let (allowedEntropyList, blockedEntropyList) = getAllowedBlockedEntropyLists(connectionDirection: connectionDirection)
        
        guard blockedEntropyList.count > 0
        else
        {
            print("\nUnable to test entropy. The blocked entropy list is empty.")
            return
        }
        
        // Allowed
        testModel(entropyList: allowedEntropyList, connectionType: .transportA, connectionDirection: connectionDirection, configModel: configModel)
        
        // Blocked
        testModel(entropyList: blockedEntropyList, connectionType: .transportB, connectionDirection: connectionDirection, configModel: configModel)
    }
    
    func testModel(entropyList: [Double], connectionType: ClassificationLabel, connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
    {
        let entropyClassifierName: String
        let entropyRegressorName: String
        let accuracyKey: String
        let entropyKey: String
        
        switch connectionDirection
        {
        case .outgoing:
            entropyClassifierName = outEntropyClassifierName
            entropyRegressorName = outEntropyRegressorName
            switch connectionType
            {
            case .transportA:
                accuracyKey = allowedOutgoingEntropyAccuracyKey
                entropyKey = allowedOutgoingEntropyKey
            case .transportB:
                accuracyKey = blockedOutgoingEntropyAccuracyKey
                entropyKey = blockedOutgoingEntropyKey
            }
        case .incoming:
            entropyClassifierName = inEntropyClassifierName
            entropyRegressorName = inEntropyRegressorName
            switch connectionType
            {
            case .transportA:
                accuracyKey = allowedIncomingEntropyAccuracyKey
                entropyKey = allowedIncomingEntropyKey
            case .transportB:
                accuracyKey = blockedIncomingEntropyAccuracyKey
                entropyKey = blockedIncomingEntropyKey
            }
        }

        do
        {
            let classifierFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.entropy.rawValue: entropyList])
            let regressorFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.classification.rawValue: [connectionType.rawValue]])
            
            guard let tempDirURL = getAdversaryTempDirectory()
                else
            {
                print("\nFailed to test entropy model. Unable to locate application document directory.")
                return
            }
            
            let temporaryDirURL = tempDirURL.appendingPathComponent("\(configModel.modelName)", isDirectory: true)
            let classifierFileURL = temporaryDirURL.appendingPathComponent(entropyClassifierName, isDirectory: false).appendingPathExtension(modelFileExtension)
            let regressorFileURL = temporaryDirURL.appendingPathComponent(entropyRegressorName).appendingPathExtension(modelFileExtension)
            
            // This is the dictionary where we will save our results (saves to Redis db)
            let entropyDictionary: RMap<String,Double> = RMap(key: testResultsKey)
            
            // Regressor
            if FileManager.default.fileExists(atPath: regressorFileURL.path)
            {
                guard let regressorPrediction = MLModelController().prediction(fileURL: regressorFileURL, batchFeatureProvider: regressorFeatureProvider)
                    else
                {
                    print("\n🛑  Failed to make an entropy regressor prediction.")
                    return
                }
                
                guard regressorPrediction.count > 0
                    else { return }
                
                // We are only expecting one result
                let thisFeatureNames = regressorPrediction.features(at: 0).featureNames
                
                // Check that we received a result with a feature named 'entropy' and that it has a value.
                guard let firstFeatureName = thisFeatureNames.first
                    else { return }
                guard firstFeatureName == ColumnLabel.entropy.rawValue
                    else { return }
                guard let thisFeatureValue = regressorPrediction.features(at: 0).featureValue(for: firstFeatureName)
                    else { return }
                
                print("🔮 Entropy prediction for \(entropyKey): \(thisFeatureValue).")
                entropyDictionary[entropyKey] = thisFeatureValue.doubleValue
            }
            
            // Classifier
            if FileManager.default.fileExists(atPath: classifierFileURL.path)
            {
                guard let classifierPrediction = MLModelController().prediction(fileURL: classifierFileURL, batchFeatureProvider: classifierFeatureProvider)
                    else
                {
                    print("\n🛑  Failed to make an entropy classifier prediction.")
                    return
                }
                
                let classifierFeatureCount = classifierPrediction.count
                var allowedBlockedCount: Double = 0.0
                for index in 0 ..< classifierFeatureCount
                {
                    let thisFeature = classifierPrediction.features(at: index)
                    guard let entropyClassification = thisFeature.featureValue(for: "classification")
                        else { continue }
                    if entropyClassification.stringValue == connectionType.rawValue
                    {
                        allowedBlockedCount += 1
                    }
                }
                
                var accuracy = allowedBlockedCount/Double(classifierFeatureCount)
                // Round it to 3 decimal places
                accuracy = (accuracy * 1000).rounded()/1000
                // Show the accuracy as a percentage value
                accuracy = accuracy * 100
                print("🔮 Entropy classification prediction accuracy: \(accuracy) \(connectionType.rawValue).")
                
                entropyDictionary[accuracyKey] = accuracy
            }
        }
        catch
        {
            print("Unable to test \(connectionDirection) entropy. Error creating batch feature provider: \(error)")
        }
    }
    
    func trainEntropy(table entropyTable: MLDataTable, connectionDirection: ConnectionDirection, modelName: String)
    {
        let requiredEntropyKey: String
        let forbiddenEntropyKey: String
        let entropyTAccKey: String
        let entropyVAccKey: String
        let entropyEAccKey: String
        let entropyClassifierName: String
        let entropyRegressorName: String
        
        switch connectionDirection
        {
        case .outgoing:
            requiredEntropyKey = outgoingRequiredEntropyKey
            forbiddenEntropyKey = outgoingForbiddenEntropyKey
            entropyTAccKey = outgoingEntropyTAccKey
            entropyVAccKey = outgoingEntropyVAccKey
            entropyEAccKey = outgoingEntropyEAccKey
            entropyClassifierName = outEntropyClassifierName
            entropyRegressorName = outEntropyRegressorName
        case .incoming:
            requiredEntropyKey = incomingRequiredEntropyKey
            forbiddenEntropyKey = incomingForbiddenEntropyKey
            entropyTAccKey = incomingEntropyTAccKey
            entropyVAccKey = incomingEntropyVAccKey
            entropyEAccKey = incomingEntropyEAccKey
            entropyClassifierName = inEntropyClassifierName
            entropyRegressorName = inEntropyRegressorName
        }
        
        // Set aside 20% of the model's data rows for evaluation, leaving the remaining 80% for training
        let (entropyEvaluationTable, entropyTrainingTable) = entropyTable.randomSplit(by: 0.20)
        
        // Train the classifier
        do
        {
            // This is the dictionary we will save our results to
            let entropyResults: RMap<String,Double> = RMap(key: entropyTrainingResultsKey)
            let classifier = try MLClassifier(trainingData: entropyTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
            
            // Classifier Training Accuracy as a Percentage
            let trainingError = classifier.trainingMetrics.classificationError
            var trainingAccuracy: Double? = nil
            if trainingError >= 0
            {
                trainingAccuracy = (1.0 - trainingError) * 100
                
            }
            if trainingAccuracy != nil
            {
                entropyResults[entropyTAccKey] = trainingAccuracy
            }
            
            // Classifier validation accuracy as a percentage
            let validationError = classifier.validationMetrics.classificationError
            var validationAccuracy: Double? = nil
            
            // Sometimes we get a negative number, this is not valid for our purposes
            if validationError >= 0
            {
                validationAccuracy = (1.0 - validationError) * 100
            }

            if validationAccuracy != nil
            {
                entropyResults[entropyVAccKey] = validationAccuracy!
            }
            // Evaluate the classifier
            let classifierEvaluation = classifier.evaluation(on: entropyEvaluationTable)
            
            // Classifier evaluation accuracy as a percentage
            let evaluationError = classifierEvaluation.classificationError
            var evaluationAccuracy: Double? = nil
            if evaluationError >= 0
            {
                evaluationAccuracy = (1.0 - evaluationError) * 100
            }
            if evaluationAccuracy != nil
            {
                entropyResults[entropyEAccKey] = evaluationAccuracy
            }
            
            // Regressor
            do
            {
                let regressor = try MLRegressor(trainingData: entropyTrainingTable, targetColumn: ColumnLabel.entropy.rawValue)
                
                guard let (allowedEntropyTable, blockedEntropyTable) = MLModelController().createAllowedBlockedTables(fromTable: entropyTable)
                else
                {
                    print("\nUnable to create allowed and blocked tables from entropy table.")
                    return
                }

                // Allowed Entropy
                do
                {
                    let allowedEntropyColumn = try regressor.predictions(from: allowedEntropyTable)
                    
                    guard let allowedEntropies = allowedEntropyColumn.doubles
                        else
                    {
                        print("Failed to identify allowed entropy.")
                        return
                    }
                    
                    let predictedAllowedEntropy = allowedEntropies[0]
                    print("\nPredicted allowed entropy = \(predictedAllowedEntropy)")
                    
                    /// Save Results
                    entropyResults[requiredEntropyKey] = predictedAllowedEntropy
                }
                catch let allowedColumnError
                {
                    print("\nError creating allowed entropy column:\(allowedColumnError)")
                }
                
                // Blocked Entropy
                do
                {
                    let blockedEntropyColumn = try regressor.predictions(from: blockedEntropyTable)
                    guard let blockedEntropies = blockedEntropyColumn.doubles
                        else
                    {
                        print("\nFailed to identify blocked entropy.")
                        return
                    }
                    
                    let predictedBlockedEntropy = blockedEntropies[0]
                    print("\nPredicted blocked entropy = \(predictedBlockedEntropy)")
                    
                    // Save Scores
                    entropyResults[forbiddenEntropyKey] = predictedBlockedEntropy
                    
                    // Save the models
                    MLModelController().saveModel(classifier: classifier,
                                                  classifierMetadata: entropyClassifierMetadata,
                                                  classifierFileName: entropyClassifierName,
                                                  regressor: regressor,
                                                  regressorMetadata: entropyRegressorMetadata,
                                                  regressorFileName: entropyRegressorName,
                                                  groupName: modelName)
                }
                catch let blockedColumnError
                {
                    print("Error creating blocked entropy column: \(blockedColumnError)")
                }
            }
            catch let regressorError
            {
                print("Error creating regressor for entropy: \(regressorError)")
            }
        }
        catch let classifierError
        {
            print("\nError creating classifier: \(classifierError)")
        }
    }

}
