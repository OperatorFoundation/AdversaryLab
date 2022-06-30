//
//  Entropy.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import CreateML
import CoreML
import Foundation

class EntropyCoreML
{
    func processEntropy(labData: LabData, forConnection connection: ObservedConnection) -> (processsed: Bool, inEntropy: Double?, outEntropy: Double?, error: Error?)
    {
        var outData: Data?
        var inData: Data?
        
        switch connection.connectionType
        {
        case .transportA:
            // Get the incoming packet that corresponds with this connection ID
                inData = labData.connectionGroupData.aConnectionData.incomingPackets[connection.connectionID]
            // Get the outgoing packet that corresponds with this connection ID
                outData = labData.connectionGroupData.aConnectionData.outgoingPackets[connection.connectionID]
        case .transportB:
                inData = labData.connectionGroupData.bConnectionData.incomingPackets[connection.connectionID]
                outData = labData.connectionGroupData.bConnectionData.outgoingPackets[connection.connectionID]
        }
        
        guard let outPacket = outData else { return(false, nil, nil, nil) }
        guard let inPacket = inData else { return(false, nil, nil, nil) }
        
        let outPacketEntropy = calculateEntropy(for: outPacket)
        let inPacketEntropy = calculateEntropy(for: inPacket)
        
        // Save Entropies to our global var
        switch connection.connectionType
        {
        case .transportA:
                labData.packetEntropies.incomingA.append(inPacketEntropy)
                labData.packetEntropies.outgoingA.append(outPacketEntropy)
        case .transportB:
                labData.packetEntropies.incomingB.append(inPacketEntropy)
                labData.packetEntropies.outgoingB.append(outPacketEntropy)
        }
        
        return (true, inPacketEntropy, outPacketEntropy, nil)
    }
    
    func calculateEntropy(for packet: Data) -> Double
    {
        let probabilities: [Double] = calculateProbabilities(for: packet)
        var entropy: Double = 0
        
        for probability in probabilities
        {
            if probability != 0 {
                let plog2 = log2(probability)
                entropy += (plog2 * probability)
            }
        }
        entropy = -entropy
        
        return entropy
    }
    
    /// Calculates the probability of each byte in the data packet
    /// and returns them in an array where the index is the byte and value is the probability
    private func calculateProbabilities(for packet: Data) -> [Double]
    {
        let packetArray = [UInt8](packet)
        var countArray = Array(repeating: 0.0, count: 256)
        
        for byte in packetArray {
            let index = Int(byte)
            countArray[index] += 1
        }
        
        for (index, countValue) in countArray.enumerated()
        {
            if countValue != 0 {
                countArray[index] /= Double(packet.count)
            }
        }
        
        return countArray
    }
    
    func scoreAllEntropyInDatabase(labData: LabData, configModel: ProcessingConfigurationModel)
    {
        if configModel.trainingMode
        {
            // Outgoing
            let outEntropyTable = createEntropyTable(labData: labData, connectionDirection: .outgoing)
            trainEntropy(labData: labData, table: outEntropyTable, connectionDirection: .outgoing, modelName: configModel.modelName)
            
            // Incoming
            let inEntropyTable = createEntropyTable(labData: labData, connectionDirection: .incoming)
            trainEntropy(labData: labData, table: inEntropyTable, connectionDirection: .incoming, modelName: configModel.modelName)
        }
        else
        {
            testModel(labData: labData, connectionDirection: .incoming, configModel: configModel)
            testModel(labData: labData, connectionDirection: .outgoing, configModel: configModel)
        }
    }
    
    func createEntropyTable(labData: LabData, connectionDirection: ConnectionDirection) -> MLDataTable
    {
        let (entropyList, classificationLabels) = getEntropyAndClassificationLists(labData: labData, connectionDirection: connectionDirection)
        
        var entropyTable = MLDataTable()
        let entropyColumn = MLDataColumn(entropyList)
        let classificationColumn = MLDataColumn(classificationLabels)
        entropyTable.addColumn(entropyColumn, named: ColumnLabel.entropy.rawValue)
        entropyTable.addColumn(classificationColumn, named: ColumnLabel.classification.rawValue)
        
        return entropyTable
    }
    
    func getEntropyAndClassificationLists(labData: LabData, connectionDirection: ConnectionDirection) -> (entropyList: [Double], classificationLabels: [String])
    {
        var entropyList = [Double]()
        var classificationLabels = [String]()
        var aEntropyList = [Double]()
        var bEntropyList = [Double]()

        switch connectionDirection
        {
        case .incoming:
                aEntropyList = labData.packetEntropies.incomingA
                bEntropyList = labData.packetEntropies.incomingB
        case .outgoing:
                aEntropyList = labData.packetEntropies.outgoingA
                bEntropyList = labData.packetEntropies.outgoingB
        }
        
        // Allowed Traffic
        for entropyIndex in 0 ..< aEntropyList.count
        {
            let aEntropy = aEntropyList[entropyIndex]
            entropyList.append(aEntropy)
            classificationLabels.append(ClassificationLabel.transportA.rawValue)
        }
        
        /// Blocked traffic
        for entropyIndex in 0 ..< bEntropyList.count
        {
            let bEntropy = bEntropyList[entropyIndex]
            entropyList.append(bEntropy)
            classificationLabels.append(ClassificationLabel.transportB.rawValue)
        }
        
        return (entropyList, classificationLabels)
    }
    
    func testModel(labData: LabData, connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
    {
        var aEntropyList = [Double]()
        var bEntropyList = [Double]()

        switch connectionDirection
        {
        case .incoming:
                aEntropyList = labData.packetEntropies.incomingA
                bEntropyList = labData.packetEntropies.incomingB
        case .outgoing:
                aEntropyList = labData.packetEntropies.outgoingA
                bEntropyList = labData.packetEntropies.outgoingB
        }
        
        guard bEntropyList.count > 0
        else
        {
            print("\nUnable to test entropy. The blocked entropy list is empty.")
            return
        }
        
        // Allowed
        testModel(labData: labData, entropyList: aEntropyList, connectionType: .transportA, connectionDirection: connectionDirection, configModel: configModel)
        
        // Blocked
        testModel(labData: labData, entropyList: bEntropyList, connectionType: .transportB, connectionDirection: connectionDirection, configModel: configModel)
    }
    
    func testModel(labData: LabData, entropyList: [Double], connectionType: ClassificationLabel, connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
    {
        let entropyClassifierName: String
        let entropyRegressorName: String
        
        switch connectionDirection
        {
        case .outgoing:
            entropyClassifierName = outEntropyClassifierName
            entropyRegressorName = outEntropyRegressorName
        case .incoming:
            entropyClassifierName = inEntropyClassifierName
            entropyRegressorName = inEntropyRegressorName
        }

        do
        {
            let classifierFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.entropy.rawValue: entropyList])
            let regressorFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.classification.rawValue: [connectionType.rawValue]])
            
            guard let tempDirURL = getAdversaryTempDirectory()
                else
            {
                print("\nFailed to test entropy model. Unable to locate application document directory.")
                return
            }
            
            let temporaryDirURL = tempDirURL.appendingPathComponent("\(configModel.modelName)", isDirectory: true)
            let classifierFileURL = temporaryDirURL.appendingPathComponent(entropyClassifierName, isDirectory: false).appendingPathExtension(modelFileExtension)
            let regressorFileURL = temporaryDirURL.appendingPathComponent(entropyRegressorName).appendingPathExtension(modelFileExtension)
                        
            // Regressor
            if FileManager.default.fileExists(atPath: regressorFileURL.path)
            {
                guard let regressorPrediction = MLModelController().prediction(fileURL: regressorFileURL, batchFeatureProvider: regressorFeatureProvider)
                    else
                {
                    print("\n🛑  Failed to make an entropy regressor prediction.")
                    return
                }
                
                guard regressorPrediction.count > 0
                    else { return }
                
                // We are only expecting one result
                let thisFeatureNames = regressorPrediction.features(at: 0).featureNames
                
                // Check that we received a result with a feature named 'entropy' and that it has a value.
                guard let firstFeatureName = thisFeatureNames.first
                    else { return }
                guard firstFeatureName == ColumnLabel.entropy.rawValue
                    else { return }
                guard let thisFeatureValue = regressorPrediction.features(at: 0).featureValue(for: firstFeatureName)
                    else { return }
                       
                // Save the test results
                switch connectionDirection
                {
                case .incoming:
                    switch connectionType
                    {
                    case .transportA:
                            labData.packetEntropies.incomingATestResults = TestResults(prediction: thisFeatureValue.doubleValue, accuracy: nil)
                    case .transportB:
                            labData.packetEntropies.incomingBTestResults = TestResults(prediction: thisFeatureValue.doubleValue, accuracy: nil)
                    }
                case .outgoing:
                    switch connectionType
                    {
                    case .transportA:
                            labData.packetEntropies.outgoingATestResults = TestResults(prediction: thisFeatureValue.doubleValue, accuracy: nil)
                    case .transportB:
                            labData.packetEntropies.outgoingBTestResults = TestResults(prediction: thisFeatureValue.doubleValue, accuracy: nil)
                    }
                }
                
            }
            
            // Classifier
            if FileManager.default.fileExists(atPath: classifierFileURL.path)
            {
                guard let classifierPrediction = MLModelController().prediction(fileURL: classifierFileURL, batchFeatureProvider: classifierFeatureProvider)
                    else
                {
                    print("\n🛑  Failed to make an entropy classifier prediction.")
                    return
                }
                
                let classifierFeatureCount = classifierPrediction.count
                var allowedBlockedCount: Double = 0.0
                for index in 0 ..< classifierFeatureCount
                {
                    let thisFeature = classifierPrediction.features(at: index)
                    guard let entropyClassification = thisFeature.featureValue(for: "classification")
                        else { continue }
                    if entropyClassification.stringValue == connectionType.rawValue
                    {
                        allowedBlockedCount += 1
                    }
                }
                
                var accuracy = allowedBlockedCount/Double(classifierFeatureCount)
                // Round it to 3 decimal places
                accuracy = (accuracy * 1000).rounded()/1000
                // Show the accuracy as a percentage value
                accuracy = accuracy * 100
                print("🔮 Entropy classification prediction accuracy: \(accuracy) \(connectionType.rawValue).")
                
                if accuracy > 0
                {
                    // Save the test accuracy
                    switch connectionDirection
                    {
                    case .incoming:
                        switch connectionType
                        {
                        case .transportA:
                                labData.packetEntropies.incomingATestResults?.accuracy = accuracy
                        case .transportB:
                                labData.packetEntropies.incomingBTestResults?.accuracy = accuracy
                        }
                    case .outgoing:
                        switch connectionType
                        {
                        case .transportA:
                                labData.packetEntropies.outgoingATestResults?.accuracy = accuracy
                        case .transportB:
                                labData.packetEntropies.outgoingBTestResults?.accuracy = accuracy
                        }
                    }
                }
            }
        }
        catch
        {
            print("Unable to test \(connectionDirection) entropy. Error creating batch feature provider: \(error)")
        }
    }
    
    func trainEntropy(labData: LabData, table entropyTable: MLDataTable, connectionDirection: ConnectionDirection, modelName: String)
    {
        let entropyClassifierName: String
        let entropyRegressorName: String
        
        switch connectionDirection
        {
        case .outgoing:
            entropyClassifierName = outEntropyClassifierName
            entropyRegressorName = outEntropyRegressorName
        case .incoming:
            entropyClassifierName = inEntropyClassifierName
            entropyRegressorName = inEntropyRegressorName
        }
        
        // Set aside 20% of the model's data rows for evaluation, leaving the remaining 80% for training
        let (entropyEvaluationTable, entropyTrainingTable) = entropyTable.randomSplit(by: 0.20)

        // Train the classifier
        do
        {
            // This is the dictionary we will save our results to
            let classifier = try MLClassifier(trainingData: entropyTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
            
            // Classifier Training Accuracy as a Percentage
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
            let classifierEvaluation = classifier.evaluation(on: entropyEvaluationTable)
            
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
                let regressor = try MLRegressor(trainingData: entropyTrainingTable, targetColumn: ColumnLabel.entropy.rawValue)
                
                guard let (allowedEntropyTable, blockedEntropyTable) = MLModelController().createAandBTables(fromTable: entropyTable)
                else
                {
                    print("\nUnable to create allowed and blocked tables from entropy table.")
                    return
                }

                // Allowed Entropy
                do
                {
                    let transportAEntropyColumn = try regressor.predictions(from: allowedEntropyTable)
                    
                    guard let transportAEntropies = transportAEntropyColumn.doubles
                        else
                    {
                        print("Failed to identify allowed entropy.")
                        return
                    }
                    
                    let predictedTransportAEntropy = transportAEntropies[0]
                    print("\nPredicted allowed entropy = \(predictedTransportAEntropy)")
                    
                    // TransportB Entropy
                    let transportBEntropyColumn = try regressor.predictions(from: blockedEntropyTable)
                    guard let transportBEntropies = transportBEntropyColumn.doubles
                        else
                    {
                        print("\nFailed to identify blocked entropy.")
                        return
                    }
                    
                    let predictedTransportBEntropy = transportBEntropies[0]
                    print("\nPredicted transportB entropy = \(predictedTransportBEntropy)")
                    
                    // Save Scores
                    switch connectionDirection
                    {
                    case .incoming:
                            labData.trainingData.incomingEntropyTrainingResults = TrainingResults(
                            predictionForA: predictedTransportAEntropy,
                            predictionForB: predictedTransportBEntropy,
                            trainingAccuracy: trainingAccuracy,
                            validationAccuracy: validationAccuracy,
                            evaluationAccuracy: evaluationAccuracy)
                    case .outgoing:
                            labData.trainingData.outgoingEntropyTrainingResults = TrainingResults(
                            predictionForA: predictedTransportAEntropy,
                            predictionForB: predictedTransportBEntropy,
                            trainingAccuracy: trainingAccuracy,
                            validationAccuracy: validationAccuracy,
                            evaluationAccuracy: evaluationAccuracy)
                    }
                    
                    // Save the models
                    FileController().saveModel(classifier: classifier,
                                                  classifierMetadata: entropyClassifierMetadata,
                                                  classifierFileName: entropyClassifierName,
                                                  regressor: regressor,
                                                  regressorMetadata: entropyRegressorMetadata,
                                                  regressorFileName: entropyRegressorName,
                                                  groupName: modelName)
                }
                catch let allowedColumnError
                {
                    print("\nError creating entropy column:\(allowedColumnError)")
                }
            }
            catch let regressorError
            {
                print("Error creating regressor for entropy: \(regressorError)")
            }
        }
        catch let classifierError
        {
            print("\nError creating classifier: \(classifierError)")
        }
    }

}
