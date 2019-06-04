//
//  Timing.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn
import CreateML
import CoreML

class TimingCoreML
{
    func processTiming(forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
    {
        let outPacketDateHash: RMap<String, Double> = RMap(key: connection.outgoingDateKey)
        let inPacketDateHash: RMap<String, Double> = RMap(key: connection.incomingDateKey)
        let timeDifferenceList: RList<Double> = RList(key: connection.timeDifferenceKey)
        
        // Get the out packet time stamp
        guard let outTimeInterval = outPacketDateHash[connection.connectionID]
            else
        {
            return (false, PacketTimingError.noOutPacketDateForConnection(connection.connectionID))
        }
        
        // Get the in packet time stamp
        guard let inTimeInterval = inPacketDateHash[connection.connectionID]
            else
        {
            return (false, PacketTimingError.noInPacketDateForConnection(connection.connectionID))
        }
        
        // Add the time difference for this connection to the database
        let timeDifference = (outTimeInterval - inTimeInterval)
        timeDifferenceList.append(timeDifference)
        
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
            testModels(configModel: configModel)
        }
    }
    
    func testModels(configModel: ProcessingConfigurationModel)
    {
        var blockedTimeDifferenceList = [Double]()
        let bTimeDifferenceList: RList<Double> = RList(key: blockedConnectionsTimeDiffKey)
        if bTimeDifferenceList.count > 0
        {
            for timeDifference in blockedTimeDifferenceList
            {
                timeDifferenceList.append(timeDifference)
            }
        }
        
        var allowedTimeDifferenceList = [Double]()
        let aTimeDifferenceList: RList<Double> = RList(key: allowedConnectionsTimeDiffKey)
        for timeDifference in aTimeDifferenceList
        {
            allowedTimeDifferenceList.append(timeDifference)
        }

        
        do
        {
            let batchFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.timeDifference.rawValue: timeDifferenceList])
            
            guard let appDirectory = getAdversarySupportDirectory()
                else
            {
                print("\nFailed to test models. Unable to locate application document directory.")
                return
            }
            
            let temporaryDirURL = appDirectory.appendingPathComponent("\(configModel.modelName)/temp/\(configModel.modelName)", isDirectory: true)
            
            let classifierFileURL = temporaryDirURL.appendingPathComponent(timingClassifierName, isDirectory: false).appendingPathExtension("mlmodel")
            
            if FileManager.default.fileExists(atPath: classifierFileURL.path)
            {
                guard let classifierPrediction = MLModelController().prediction(fileURL: classifierFileURL, batchFeatureProvider: batchFeatureProvider)
                else
                {
                    print("\nFailed to make a timing prediction.")
                    return
                }
                
                // TODO: Save the classifier prediction accuracy
                let firstFeature = classifierPrediction.features(at: 0)
                let probability = firstFeature.featureValue(for: "classificationProbability").debugDescription
                let timingClassification = firstFeature.featureValue(for: "classification").debugDescription
                print("\n🔮  Created a timing prediction from a model file. Feature at index 0 \(firstFeature)\nFeature Names:\n\(firstFeature.featureNames)\nClassification Probability:\n\(probability)\nClassification:\n\(timingClassification)")
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
        let (timeEvaluationTable, timeTrainingTable) = timeDifferenceTable.randomSplit(by: 0.20)
        
        // Train the classifier
        do
        {
            let classifier = try MLClassifier(trainingData: timeTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
            
            // Classifier training accuracy as a percentage
            let trainingError = classifier.trainingMetrics.classificationError
            let trainingAccuracy = (1.0 - trainingError) * 100
            print("\nTime difference traning accuracy = \(trainingAccuracy)")
            
            // Classifier validation accuracy as a percentage
            let validationError = classifier.validationMetrics.classificationError
            let validationAccuracy = (1.0 - validationError ) * 100
            print("\nTime difference validation accuracy = \(validationAccuracy)")
            
            // Evaluate the classifier
            let classifierEvaluation = classifier.evaluation(on: timeEvaluationTable)
            
            // Classifier evaluation accuracy as a percentage
            let evaluationError = classifierEvaluation.classificationError
            let evaluationAccuracy = (1.0 - evaluationError) * 100
            print("\nTime difference evaluation accuracy = \(evaluationAccuracy)")
            
            // Regressor
            do
            {
                let regressor = try MLRegressor(trainingData: timeTrainingTable, targetColumn: ColumnLabel.timeDifference.rawValue)
                
                // The largest distance between predictions and expected values
                let worstTrainingError = regressor.trainingMetrics.maximumError
                let worstValidationError = regressor.validationMetrics.maximumError
                
                // Evaluate the regressor
                let regressorEvaluation = regressor.evaluation(on: timeEvaluationTable)
                
                // The largest distance between predictions and expected values
                let worstEvaluationError = regressorEvaluation.maximumError
                
                print("\nTime Difference regressor:")
                print("Worst Training Error: \(worstTrainingError)")
                print("Worst Validation Error: \(worstValidationError)")
                print("Worst Evaluation Error: \(worstEvaluationError)")
                
                guard let (allowedTimingTable, blockedTimingTable) = MLModelController().createAllowedBlockedTables(fromTable: timeDifferenceTable)
                else
                {
                    print("\nUnable to create allowed and blocked tables from time difference table.")
                    return
                }
                
                // This is the dictionary where we will save our results
                let timingDictionary: RMap<String,Double> = RMap(key: timeDifferenceTrainingResultsKey)
                
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
                    print("\n Predicted allowed time difference = \(predictedAllowedTimeDifference)")
                    
                    // Save scores
                    timingDictionary[requiredTimeDiffKey] = predictedAllowedTimeDifference
                    timingDictionary[timeDiffEAccKey] = evaluationAccuracy
                    timingDictionary[timeDiffTAccKey] = trainingAccuracy
                    timingDictionary[timeDiffVAccKey] = validationAccuracy
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
        
        /// TimeDifferences for the Allowed traffic
        let allowedTimeDifferenceList: RList<Double> = RList(key: allowedConnectionsTimeDiffKey)
        
        for timeDifferenceIndex in 0 ..< allowedTimeDifferenceList.count
        {
            guard let aTimeDifference = allowedTimeDifferenceList[timeDifferenceIndex]
                else
            {
                continue
            }
            
            timeDifferenceList.append(aTimeDifference)
            classificationLabels.append(ClassificationLabel.allowed.rawValue)
        }
        
        /// TimeDifferences for the Blocked traffic
        let blockedTimeDifferenceList: RList<Double> = RList(key: blockedConnectionsTimeDiffKey)
        
        for timeDifferenceIndex in 0 ..< blockedTimeDifferenceList.count
        {
            guard let bTimeDifference = blockedTimeDifferenceList[timeDifferenceIndex]
                else
            {
                continue
            }
            
            timeDifferenceList.append(bTimeDifference)
            classificationLabels.append(ClassificationLabel.blocked.rawValue)
        }
        
        return (timeDifferenceList, classificationLabels)
    }

}
