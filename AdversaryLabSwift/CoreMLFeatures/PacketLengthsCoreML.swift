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
//import Song

struct LengthRecommender: Codable {
    let allowedLength: Int
    let allowedScore: Double
    let blockedLength: Int
    let blockedScore: Double
}

extension LengthRecommender {
    
    /// Assuming that these arrays are parallel
    init?(connectionDirection: ConnectionDirection)
    {
        guard let (aLength, aScore, bLength, bScore) = getHighestScoredLength(forConnectionDirection: connectionDirection)
        else {
            return nil
        }
        
        self.allowedLength = aLength
        self.allowedScore = aScore
        self.blockedLength = bLength
        self.blockedScore = bScore
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
    guard let (allowedLength, allowedScore) = allowedLengthsRSet.first
        else {
            return nil
    }
    
    /// B is the sorted set of lengths for the Blocked traffic
    let blockedLengthsRSet: RSortedSet<Int> = RSortedSet(key: blockedLengthsKey)
    guard let (blockedLength, blockedScore) = blockedLengthsRSet.first
        else {
            return nil
    }
    
    return (allowedLength, Double(allowedScore), blockedLength, Double(blockedScore))
}

class PacketLengthsCoreML
{
    // TODO: Use Song Data and save to our global PacketLengths instance
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
        
        // Increment the score of this particular outgoing packet length
    
        // FIXME: Testing Song via global var packetLengths
        switch connection.connectionType
        {
        case .transportA:
            packetLengths.outgoingA.add(element: outPacket.count)
        case .transportB:
            packetLengths.outgoingB.add(element: outPacket.count)
        }
        
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
        
        // Increment the score of this particular incoming packet length
        // FIXME: Testing Song via global var packetLengths
        switch connection.connectionType
        {
        case .transportA:
            packetLengths.incomingA.add(element: inPacket.count)
        case .transportB:
            packetLengths.incomingB.add(element: inPacket.count)
        }
        
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
            let (allowedLengths, _, blockedLengths, _) = getLengthsAndScores(forConnectionDirection: connectionDirection)
            
            guard blockedLengths.count > 0
            else
            {
                print("\nUnable to test lengths. The blocked lengths list is empty.")
                return
            }
            
            // Allowed
            testModel(lengths: allowedLengths,
                      connectionType: .transportA,
                      connectionDirection: connectionDirection,
                      configModel: configModel)
            
            // Blocked
            testModel(lengths: blockedLengths,
                      connectionType: .transportB,
                      connectionDirection: connectionDirection,
                      configModel: configModel)
        }
    }
    
    func testModel(lengths: [Int], connectionType: ClassificationLabel, connectionDirection: ConnectionDirection, configModel: ProcessingConfigurationModel)
    {
        let classifierName: String
        let recommenderName: String
        let accuracyKey: String
        let lengthKey: String
        
        switch connectionDirection
        {
        case .incoming:
            classifierName = inLengthClassifierName
            recommenderName = inLengthRecommenderName
            switch connectionType
            {
            case .transportA:
                accuracyKey = allowedIncomingLengthAccuracyKey
                lengthKey = allowedIncomingLengthKey
            case .transportB:
                accuracyKey = blockedIncomingLengthAccuracyKey
                lengthKey = blockedIncomingLengthKey
            }
        case .outgoing:
            classifierName = outLengthClassifierName
            recommenderName = outLengthRecommenderName
            switch connectionType
            {
            case .transportA:
                accuracyKey = allowedOutgoingLengthAccuracyKey
                lengthKey = allowedOutgoingLengthKey
            case .transportB:
                accuracyKey = blockedOutgoingLengthAccuracyKey
                lengthKey = blockedOutgoingLengthKey
            }
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
            
            // This is the dictionary where we will save our results
            let lengthDictionary: RMap<String,Double> = RMap(key: testResultsKey)
            
            // TODO: MLRecommender
            if FileManager.default.fileExists(atPath: recommenderFileURL.path)
            {
                let decoder = JSONDecoder()
                let recommenderData = try Data(contentsOf: recommenderFileURL)
                let result = try decoder.decode(LengthRecommender.self, from: recommenderData)
//                let decoder = SongDecoder()
//                let recommenderData = try Data(contentsOf: recommenderFileURL)
//                let result = try decoder.decode(LengthRecommender.self, from: recommenderData)
                print("🔮 Length prediction for \(lengthKey): \(result).")
                
                switch connectionType
                {
                case .transportA:
                    lengthDictionary[lengthKey] = Double(result.allowedLength)
                case .transportB:
                    lengthDictionary[lengthKey] = Double(result.blockedLength)
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
                    print("\n🔮 Length prediction: \(accuracy) \(connectionType.rawValue).")
                    
                    lengthDictionary[accuracyKey] = accuracy
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
        let requiredLengthKey: String
        let forbiddenLengthKey: String
        let lengthsTAccKey: String
        let lengthsVAccKey: String
        let lengthsEAccKey: String
        let recommenderName: String
        let classifierName: String
        
        switch connectionDirection
        {
        case .incoming:
            requiredLengthKey = incomingRequiredLengthKey
            forbiddenLengthKey = incomingForbiddenLengthKey
            lengthsTAccKey = incomingLengthsTAccKey
            lengthsVAccKey = incomingLengthsVAccKey
            lengthsEAccKey = incomingLengthsEAccKey
            recommenderName = inLengthRecommenderName
            classifierName = inLengthClassifierName
        case .outgoing:
            requiredLengthKey = outgoingRequiredLengthKey
            forbiddenLengthKey = outgoingForbiddenLengthKey
            lengthsTAccKey = outgoingLengthsTAccKey
            lengthsVAccKey = outgoingLengthsVAccKey
            lengthsEAccKey = outgoingLengthsEAccKey
            recommenderName = outLengthRecommenderName
            classifierName = outLengthClassifierName
        }
        
        // Set aside 30% of the model's data rows for evaluation, leaving the remaining 70% for training
        let (classifierEvaluationTable, classifierTrainingTable) = lengthsClassifierTable.randomSplit(by: 0.30)
        
        // Train the classifier
        do
        {
            let classifier = try MLClassifier(trainingData: classifierTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
            // Save Length Recommendations
            let lengthsDictionary: RMap<String, Double> = RMap(key: packetLengthsTrainingResultsKey)
            lengthsDictionary[requiredLengthKey] = Double(lengthRecommender.allowedLength)
            lengthsDictionary[forbiddenLengthKey] = Double(lengthRecommender.blockedLength)
            
            // Training Accuracy
            let trainingError = classifier.trainingMetrics.classificationError
            var trainingAccuracy: Double? = nil
            if trainingError >= 0
            {
                trainingAccuracy = (1.0 - trainingError) * 100
            }
                
            lengthsDictionary[lengthsTAccKey] = trainingAccuracy
            
            // Evaluation Accuracy
            let classifierEvaluation = classifier.evaluation(on: classifierEvaluationTable)
            let evaluationError = classifierEvaluation.classificationError
            var evaluationAccuracy: Double? = nil
            if evaluationError >= 0
            {
                evaluationAccuracy = (1.0 - classifierEvaluation.classificationError) * 100
            }
            
            if evaluationAccuracy != nil
            {
                lengthsDictionary[lengthsEAccKey] = evaluationAccuracy
            }

            // Validation Accuracy
            let validationError = classifier.validationMetrics.classificationError
            var validationAccuracy: Double? = nil
            
            // Sometimes we get a negative number, this is not valid for our purposes
            if validationError >= 0
            {
                validationAccuracy = (1.0 - validationError) * 100
            }
            
            if validationAccuracy != nil
            {
                lengthsDictionary[lengthsVAccKey] = validationAccuracy!
            }

            // Save the models to a file
            MLModelController().saveModel(classifier: classifier, classifierMetadata: lengthsClassifierMetadata, classifierFileName: classifierName, recommender: lengthRecommender, recommenderFileName: recommenderName, groupName: modelName)
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
    
    func getLengthsAndScores(forConnectionDirection connectionDirection: ConnectionDirection) -> (allowedLengths:[Int], allowedLengthScores:[Double], blockedLengths: [Int], blockedLengthScores: [Double])
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
        let (allowedLengthsArray, allowedScoresArray) = arrays(from: [allowedLengthsRSet])
        
        /// B is the sorted set of lengths for the Blocked traffic
        let blockedLengthsRSet: RSortedSet<Int> = RSortedSet(key: blockedLengthsKey)
        let (blockedLengthsArray, blockedScoresArray) = arrays(from: [blockedLengthsRSet])
        
        return (allowedLengthsArray, allowedScoresArray, blockedLengthsArray, blockedScoresArray)
    }
    
    // TODO: Rewrite this so that it gets the data from our global PacketLengths instance
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
        
//        let allowedLengthsKey: String
//        let blockedLengthsKey: String
//
//        switch connectionDirection
//        {
//        case .incoming:
//            allowedLengthsKey = allowedIncomingLengthKey
//            blockedLengthsKey = blockedIncomingLengthKey
//        case .outgoing:
//            allowedLengthsKey = allowedOutgoingLengthKey
//            blockedLengthsKey = blockedOutgoingLengthKey
//        }
//
//        /// A is the sorted set of lengths for the Allowed traffic
//        let allowedLengthsRSet: RSortedSet<Int> = RSortedSet(key: allowedLengthsKey)
//        let (allowedLengthsArray, allowedLengthScores) = arrays(from: [allowedLengthsRSet])
//
//        /// B is the sorted set of lengths for the Blocked traffic
//        let blockedLengthsRSet: RSortedSet<Int> = RSortedSet(key: blockedLengthsKey)
//        let (blockedLengthsArray, blockedLengthsScores) = arrays(from: [blockedLengthsRSet])
//
//        lengths.append(contentsOf: allowedLengthsArray)
//        scores.append(contentsOf: allowedLengthScores)
//        for _ in allowedLengthsArray
//        {
//            classificationLabels.append(ClassificationLabel.transportA.rawValue)
//        }
//
//        lengths.append(contentsOf: blockedLengthsArray)
//        scores.append(contentsOf: blockedLengthsScores)
//        for _ in blockedLengthsArray
//        {
//            classificationLabels.append(ClassificationLabel.transportB.rawValue)
//        }
        
        return(lengths, scores, classificationLabels)
    }
    
}

/// Returns one array containing each element in all of the sorted sets provided. This method takes an array of sorted sets of Ints and returns an array of Ints. Values are not repeated based on score. Each value will be added to the array only one time
/// - Parameters:
///     - redisSets: [RSortedSet<Int>], an array of sorted sets to turn in to one array of Ints.
/// - Returns: [Int], an array of Ints.
func arrays(from redisSets:[RSortedSet<Int>]) -> (values: [Int], scores: [Double])
{
    var valueArray = [Int]()
    var scoreArray = [Double]()
    
    for set in redisSets
    {
        if set.count == 1
        {
            if let newMember: Int = set[0], let score: Float = set.getScore(for: newMember)
            {
                valueArray.append(newMember)
                scoreArray.append(Double(score))
                
                // Add the one value to the arrays twice because MLCreate requires more than one
                scoreArray.append(Double(score))
                valueArray.append(newMember)
            }
        }
        
        for i in 0 ..< set.count
        {
            if let newMember: Int = set[i], let score: Float = set.getScore(for: newMember)
            {
                valueArray.append(newMember)
                scoreArray.append(Double(score))
            }
        }
    }
    
    return (valueArray, scoreArray)
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



