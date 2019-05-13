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
    
    func scoreAllEntropyInDatabase(modelName: String)
    {
        // Outgoing
        let outEntropyTable = createEntropyTable(connectionDirection: .outgoing)
        scoreEntropy(table: outEntropyTable, connectionDirection: .outgoing, modelName: modelName)
        
        // Incoming
        let inEntropyTable = createEntropyTable(connectionDirection: .incoming)
        scoreEntropy(table: inEntropyTable, connectionDirection: .incoming, modelName: modelName)
    }
    
    func createEntropyTable(connectionDirection: ConnectionDirection) -> MLDataTable
    {
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
        
        var entropyList = [Double]()
        var classificationLabels = [String]()
        
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
        
        var entropyTable = MLDataTable()
        let entropyColumn = MLDataColumn(entropyList)
        let classificationColumn = MLDataColumn(classificationLabels)
        entropyTable.addColumn(entropyColumn, named: ColumnLabel.entropy.rawValue)
        entropyTable.addColumn(classificationColumn, named: ColumnLabel.classification.rawValue)
        
        return entropyTable
    }
    
    func scoreEntropy(table entropyTable: MLDataTable, connectionDirection: ConnectionDirection, modelName: String)
    {
        let requiredEntropyKey: String
        let forbiddenEntropyKey: String
        let entropyTAccKey: String
        let entropyVAccKey: String
        let entropyEAccKey: String
        
        switch connectionDirection
        {
        case .outgoing:
            requiredEntropyKey = outgoingRequiredEntropyKey
            forbiddenEntropyKey = outgoingForbiddenEntropyKey
            entropyTAccKey = outgoingEntropyTAccKey
            entropyVAccKey = outgoingEntropyVAccKey
            entropyEAccKey = outgoingEntropyEAccKey
        case .incoming:
            requiredEntropyKey = incomingRequiredEntropyKey
            forbiddenEntropyKey = incomingForbiddenEntropyKey
            entropyTAccKey = incomingEntropyTAccKey
            entropyVAccKey = incomingEntropyVAccKey
            entropyEAccKey = incomingEntropyEAccKey
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
                
                // This is the dictionary we will save our results to
                let entropyResults: RMap<String,Double> = RMap(key: entropyResultsKey)
                
                // Allowed Entropy
                do
                {
                    let allowedEntropyTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.allowed.rawValue, ColumnLabel.entropy.rawValue: 0])
                    
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
                }
                catch let allowedTableError
                {
                    print("Error creating allowed entropy table: \(allowedTableError)")
                }
                
                // Blocked Entropy
                do
                {
                    let blockedEntropyTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.blocked.rawValue, ColumnLabel.entropy.rawValue: 0])
                    
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
                        MLModelController().saveModel(classifier: classifier, classifierMetadata: entropyClassifierMetadata, regressor: regressor, regressorMetadata: entropyRegressorMetadata, fileName: ColumnLabel.entropy.rawValue, groupName: modelName)
                    }
                    catch let blockedColumnError
                    {
                        print("Error creating blocked entropy column: \(blockedColumnError)")
                    }
                }
                catch let blockedTableError
                {
                    print("Error creating blocked table for entropy: \(blockedTableError)")
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
