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
    var outgoingEntropyTrainingResults: NumericTrainingResults?
    var incomingEntropyTrainingResults: NumericTrainingResults?
    
    var outgoingLengthsTrainingResults: NumericTrainingResults?
    var incomingLengthsTrainingResults: NumericTrainingResults?
    
    var outgoingFloatSequencesTrainingResults: FloatSequenceTrainingResults?
    var incomingFloatSequencesTrainingResults: FloatSequenceTrainingResults?
    
    var timingTrainingResults: NumericTrainingResults?
}
