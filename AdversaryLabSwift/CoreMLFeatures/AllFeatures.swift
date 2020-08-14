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
            testModel(connectionType: .transportA, configModel: configModel)
            
            // Blocked
            testModel(connectionType: .transportB, configModel: configModel)
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
        case .transportA:
            for index in 0 ..< classificationLabels.count
            {
                if classificationLabels[index] == ClassificationLabel.transportA.rawValue
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
        case .transportB:
            for index in 0 ..< classificationLabels.count
            {
                if classificationLabels[index] == ClassificationLabel.transportB.rawValue
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
            guard let tempDirURL = getAdversaryTempDirectory()
                else
            {
                print("\nFailed to test all features model. Unable to locate the application document directory.")
                return
            }
            
            let temporaryDirURL = tempDirURL.appendingPathComponent("\(configModel.modelName)", isDirectory: true)
            let classifierFileURL = temporaryDirURL.appendingPathComponent(allClassifierName, isDirectory: false).appendingPathExtension(modelFileExtension)

            if FileManager.default.fileExists(atPath: classifierFileURL.path)
            {
                let batchFeatureProvider: MLArrayBatchProvider
                let compiledModelURL = try MLModel.compileModel(at: classifierFileURL)
                let model = try MLModel(contentsOf: compiledModelURL)
                let inputs = model.modelDescription.inputDescriptionsByName
                let accuracyKey: String
                
                switch connectionType
                {
                case .transportA:
                    accuracyKey = allowedAllFeaturesAccuracyKey

                case .transportB:
                    accuracyKey = blockedAllFeaturesAccuracyKey
                }
                
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
                
                var accuracy = allowedBlockedCount/Double(featureCount)
                // Round it to 3 decimal places
                accuracy = (accuracy * 1000).rounded()/1000
                // Show the accuracy as a percentage value
                accuracy = accuracy * 100
                print("\n🔮 All Features prediction: \(accuracy) \(connectionType.rawValue).")
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
    
//    func test(feature resultsKey: String, regressorName: String, temporaryDirURL: URL, connectionType: ClassificationLabel, expectedFeatureName: String, featureValueType: MLFeatureType)
//    {
//        let regressorFileURL = temporaryDirURL.appendingPathComponent(regressorName, isDirectory: false).appendingPathExtension(modelFileExtension)
//        
//        if FileManager.default.fileExists(atPath: regressorFileURL.path)
//        {
//            do
//            {
//                let regressorFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.classification.rawValue: [connectionType.rawValue]])
//                
//                guard let regressorPrediction = MLModelController().prediction(fileURL: regressorFileURL, batchFeatureProvider: regressorFeatureProvider)
//                    else { return }
//                
//                guard regressorPrediction.count > 0
//                    else { return }
//                
//                // We are only expecting one result
//                let thisFeatureNames = regressorPrediction.features(at: 0).featureNames
//                
//                guard let firstFeatureName = thisFeatureNames.first
//                    else { return }
//                guard firstFeatureName == expectedFeatureName
//                    else { return }
//                guard let thisFeatureValue = regressorPrediction.features(at: 0).featureValue(for: firstFeatureName)
//                    else { return }
//                
//                print("🔮 AllFeatures prediction for \(expectedFeatureName): \(thisFeatureValue).")
//                switch featureValueType
//                {
//                case .string:
//                    // This is the dictionary where we will save our results
//                    // TLS Values are the only non Double results currently
//                    let resultsDictionary: RMap<String,String> = RMap(key: allFeaturesTLSTestResultsKey)
//                    resultsDictionary[resultsKey] = thisFeatureValue.stringValue
//                case .double:
//                    // This is the dictionary where we will save our results
//                    let resultsDictionary: RMap<String,Double> = RMap(key: testResultsKey)
//                    resultsDictionary[resultsKey] = thisFeatureValue.doubleValue
//                default:
//                    print("Received an unexpected value type from a regressor prediction: \(featureValueType)")
//                }
//            }
//            catch
//            {
//                print("\nError testing all features model \(resultsKey): \(error)")
//            }
//        }
//    }
    
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
        // Set aside 30% of the model's data rows for evaluation, leaving the remaining 80% for training
        let (evaluationTable, trainingTable) = allFeaturesTable.randomSplit(by: 0.30)
        
        print("\nAll Features training table has \(trainingTable.rows.count) rows.")
        print("All Features eval table has \(evaluationTable.rows.count) rows.")
        
        // Train the classifier
        do
        {
            let allFeaturesDictionary: RMap<String, Double> = RMap(key: allFeaturesTrainingAccuracyKey)
            let classifier = try MLClassifier(trainingData: trainingTable, targetColumn: ColumnLabel.classification.rawValue)
            let trainingError = classifier.trainingMetrics.classificationError
            var trainingAccuracy: Double? = nil
            if trainingError >= 0
            {
                trainingAccuracy = (1.0 - trainingError) * 100
            }
            if trainingAccuracy != nil
            {
                allFeaturesDictionary[allFeaturesTAccKey] = trainingAccuracy
            }
            
            let classifierEvaluation = classifier.evaluation(on: evaluationTable)
            let evaluationError = classifierEvaluation.classificationError
            var evaluationAccuracy: Double? = nil
            if evaluationError >= 0
            {
                evaluationAccuracy = (1.0 - evaluationError) * 100
            }
            if evaluationAccuracy != nil
            {
                allFeaturesDictionary[allFeaturesEAccKey] = evaluationAccuracy
            }
            
            let validationError = classifier.validationMetrics.classificationError
            var validationAccuracy: Double? = nil
            // Sometimes we get a negative number, this is not valid for our purposes
            if validationError >= 0
            {
                validationAccuracy = (1.0 - validationError) * 100
            }
            if validationAccuracy != nil
            {
                allFeaturesDictionary[allFeaturesVAccKey] = validationAccuracy!
            }

            let modelController = MLModelController()

            modelController.save(classifier: classifier, classifierMetadata: allFeaturesClassifierMetadata, fileName: allClassifierName, groupName: configModel.modelName)
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
