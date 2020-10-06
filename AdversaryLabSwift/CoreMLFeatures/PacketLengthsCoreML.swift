//
//  PacketLengths.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import CreateML
import CoreML
import Foundation

import Abacus

struct LengthRecommender: Codable {
    let transportALength: Int
    let transportAScore: Double
    let transportBLength: Int
    let transportBScore: Double
}

extension LengthRecommender {
    
    /// Assuming that these arrays are parallel
    init?(connectionDirection: ConnectionDirection)
    {
        guard let (aLength, aScore, bLength, bScore) = getHighestScoredLength(forConnectionDirection: connectionDirection)
        else {
            return nil
        }
        
        self.transportALength = aLength
        self.transportAScore = aScore
        self.transportBLength = bLength
        self.transportBScore = bScore
    }
    
    func write(to fileURL: URL) throws
    {
        let encoder = JSONEncoder()
        let result = try encoder.encode(self)
        try result.write(to: fileURL)
//        let encoder = SongEncoder()
//        let result = try encoder.encode(self)
//        try result.write(to: fileURL)
    }
}

func getHighestScoredLength(forConnectionDirection connectionDirection: ConnectionDirection) -> (allowedLengths: Int, allowedLengthScore: Double, blockedLength: Int, blockedLengthScore: Double)?
{
    let aLengths: SortedMultiset<Int>
    let bLengths: SortedMultiset<Int>
    
    switch connectionDirection
    {
    case .incoming:
        aLengths = packetLengths.incomingA
        bLengths = packetLengths.incomingB
    case .outgoing:
        aLengths = packetLengths.outgoingA
        bLengths = packetLengths.outgoingB
    }
    
    /// A is the sorted set of lengths for the Transport A traffic
    guard let (aTopLength, aTopScore) = aLengths.array.first
        else { return nil }
    
    /// B is the sorted set of lengths for the Transport B traffic
    guard let (bTopLength, bTopScore) = bLengths.array.first
        else { return nil }
    
    return (aTopLength, Double(aTopScore), bTopLength, Double(bTopScore))
}

class PacketLengthsCoreML
{
    // TODO: Use Song Data and save to our global PacketLengths instance
    func processPacketLengths(forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
    {
        switch connection.connectionType
        {
        case .transportA:
            // Get the out packet that corresponds with this connection ID
            guard let outPacket = connectionGroupData.aConnectionData.outgoingPackets[connection.connectionID]
            else { return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID)) }
            
            // Get the in packet that corresponds with this connection ID
            guard let inPacket = connectionGroupData.aConnectionData.incomingPackets[connection.connectionID]
            else { return(false, PacketLengthError.noInPacketForConnection(connection.connectionID)) }
            
            /// Sanity Check
            if outPacket.count < 10 || inPacket.count < 10
            {
                print("\n### packet count = \(String(outPacket.count))")
                print("\n⁉️  We got a weird out packet size... \(String(describing: String(data: outPacket, encoding: .utf8)))<----")
            }
            
            // Add these packet lengths to our packetLengths
            // Adding an element increases the score if the element already exists
            packetLengths.outgoingA.add(element: outPacket.count)
            packetLengths.incomingA.add(element: inPacket.count)

        case .transportB:
            guard let outPacket = connectionGroupData.bConnectionData.outgoingPackets[connection.connectionID]
            else
            { return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID)) }
            
            guard let inPacket = connectionGroupData.bConnectionData.incomingPackets[connection.connectionID]
            else
            { return (false, PacketLengthError.noInPacketForConnection(connection.connectionID)) }
            
            /// Sanity Check
            if outPacket.count < 10 || inPacket.count < 10
            {
                print("\n### packet count = \(String(outPacket.count))")
                print("\n⁉️  We got a weird out packet size... \(String(describing: String(data: outPacket, encoding: .utf8)))<----")
            }
            
            packetLengths.outgoingB.add(element: outPacket.count)
            packetLengths.incomingB.add(element: inPacket.count)
        }
        
        return(true, nil)
    }
    
    /**
     Train a model for packet lengths
     
     - Parameter modelName: A String that will be used to save the resulting mlm file.
     */
    func scoreAllPacketLengths(configModel: ProcessingConfigurationModel)
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
            let classifierTable = createLengthClassifierTable(connectionDirection: connectionDirection)
            guard let lengthRecommender = LengthRecommender(connectionDirection: connectionDirection)
            else
            { return }
            
            trainModels(lengthsClassifierTable: classifierTable, lengthRecommender: lengthRecommender, connectionDirection: connectionDirection, modelName: configModel.modelName)
        }
        else
        {
            let aLengths: [Int]
            let bLengths: [Int]
            
            switch connectionDirection
            {
            case .outgoing:
                aLengths = packetLengths.outgoingA.values
                bLengths = packetLengths.outgoingB.values
            case .incoming:
                aLengths = packetLengths.incomingA.values
                bLengths = packetLengths.incomingB.values
            }
            
            guard bLengths.count > 0
            else
            {
                print("\nUnable to test lengths. The blocked lengths list is empty.")
                return
            }
            
            // TransportA
            testModel(lengths: aLengths,
                      connectionType: .transportA,
                      connectionDirection: connectionDirection,
                      configModel: configModel)
            
            // TransportB
            testModel(lengths: bLengths,
                      connectionType: .transportB,
                      connectionDirection: connectionDirection,
                      configModel: configModel)
        }
    }
    
    func testModel(lengths: [Int], connectionType: ClassificationLabel, connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
    {
        let classifierName: String
        let recommenderName: String
        
        switch connectionDirection
        {
        case .incoming:
            classifierName = inLengthClassifierName
            recommenderName = inLengthRecommenderName
        case .outgoing:
            classifierName = outLengthClassifierName
            recommenderName = outLengthRecommenderName
        }
        do
        {
            let classifierFeatureProvider = try MLArrayBatchProvider(dictionary: [ColumnLabel.length.rawValue: lengths])
            
            guard let tempDirURL = getAdversaryTempDirectory()
            else
            {
                print("\nFailed to test models. Unable to locate application document directory.")
                return
            }
            
            let temporaryDirURL = tempDirURL.appendingPathComponent("\(configModel.modelName)", isDirectory: true)
            let classifierFileURL = temporaryDirURL.appendingPathComponent(classifierName, isDirectory: false).appendingPathExtension(modelFileExtension)
                       
            let recommenderFileURL = temporaryDirURL.appendingPathComponent(recommenderName, isDirectory: false).appendingPathExtension(songFileExtension)
                        
            if FileManager.default.fileExists(atPath: recommenderFileURL.path)
            {
                let decoder = JSONDecoder()
                let recommenderData = try Data(contentsOf: recommenderFileURL)
                let result = try decoder.decode(LengthRecommender.self, from: recommenderData)
                
                // Save the test results
                switch connectionDirection
                {
                case .incoming:
                    switch connectionType
                    {
                    case .transportA:
                        packetLengths.incomingATestResults = TestResults(prediction: Double(result.transportALength), accuracy: nil)
                    case .transportB:
                        packetLengths.incomingBTestResults = TestResults(prediction: Double(result.transportALength), accuracy: nil)
                    }
                case .outgoing:
                    switch connectionType
                    {
                    case .transportA:
                        packetLengths.outgoingATestResults = TestResults(prediction: Double(result.transportALength), accuracy: nil)
                    case .transportB:
                        packetLengths.outgoingBTestResults = TestResults(prediction: Double(result.transportALength), accuracy: nil)
                    }
                }
            }
            else
            {
                print("\nFailed to find recommender file in the expected location: \(recommenderFileURL.path)")
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
                    
                    var accuracy = allowedBlockedCount/Double(featureCount)
                    // Round it to 3 decimal places
                    accuracy = (accuracy * 1000).rounded()/1000
                    // Show the accuracy as a percentage value
                    accuracy = accuracy * 100
                    
                    switch connectionDirection
                    {
                    case .incoming:
                        switch connectionType
                        {
                        case .transportA:
                            packetLengths.incomingATestResults?.accuracy = accuracy
                        case .transportB:
                            packetLengths.incomingBTestResults?.accuracy = accuracy
                        }
                    case .outgoing:
                        switch connectionType
                        {
                        case .transportA:
                            packetLengths.outgoingATestResults?.accuracy = accuracy
                        case .transportB:
                            packetLengths.outgoingBTestResults?.accuracy = accuracy
                        }
                    }
                }
            }
            else
            {
                print("\nFailed to find classifier file at the expected location: \(classifierFileURL.path)")
            }
        }
        catch let lengthRecommenderError
        {
            print("\n❗️ Error decoding length recommender: \(lengthRecommenderError)")
        }
    }
    
    func createLengthClassifierTable(connectionDirection: ConnectionDirection) -> MLDataTable
    {
        var expandedLengths = [Int]()
        var expandedClassificationLabels = [String]()
        
        let (lengths, scores, classificationLabels) = getLengthsAndClassificationsArrays(connectionDirection: connectionDirection)
        
        for (index, length) in lengths.enumerated()
        {
            // FIXME: Does this still need to be a double after switch to Abacus data?
            let score: Double = Double(scores[index])
            let classification = classificationLabels[index]
            let count = Int(score)
            
            for _ in 0 ..< count
            {
                expandedLengths.append(length)
                expandedClassificationLabels.append(classification)
            }
        }
        
        // Create the Lengths Table
        var lengthsTable = MLDataTable()
        let lengthsColumn = MLDataColumn(expandedLengths)
        let classyLabelColumn = MLDataColumn(expandedClassificationLabels)
        lengthsTable.addColumn(lengthsColumn, named: ColumnLabel.length.rawValue)
        lengthsTable.addColumn(classyLabelColumn, named: ColumnLabel.classification.rawValue)
        
        return lengthsTable
    }
    
    func trainModels(lengthsClassifierTable: MLDataTable, lengthRecommender: LengthRecommender, connectionDirection: ConnectionDirection, modelName: String)
    {
        let recommenderName: String
        let classifierName: String
        
        switch connectionDirection
        {
        case .incoming:
            recommenderName = inLengthRecommenderName
            classifierName = inLengthClassifierName
        case .outgoing:
            recommenderName = outLengthRecommenderName
            classifierName = outLengthClassifierName
        }
        
        // Set aside 30% of the model's data rows for evaluation, leaving the remaining 70% for training
        let (classifierEvaluationTable, classifierTrainingTable) = lengthsClassifierTable.randomSplit(by: 0.30)
        
        // Train the classifier
        do
        {
            let classifier = try MLClassifier(trainingData: classifierTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
                        
            // Training Accuracy
            let trainingError = classifier.trainingMetrics.classificationError
            var trainingAccuracy: Double? = nil
            if trainingError >= 0
            {
                trainingAccuracy = (1.0 - trainingError) * 100
            }
                            
            // Evaluation Accuracy
            let classifierEvaluation = classifier.evaluation(on: classifierEvaluationTable)
            let evaluationError = classifierEvaluation.classificationError
            var evaluationAccuracy: Double? = nil
            if evaluationError >= 0
            {
                evaluationAccuracy = (1.0 - evaluationError) * 100
            }

            // Validation Accuracy
            let validationError = classifier.validationMetrics.classificationError
            var validationAccuracy: Double? = nil
            
            // Sometimes we get a negative number, this is not valid for our purposes
            if validationError >= 0
            {
                validationAccuracy = (1.0 - validationError) * 100
            }
            
            // Save Length Recommendations
            switch connectionDirection
            {
            case .incoming:
                trainingData.incomingLengthsTrainingResults = TrainingResults(
                    predictionForA: Double(lengthRecommender.transportALength),
                    predictionForB: Double(lengthRecommender.transportBLength),
                    trainingAccuracy: trainingAccuracy,
                    validationAccuracy: validationAccuracy,
                    evaluationAccuracy: evaluationAccuracy)
            case .outgoing:
                trainingData.outgoingLengthsTrainingResults = TrainingResults(
                    predictionForA: Double(lengthRecommender.transportALength),
                    predictionForB: Double(lengthRecommender.transportBLength),
                    trainingAccuracy: trainingAccuracy,
                    validationAccuracy: validationAccuracy,
                    evaluationAccuracy: evaluationAccuracy)
            }

            // Save the models to a file
            FileController().saveModel(classifier: classifier, classifierMetadata: lengthsClassifierMetadata, classifierFileName: classifierName, recommender: lengthRecommender, recommenderFileName: recommenderName, groupName: modelName)
        }
        catch let error
        {
            print("\nError creating the classifier for lengths:\(error)")
        }
    }
    
    func scale(scores: [Double]) -> [Double]?
    {
        guard !scores.isEmpty, let max = scores.max()
        else {
            return nil
        }
        
        let scaleFactor = 5/max
        
        let scaled = scores.map
        { (score) -> Double in
            
            return score * scaleFactor
        }
        
        return scaled
    }
    
    func getLengthsAndClassificationsArrays(connectionDirection: ConnectionDirection) -> (lengths: [Int], scores: [Int], classifications: [String])
    {
        var lengths = [Int]()
        var scores = [Int]()
        var classificationLabels = [String]()

        switch connectionDirection
        {
        case .incoming:
            // Add transport A lengths
            lengths.append(contentsOf: packetLengths.incomingA.values)
            scores.append(contentsOf: packetLengths.incomingA.counts)
            for _ in packetLengths.incomingA.values
            {
                classificationLabels.append(ClassificationLabel.transportA.rawValue)
            }
            
            // Add transport B lengths
            lengths.append(contentsOf: packetLengths.incomingB.values)
            scores.append(contentsOf: packetLengths.incomingB.counts)
            for _ in packetLengths.incomingB.values
            {
                classificationLabels.append(ClassificationLabel.transportB.rawValue)
            }
        case .outgoing:
            // Add transport A lengths
            lengths.append(contentsOf: packetLengths.outgoingA.values)
            scores.append(contentsOf: packetLengths.outgoingA.counts)
            for _ in packetLengths.outgoingA.values
            {
                classificationLabels.append(ClassificationLabel.transportA.rawValue)
            }
            
            // Add transport B lengths
            lengths.append(contentsOf: packetLengths.outgoingB.values)
            scores.append(contentsOf: packetLengths.outgoingB.counts)
            for _ in packetLengths.outgoingB.values
            {
                classificationLabels.append(ClassificationLabel.transportB.rawValue)
            }
        }
        
        return(lengths, scores, classificationLabels)
    }
    
}
