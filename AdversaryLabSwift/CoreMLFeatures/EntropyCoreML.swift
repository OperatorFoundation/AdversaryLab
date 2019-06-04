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
            testEntropy(connectionDirection: .outgoing, configModel: configModel)
            testEntropy(connectionDirection: .incoming, configModel: configModel)
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
    
    func getEntropyAndClassificationLists(connectionDirection: ConnectionDirection) -> (entropyList: [Double], classificationLabels: [String])
    {
        var entropyList = [Double]()
        var classificationLabels = [String]()
        
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
        let allowedEntropyList: RList<Double> = RList(key: allowedEntropyKey)
        
        for entropyIndex in 0 ..< allowedEntropyList.count
        {
            guard let aEntropy = allowedEntropyList[entropyIndex]
                else
            {
                continue
            }
            
            entropyList.append(aEntropy)
            classificationLabels.append(ClassificationLabel.allowed.rawValue)
        }
        
        /// Blocked traffic
        let blockedEntropyList: RList<Double> = RList(key: blockedEntropyKey)
        
        for entropyIndex in 0 ..< blockedEntropyList.count
        {
            guard let bEntropy = blockedEntropyList[entropyIndex]
                else
            {
                continue
            }
            
            entropyList.append(bEntropy)
            classificationLabels.append(ClassificationLabel.blocked.rawValue)
        }
        
        return (entropyList, classificationLabels)
    }
    
    func testEntropy(connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
    {
        let (entropyList, classificationLabels) = getEntropyAndClassificationLists(connectionDirection: connectionDirection)
        
        let entropyColumnLabel: String
        let entropyClassifierName: String
        
        switch connectionDirection
        {
        case .outgoing:
            entropyColumnLabel = ColumnLabel.outEntropy.rawValue
            entropyClassifierName = outEntropyClassifierName
        case .incoming:
            entropyColumnLabel = ColumnLabel.inEntropy.rawValue
            entropyClassifierName = inEntropyClassifierName
        }
        
        guard entropyList.count == classificationLabels.count
            else { return }
        
        do
        {
            let batchFeatureProvider = try MLArrayBatchProvider(dictionary: [entropyColumnLabel: entropyList, ColumnLabel.classification.rawValue: classificationLabels])
            
            guard let appDirectory = getAdversarySupportDirectory()
                else
            {
                print("\nFailed to test entropy model. Unable to locate application document directory.")
                return
            }
            
            let temporaryDirURL = appDirectory.appendingPathComponent("\(configModel.modelName)/temp/\(configModel.modelName)", isDirectory: true)
            
            let classifierFileURL = temporaryDirURL.appendingPathComponent(entropyClassifierName, isDirectory: false).appendingPathExtension("mlmodel")
            
            if FileManager.default.fileExists(atPath: classifierFileURL.path)
            {
                guard let classifierPrediction = MLModelController().prediction(fileURL: classifierFileURL, batchFeatureProvider: batchFeatureProvider)
                    else
                {
                    print("\nFailed to make an entropy prediction.")
                    return
                }
                
                // TODO: Save the classifier prediction accuracy
                let firstFeature = classifierPrediction.features(at: 0)
                let probability = firstFeature.featureValue(for: "classificationProbability").debugDescription
                print("\n🔮  Created an entropy prediction from a model file. Feature at index 0 \(firstFeature)\nFeature Names:\n\(firstFeature.featureNames)\nClassification Probability:\n\(probability)")
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
            let classifier = try MLClassifier(trainingData: entropyTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
            
            // Classifier Training Accuracy as a Percentage
            let trainingError = classifier.trainingMetrics.classificationError
            let trainingAccuracy = (1.0 - trainingError) * 100
            print("\nEntropy training accuracy = \(trainingAccuracy)")
            
            // Classifier validation accuracy as a percentage
            let validationError = classifier.validationMetrics.classificationError
            let validationAccuracy = (1.0 - validationError) * 100
            print("\nEntropy validation accuracy = \(validationAccuracy)")
            
            // Evaluate the classifier
            let classifierEvaluation = classifier.evaluation(on: entropyEvaluationTable)
            
            // Classifier evaluation accuracy as a percentage
            let evaluationError = classifierEvaluation.classificationError
            let evaluationAccuracy = (1.0 - evaluationError) * 100
            print("\nEntropy Evaluation Accuracy = \(evaluationAccuracy)")
            
            // Regressor
            do
            {
                let regressor = try MLRegressor(trainingData: entropyTrainingTable, targetColumn: ColumnLabel.entropy.rawValue)
                
                // The largest distance between predictions and expected values
                let worstTrainingError = regressor.trainingMetrics.maximumError
                let worstValidationError = regressor.validationMetrics.maximumError
                
                // Evaluate the regressor
                let regressorEvaluation = regressor.evaluation(on: entropyEvaluationTable)
                
                // The largest distance between predictions and expected values
                let worstEvaluationError = regressorEvaluation.maximumError
                
                print("\nEntropy regressor:")
                print("Worst Training Error: \(worstTrainingError)")
                print("Worst Validation Error: \(worstValidationError)")
                print("Worst Evaluation Error: \(worstEvaluationError)")
                
                guard let (allowedEntropyTable, blockedEntropyTable) = MLModelController().createAllowedBlockedTables(fromTable: entropyTable)
                else
                {
                    print("\nUnable to create allowed and blocked tables from entropy table.")
                    return
                }
                
                // This is the dictionary we will save our results to
                let entropyResults: RMap<String,Double> = RMap(key: entropyTrainingResultsKey)
                
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
                    entropyResults[entropyTAccKey] = trainingAccuracy
                    entropyResults[entropyVAccKey] = validationAccuracy
                    entropyResults[entropyEAccKey] = evaluationAccuracy
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

func newDoubleSet(from redisSets:[RSortedSet<Double>]) -> Set<Double>
{
    var swiftSet = Set<Double>()
    for set in redisSets
    {
        for i in 0 ..< set.count
        {
            if let newMember: Double = set[i]
            {
                swiftSet.insert(newMember)
            }
        }
    }
    
    return swiftSet
}
