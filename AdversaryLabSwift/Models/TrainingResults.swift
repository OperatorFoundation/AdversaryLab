//
//  TrainingResults.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 9/4/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation

import Abacus

class TrainingResults
{
    var trainingAccuracy: Double?
    var validationAccuracy: Double?
    var evaluationAccuracy: Double?
    
    init() {
    }
}

class NumericTrainingResults: TrainingResults, Codable
{
    var transportAPrediction: Double
    var transportBPrediction: Double
    
    convenience init(predictionForA: Double, predictionForB: Double)
    {
        self.init(predictionForA: predictionForA, predictionForB: predictionForB, trainingAccuracy: nil, validationAccuracy: nil, evaluationAccuracy: nil)
    }
    
    init(predictionForA: Double, predictionForB: Double, trainingAccuracy: Double?, validationAccuracy: Double?, evaluationAccuracy: Double?)
    {
        self.transportAPrediction = predictionForA
        self.transportBPrediction = predictionForB
        
        
        super.init()
        self.trainingAccuracy = trainingAccuracy
        self.validationAccuracy = validationAccuracy
        self.evaluationAccuracy = evaluationAccuracy
    }
}

class FloatSequenceTrainingResults: TrainingResults, Codable
{
    var transportAPrediction: [Data]
    var transportBPrediction: [Data]
    
    convenience init(predictionForA: [Data], predictionForB: [Data])
    {
        self.init(predictionForA: predictionForA, predictionForB: predictionForB, trainingAccuracy: nil, validationAccuracy: nil, evaluationAccuracy: nil)
    }
    
    init(predictionForA: [Data], predictionForB: [Data], trainingAccuracy: Double?, validationAccuracy: Double?, evaluationAccuracy: Double?)
    {
        self.transportAPrediction = predictionForA
        self.transportBPrediction = predictionForB
        
        super.init()
        self.trainingAccuracy = trainingAccuracy
        self.validationAccuracy = validationAccuracy
        self.evaluationAccuracy = evaluationAccuracy
    }
}

class OffsetSequenceTrainingResults: TrainingResults, Codable
{
    var transportAPrediction: [OffsetSequence]
    var transportBPrediction: [OffsetSequence]

    convenience init(predictionForA: [OffsetSequence], predictionForB: [OffsetSequence])
    {
        self.init(predictionForA: predictionForA, predictionForB: predictionForB, trainingAccuracy: nil, validationAccuracy: nil, evaluationAccuracy: nil)
    }
    
    init(predictionForA: [OffsetSequence], predictionForB: [OffsetSequence], trainingAccuracy: Double?, validationAccuracy: Double?, evaluationAccuracy: Double?)
    {
        self.transportAPrediction = predictionForA
        self.transportBPrediction = predictionForB
        
        super.init()
        self.trainingAccuracy = trainingAccuracy
        self.validationAccuracy = validationAccuracy
        self.evaluationAccuracy = evaluationAccuracy
    }
}
