//
//  SequencesCoreML.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 7/2/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import CreateML
import Auburn

class SequencesCoreML
{
    func createOffsetTable(connectionDirection: ConnectionDirection) -> MLDataTable
    {
        var offsetTable = MLDataTable()
        let allowedTable = createTable(forConnectionType: .allowed, andDirection: connectionDirection)
        let blockedTable = createTable(forConnectionType: .blocked, andDirection: connectionDirection)
        
        offsetTable.append(contentsOf: allowedTable)
        offsetTable.append(contentsOf: blockedTable)
        
        return offsetTable
    }
    
    func createTable(forConnectionType connectionType: ClassificationLabel, andDirection connectionDirection: ConnectionDirection) -> MLDataTable
    {
        let connectionsList: RList<String>
        let packetsMap: RMap<String, Data>
        let trainingSequences: RList<Data>
        let trainingSequenceOffsets: RList<Int>
        var dataTable = MLDataTable()
        
        switch connectionDirection
        {
        case .incoming:
            trainingSequences = RList(key: incomingOffsetTrainingSequencesKey)
            trainingSequenceOffsets = RList(key: incomingOffsetTrainingSequenceOffsetsKey)
        case .outgoing:
            trainingSequences = RList(key: outgoingOffsetTrainingSequencesKey)
            trainingSequenceOffsets = RList(key: outgoingOffsetTrainingSequenceOffsetsKey)
        }
        
        switch connectionType
        {
        case .allowed:
            connectionsList = RList(key: allowedConnectionsKey)
            switch connectionDirection
            {
            case .incoming:
                packetsMap = RMap(key: allowedIncomingKey)
            case .outgoing:
                packetsMap = RMap(key: allowedOutgoingKey)
            }
        case .blocked:
            connectionsList = RList(key: blockedConnectionsKey)
            switch connectionDirection
            {
            case .incoming:
                packetsMap = RMap(key: blockedIncomingKey)
            case .outgoing:
                packetsMap = RMap(key: blockedOutgoingKey)
            }
        }
        
        for connectionID in connectionsList
        {
            guard let packet = packetsMap[connectionID] else { continue }
            
            var rowTable = MLDataTable()
            let classyColumn = MLDataColumn([connectionType.rawValue])
            rowTable.addColumn(classyColumn, named: ColumnLabel.classification.rawValue)
            
            for index in 0 ..< trainingSequences.count
            {
                guard let offset = trainingSequenceOffsets[index] else { continue }
                guard let trainingSequence = trainingSequences[index] else { continue }
                guard packet.count >= offset + trainingSequence.count else { continue }
                let subsequence = packet[offset..<offset + trainingSequence.count]
                let sequenceColumn: MLDataColumn<Int>
                
                if subsequence == trainingSequence
                {
                    sequenceColumn = MLDataColumn([1])
                }
                else
                {
                    sequenceColumn = MLDataColumn([0])
                }
                
                rowTable.addColumn(sequenceColumn, named: "sequence\(index)")
            }
            
            dataTable.append(contentsOf: rowTable)
        }
        
        return dataTable
    }
    
    
    func trainOffsetModels(connectionDirection: ConnectionDirection, modelName: String)
    {
        let sequencesTAccKey: String
        let sequencesVAccKey: String
        let sequencesEAccKey: String
        let classifierName: String
        let offsetSequenceTable = createOffsetTable(connectionDirection: connectionDirection)
        
        switch connectionDirection
        {
        case .incoming:
            sequencesTAccKey = incomingOffsetSequencesTAccKey
            sequencesVAccKey = incomingOffsetSequencesVAccKey
            sequencesEAccKey = incomingOffsetSequencesEAccKey
            classifierName = inOffsetClassifierName
        case .outgoing:
            sequencesTAccKey = outgoingOffsetSequencesTAccKey
            sequencesVAccKey = outgoingOffsetSequencesVAccKey
            sequencesEAccKey = outgoingOffsetSequencesEAccKey
            classifierName = outOffsetClassifierName
        }
        
        // Set aside 20% of the model's data rows for evaluation, leaving the remaining 80% for training
        let (offsetEvaluationTable, offsetTrainingTable) = offsetSequenceTable.randomSplit(by: 0.20)
        
        // Train the classifier
        do
        {
            let classifier = try MLClassifier(trainingData: offsetTrainingTable, targetColumn: ColumnLabel.classification.rawValue)
            let trainingAccuracy = (1.0 - classifier.trainingMetrics.classificationError) * 100
            let classifierEvaluation = classifier.evaluation(on: offsetEvaluationTable)
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
            
            // Save Scores
            let offsetDictionary: RMap<String, Double> = RMap(key: offsetSequencesTrainingResultsKey)
            offsetDictionary[sequencesTAccKey] = trainingAccuracy
            offsetDictionary[sequencesEAccKey] = evaluationAccuracy
            
            if validationAccuracy != nil
            {
                offsetDictionary[sequencesVAccKey] = validationAccuracy!
            }
            
            // Save the models to a file
            MLModelController().save(classifier: classifier, classifierMetadata: offsetClassifierMetadata, fileName: classifierName, groupName: modelName)
        }
        catch let error
        {
            print("\nError creating the classifier for lengths:\(error)")
        }
    }
}
