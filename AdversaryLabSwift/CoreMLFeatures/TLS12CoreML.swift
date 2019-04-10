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

let tlsRequestStart=Data(bytes: [0x16, 0x03])
let tlsResponseStart=Data(bytes: [0x16, 0x03])
let commonNameStart=Data(bytes: [0x55, 0x04, 0x03])
let commonNameEnd=Data(bytes: [0x30])

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
    
    func processTls12(_ connection: ObservedConnection)
    {
        let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
        let tlsCommonNameSet: RSortedSet<String> = RSortedSet(key: connection.outgoingTlsCommonNameKey)
        
        // Get the out packet that corresponds with this connection ID
        guard let outPacket: Data = outPacketHash[connection.connectionID]
            else
        {
            NSLog("No TLS outgoing packet found")
            return
        }
        
        let maybeBegin = findCommonNameStart(outPacket)
        guard let begin = maybeBegin else {
            NSLog("No common name beginning found")
            NSLog("\(connection.outgoingKey) \(connection.connectionID) \(outPacket.count)")
            return
        }
        
        let maybeEnd = findCommonNameEnd(outPacket, begin+commonNameStart.count)
        guard let end = maybeEnd else {
            NSLog("No common name beginning end")
            return
        }
        
        let commonData = extract(outPacket, begin+commonNameStart.count, end-1)
        let commonName = commonData.string
        NSLog("Found TLS 1.2 common name: \(commonName) \(commonName.count) \(begin) \(end)")
        
        let _ = tlsCommonNameSet.incrementScore(ofField: commonName, byIncrement: 1)
    }
    
    func scoreTls12()
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
        
        var tlsTable = MLDataTable()
        let tlsColumn = MLDataColumn(allTLSNames)
        let classyColumn = MLDataColumn(classificationLabels)
        tlsTable.addColumn(tlsColumn, named: ColumnLabel.tlsNames.rawValue)
        tlsTable.addColumn(classyColumn, named: ColumnLabel.classification.rawValue)
        
        // Set aside 20% of the model's data rows for evaluation, leaving the remaining 80% for training
        let (tlsEvaluationTable, tlsTrainingTable) = tlsTable.randomSplit(by: 0.20)
        
        
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
                
                // Allowed TLS Names
                do
                {
                    let allowedTLSTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.allowed.rawValue, ColumnLabel.tlsNames.rawValue: ""])
                    
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
                        
                        // TODO: This is only one result?
                        /// Save Scores
                        let requiredTLSNames: RSortedSet<String> = RSortedSet(key: allowedTlsScoreKey)
                        let (_, _) = requiredTLSNames.insert((predictedAllowedTLSName, Float(evaluationAccuracy)))
                    }
                    catch let allowedTLSColumnError
                    {
                        print("\nError creating allowed TLS column: \(allowedTLSColumnError)")
                    }
                }
                catch let allowedTLSTableError
                {
                    print("\nError creating allowed tls table: \(allowedTLSTableError)")
                }
                
                // Blocked TLS Named
                do
                {
                    let blockedTLSTable = try MLDataTable(dictionary: [ColumnLabel.classification.rawValue: ClassificationLabel.blocked.rawValue, ColumnLabel.tlsNames.rawValue: ""])
                    
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
                        let forbiddenTLSNames: RSortedSet<String> = RSortedSet(key: blockedTlsScoreKey)
                        let (_, _) = forbiddenTLSNames.insert((predictedBlockedTLSName, Float(evaluationAccuracy)))
                        
                        // Save the model
                        MLModelController().saveModel(classifier: classifier, classifierMetadata: tlsClassifierMetadata, regressor: regressor, regressorMetadata: tlsRegressorMetadata, name: ColumnLabel.tlsNames.rawValue)
                    }
                    catch let blockedTLSColumnError
                    {
                        print("\nError creating blocked TLS column: \(blockedTLSColumnError)")
                    }
                }
                catch let blockedTLSTableError
                {
                    print("\nError creating blocked tls table: \(blockedTLSTableError)")
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
    
    private func findCommonNameStart(_ outPacket: Data) -> Int? {
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
