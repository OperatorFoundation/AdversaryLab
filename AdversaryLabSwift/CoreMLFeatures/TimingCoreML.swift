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
    
    func processTiming(labData: LabData, forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
    {
        var outDate: Double?
        var inDate: Double?
        
        switch connection.connectionType
        {
        case .transportA:
                outDate = labData.connectionGroupData.aConnectionData.outgoingDates[connection.connectionID]
                inDate = labData.connectionGroupData.aConnectionData.incomingDates[connection.connectionID]
            
        case .transportB:
                outDate = labData.connectionGroupData.bConnectionData.outgoingDates[connection.connectionID]
                inDate = labData.connectionGroupData.bConnectionData.incomingDates[connection.connectionID]
        }
        
        guard let timeOut = outDate else { return (false, nil) }
        guard let timeIn = inDate else { return (false, nil) }
        
        // Add the time difference for this connection to the database
        let timeDifference = (timeOut - timeIn)
        
        switch connection.connectionType
        {
        case .transportA:
                labData.packetTimings.transportA.append(timeDifference)
        case .transportB:
                labData.packetTimings.transportB.append(timeDifference)
        }
        
        return (true, nil)
    }
    
//    func scoreAllTiming()
//    {
//        scoreTiming(allowedTimeDifferenceKey: allowedConnectionsTimeDiffKey, blockedTimeDifferenceKey: blockedConnectionsTimeDiffKey, requiredTimeDifferenceKey: requiredTimeDiffKey, requiredTimeDifferenceAccKey: requiredTimeDiffAccKey, forbiddenTimeDifferenceKey: forbiddenTimeDiffKey, forbiddenTimeDifferenceAccKey: forbiddenTimeDiffAccKey)
//    }
    
    func scoreTiming(labData: LabData, configModel: ProcessingConfigurationModel)
    {
        if configModel.trainingMode
        {
            trainModels(labData: labData, configModel: configModel)
        }
        else
        {
            testModel(labData: labData, configModel: configModel)
        }
    }
    
    func testModel(labData: LabData, configModel: ProcessingConfigurationModel)
    {
        guard labData.packetTimings.transportB.count > 0
            else
        {
            print("\nError: No blocked time differences found in the database. Tests cannot be run without blocked connection data.")
            return
        }
        
        self.testModel(labData: labData, connectionType: .transportB, timeDifferences: labData.packetTimings.transportB, configModel: configModel)
        
        if labData.packetTimings.transportA.count > 0
        {
            self.testModel(labData: labData, connectionType: .transportA, timeDifferences: labData.packetTimings.transportA, configModel: configModel)
        }
    }
    
    func testModel(labData: LabData, connectionType: ClassificationLabel, timeDifferences: [Double], configModel: ProcessingConfigurationModel)
    {
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
                
                switch connectionType
                {
                case .transportA:
                        labData.packetTimings.transportATestResults = TestResults(prediction: thisFeatureValue.doubleValue/1000, accuracy: nil)
                case .transportB:
                        labData.packetTimings.transportBTestResults = TestResults(prediction: thisFeatureValue.doubleValue/1000, accuracy: nil)
                }
                
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
                
                // Save the accuracy
                if accuracy > 0
                {
                    switch connectionType
                    {
                    case .transportA:
                            labData.packetTimings.transportATestResults?.accuracy = accuracy
                    case .transportB:
                            labData.packetTimings.transportBTestResults?.accuracy = accuracy
                    }
                }
            }
        }
        catch
        {
            print("Unable to test timing model. Error creating the feature provider: \(error)")
        }
    }
    
    func trainModels(labData: LabData, configModel: ProcessingConfigurationModel)
    {
        let (timeDifferenceList, classificationLabels) = getTimeDifferenceAndClassificationArrays(labData: labData)
        
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
            let classifier = try MLClassifier(trainingData: timeTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
            
            // Classifier training accuracy as a percentage
            let trainingError = classifier.trainingMetrics.classificationError
            var trainingAccuracy: Double? = nil
            if trainingError >= 0
            {
                trainingAccuracy = (1.0 - trainingError) * 100
            }
            
            // Classifier validation accuracy as a percentage
            let validationError = classifier.validationMetrics.classificationError
            var validationAccuracy: Double? = nil

            // Sometimes we get a negative number, this is not valid for our purposes
            if validationError >= 0
            {
                validationAccuracy = (1.0 - validationError) * 100
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
            
            // Regressor
            do
            {
                let regressor = try MLRegressor(trainingData: timeTrainingTable, targetColumn: ColumnLabel.timeDifference.rawValue)
                
                guard let (transportATimingTable, transportBTimingTable) = MLModelController().createAandBTables(fromTable: timeDifferenceTable)
                else
                {
                    print("\nUnable to create allowed and blocked tables from time difference table.")
                    return
                }
 
                // TransportA Connection Time Differences
                do
                {
                    let transportATimeColumn = try regressor.predictions(from: transportATimingTable)
                    
                    guard let transportATimeDifferences = transportATimeColumn.doubles
                    else
                    {
                        print("\nFailed to identify allowed time differences.")
                        return
                    }
                    
                    let transportAPredictedTimeDifference = transportATimeDifferences[0]
                    print("\nPredicted transportA time difference = \(transportAPredictedTimeDifference)")
                    
                    // transportB Connection Time Differences
                    let transportBColumn = try regressor.predictions(from: transportBTimingTable)
                    guard let transportBTimeDifferences = transportBColumn.doubles
                    else
                    {
                        print("\nFailed to identify blocked time differences.")
                        return
                    }
                    
                    let transportBPredictedTimeDifference = transportBTimeDifferences[0]
                    print("\nPredicted transportB time difference = \(transportBPredictedTimeDifference)")
                    
                    /// Save Predicted Time Difference
                    labData.trainingData.timingTrainingResults = TrainingResults(
                        predictionForA: transportAPredictedTimeDifference/1000,
                        predictionForB: transportBPredictedTimeDifference/1000,
                        trainingAccuracy: trainingAccuracy,
                        validationAccuracy: validationAccuracy,
                        evaluationAccuracy: evaluationAccuracy)
                    
                    
                    // Save the models
                    FileController().saveModel(classifier: classifier,
                                                  classifierMetadata: timingClassifierMetadata,
                                                  classifierFileName: timingClassifierName,
                                                  regressor: regressor,
                                                  regressorMetadata: timingRegressorMetadata,
                                                  regressorFileName: timingRegressorName,
                                                  groupName: configModel.modelName)
                }
                catch let allowedColumnError
                {
                    print("\nError creating time difference column: \(allowedColumnError)")
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
    
    
    func getTimeDifferenceAndClassificationArrays(labData: LabData) -> (timeDifferenceList: [Double], classificationLabels: [String])
    {
        var timeDifferenceList = [Double]()
        var classificationLabels = [String]()
        
        /// TimeDifferences for the Transport A traffic
        for aTimeDifference in labData.packetTimings.transportA
        {
            timeDifferenceList.append(aTimeDifference)
            classificationLabels.append(ClassificationLabel.transportA.rawValue)
        }
        
        /// TimeDifferences for Transport B traffic
        for bTimeDifference in labData.packetTimings.transportB
        {
            timeDifferenceList.append(bTimeDifference)
            classificationLabels.append(ClassificationLabel.transportB.rawValue)
        }
        
        return (timeDifferenceList, classificationLabels)
    }

}
