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
import CoreML

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
    
    func scoreAllFeatures(configModel: ProcessingConfigurationModel)
    {
        if configModel.trainingMode
        {
            trainAllFeatures(configModel: configModel)
        }
        else
        {
            testAllFeatures(configModel: configModel)
        }
    }
    
    func testAllFeatures(configModel: ProcessingConfigurationModel)
    {
        guard !timeDifferenceList.isEmpty,
            !inLengths.isEmpty,
            !outLengths.isEmpty,
            !inEntropies.isEmpty,
            !outEntropies.isEmpty,
            !classificationLabels.isEmpty
            else { return }
        
        guard timeDifferenceList.count == classificationLabels.count,
            inLengths.count == classificationLabels.count,
            outLengths.count == classificationLabels.count,
            inEntropies.count == classificationLabels.count,
            outEntropies.count == classificationLabels.count
            else { return }
        
        do
        {
            let batchFeatureProvider = try MLArrayBatchProvider(dictionary: [
                ColumnLabel.timeDifference.rawValue: timeDifferenceList,
                ColumnLabel.inLength.rawValue: inLengths,
                ColumnLabel.outLength.rawValue: outLengths,
                ColumnLabel.inEntropy.rawValue: inEntropies,
                ColumnLabel.outEntropy.rawValue: outEntropies,
                ColumnLabel.classification.rawValue: classificationLabels])
            
            guard let appDirectory = getAdversarySupportDirectory()
                else
            {
                print("\nFailed to test all features model. Unable to locate the application document directory.")
                return
            }
            
            let temporaryDirURL = appDirectory.appendingPathComponent("\(configModel.modelName)/temp/\(configModel.modelName)", isDirectory: true)
            
            let classifierFileURL = temporaryDirURL.appendingPathComponent(allClassifierName, isDirectory: false).appendingPathExtension("mlmodel")
            
            if FileManager.default.fileExists(atPath: classifierFileURL.path)
            {
                guard let classifierPrediction = MLModelController().prediction(fileURL: classifierFileURL, batchFeatureProvider: batchFeatureProvider)
                    else
                {
                    print("\nFailed to make an all features prediction.")
                    return
                }

                // TODO: Save the classifier prediction accuracy
                let firstFeature = classifierPrediction.features(at: 0)
                
                print("\n🔮  Created an all features prediction from a model file. Feature at index 0:\n\(firstFeature)\nFeature Names: \(firstFeature.featureNames)")
            }
        }
        catch
        {
            print("\nError testing all features model: \(error)")
        }
    }
    
    func trainAllFeatures(configModel: ProcessingConfigurationModel)
    {
        guard !timeDifferenceList.isEmpty,
            !inLengths.isEmpty,
            !outLengths.isEmpty,
            !inEntropies.isEmpty,
            !outEntropies.isEmpty,
            !classificationLabels.isEmpty
            else { return }
        
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
        
        if configModel.enableTLSAnalysis
        {
            let tlsColumn = MLDataColumn(tlsNames)
            allOutFeaturesTable.addColumn(tlsColumn, named: ColumnLabel.tlsNames.rawValue)
            allInFeaturesTable.addColumn(tlsColumn, named: ColumnLabel.tlsNames.rawValue)
        }
        
        train(allFeaturesTable: allOutFeaturesTable, forDirection: .outgoing, configModel: configModel)
        train(allFeaturesTable: allInFeaturesTable, forDirection: .incoming, configModel: configModel)
    }
    
    func train(allFeaturesTable: MLDataTable, forDirection connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
    {
        let lengthColumnLabel: String
        let requiredLengthKey: String
        let forbiddenLengthKey: String
        let entropyColumnLabel: String
        let requiredEntropyKey: String
        let forbiddenEntropyKey: String
        let allEntropyRegressorName: String
        let allLengthRegressorName: String
        
        switch connectionDirection
        {
        case .outgoing:
            lengthColumnLabel = ColumnLabel.outLength.rawValue
            requiredLengthKey = outgoingRequiredLengthKey
            forbiddenLengthKey = outgoingForbiddenLengthKey
            entropyColumnLabel = ColumnLabel.outEntropy.rawValue
            requiredEntropyKey = outgoingRequiredEntropyKey
            forbiddenEntropyKey = outgoingForbiddenEntropyKey
            allEntropyRegressorName = allOutEntropyRegressorName
            allLengthRegressorName = allOutPacketLengthRegressorName
        case .incoming:
            lengthColumnLabel = ColumnLabel.inLength.rawValue
            requiredLengthKey = incomingRequiredLengthKey
            forbiddenLengthKey = incomingForbiddenLengthKey
            entropyColumnLabel = ColumnLabel.inEntropy.rawValue
            requiredEntropyKey = incomingRequiredEntropyKey
            forbiddenEntropyKey = incomingForbiddenEntropyKey
            allEntropyRegressorName = allInEntropyRegressorName
            allLengthRegressorName = allInPacketLengthRegressorName
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

                let allFeaturesDictionary: RMap<String, Double> = RMap(key: allFeaturesTrainingAccuracyKey)
                let timingDictionary: RMap<String, Double> = RMap(key: allFeaturesTimeTrainingResultsKey)
                let entropyDictionary: RMap<String, Double> = RMap(key: allFeaturesEntropyTrainingResultsKey)
                let lengthDictionary: RMap<String, Double> = RMap(key: allFeaturesLengthTrainingResultsKey)
                
                allFeaturesDictionary[allFeaturesEAccKey] = evaluationAccuracy
                allFeaturesDictionary[allFeaturesTAccKey] = trainingAccuracy
                allFeaturesDictionary[allFeaturesVAccKey] = validationAccuracy
                
                let modelController = MLModelController()
                guard let (allowedTable, blockedTable) = modelController.createAllowedBlockedTables(fromTable: allFeaturesTable)
                    else
                {
                    print("\nUnable to create allowed and blocked tables from all features table.")
                    return
                }
                // Allowed
                do
                {
                    let allowedTimeColumn = try timeRegressor.predictions(from: allowedTable)
                    let allowedEntropyColumn = try entropyRegressor.predictions(from: allowedTable)
                    let allowedLengthColumn = try lengthRegressor.predictions(from: allowedTable)

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
                    
                    if configModel.enableTLSAnalysis
                    {
                        do
                        {
                            let tlsDictionary: RMap<String, String> = RMap(key: allFeaturesTLSTraininResultsKey)
                            let tlsRegressor = try MLRegressor(trainingData: trainingTable, targetColumn: ColumnLabel.tlsNames.rawValue)
                            let allowedTLSColumn = try tlsRegressor.predictions(from: allowedTable)
                            
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

                // Blocked
                do
                {
                    let blockedTimeColumn = try timeRegressor.predictions(from: blockedTable)
                    let blockedEntropyColumn = try entropyRegressor.predictions(from: blockedTable)
                    let blockedLengthColumn = try lengthRegressor.predictions(from: blockedTable)
                    
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
                    
                    if configModel.enableTLSAnalysis
                    {
                        do
                        {
                            let tlsDictionary: RMap<String, String> = RMap(key: allFeaturesTLSTraininResultsKey)
                            let tlsRegressor = try MLRegressor(trainingData: trainingTable, targetColumn: ColumnLabel.tlsNames.rawValue)
                            let blockedTLSColumn = try tlsRegressor.predictions(from: blockedTable)
                            
                            // TLS is Optional
                            if let blockedTLS = blockedTLSColumn.strings
                            {
                                let predictedBlockedTLS = blockedTLS[0]
                                tlsDictionary[forbiddenTLSKey] = predictedBlockedTLS
                                MLModelController().save(regressor: tlsRegressor, regressorMetadata: allFeaturesTLSRegressorMetadata, fileName: allTLSRegressorName, groupName: configModel.modelName)
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
                    modelController.save(classifier: classifier, classifierMetadata: allFeaturesClassifierMetadata, fileName: allClassifierName, groupName: configModel.modelName)
                    modelController.save(regressor: timeRegressor, regressorMetadata: allFeaturesTimingRegressorMetadata, fileName: allTimingRegressorName, groupName: configModel.modelName)
                    modelController.save(regressor: entropyRegressor, regressorMetadata: allFeaturesEntropyRegressorMetadata, fileName: allEntropyRegressorName, groupName: configModel.modelName)
                    modelController.save(regressor: lengthRegressor, regressorMetadata: allFeaturesLengthsRegressorMetadata, fileName: allLengthRegressorName, groupName: configModel.modelName)
                }
                catch let blockedColumnsError
                {
                    print("\nError creating all features blocked column: \(blockedColumnsError)")
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
        else
        {
            tlsNames.append("n/a")
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
