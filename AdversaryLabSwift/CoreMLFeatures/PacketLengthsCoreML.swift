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
    
    /**
     Train a model for packet lengths
     
     - Parameter modelName: A String that will be used to save the resulting mlm file.
     */
    func scoreAllPacketLengths(configModel: ProcessingConfigurationModel)
        //(modelName: String, trainingMode: Bool)
    {
        // Outgoing Lengths Scoring
        scorePacketLengths(connectionDirection: .outgoing, configModel: configModel)
        
        //Incoming Lengths Scoring
        scorePacketLengths(connectionDirection: .incoming, configModel: configModel)
    }
    
    func scorePacketLengths(connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
    {
        if configModel.trainingMode
        {
            let lengthsTable = createLengthTable(connectionDirection: connectionDirection)
            trainModels(lengthsTable: lengthsTable, connectionDirection: connectionDirection, modelName: configModel.modelName)
        }
        else
        {
            let (allowedLengths, blockedLengths) = getLengths(forConnectionDirection: connectionDirection)
            
            guard blockedLengths.count > 0
            else
            {
                print("\nUnable to test lengths. The blocked lengths list is empty.")
                return
            }
            
            // Allowed
            testModel(lengths: allowedLengths, connectionType: .allowed, connectionDirection: connectionDirection, configModel: configModel)
            
            // Blocked
            testModel(lengths: blockedLengths, connectionType: .blocked, connectionDirection: connectionDirection, configModel: configModel)
        }
    }
    
    func testModel(lengths: [Int], connectionType: ClassificationLabel, connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
    {
        let classifierName: String
        let regressorName: String
        let accuracyKey: String
        let lengthKey: String
        
        switch connectionDirection
        {
        case .incoming:
            classifierName = inLengthClassifierName
            regressorName = inLengthRegressorName
            switch connectionType
            {
            case .allowed:
                accuracyKey = allowedIncomingLengthAccuracyKey
                lengthKey = allowedIncomingLengthKey
            case .blocked:
                accuracyKey = blockedIncomingLengthAccuracyKey
                lengthKey = blockedIncomingLengthKey
            }
        case .outgoing:
            classifierName = outLengthClassifierName
            regressorName = outLengthRegressorName
            switch connectionType
            {
            case .allowed:
                accuracyKey = allowedOutgoingLengthAccuracyKey
                lengthKey = allowedOutgoingLengthKey
            case .blocked:
                accuracyKey = blockedOutgoingLengthAccuracyKey
                lengthKey = blockedOutgoingLengthKey
            }
        }
        do
        {
            let classifierFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.length.rawValue: lengths])
            let regressorFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.classification.rawValue: [connectionType.rawValue]])
            
            guard let appDirectory = getAdversarySupportDirectory()
            else
            {
                print("\nFailed to test models. Unable to locate application document directory.")
                return
            }
            
            let temporaryDirURL = appDirectory.appendingPathComponent("\(configModel.modelName)/temp/\(configModel.modelName)", isDirectory: true)
            let classifierFileURL = temporaryDirURL.appendingPathComponent(classifierName, isDirectory: false).appendingPathExtension(modelFileExtension)
            let regressorFileURL = temporaryDirURL.appendingPathComponent(regressorName, isDirectory: false).appendingPathExtension(modelFileExtension)
            
            // This is the dictionary where we will save our results
            let lengthDictionary: RMap<String,Double> = RMap(key: testResultsKey)
            
            // Regressor
            if FileManager.default.fileExists(atPath: regressorFileURL.path)
            {
                if let regressorPrediction = MLModelController().prediction(fileURL: regressorFileURL, batchFeatureProvider: regressorFeatureProvider)
                {
                    guard regressorPrediction.count > 0
                        else { return }
                    
                    // We are only expecting one result
                    let thisFeatureNames = regressorPrediction.features(at: 0).featureNames
                    
                    // Check that we received a result with a feature named 'entropy' and that it has a value.
                    guard let firstFeatureName = thisFeatureNames.first
                        else { return }
                    guard firstFeatureName == ColumnLabel.length.rawValue
                        else { return }
                    guard let thisFeatureValue = regressorPrediction.features(at: 0).featureValue(for: firstFeatureName)
                        else { return }
                    
                    print("🔮 Length prediction for \(lengthKey): \(thisFeatureValue).")
                    lengthDictionary[lengthKey] = thisFeatureValue.doubleValue
                }
            }
            
            // Classifier
            if FileManager.default.fileExists(atPath: classifierFileURL.path)
            {
                if let classifierPrediction = MLModelController().prediction(fileURL: classifierFileURL, batchFeatureProvider: classifierFeatureProvider)
                {
                    guard classifierPrediction.count > 0
                    else
                    {
                        print("\nLength classifier prediction has no values.")
                        return
                    }
                    
                    let featureCount = classifierPrediction.count
                    
                    guard featureCount > 0
                    else
                    {
                        print("/nLength prediction had no values.")
                        return
                    }
                    
                    var allowedBlockedCount: Double = 0.0
                    for index in 0 ..< featureCount
                    {
                        let thisFeature = classifierPrediction.features(at: index)
                        guard let lengthClassification = thisFeature.featureValue(for: "classification")
                            else { continue }
                        if lengthClassification.stringValue == connectionType.rawValue
                        {
                            allowedBlockedCount += 1
                        }
                    }
                    
                    let accuracy = allowedBlockedCount/Double(featureCount)
                    print("\n🔮 Length prediction: \(accuracy * 100) \(connectionType.rawValue).")
                    
                    lengthDictionary[accuracyKey] = accuracy
                }
            }
        }
        catch let featureProviderError
        {
            print("\nError creating lengths feature provider: \(featureProviderError)")
        }
    }
    
    func createLengthTable(connectionDirection: ConnectionDirection) -> MLDataTable
    {
        let (lengths, classificationLabels) = getLengthsAndClassificationsArrays(connectionDirection: connectionDirection)
        
        // Create the Lengths Table
        var lengthsTable = MLDataTable()
        let lengthsColumn = MLDataColumn(lengths)
        let classyLabelColumn = MLDataColumn(classificationLabels)
        lengthsTable.addColumn(lengthsColumn, named: ColumnLabel.length.rawValue)
        lengthsTable.addColumn(classyLabelColumn, named: ColumnLabel.classification.rawValue)
        
        return lengthsTable
    }
    
    func trainModels(lengthsTable: MLDataTable, connectionDirection: ConnectionDirection, modelName: String)
    {
        let requiredLengthKey: String
        let forbiddenLengthKey: String
        let lengthsTAccKey: String
        let lengthsVAccKey: String
        let lengthsEAccKey: String
        let regressorName: String
        let classifierName: String
        
        switch connectionDirection
        {
        case .incoming:
            requiredLengthKey = incomingRequiredLengthKey
            forbiddenLengthKey = incomingForbiddenLengthKey
            lengthsTAccKey = incomingLengthsTAccKey
            lengthsVAccKey = incomingLengthsVAccKey
            lengthsEAccKey = incomingLengthsEAccKey
            regressorName = inLengthRegressorName
            classifierName = inLengthClassifierName
        case .outgoing:
            requiredLengthKey = outgoingRequiredLengthKey
            forbiddenLengthKey = outgoingForbiddenLengthKey
            lengthsTAccKey = outgoingLengthsTAccKey
            lengthsVAccKey = outgoingLengthsVAccKey
            lengthsEAccKey = outgoingLengthsEAccKey
            regressorName = outLengthRegressorName
            classifierName = outLengthClassifierName
        }
        
        // Set aside 20% of the model's data rows for evaluation, leaving the remaining 80% for training
        let (lengthsEvaluationTable, lengthsTrainingTable) = lengthsTable.randomSplit(by: 0.20)
        
        // Train the classifier
        do
        {
            let classifier = try MLClassifier(trainingData: lengthsTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
            let trainingAccuracy = (1.0 - classifier.trainingMetrics.classificationError) * 100
            let classifierEvaluation = classifier.evaluation(on: lengthsEvaluationTable)
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
            
            do
            {
                let regressor = try MLRegressor(trainingData: lengthsTrainingTable, targetColumn: ColumnLabel.length.rawValue)
                
                guard let (allowedTable, blockedTable) = MLModelController().createAllowedBlockedTables(fromTable: lengthsTable)
                    else
                {
                    print("\nUnable to get allowed/blocked tables from lengths data table.")
                    return
                }
                
                let allowedPredictionColumn = try regressor.predictions(from: allowedTable)
                let blockedPredictionColumn = try regressor.predictions(from: blockedTable)
                
                guard let allowedLengths = allowedPredictionColumn.doubles
                    else
                {
                    print("Failed to get allowed lengths from allowed column.")
                    return
                }
                
                guard let blockedLengths = blockedPredictionColumn.doubles
                    else
                {
                    print("Failed to get blocked lengths from blocked column.")
                    return
                }

                let predictedAllowedLength = allowedLengths[0]
                let predictedBlockedLength = blockedLengths[0]
                
                // Save Scores
                let lengthsDictionary: RMap<String, Double> = RMap(key: packetLengthsTrainingResultsKey)
                lengthsDictionary[requiredLengthKey] = predictedAllowedLength
                lengthsDictionary[forbiddenLengthKey] = predictedBlockedLength
                lengthsDictionary[lengthsTAccKey] = trainingAccuracy
                lengthsDictionary[lengthsEAccKey] = evaluationAccuracy
                
                if validationAccuracy != nil
                {
                    lengthsDictionary[lengthsVAccKey] = validationAccuracy!
                }
                
                // Save the models to a file
                MLModelController().saveModel(classifier: classifier,
                                              classifierMetadata: lengthsClassifierMetadata,
                                              classifierFileName: classifierName,
                                              regressor: regressor,
                                              regressorMetadata: lengthsRegressorMetadata,
                                              regressorFileName: regressorName,
                                              groupName: modelName)
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
    
    func getLengths(forConnectionDirection connectionDirection: ConnectionDirection) -> (allowedLengths:[Int], blockedLengths: [Int])
    {
        let allowedLengthsKey: String
        let blockedLengthsKey: String
        
        switch connectionDirection
        {
        case .incoming:
            allowedLengthsKey = allowedIncomingLengthKey
            blockedLengthsKey = blockedIncomingLengthKey
        case .outgoing:
            allowedLengthsKey = allowedOutgoingLengthKey
            blockedLengthsKey = blockedOutgoingLengthKey
        }
        
        /// A is the sorted set of lengths for the Allowed traffic
        let allowedLengthsRSet: RSortedSet<Int> = RSortedSet(key: allowedLengthsKey)
        let allowedLengthsArray = newIntArrayUniqueValues(from: [allowedLengthsRSet])
        
        /// B is the sorted set of lengths for the Blocked traffic
        let blockedLengthsRSet: RSortedSet<Int> = RSortedSet(key: blockedLengthsKey)
        let blockedLengthsArray = newIntArrayUniqueValues(from: [blockedLengthsRSet])
        
        return (allowedLengthsArray, blockedLengthsArray)
    }
    
    func getLengthsAndClassificationsArrays(connectionDirection: ConnectionDirection) -> (lengths: [Int], classifications: [String])
    {
        var lengths = [Int]()
        var classificationLabels = [String]()
        
        let allowedLengthsKey: String
        let blockedLengthsKey: String
        
        switch connectionDirection
        {
        case .incoming:
            allowedLengthsKey = allowedIncomingLengthKey
            blockedLengthsKey = blockedIncomingLengthKey
        case .outgoing:
            allowedLengthsKey = allowedOutgoingLengthKey
            blockedLengthsKey = blockedOutgoingLengthKey
        }
        
        /// A is the sorted set of lengths for the Allowed traffic
        let allowedLengthsRSet: RSortedSet<Int> = RSortedSet(key: allowedLengthsKey)
        let allowedLengthsArray = newIntArrayUniqueValues(from: [allowedLengthsRSet])
        
        /// B is the sorted set of lengths for the Blocked traffic
        let blockedLengthsRSet: RSortedSet<Int> = RSortedSet(key: blockedLengthsKey)
        let blockedLengthsArray = newIntArrayUniqueValues(from: [blockedLengthsRSet])
        
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
                classificationLabels.append(ClassificationLabel.allowed.rawValue)
            }
        }
        
        for length in blockedLengthsArray
        {
            guard let score: Float = blockedLengthsRSet[length]
                else { continue }
            
            let count = Int(score)
            
            for _ in 0 ..< count
            {
                lengths.append(length)
                classificationLabels.append(ClassificationLabel.blocked.rawValue)
            }
        }
        
        return(lengths, classificationLabels)
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
    
}

// TODO: Add this to Auburn instead

/// Returns one array containing each element in all of the sorted sets provided. This method takes an array of sorted sets of Ints and returns an array of Ints. Values are not repeated based on score. Each value will be added to the array only one time
/// - Parameters:
///     - redisSets: [RSortedSet<Int>], an array of sorted sets to turn in to one array of Ints.
/// - Returns: [Int], an array of Ints.
func newIntArrayUniqueValues(from redisSets:[RSortedSet<Int>]) -> [Int]
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

/// Returns an array of doubles created using the elements in the sorted set of Ints. The number of times a given element is added to the array is equal to the score of that element in the set.
/// - Parameters:
///     - intSortedSet: RSortedSet<Int>, the sorted set of Ints to use to create the array.
/// - Returns: [Double], An array of Doubles.
func newDoubleArrayUsingScores(from intSortedSet: RSortedSet<Int>) -> [Double]
{
    var newArray = [Double]()
    
    for i in 0 ..< intSortedSet.count
    {
        guard let value: Int = intSortedSet[i]
            else { continue }
        
        guard let score = intSortedSet.getScore(for: value)
            else { continue }
        
        // The score is the number of times we saw a given value
        // Add the value to the array "score" times
        for _ in 0..<Int(score)
        {
            newArray.append(Double(value))
        }
    }
    
    newArray.sort()
    return newArray
}



