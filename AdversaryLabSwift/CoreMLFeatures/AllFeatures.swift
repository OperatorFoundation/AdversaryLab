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
            // Allowed
            testModel(connectionType: .allowed, configModel: configModel)
            
            // Blocked
            testModel(connectionType: .blocked, configModel: configModel)
        }
    }
    
    func createTestingArrays(connectionType: ClassificationLabel, includeTLS: Bool) -> (incomingLengths: [Int], outgoingLengths: [Int], incomingEntropy: [Double],
        outgoingEntropy: [Double], timeDifferences: [Double], tlsNames: [String]?)?
    {
        var incomingLengths = [Int]()
        var outgoingLengths = [Int]()
        var incomingEntropy = [Double]()
        var outgoingEntropy = [Double]()
        var timeDifferences = [Double]()
        var tls = [String]()
        
        guard !timeDifferenceList.isEmpty,
            !inLengths.isEmpty,
            !outLengths.isEmpty,
            !inEntropies.isEmpty,
            !outEntropies.isEmpty
            else { return nil }
        
        guard timeDifferenceList.count == classificationLabels.count,
            inLengths.count == classificationLabels.count,
            outLengths.count == classificationLabels.count,
            inEntropies.count == classificationLabels.count,
            outEntropies.count == classificationLabels.count
            else { return nil }
        
        if includeTLS
        {
            guard !tlsNames.isEmpty, tlsNames.count == classificationLabels.count
                else { return nil }
        }
        
        switch connectionType
        {
        case .allowed:
            for index in 0 ..< classificationLabels.count
            {
                if classificationLabels[index] == ClassificationLabel.allowed.rawValue
                {
                    incomingLengths.append(inLengths[index])
                    outgoingLengths.append(outLengths[index])
                    incomingEntropy.append(inEntropies[index])
                    outgoingEntropy.append(outEntropies[index])
                    timeDifferences.append(timeDifferenceList[index])
                    
                    if includeTLS
                    {
                        tls.append(tlsNames[index])
                    }
                }
            }
        case .blocked:
            for index in 0 ..< classificationLabels.count
            {
                if classificationLabels[index] == ClassificationLabel.blocked.rawValue
                {
                    incomingLengths.append(inLengths[index])
                    outgoingLengths.append(outLengths[index])
                    incomingEntropy.append(inEntropies[index])
                    outgoingEntropy.append(outEntropies[index])
                    timeDifferences.append(timeDifferenceList[index])
                    
                    if includeTLS
                    {
                        tls.append(tlsNames[index])
                    }
                }
            }
        }
        
        if includeTLS
        {
            return (incomingLengths, outgoingLengths, incomingEntropy, outgoingEntropy, timeDifferences, tls)
        }
        
        return (incomingLengths, outgoingLengths, incomingEntropy, outgoingEntropy, timeDifferences, nil)
    }
    
    func testModel(connectionType: ClassificationLabel, configModel: ProcessingConfigurationModel)
    {
        do
        {
            guard let appDirectory = getAdversarySupportDirectory()
                else
            {
                print("\nFailed to test all features model. Unable to locate the application document directory.")
                return
            }
            
            let temporaryDirURL = appDirectory.appendingPathComponent("\(configModel.modelName)/temp/\(configModel.modelName)", isDirectory: true)
            let classifierFileURL = temporaryDirURL.appendingPathComponent(allClassifierName, isDirectory: false).appendingPathExtension(modelFileExtension)

            if FileManager.default.fileExists(atPath: classifierFileURL.path)
            {
                let batchFeatureProvider: MLArrayBatchProvider
                let compiledModelURL = try MLModel.compileModel(at: classifierFileURL)
                let model = try MLModel(contentsOf: compiledModelURL)
                let inputs = model.modelDescription.inputDescriptionsByName

                let accuracyKey: String
                let inLengthKey: String
                let outLengthKey:String
                let inEntropyKey: String
                let outEntropyKey: String
                let timingKey: String
                let tlsKey: String
                
                switch connectionType
                {
                case .allowed:
                    accuracyKey = allowedAllFeaturesAccuracyKey
                    inLengthKey = allowedAllFeaturesIncomingLengthKey
                    outLengthKey = allowedAllFeaturesOutgoingLengthKey
                    inEntropyKey = allowedAllFeaturesIncomingEntropyKey
                    outEntropyKey = allowedAllFeaturesOutgoingEntropyKey
                    timingKey = allowedAllFeaturesTimingKey
                    tlsKey = allowedAllFeaturesTLSKey

                case .blocked:
                    accuracyKey = blockedAllFeaturesAccuracyKey
                    inLengthKey = blockedAllFeaturesIncomingLengthKey
                    outLengthKey = blockedAllFeaturesOutgoingLengthKey
                    inEntropyKey = blockedAllFeaturesIncomingEntropyKey
                    outEntropyKey = blockedAllFeaturesOutgoingEntropyKey
                    timingKey = blockedAllFeaturesTimingKey
                    tlsKey = blockedAllFeaturesTLSKey
                }
                
                test(feature: inLengthKey, regressorName: allInPacketLengthRegressorName, temporaryDirURL: temporaryDirURL, connectionType: connectionType, expectedFeatureName: ColumnLabel.inLength.rawValue, featureValueType: .double)
                test(feature: outLengthKey, regressorName: allOutPacketLengthRegressorName, temporaryDirURL: temporaryDirURL, connectionType: connectionType, expectedFeatureName: ColumnLabel.outLength.rawValue, featureValueType: .double)
                test(feature: inEntropyKey, regressorName: allInEntropyRegressorName, temporaryDirURL: temporaryDirURL, connectionType: connectionType, expectedFeatureName: ColumnLabel.inEntropy.rawValue, featureValueType: .double)
                test(feature: outEntropyKey, regressorName: allOutEntropyRegressorName, temporaryDirURL: temporaryDirURL, connectionType: connectionType, expectedFeatureName: ColumnLabel.outEntropy.rawValue, featureValueType: .double)
                test(feature: tlsKey, regressorName: allTLSRegressorName, temporaryDirURL: temporaryDirURL, connectionType: connectionType, expectedFeatureName: ColumnLabel.tlsNames.rawValue, featureValueType: .string)
                test(feature: timingKey, regressorName: allTimingRegressorName, temporaryDirURL: temporaryDirURL, connectionType: connectionType, expectedFeatureName: ColumnLabel.timeDifference.rawValue, featureValueType: .double)
                
                if inputs.keys.contains(ColumnLabel.tlsNames.rawValue)
                {
                    guard let (incomingLengths, outgoingLengths, incomingEntropy, outgoingEntropy, timeDifferences, tls) = createTestingArrays(connectionType: connectionType, includeTLS: true)
                    else
                    { return }
                    
                    batchFeatureProvider = try MLArrayBatchProvider(dictionary: [
                        ColumnLabel.timeDifference.rawValue: timeDifferences,
                        ColumnLabel.inLength.rawValue: incomingLengths,
                        ColumnLabel.outLength.rawValue: outgoingLengths,
                        ColumnLabel.inEntropy.rawValue: incomingEntropy,
                        ColumnLabel.outEntropy.rawValue: outgoingEntropy,
                        ColumnLabel.tlsNames.rawValue: tls!])
                }
                else
                {
                    guard let (incomingLengths, outgoingLengths, incomingEntropy, outgoingEntropy, timeDifferences, _) = createTestingArrays(connectionType: connectionType, includeTLS: false)
                        else
                    { return }
                    
                    batchFeatureProvider = try MLArrayBatchProvider(dictionary: [
                        ColumnLabel.timeDifference.rawValue: timeDifferences,
                        ColumnLabel.inLength.rawValue: incomingLengths,
                        ColumnLabel.outLength.rawValue: outgoingLengths,
                        ColumnLabel.inEntropy.rawValue: incomingEntropy,
                        ColumnLabel.outEntropy.rawValue: outgoingEntropy])
                }
                
                guard let classifierPrediction = MLModelController().prediction(fileURL: classifierFileURL, batchFeatureProvider: batchFeatureProvider)
                    else
                {
                    print("\n🛑  Failed to make an all features prediction.")
                    return
                }

                let featureCount = classifierPrediction.count
                guard featureCount > 0
                    else { return }
                
                var allowedBlockedCount: Double = 0.0
                for index in 0 ..< featureCount
                {
                    let thisFeature = classifierPrediction.features(at: index)
                    guard let timingClassification = thisFeature.featureValue(for: "classification")
                        else { continue }
                    if timingClassification.stringValue == connectionType.rawValue
                    {
                        allowedBlockedCount += 1
                    }
                }
                
                let accuracy = allowedBlockedCount/Double(featureCount)
                print("\n🔮 All Features prediction: \(accuracy * 100) \(connectionType.rawValue).")
                // This is the dictionary where we will save our results
                let resultsDictionary: RMap<String,Double> = RMap(key: testResultsKey)
                resultsDictionary[accuracyKey] = accuracy
            }
        }
        catch
        {
            print("\nError testing all features model: \(error)")
        }
    }
    
    func test(feature resultsKey: String, regressorName: String, temporaryDirURL: URL, connectionType: ClassificationLabel, expectedFeatureName: String, featureValueType: MLFeatureType)
    {
        let regressorFileURL = temporaryDirURL.appendingPathComponent(regressorName, isDirectory: false).appendingPathExtension(modelFileExtension)
        
        if FileManager.default.fileExists(atPath: regressorFileURL.path)
        {
            do
            {
                let regressorFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.classification.rawValue: [connectionType.rawValue]])
                
                guard let regressorPrediction = MLModelController().prediction(fileURL: regressorFileURL, batchFeatureProvider: regressorFeatureProvider)
                    else { return }
                
                guard regressorPrediction.count > 0
                    else { return }
                
                // We are only expecting one result
                let thisFeatureNames = regressorPrediction.features(at: 0).featureNames
                
                guard let firstFeatureName = thisFeatureNames.first
                    else { return }
                guard firstFeatureName == expectedFeatureName
                    else { return }
                guard let thisFeatureValue = regressorPrediction.features(at: 0).featureValue(for: firstFeatureName)
                    else { return }
                
                print("🔮 AllFeatures prediction for \(expectedFeatureName): \(thisFeatureValue).")
                switch featureValueType
                {
                case .string:
                    // This is the dictionary where we will save our results
                    // TLS Values are the only non Double results currently
                    let resultsDictionary: RMap<String,Double> = RMap(key: tlsTestResultsKey)
                    resultsDictionary[resultsKey] = thisFeatureValue.doubleValue
                case .double:
                    // This is the dictionary where we will save our results
                    let resultsDictionary: RMap<String,Double> = RMap(key: testResultsKey)
                    resultsDictionary[resultsKey] = thisFeatureValue.doubleValue
                default:
                    print("Received an unexpected value type from a regressor prediction: \(featureValueType)")
                }
            }
            catch
            {
                print("\nError testing all features model \(resultsKey): \(error)")
            }
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
        var allFeaturesTable = MLDataTable()
        let outLengthsColumn = MLDataColumn(outLengths)
        let outEntropyColumn = MLDataColumn(outEntropies)
        let inLengthsColumn = MLDataColumn(inLengths)
        let inEntropyColumn = MLDataColumn(inEntropies)
        allFeaturesTable.addColumn(timeDifferenceColumn, named: ColumnLabel.timeDifference.rawValue)
        allFeaturesTable.addColumn(outLengthsColumn, named:ColumnLabel.outLength.rawValue)
        allFeaturesTable.addColumn(outEntropyColumn, named: ColumnLabel.outEntropy.rawValue)
        allFeaturesTable.addColumn(inLengthsColumn, named: ColumnLabel.inLength.rawValue)
        allFeaturesTable.addColumn(inEntropyColumn, named: ColumnLabel.inEntropy.rawValue)
        allFeaturesTable.addColumn(classyColumn, named: ColumnLabel.classification.rawValue)
        
        if configModel.enableTLSAnalysis
        {
            let tlsColumn = MLDataColumn(tlsNames)
            allFeaturesTable.addColumn(tlsColumn, named: ColumnLabel.tlsNames.rawValue)
        }
        
        train(allFeaturesTable: allFeaturesTable, configModel: configModel)
    }
    
    func train(allFeaturesTable: MLDataTable, configModel: ProcessingConfigurationModel)
    {
        // Set aside 20% of the model's data rows for evaluation, leaving the remaining 80% for training
        let (evaluationTable, trainingTable) = allFeaturesTable.randomSplit(by: 0.20)
        
        print("\n All Features training table has \(trainingTable.rows.count) rows.")
        print("All Features eval table has \(evaluationTable.rows.count) rows.")
        
        // Train the classifier
        do
        {
            let classifier = try MLClassifier(trainingData: trainingTable, targetColumn: ColumnLabel.classification.rawValue)
            let trainingAccuracy = (1.0 - classifier.trainingMetrics.classificationError) * 100
            let classifierEvaluation = classifier.evaluation(on: evaluationTable)
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

            // Regressors
            do
            {
                let timeRegressor = try MLRegressor(trainingData: trainingTable, targetColumn: ColumnLabel.timeDifference.rawValue)
                let inEntropyRegressor = try MLRegressor(trainingData: trainingTable, targetColumn: ColumnLabel.inEntropy.rawValue)
                let outEntropyRegressor = try MLRegressor(trainingData: trainingTable, targetColumn: ColumnLabel.outEntropy.rawValue)
                let inLengthRegressor = try MLRegressor(trainingData: trainingTable, targetColumn: ColumnLabel.inLength.rawValue)
                let outLengthRegressor = try MLRegressor(trainingData: trainingTable, targetColumn: ColumnLabel.outLength.rawValue)

                let allFeaturesDictionary: RMap<String, Double> = RMap(key: allFeaturesTrainingAccuracyKey)
                let timingDictionary: RMap<String, Double> = RMap(key: allFeaturesTimeTrainingResultsKey)
                let entropyDictionary: RMap<String, Double> = RMap(key: allFeaturesEntropyTrainingResultsKey)
                let lengthDictionary: RMap<String, Double> = RMap(key: allFeaturesLengthTrainingResultsKey)
                
                allFeaturesDictionary[allFeaturesEAccKey] = evaluationAccuracy
                allFeaturesDictionary[allFeaturesTAccKey] = trainingAccuracy
                
                if validationAccuracy != nil
                {
                    allFeaturesDictionary[allFeaturesVAccKey] = validationAccuracy!
                }
                
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
                    let allowedInEntropyColumn = try inEntropyRegressor.predictions(from: allowedTable)
                    let allowedOutEntropyColumn = try outEntropyRegressor.predictions(from: allowedTable)
                    let allowedInLengthColumn = try inLengthRegressor.predictions(from: allowedTable)
                    let allowedOutLengthColumn = try outLengthRegressor.predictions(from: allowedTable)

                    guard let allowedTimeDifferences = allowedTimeColumn.doubles,
                        let allowedInEntropy = allowedInEntropyColumn.doubles,
                        let allowedOutEntropy = allowedOutEntropyColumn.doubles,
                        let allowedInLength = allowedInLengthColumn.doubles,
                        let allowedOutLength = allowedOutLengthColumn.doubles
                        else
                    {
                        print("\nFailed to identify predictions from all features regressor.")
                        return
                    }

                    let predictedAllowedTimeDifference = allowedTimeDifferences[0]
                    let predictedAllowedInEntropy = allowedInEntropy[0]
                    let predictedAllowedOutEntropy = allowedOutEntropy[0]
                    let predictedAllowedInLength = allowedInLength[0]
                    let predictedAllowedOutLength = allowedOutLength[0]
                    
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
                    entropyDictionary[outgoingRequiredEntropyKey] = predictedAllowedOutEntropy
                    entropyDictionary[incomingRequiredEntropyKey] = predictedAllowedInEntropy
                    lengthDictionary[outgoingRequiredLengthKey] = predictedAllowedOutLength
                    lengthDictionary[incomingRequiredLengthKey] = predictedAllowedInLength
                }
                catch let allowedColumnError
                {
                    print("\nError creating allowed column for all features training: \(allowedColumnError)")
                }

                // Blocked
                do
                {
                    let blockedTimeColumn = try timeRegressor.predictions(from: blockedTable)
                    let blockedInEntropyColumn = try inEntropyRegressor.predictions(from: blockedTable)
                    let blockedOutEntropyColumn = try outEntropyRegressor.predictions(from: blockedTable)
                    let blockedInLengthColumn = try inLengthRegressor.predictions(from: blockedTable)
                    let blockedOutLengthColumn = try outLengthRegressor.predictions(from: blockedTable)
                    
                    guard let blockedTimeDifferences = blockedTimeColumn.doubles,
                        let blockedInEntropy = blockedInEntropyColumn.doubles,
                        let blockedOutEntropy = blockedOutEntropyColumn.doubles,
                        let blockedInLengths = blockedInLengthColumn.doubles,
                        let blockedOutLengths = blockedOutLengthColumn.doubles
                    else
                    {
                        print("\nUnable to get blocked predictions from all features")
                        return
                    }
                    
                    let predictedBlockedTimeDifference = blockedTimeDifferences[0]
                    let predictedBlockedInEntropy = blockedInEntropy[0]
                    let predictedBlockedOutEntropy = blockedOutEntropy[0]
                    let predictedBlockedInLength = blockedInLengths[0]
                    let predictedBlockedOutLength = blockedOutLengths[0]
                    
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
                    entropyDictionary[incomingForbiddenEntropyKey] = predictedBlockedInEntropy
                    entropyDictionary[outgoingForbiddenEntropyKey] = predictedBlockedOutEntropy
                    lengthDictionary[incomingForbiddenLengthKey] = predictedBlockedInLength
                    lengthDictionary[outgoingForbiddenLengthKey] = predictedBlockedOutLength
                    
                    // Save the models
                    let modelController = MLModelController()
                    modelController.save(classifier: classifier, classifierMetadata: allFeaturesClassifierMetadata, fileName: allClassifierName, groupName: configModel.modelName)
                    modelController.save(regressor: timeRegressor, regressorMetadata: allFeaturesTimingRegressorMetadata, fileName: allTimingRegressorName, groupName: configModel.modelName)
                    modelController.save(regressor: inEntropyRegressor, regressorMetadata: allFeaturesEntropyRegressorMetadata, fileName: allInEntropyRegressorName, groupName: configModel.modelName)
                    modelController.save(regressor: outEntropyRegressor, regressorMetadata: allFeaturesEntropyRegressorMetadata, fileName: allOutEntropyRegressorName, groupName: configModel.modelName)
                    modelController.save(regressor: inLengthRegressor, regressorMetadata: allFeaturesLengthsRegressorMetadata, fileName: allInPacketLengthRegressorName, groupName: configModel.modelName)
                    modelController.save(regressor: outLengthRegressor, regressorMetadata: allFeaturesLengthsRegressorMetadata, fileName: allOutPacketLengthRegressorName, groupName: configModel.modelName)
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
