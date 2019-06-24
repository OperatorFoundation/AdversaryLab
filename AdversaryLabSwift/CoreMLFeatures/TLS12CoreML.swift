//
//  TLS12CoreML.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 4/4/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn
import Datable
import CreateML
import CoreML

let tlsRequestStart=Data([0x16, 0x03])
let tlsResponseStart=Data([0x16, 0x03])
let commonNameStart=Data([0x55, 0x04, 0x03])
let commonNameEnd=Data([0x30])

class TLS12CoreML
{
    func isTls12(forConnection connection: ObservedConnection) -> Bool
    {
        // Get the in packet that corresponds with this connection ID
        let inPacketHash: RMap<String, Data> = RMap(key: connection.incomingKey)
        guard let inPacket: Data = inPacketHash[connection.connectionID] else {
            NSLog("Error, connection has no incoming packet")
            return false
        }
        
        let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
        guard let outPacket: Data = outPacketHash[connection.connectionID] else {
            NSLog("Error, connection has no outgoing packet")
            return false
        }
        
        let maybeRequestRange = inPacket.range(of: tlsRequestStart, options: .anchored, in: nil)
        let maybeResponseRange = outPacket.range(of: tlsResponseStart, options: .anchored, in: nil)
        
        guard maybeRequestRange != nil
            else
        {
            //NSLog("TLS request not found \(inPacket as NSData)")
            return false
        }
        
        guard maybeResponseRange != nil else {
            //NSLog("TLS response not found \(outPacket as NSData)")
            return false
        }
        
        return true
    }
    
    func processTls12(_ connection: ObservedConnection) -> String?
    {
        let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
        let tlsCommonNameSet: RSortedSet<String> = RSortedSet(key: connection.outgoingTlsCommonNameKey)
        
        // Get the out packet that corresponds with this connection ID
        guard let outPacket: Data = outPacketHash[connection.connectionID]
            else
        {
            //NSLog("No TLS outgoing packet found")
            return nil
        }
        
        let maybeBegin = findCommonNameStart(outPacket)
        guard let begin = maybeBegin else {
            //NSLog("No common name beginning found")
            //NSLog("\(connection.outgoingKey) \(connection.connectionID) \(outPacket.count)")
            return nil
        }
        
        let maybeEnd = findCommonNameEnd(outPacket, begin+commonNameStart.count)
        guard let end = maybeEnd else {
            //NSLog("No common name beginning end")
            return nil
        }
        
        let commonData = extract(outPacket, begin+commonNameStart.count, end-1)
        let commonName = commonData.string
        //NSLog("Found TLS 1.2 common name: \(commonName) \(commonName.count) \(begin) \(end)")
        
        let _ = tlsCommonNameSet.incrementScore(ofField: commonName, byIncrement: 1)
        return commonName
    }
    
    func getTLSAndClassificationLists() -> (allTLSNames: [String], classificationLabels: [String])
    {
        var allTLSNames = [String]()
        var classificationLabels = [String]()
        
        /// A is the sorted set of TLS names for the Allowed traffic
        let allowedTLSNamesSet: RSortedSet<String> = RSortedSet(key: allowedTlsCommonNameKey)
        let allowedTLSArray = newStringArray(from: [allowedTLSNamesSet])
        
        for tlsIndex in 0 ..< allowedTLSArray.count
        {
            let tlsName = allowedTLSArray[tlsIndex]
            allTLSNames.append(tlsName)
            classificationLabels.append(ClassificationLabel.allowed.rawValue)
        }
        
        /// B is the sorted set of TLS names for the Blocked traffic
        let blockedTLSNamesSet: RSortedSet<String> = RSortedSet(key: blockedTlsCommonNameKey)
        let blockedTLSArray = newStringArray(from: [blockedTLSNamesSet])
        
        for tlsIndex in 0 ..< blockedTLSArray.count
        {
            let tlsName = blockedTLSArray[tlsIndex]
            allTLSNames.append(tlsName)
            classificationLabels.append(ClassificationLabel.blocked.rawValue)
        }
        
        return (allTLSNames, classificationLabels)
    }
    
    func testModel(name: String)
    {
        // Blocked
        let blockedTLSNamesSet: RSortedSet<String> = RSortedSet(key: blockedTlsCommonNameKey)
        let blockedTLSNames = newStringArray(from: [blockedTLSNamesSet])
        
        guard blockedTLSNames.count > 0
        else
        {
            print("\nUnable to test TLS names. Blocked names list is empty.")
            return
        }
        testModel(connectionType: .blocked, tlsNames: blockedTLSNames, modelName: name)
        
        // Allowed
        let allowedTLSNamesSet: RSortedSet<String> = RSortedSet(key: allowedTlsCommonNameKey)
        let allowedTLSNames = newStringArray(from: [allowedTLSNamesSet])
        testModel(connectionType: .allowed, tlsNames: allowedTLSNames, modelName: name)
    }
    
    func testModel(connectionType: ClassificationLabel, tlsNames: [String], modelName: String)
    {
        let accuracyKey: String
        
        switch connectionType
        {
        case .allowed:
            accuracyKey = tlsAllowAccuracyKey
        case .blocked:
            accuracyKey = tlsBlockAccuracyKey
        }
        do
        {
            let batchFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.tlsNames.rawValue: tlsNames])
            
            guard let appDirectory = getAdversarySupportDirectory()
                else
            {
                print("\nFailed to test TLS model. Unable to locate application document directory.")
                return
            }
            
            let temporaryDirURL = appDirectory.appendingPathComponent("\(modelName)/temp/\(modelName)", isDirectory: true)
            
            let classifierFileURL = temporaryDirURL.appendingPathComponent(timingClassifierName, isDirectory: false).appendingPathExtension("mlmodel")
            
            if FileManager.default.fileExists(atPath: classifierFileURL.path)
            {
                guard let classifierPrediction = MLModelController().prediction(fileURL: classifierFileURL, batchFeatureProvider: batchFeatureProvider)
                else
                {
                    print("\n🛑  Failed to make a TLS prediction.")
                    return
                }
                
                let featureCount = classifierPrediction.count
                
                guard featureCount > 0
                else
                {
                    print("\nTLS12 prediction had no values.")
                    return
                }
                var allowedBlockedCount: Double = 0.0
                for index in 0 ..< featureCount
                {
                    let thisFeature = classifierPrediction.features(at: index)
                    guard let tlsClassification = thisFeature.featureValue(for: "classification")
                        else { continue }
                    if tlsClassification.stringValue == connectionType.rawValue
                    {
                        allowedBlockedCount += 1
                    }
                }
                
                let accuracy = allowedBlockedCount/Double(featureCount)
                print("\n🔮 TLS12 prediction: \(accuracy * 100) \(connectionType.rawValue).")
                // This is the dictionary where we will save our results
                let tlsDictionary: RMap<String,Double> = RMap(key: testResultsKey)
                tlsDictionary[accuracyKey] = accuracy
            }
        }
        catch
        {
            print("\nError testing TLS12 Model: \(error)")
        }
    }
    
    func trainTLS12Model(modelName: String)
    {
        let (allTLSNames, classificationLabels) = getTLSAndClassificationLists()
        
        guard allTLSNames.count > 2
            else { return }
        
        var tlsTable = MLDataTable()
        let tlsColumn = MLDataColumn(allTLSNames)
        let classyColumn = MLDataColumn(classificationLabels)
        tlsTable.addColumn(tlsColumn, named: ColumnLabel.tlsNames.rawValue)
        tlsTable.addColumn(classyColumn, named: ColumnLabel.classification.rawValue)
        
        // Set aside 20% of the model's data rows for evaluation, leaving the remaining 80% for training
        let (tlsEvaluationTable, tlsTrainingTable) = tlsTable.randomSplit(by: 0.20)
        guard tlsTrainingTable.rows.count > 2, tlsEvaluationTable.rows.count > 2
        else
        {
            print("\nUnable to train for TLS, there is not enough data.")
            return
        }
        
        // Train the classifier
        do
        {
            let classifier = try MLClassifier(trainingData: tlsTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
            
            // Classifier training accuracy as a percentage
            let trainingError = classifier.trainingMetrics.classificationError
            let trainingAccuracy = (1.0 - trainingError) * 100
            print("\nTLS training accuracy = \(trainingAccuracy)")
            
            // Classifier validation accuracy as a percentage
            let validationError = classifier.validationMetrics.classificationError
            let validationAccuracy = (1.0 - validationError) * 100
            print("\nTLS validation accuracy = \(validationAccuracy)")
            
            // Evaluate the classifier
            let classifierEvaluation = classifier.evaluation(on: tlsEvaluationTable)
            
            // Classifier evaluation accuracy as a percentage
            let evaluationError = classifierEvaluation.classificationError
            let evaluationAccuracy = (1.0 - evaluationError) * 100
            print("\nTLS evaluation accuracy = \(evaluationAccuracy)")
            
            // Regressor
            do
            {
                let regressor = try MLRegressor(trainingData: tlsTrainingTable, targetColumn: ColumnLabel.tlsNames.rawValue)
                
                // The largest distance between predictions and expected values
                let worstTrainingError = regressor.trainingMetrics.maximumError
                let worstValidationError = regressor.validationMetrics.maximumError
                
                // Evaluate the regressor
                let regressorEvaluation = regressor.evaluation(on: tlsEvaluationTable)
                
                // The largest distance between predictions and expected values
                let worstEvaluationError = regressorEvaluation.maximumError
                
                print("\nTLS names regressor:")
                print("Worst Training Error: \(worstTrainingError)")
                print("Worst Validation Error: \(worstValidationError)")
                print("Worst Evaluation Error: \(worstEvaluationError)")
                
                // Save our results accuracy
                let tlsAccuracy: RMap <String, Double> = RMap(key: tlsTrainingAccuracyKey)
                tlsAccuracy[tlsTAccKey] = trainingAccuracy
                tlsAccuracy[tlsVAccKey] = validationAccuracy
                tlsAccuracy[tlsEAccKey] = evaluationAccuracy
                
                guard let (allowedTLSTable, blockedTLSTable) = MLModelController().createAllowedBlockedTables(fromTable: tlsTable)
                else
                {
                    print("\nUnable to create allowed and blocked tables from tls table.")
                    return
                }
                
                // This is the dictionary where we will save our predictions
                let tlsResults: RMap <String, String> = RMap(key: tlsTrainingResultsKey)
                
                // Allowed TLS Names
                do
                {
                    let allowedTLSColumn = try regressor.predictions(from: allowedTLSTable)
                    
                    guard let allowedTLSNames = allowedTLSColumn.strings
                        else
                    {
                        print("\nFailed to predict allowed TLS name.")
                        return
                    }
                    
                    let predictedAllowedTLSName = allowedTLSNames[0]
                    print("\nPredicted allowed TLS Name = \(predictedAllowedTLSName)")
                    
                    // TODO: This is only one result
                    /// Save Prediction
                    tlsResults[requiredTLSKey] = predictedAllowedTLSName
                }
                catch let allowedTLSColumnError
                {
                    print("\nError creating allowed TLS column: \(allowedTLSColumnError)")
                }
                
                // Blocked TLS Named
                do
                {
                    let blockedTLSColumn = try regressor.predictions(from: blockedTLSTable)
                    
                    guard let blockedTLSNames = blockedTLSColumn.strings
                        else
                    {
                        print("\nFailed to predict blocked tls name.")
                        return
                    }
                    
                    let predictedBlockedTLSName = blockedTLSNames[0]
                    print("\nPredicted blocked tls name = \(predictedBlockedTLSName)")
                    
                    /// Save Scores
                    tlsResults[forbiddenTLSKey] = predictedBlockedTLSName
                    
                    // Save the model
                    MLModelController().saveModel(classifier: classifier,
                                                  classifierMetadata: tlsClassifierMetadata,
                                                  classifierFileName: tlsClassifierName,
                                                  regressor: regressor,
                                                  regressorMetadata: tlsRegressorMetadata,
                                                  regressorFileName: tlsRegressorName,
                                                  groupName: modelName)
                }
                catch let blockedTLSColumnError
                {
                    print("\nError creating blocked TLS column: \(blockedTLSColumnError)")
                }
            }
            catch let regressorError
            {
                print("\nError creating the tls regressor: \(regressorError)")
                print("TLS Table:\n\(tlsTable)\n")
            }
        }
        catch let classifierError
        {
            print("Error creating tls classifier: \(classifierError)")
        }
    }
    
    func scoreTLS12(configModel: ProcessingConfigurationModel)
    {
        if configModel.trainingMode
        {
            trainTLS12Model(modelName: configModel.modelName)
        }
        else
        {
            testModel(name: configModel.modelName)
        }
    }
    
    private func findCommonNameStart(_ outPacket: Data) -> Int?
    {
        let maybeRange = outPacket.range(of: commonNameStart)
        guard let range = maybeRange else {
            return nil
        }
        
        let maybeNextRange = outPacket.range(of: commonNameStart, options: [], in: range.upperBound..<outPacket.count)
        guard let nextRange = maybeNextRange else {
            return nil
        }
        
        return nextRange.lowerBound
    }
    
    private func findCommonNameEnd(_ outPacket: Data, _ begin: Int) -> Int? {
        let maybeRange = outPacket.range(of: commonNameEnd, options: [], in: begin..<outPacket.count)
        guard let range = maybeRange else {
            return nil
        }
        
        return range.lowerBound
    }
    
    func newStringSet(from redisSets:[RSortedSet<String>]) -> Set<String>
    {
        var swiftSet = Set<String>()
        for set in redisSets
        {
            for i in 0 ..< set.count
            {
                if let newMember: String = set[i]
                {
                    swiftSet.insert(newMember)
                }
            }
        }
        
        return swiftSet
    }
    
    
    
    private func extract(_ outPacket: Data, _ begin: Int, _ end: Int) -> Data {
        return outPacket[begin+2...end]
    }

}

func newStringArray(from redisSets:[RSortedSet<String>]) -> [String]
{
    var swiftArray = [String]()
    for set in redisSets
    {
        for i in 0 ..< set.count
        {
            if let newMember: String = set[i]
            {
                swiftArray.append(newMember)
            }
        }
    }
    
    return swiftArray
}
