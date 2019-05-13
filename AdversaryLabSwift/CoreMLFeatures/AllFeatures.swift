//
//  AllFeatures.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 4/8/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn
import CreateML

class AllFeatures
{
    static let sharedInstance = AllFeatures()
    
    var timeDifferenceList = [Double]()
    var inLengths = [Int]()
    var outLengths = [Int]()
    var inEntropies = [Double]()
    var outEntropies = [Double]()
    var tlsNames = [String]()
    var classificationLabels = [String]()
    
    func scoreAllFeatures(modelName: String)
    {
        var scoreTLS: Bool
        
        guard !timeDifferenceList.isEmpty,
            !inLengths.isEmpty,
            !outLengths.isEmpty,
            !inEntropies.isEmpty,
            !outEntropies.isEmpty,
            !classificationLabels.isEmpty
            else { return }
        
        // Uneven number of values in tls column creates error
        scoreTLS = false
        
//        if tlsNames.isEmpty
//        {
//            scoreTLS = false
//        }
//        else
//        {
//            scoreTLS = true
//        }
        
        let timeDifferenceColumn = MLDataColumn(timeDifferenceList)
        let classyColumn = MLDataColumn(classificationLabels)
        
        // Outgoing Connections Table
        var allOutFeaturesTable = MLDataTable()
        let outLengthsColumn = MLDataColumn(outLengths)
        let outEntropyColumn = MLDataColumn(outEntropies)
        allOutFeaturesTable.addColumn(timeDifferenceColumn, named: ColumnLabel.timeDifference.rawValue)
        allOutFeaturesTable.addColumn(outLengthsColumn, named:ColumnLabel.outLength.rawValue)
        allOutFeaturesTable.addColumn(outEntropyColumn, named: ColumnLabel.outEntropy.rawValue)
        allOutFeaturesTable.addColumn(classyColumn, named: ColumnLabel.classification.rawValue)

        // Incoming Connections Table
        var allInFeaturesTable = MLDataTable()
        let inLengthsColumn = MLDataColumn(inLengths)
        let inEntropyColumn = MLDataColumn(inEntropies)
        allInFeaturesTable.addColumn(timeDifferenceColumn, named: ColumnLabel.timeDifference.rawValue)
        allInFeaturesTable.addColumn(inLengthsColumn, named: ColumnLabel.inLength.rawValue)
        allInFeaturesTable.addColumn(inEntropyColumn, named: ColumnLabel.inEntropy.rawValue)
        allInFeaturesTable.addColumn(classyColumn, named: ColumnLabel.classification.rawValue)
        
        if scoreTLS
        {
            let tlsColumn = MLDataColumn(tlsNames)
            allOutFeaturesTable.addColumn(tlsColumn, named: ColumnLabel.tlsNames.rawValue)
            allInFeaturesTable.addColumn(tlsColumn, named: ColumnLabel.tlsNames.rawValue)
        }
        
        train(allFeaturesTable: allOutFeaturesTable, forDirection: .outgoing, withModelName: modelName, includeTLS: scoreTLS)
        train(allFeaturesTable: allInFeaturesTable, forDirection: .incoming, withModelName: modelName, includeTLS: scoreTLS)
    }
    
    func train(allFeaturesTable: MLDataTable, forDirection connectionDirection: ConnectionDirection, withModelName modelName: String, includeTLS: Bool)
    {
        let lengthColumnLabel: String
        let requiredLengthKey: String
        let forbiddenLengthKey: String
        let entropyColumnLabel: String
        let requiredEntropyKey: String
        let forbiddenEntropyKey: String
        
        switch connectionDirection
        {
        case .outgoing:
            lengthColumnLabel = ColumnLabel.outLength.rawValue
            requiredLengthKey = outgoingRequiredLengthKey
            forbiddenLengthKey = outgoingForbiddenLengthKey
            entropyColumnLabel = ColumnLabel.outEntropy.rawValue
            requiredEntropyKey = outgoingRequiredEntropyKey
            forbiddenEntropyKey = outgoingForbiddenEntropyKey
        case .incoming:
            lengthColumnLabel = ColumnLabel.inLength.rawValue
            requiredLengthKey = incomingRequiredLengthKey
            forbiddenLengthKey = incomingForbiddenLengthKey
            entropyColumnLabel = ColumnLabel.inEntropy.rawValue
            requiredEntropyKey = incomingRequiredEntropyKey
            forbiddenEntropyKey = incomingForbiddenEntropyKey
        }
        // Set aside 20% of the model's data rows for evaluation, leaving the remaining 80% for training
        
        let (evaluationTable, trainingTable) = allFeaturesTable.randomSplit(by: 0.20)
        
        // Train the classifier
        do
        {
            let classifier = try MLClassifier(trainingData: trainingTable, targetColumn: ColumnLabel.classification.rawValue)
            let trainingAccuracy = (1.0 - classifier.trainingMetrics.classificationError) * 100
            let validationAccuracy = (1.0 - classifier.validationMetrics.classificationError) * 100
            let classifierEvaluation = classifier.evaluation(on: evaluationTable)
            let evaluationAccuracy = (1.0 - classifierEvaluation.classificationError) * 100

            // Regressors
            do
            {
                let timeRegressor = try MLRegressor(trainingData: trainingTable, targetColumn: ColumnLabel.timeDifference.rawValue)
                let entropyRegressor = try MLRegressor(trainingData: trainingTable, targetColumn: entropyColumnLabel)
                let lengthRegressor = try MLRegressor(trainingData: trainingTable, targetColumn: lengthColumnLabel)
                
//                let worstTrainingError = timeRegressor.trainingMetrics.maximumError
//                let worstValidationError = timeRegressor.validationMetrics.maximumError
//                let worstEvaluationError = timeRegressor.evaluation(on: evaluationTable).maximumError
                
                let allFeaturesDictionary: RMap<String, Double> = RMap(key: allFeaturesAccuracyKey)
                let timingDictionary: RMap<String, Double> = RMap(key: allFeaturesTimeResultsKey)
                let entropyDictionary: RMap<String, Double> = RMap(key: allFeaturesEntropyResultsKey)
                let lengthDictionary: RMap<String, Double> = RMap(key: allFeaturesLengthResultsKey)
                
                allFeaturesDictionary[allFeaturesEAccKey] = evaluationAccuracy
                allFeaturesDictionary[allFeaturesTAccKey] = trainingAccuracy
                allFeaturesDictionary[allFeaturesVAccKey] = validationAccuracy

                // Allowed
                do
                {
                    let allowedTimeTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.allowed.rawValue, ColumnLabel.timeDifference.rawValue: 0])
                    let allowedEntropyTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.allowed.rawValue, entropyColumnLabel: 0])
                    let allowedLengthTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.allowed.rawValue, lengthColumnLabel: 0])

                    do
                    {
                        let allowedTimeColumn = try timeRegressor.predictions(from: allowedTimeTable)
                        print("\nCreated allowed time column.")
                        let allowedEntropyColumn = try entropyRegressor.predictions(from: allowedEntropyTable)
                        print("\nCreated allowed entropy column.")
                        let allowedLengthColumn = try lengthRegressor.predictions(from: allowedLengthTable)
                        print("\nCreated allowed length column.")

                        guard let allowedTimeDifferences = allowedTimeColumn.doubles,
                            let allowedEntropy = allowedEntropyColumn.doubles,
                            let allowedLength = allowedLengthColumn.doubles
                            else
                        {
                            print("\nFailed to identify predictions from all features regressor.")
                            return
                        }

                        let predictedAllowedTimeDifference = allowedTimeDifferences[0]
                        let predictedAllowedEntropy = allowedEntropy[0]
                        let predictedAllowedLength = allowedLength[0]
                        
                        if includeTLS
                        {
                            do
                            {
                                let tlsDictionary: RMap<String, String> = RMap(key: allFeaturesTLSResultsKey)
                                let tlsRegressor = try MLRegressor(trainingData: trainingTable, targetColumn: ColumnLabel.tlsNames.rawValue)
                                
                                let allowedTLSTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.allowed.rawValue, ColumnLabel.timeDifference.rawValue:""])
                                let allowedTLSColumn = try tlsRegressor.predictions(from: allowedTLSTable)
                                if let allowedTLS = allowedTLSColumn.strings
                                {
                                    let predictedAllowedTLS = allowedTLS[0]
                                    tlsDictionary[requiredTLSKey] = predictedAllowedTLS
                                }
                            }
                            catch let tlsTrainingError
                            {
                                print("\nReceived a tls training error when training for all features: \(tlsTrainingError)")
                            }
                        }
                        
                        // Save scores
                        timingDictionary[requiredTimeDiffKey] = predictedAllowedTimeDifference
                        entropyDictionary[requiredEntropyKey] = predictedAllowedEntropy
                        lengthDictionary[requiredLengthKey] = predictedAllowedLength
                    }
                    catch let allowedColumnError
                    {
                        print("\nError creating allowed column for all features training: \(allowedColumnError)")
                    }
                }
                catch let allowedTableError
                {
                    print("\nError creating allowed all features table: \(allowedTableError)")
                }
                
                // Blocked
                do
                {
                    let blockedTimeTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.blocked.rawValue, ColumnLabel.timeDifference.rawValue: 0])
                    let blockedEntropyTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.blocked.rawValue, entropyColumnLabel: 0])
                    let blockedLengthTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.blocked.rawValue, lengthColumnLabel: 0])

                    do
                    {
                        let blockedTimeColumn = try timeRegressor.predictions(from: blockedTimeTable)
                        let blockedEntropyColumn = try entropyRegressor.predictions(from: blockedEntropyTable)
                        let blockedLengthColumn = try lengthRegressor.predictions(from: blockedLengthTable)
                        
                        guard let blockedTimeDifferences = blockedTimeColumn.doubles,
                            let blockedEntropy = blockedEntropyColumn.doubles,
                            let blockedLengths = blockedLengthColumn.doubles
                        else
                        {
                            print("\nUnable to get blocked predictions from all features")
                            return
                        }
                        
                        let predictedBlockedTimeDifference = blockedTimeDifferences[0]
                        let predictedBlockedEntropy = blockedEntropy[0]
                        let predictedBlockedLength = blockedLengths[0]
                        
                        if includeTLS
                        {
                            do
                            {
                                let tlsDictionary: RMap<String, String> = RMap(key: allFeaturesTLSResultsKey)
                                let tlsRegressor = try MLRegressor(trainingData: trainingTable, targetColumn: ColumnLabel.tlsNames.rawValue)
                                
                                let allowedTLSTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.allowed.rawValue, ColumnLabel.timeDifference.rawValue:""])
                                let allowedTLSColumn = try tlsRegressor.predictions(from: allowedTLSTable)
                                if let allowedTLS = allowedTLSColumn.strings
                                {
                                    let predictedAllowedTLS = allowedTLS[0]
                                    tlsDictionary[requiredTLSKey] = predictedAllowedTLS
                                }
                                
                                let blockedTLSTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.blocked.rawValue, ColumnLabel.tlsNames.rawValue: ""])
                                let blockedTLSColumn = try tlsRegressor.predictions(from: blockedTLSTable)
                                // TLS is Optional
                                if let blockedTLS = blockedTLSColumn.strings
                                {
                                    let predictedBlockedTLS = blockedTLS[0]
                                    tlsDictionary[forbiddenTLSKey] = predictedBlockedTLS
                                    MLModelController().save(regressor: tlsRegressor, regressorMetadata: allFeaturesTLSRegressorMetadata, fileName: "AllFeaturesTLS", groupName: modelName)
                                }
                            }
                            catch let tlsTrainingError
                            {
                                print("\nReceived a tls training error when training for all features: \(tlsTrainingError)")
                            }
                        }
                        
                        // Save the results
                        timingDictionary[forbiddenTimeDiffKey] = predictedBlockedTimeDifference
                        entropyDictionary[forbiddenEntropyKey] = predictedBlockedEntropy
                        lengthDictionary[forbiddenLengthKey] = predictedBlockedLength
                        
                        // Save the models
                        let modelController = MLModelController()
                        modelController.save(classifier: classifier, classifierMetadata: allFeaturesClassifierMetadata, fileName: "AllFeatures", groupName: modelName)
                        modelController.save(regressor: timeRegressor, regressorMetadata: allFeaturesTimingRegressorMetadata, fileName: "AllFeaturesTiming", groupName: modelName)
                        modelController.save(regressor: entropyRegressor, regressorMetadata: allFeaturesEntropyRegressorMetadata, fileName: "AllFeaturesEntropy", groupName: modelName)
                        modelController.save(regressor: lengthRegressor, regressorMetadata: allFeaturesLengthsRegressorMetadata, fileName: "AllFeaturesPacketLength", groupName: modelName)
                    }
                    catch let blockedColumnsError
                    {
                        print("\nError creating all features blocked column: \(blockedColumnsError)")
                    }
                }
                catch let blockedTableError
                {
                    print("\nError creating blocked all features table: \(blockedTableError)")
                }
            }
            catch let allFeaturesRegressorError
            {
                print("\nAll features regressor error: \(allFeaturesRegressorError)")
            }
        }
        catch let classifierTrainingError
        {
            print("\nError training the classifier for AllFeatures: \(classifierTrainingError)")
        }
    }
    
    /// Returns: Bool indicating whether the connection was successfully processed
    func processData(forConnection connection: ObservedConnection) -> Bool
    {
        /// Entropy
        let (_, inEntropy, outEntropy, _) = EntropyCoreML().processEntropy(forConnection: connection)
        
        guard let inPacketEntropy = inEntropy, let outPacketEntropy = outEntropy
        else
        {
            return false
        }
        
        /// Lengths
        let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
        let inPacketHash: RMap<String, Data> = RMap(key: connection.incomingKey)

        guard let outPacket: Data = outPacketHash[connection.connectionID]
            else { return false }

        guard let inPacket = inPacketHash[connection.connectionID]
            else { return false }

        /// Timing
        let outPacketDateHash: RMap<String, Double> = RMap(key: connection.outgoingDateKey)
        let inPacketDateHash: RMap<String, Double> = RMap(key: connection.incomingDateKey)

        guard let outTimeInterval = outPacketDateHash[connection.connectionID]
            else { return false }

        guard let inTimeInterval = inPacketDateHash[connection.connectionID]
            else { return false }

        let timeDifference = (outTimeInterval - inTimeInterval)
        
        /// TLS
        let maybeTLS = TLS12CoreML().processTls12(connection)

        if let tlsName = maybeTLS
        {
            tlsNames.append(tlsName)
        }
        
        timeDifferenceList.append(timeDifference)
        inLengths.append(inPacket.count)
        outLengths.append(outPacket.count)
        inEntropies.append(inPacketEntropy)
        outEntropies.append(outPacketEntropy)
        classificationLabels.append(connection.connectionType.rawValue)
        
        return true
    }

}
