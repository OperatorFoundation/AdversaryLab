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
    
    func scoreAllPacketLengths()
    {
        // Outgoing Lengths Scoring
        scorePacketLengths(allowedLengthsKey: allowedOutgoingLengthsKey, blockedLengthsKey: blockedOutgoingLengthsKey, requiredLengthsKey: outgoingRequiredLengthsKey, forbiddenLengthsKey: outgoingForbiddenLengthsKey)
        
        //Incoming Lengths Scoring
        scorePacketLengths(allowedLengthsKey: allowedIncomingLengthsKey, blockedLengthsKey: blockedIncomingLengthsKey, requiredLengthsKey: incomingRequiredLengthsKey, forbiddenLengthsKey: incomingForbiddenLengthsKey)
    }
    
    func scorePacketLengths(allowedLengthsKey: String, blockedLengthsKey: String, requiredLengthsKey: String, forbiddenLengthsKey: String)
    {
        var lengths = [Int]()
        var classificationLabel = [String]()

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
                classificationLabel.append(ClassificationLabel.allowed.rawValue)
            }
        }
        
        for length in blockedLengthsArray
        {
            guard let score: Float = blockedLengthsRSet[length]
                else
            {
                continue
            }
            
            let count = Int(score)
            
            for _ in 0 ..< count
            {
                lengths.append(length)
                classificationLabel.append(ClassificationLabel.blocked.rawValue)
            }
        }
        
        // Create the Lengths Table
        var lengthsTable = MLDataTable()
        let lengthsColumn = MLDataColumn(lengths)
        let classyLabelColumn = MLDataColumn(classificationLabel)
        lengthsTable.addColumn(lengthsColumn, named: ColumnLabel.length.rawValue)
        lengthsTable.addColumn(classyLabelColumn, named: ColumnLabel.classification.rawValue)
        
        // Set aside 20% of the model's data rows for evaluation, leaving the remaining 80% for training
        let (lengthsEvaluationTable, lengthsTrainingTable) = lengthsTable.randomSplit(by: 0.20)
        
        // Train the classifier
        do
        {
            let classifier = try MLClassifier(trainingData: lengthsTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
            
            // Classifier training accuracy as a percentage
            let trainingError = classifier.trainingMetrics.classificationError
            let trainingAccuracy = (1.0 - trainingError) * 100
            print("Length Classifier Training Accuracy = \(trainingAccuracy)")
            
            // Classifier validation accuracy as a percentage
            let validationError = classifier.validationMetrics.classificationError
            let validationAccuracy = (1.0 - validationError) * 100
            print("Length Classifier Validation Accuracy = \(validationAccuracy)")
            
            // Evaluate the classifier
            let classifierEvaluation = classifier.evaluation(on: lengthsEvaluationTable)
            
            // Classifier evaluation accuracy as a percentage
            let evaluationError = classifierEvaluation.classificationError
            let evaluationAccuracy = (1.0 - evaluationError) * 100
            print("Length Classifier Evaluation Accuracy \(evaluationAccuracy)")
            
            do
            {
                let regressor = try MLRegressor(trainingData: lengthsTrainingTable, targetColumn: ColumnLabel.length.rawValue)
                
                // The largest distance between predictions and expected values
                let worstTrainingError = regressor.trainingMetrics.maximumError
                let worstValidationError = regressor.validationMetrics.maximumError
                
                // Evaluate the regressor
                let regressorEvaluation = regressor.evaluation(on: lengthsEvaluationTable)
                
                // The largerat distance between predictions and the expected values
                let worstEvaluationError = regressorEvaluation.maximumError
                
                print("Length Regressor:")
                print("Worst Training Error = \(worstTrainingError)")
                print("Worst Validation Error = \(worstValidationError)")
                print("Worst Evaluation Error = \(worstEvaluationError)")
                
                do
                {
                    let allowedTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.allowed.rawValue, ColumnLabel.length.rawValue: 0])
                    
                    do
                    {
                        let blockedTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.blocked.rawValue, ColumnLabel.length.rawValue: 0])
                        do
                        {
                            let allowedColumn = try regressor.predictions(from: allowedTable)
                            
                            do
                            {
                                let blockedColumn = try regressor.predictions(from: blockedTable)
                                
                                guard let allowedLengths = allowedColumn.doubles
                                else
                                {
                                    print("Failed to get allowed lengths from allowed column.")
                                    return
                                }
                                
                                guard let blockedLengths = blockedColumn.doubles
                                else
                                {
                                    print("Failed to get blocked lengths from blocked column.")
                                    return
                                }
                                
                                let predictedAllowedLength = allowedLengths[0]
                                let predictedBlockedLength = blockedLengths[0]
                                print("\nPredicted Allowed Length = \(predictedAllowedLength)")
                                print("Predicted Blocked Length = \(predictedBlockedLength)")
                                
                                /// Save Scores
                                let requiredLengths: RSortedSet<Int> = RSortedSet(key: requiredLengthsKey)
                                let _ = requiredLengths.insert((Int(predictedAllowedLength), Float(evaluationAccuracy)))
                                
                                let forbiddenLengths: RSortedSet<Int> = RSortedSet(key: forbiddenLengthsKey)
                                let _ = forbiddenLengths.insert((Int(predictedBlockedLength), Float(evaluationAccuracy)))
                            }
                            catch let blockedPredictionError
                            {
                                print("\nError making blocked lengths prediction = \(blockedPredictionError)")
                            }
                        }
                        catch let allowedPredictionError
                        {
                            print("\nError making allowed lengths prediction = \(allowedPredictionError)")
                        }
                    }
                    catch let blockedTableError
                    {
                        print("\nError creating blocked lengths table: \(blockedTableError)")
                    }
                }
                catch let allowedTableError
                {
                    print("\nError creating allowed lengths table: \(allowedTableError)")
                }
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



