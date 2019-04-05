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
    
    func scoreAllTiming()
    {
        scoreTiming(allowedTimeDifferenceKey: allowedConnectionsTimeDiffKey, allowedTimeDifferenceBinsKey: allowedConnectionsTimeDiffBinsKey, blockedTimeDifferenceKey: blockedConnectionsTimeDiffKey, blockedTimeDifferenceBinsKey: blockedConnectionsTimeDiffBinsKey, requiredTimeDifferenceKey: requiredTimeDiffKey, forbiddenTimeDifferenceKey: forbiddenTimeDiffKey)
    }
    
    
    func scoreTiming(allowedTimeDifferenceKey: String, allowedTimeDifferenceBinsKey: String, blockedTimeDifferenceKey: String, blockedTimeDifferenceBinsKey: String, requiredTimeDifferenceKey: String, forbiddenTimeDifferenceKey: String)
    {
        var timeDifferenceList = [Double]()
        var classificationLabels = [String]()
        
        /// TimeDifferences for the Allowed traffic
        let allowedTimeDifferenceList: RList<Double> = RList(key: allowedTimeDifferenceKey)
        
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
        let blockedTimeDifferenceList: RList<Double> = RList(key: blockedTimeDifferenceKey)
        
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
                
                // Allowed Connection Time Differences
                do
                {
                    let allowedTimeTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.allowed.rawValue, ColumnLabel.timeDifference.rawValue: 0])
                    
                    do
                    {
                        let allowedTimeColumn = try regressor.predictions(from: allowedTimeTable)
                        
                        guard let allowedTimeDifferences = allowedTimeColumn.doubles
                        else
                        {
                            print("\nFailed to identify allowed time differences.")
                            return
                        }
                        
                        let predictedAllowedTimeDifference = allowedTimeDifferences[0]
                        print("\n Predicted allowed time difference = \(predictedAllowedTimeDifference)")
                        
                        // Save scores
                        let requiredTiming: RSortedSet<Double> = RSortedSet(key: requiredTimeDifferenceKey)
                        let _ = requiredTiming.insert((predictedAllowedTimeDifference, Float(evaluationAccuracy)))
                        
                    }
                    catch let allowedColumnError
                    {
                        print("\nError creating allowed time difference column: \(allowedColumnError)")
                    }
                }
                catch let allowedTimeTableError
                {
                    print("\nError creating allowed time difference table: \(allowedTimeTableError)")
                }
                
                // Blocked Connection Time Differences
                do
                {
                    let blockedTimeTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.blocked.rawValue, ColumnLabel.timeDifference.rawValue: 0])
                    
                    do
                    {
                        let blockedColumn = try regressor.predictions(from: blockedTimeTable)
                        guard let blockedTimeDifferences = blockedColumn.doubles
                        else
                        {
                            print("\nFailed to identify blocked time differences.")
                            return
                        }
                        
                        let predictedBlockedTimeDifference = blockedTimeDifferences[0]
                        print("\nPredicted blocked time difference = \(predictedBlockedTimeDifference)")
                        
                        /// Save Scores
                        let forbiddenTiming: RSortedSet<Double> = RSortedSet(key: forbiddenTimeDifferenceKey)
                        let _ = forbiddenTiming.insert((predictedBlockedTimeDifference, Float(evaluationAccuracy)))
                    }
                    catch let blockedColumnError
                    {
                        print("\nError creating blocked time difference column: \(blockedColumnError)")
                    }
                }
                catch let blockedTimeTableError
                {
                    print("\nError creating blocked time difference table: \(blockedTimeTableError)")
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

}
