//
//  TestResults.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 9/4/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation

struct TestResults: Codable
{
    var prediction: Double
    var accuracy: Double?
    
    init(prediction: Double, accuracy: Double?)
    {
        self.prediction = prediction
        self.accuracy = accuracy
    }
}
