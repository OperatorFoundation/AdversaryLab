//
//  TrainingResults.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 9/4/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation

struct TrainingResults: Codable
{
    var transportAPrediction: Double
    var transportBPrediction: Double
    var trainingAccuracy: Double?
    var validationAccuracy: Double?
    var evaluationAccuracy: Double?
    
    init(predictionForA: Double, predictionForB: Double)
    {
        self.init(predictionForA: predictionForA, predictionForB: predictionForB, trainingAccuracy: nil, validationAccuracy: nil, evaluationAccuracy: nil)
    }
    
    init(predictionForA: Double, predictionForB: Double, trainingAccuracy: Double?, validationAccuracy: Double?, evaluationAccuracy: Double?)
    {
        self.transportAPrediction = predictionForA
        self.transportBPrediction = predictionForB
        self.trainingAccuracy = trainingAccuracy
        self.validationAccuracy = validationAccuracy
        self.evaluationAccuracy = evaluationAccuracy
    }
    
    
}
