//
//  TrainingData.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 9/22/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation

struct TrainingData: Codable
{
    var outgoingEntropyTrainingResults: TrainingResults?
    var incomingEntropyTrainingResults: TrainingResults?
    
    var outgoingLengthsTrainingResults: TrainingResults?
    var incomingLengthsTrainingResults: TrainingResults?
    
    var timingTrainingResults: TrainingResults?
}
