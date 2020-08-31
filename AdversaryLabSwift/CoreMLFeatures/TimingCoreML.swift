//
//  Timing.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import CreateML
import CoreML

import Auburn

class TimingCoreML
{
    // TODO: Currently not using error
    // TODO: Replace observedConnection with ConnectionType
    func processTiming(forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
    {
        var outDate: Double?
        var inDate: Double?
        
        switch connection.connectionType
        {
        case .transportA:
            outDate = connectionGroupData.aConnectionData.outgoingDates[connection.connectionID]
            inDate = connectionGroupData.aConnectionData.incomingDates[connection.connectionID]
            
        case .transportB:
            outDate = connectionGroupData.bConnectionData.outgoingDates[connection.connectionID]
            inDate = connectionGroupData.bConnectionData.incomingDates[connection.connectionID]
        }
        
        guard let timeOut = outDate else { return (false, nil) }
        guard let timeIn = inDate else { return (false, nil) }
        
        // Add the time difference for this connection to the database
        let timeDifference = (timeOut - timeIn)
        
        switch connection.connectionType
        {
        case .transportA:
            packetTimings.transportA.append(timeDifference)
        case .transportB:
            packetTimings.transportB.append(timeDifference)
        }
                
        return (true, nil)
    }
    
//    func scoreAllTiming()
//    {
//        scoreTiming(allowedTimeDifferenceKey: allowedConnectionsTimeDiffKey, blockedTimeDifferenceKey: blockedConnectionsTimeDiffKey, requiredTimeDifferenceKey: requiredTimeDiffKey, requiredTimeDifferenceAccKey: requiredTimeDiffAccKey, forbiddenTimeDifferenceKey: forbiddenTimeDiffKey, forbiddenTimeDifferenceAccKey: forbiddenTimeDiffAccKey)
//    }
    
    func scoreTiming(configModel: ProcessingConfigurationModel)
    {
        if configModel.trainingMode
        {
            trainModels(configModel: configModel)
        }
        else
        {
            testModel(configModel: configModel)
        }
    }
    
    func testModel(configModel: ProcessingConfigurationModel)
    {
        guard packetTimings.transportB.count > 0
            else
        {
            print("\nError: No blocked time differences found in the database. Tests cannot be run without blocked connection data.")
            return
        }
        
        testModel(connectionType: .transportB, timeDifferences: packetTimings.transportB, configModel: configModel)
        
        if packetTimings.transportA.count > 0
        {
            testModel(connectionType: .transportA, timeDifferences: packetTimings.transportA, configModel: configModel)
        }
    }
    
    func testModel(connectionType: ClassificationLabel, timeDifferences: [Double], configModel: ProcessingConfigurationModel)
    {
        let accuracyKey: String
        let timingKey: String
        
        switch connectionType
        {
        case .transportA:
            accuracyKey = allowedTimingAccuracyKey
            timingKey = allowedTimingKey
        case .transportB:
            accuracyKey = blockedTimingAccuracyKey
            timingKey = blockedTimingKey
        }
        
        do
        {
            let classifierFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.timeDifference.rawValue: timeDifferences])
            let regressorFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.classification.rawValue: [connectionType.rawValue]])
            
            guard let tempDirURL = getAdversaryTempDirectory()
                else
            {
                print("\nFailed to test models. Unable to locate application document directory.")
                return
            }
            
            let temporaryDirURL = tempDirURL.appendingPathComponent("\(configModel.modelName)", isDirectory: true)
            let classifierFileURL = temporaryDirURL.appendingPathComponent(timingClassifierName, isDirectory: false).appendingPathExtension(modelFileExtension)
            let regressorFileURL = temporaryDirURL.appendingPathComponent(timingRegressorName, isDirectory: false).appendingPathExtension(modelFileExtension)
            
            // This is the dictionary where we will save our results
            let timingDictionary: RMap<String,Double> = RMap(key: testResultsKey)
            
            if FileManager.default.fileExists(atPath: regressorFileURL.path)
            {
                guard let regressorPrediction = MLModelController().prediction(fileURL: regressorFileURL, batchFeatureProvider: regressorFeatureProvider)
                    else { return }
                
                // We are only expecting one result
                let thisFeatureNames = regressorPrediction.features(at: 0).featureNames
                
                // Check that we received a result with a feature named 'timeDifference' and that it has a value.
                guard let firstFeatureName = thisFeatureNames.first
                    else { return }
                guard firstFeatureName == ColumnLabel.timeDifference.rawValue
                    else { return }
                guard let thisFeatureValue = regressorPrediction.features(at: 0).featureValue(for: firstFeatureName)
                    else { return }
                
                print("🔮 Timing prediction for \(timingKey): \(thisFeatureValue).")
                timingDictionary[timingKey] = thisFeatureValue.doubleValue
            }
            
            if FileManager.default.fileExists(atPath: classifierFileURL.path)
            {
                guard let classifierPrediction = MLModelController().prediction(fileURL: classifierFileURL, batchFeatureProvider: classifierFeatureProvider)
                    else
                {
                    print("\n🛑  Failed to make a timing prediction.")
                    return
                }
                
                let featureCount = classifierPrediction.count
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
                print("\n🔮 Timing prediction: \(accuracy) \(connectionType.rawValue).")
                
                timingDictionary[accuracyKey] = accuracy
            }
        }
        catch
        {
            print("Unable to test timing model. Error creating the feature provider: \(error)")
        }
    }
    
    func trainModels(configModel: ProcessingConfigurationModel)
    {
        let (timeDifferenceList, classificationLabels) = getTimeDifferenceAndClassificationArrays()
        
        // Create the time difference table
        var timeDifferenceTable = MLDataTable()
        let timeDifferenceColumn = MLDataColumn(timeDifferenceList)
        let classificationColumn = MLDataColumn(classificationLabels)
        timeDifferenceTable.addColumn(timeDifferenceColumn, named: ColumnLabel.timeDifference.rawValue)
        timeDifferenceTable.addColumn(classificationColumn, named: ColumnLabel.classification.rawValue)
        
        // Set aside 20% of the model's data rows for evaluation, leaving the remaining 80% for training
        let (timeEvaluationTable, timeTrainingTable) = timeDifferenceTable.randomSplit(by: 0.30)
        
        // Train the classifier
        do
        {
            // This is the dictionary where we will save our results
            let timingDictionary: RMap<String,Double> = RMap(key: timeDifferenceTrainingResultsKey)
            let classifier = try MLClassifier(trainingData: timeTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
            
            // Classifier training accuracy as a percentage
            let trainingError = classifier.trainingMetrics.classificationError
            var trainingAccuracy: Double? = nil
            if trainingError >= 0
            {
                trainingAccuracy = (1.0 - trainingError) * 100
            }
            if trainingAccuracy != nil
            {
                timingDictionary[timeDiffTAccKey] = trainingAccuracy
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
                timingDictionary[timeDiffVAccKey] = validationAccuracy!
            }
            
            // Evaluate the classifier
            let classifierEvaluation = classifier.evaluation(on: timeEvaluationTable)
            
            // Classifier evaluation accuracy as a percentage
            let evaluationError = classifierEvaluation.classificationError
            var evaluationAccuracy: Double? = nil
            if evaluationError >= 0
            {
                evaluationAccuracy = (1.0 - evaluationError) * 100
            }
            if evaluationAccuracy != nil
            {
                timingDictionary[timeDiffEAccKey] = evaluationAccuracy
            }
            
            // Regressor
            do
            {
                let regressor = try MLRegressor(trainingData: timeTrainingTable, targetColumn: ColumnLabel.timeDifference.rawValue)
                
                guard let (allowedTimingTable, blockedTimingTable) = MLModelController().createAllowedBlockedTables(fromTable: timeDifferenceTable)
                else
                {
                    print("\nUnable to create allowed and blocked tables from time difference table.")
                    return
                }
 
                // Allowed Connection Time Differences
                do
                {
                    let allowedTimeColumn = try regressor.predictions(from: allowedTimingTable)
                    
                    guard let allowedTimeDifferences = allowedTimeColumn.doubles
                    else
                    {
                        print("\nFailed to identify allowed time differences.")
                        return
                    }
                    
                    let predictedAllowedTimeDifference = allowedTimeDifferences[0]
                    print("\nPredicted allowed time difference = \(predictedAllowedTimeDifference)")
                    
                    // Save scores
                    timingDictionary[requiredTimeDiffKey] = predictedAllowedTimeDifference
                }
                catch let allowedColumnError
                {
                    print("\nError creating allowed time difference column: \(allowedColumnError)")
                }
                
                // Blocked Connection Time Differences
                do
                {
                    let blockedColumn = try regressor.predictions(from: blockedTimingTable)
                    guard let blockedTimeDifferences = blockedColumn.doubles
                    else
                    {
                        print("\nFailed to identify blocked time differences.")
                        return
                    }
                    
                    let predictedBlockedTimeDifference = blockedTimeDifferences[0]
                    print("\nPredicted blocked time difference = \(predictedBlockedTimeDifference)")
                    
                    /// Save Predicted Time Difference
                    timingDictionary[forbiddenTimeDiffKey] = predictedBlockedTimeDifference
                    
                    // Save the models
                    MLModelController().saveModel(classifier: classifier,
                                                  classifierMetadata: timingClassifierMetadata,
                                                  classifierFileName: timingClassifierName,
                                                  regressor: regressor,
                                                  regressorMetadata: timingRegressorMetadata,
                                                  regressorFileName: timingRegressorName,
                                                  groupName: configModel.modelName)
                }
                catch let blockedColumnError
                {
                    print("\nError creating blocked time difference column: \(blockedColumnError)")
                }
            }
            catch let regressorError
            {
                print("\nError creating time difference regressor: \(regressorError)")
            }
        }
        catch let classiferError
        {
            print("\n Error creating the time difference classifier: \(classiferError)")
        }
    }
    
    
    func getTimeDifferenceAndClassificationArrays() -> (timeDifferenceList: [Double], classificationLabels: [String])
    {
        var timeDifferenceList = [Double]()
        var classificationLabels = [String]()
        
        /// TimeDifferences for the Transport A traffic
        for aTimeDifference in packetTimings.transportA
        {
            timeDifferenceList.append(aTimeDifference)
            classificationLabels.append(ClassificationLabel.transportA.rawValue)
        }
        
        /// TimeDifferences for Transport B traffic
        for bTimeDifference in packetTimings.transportB
        {
            timeDifferenceList.append(bTimeDifference)
            classificationLabels.append(ClassificationLabel.transportB.rawValue)
        }
        
        return (timeDifferenceList, classificationLabels)
    }

}
