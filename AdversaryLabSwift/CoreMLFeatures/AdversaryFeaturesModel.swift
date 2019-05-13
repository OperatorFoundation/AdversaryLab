//
//  AdversaryFeaturesModel.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 5/11/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import CreateML

class AdversaryFeaturesModel: NSObject
{
    let groupName: String
    
    let entropyClassifier: MLClassifier
    let entropyRegressor: MLRegressor
    let timingClassifier: MLClassifier
    let timingRegressor: MLRegressor
    let packetLengthClassifier: MLClassifier
    let packetLengthRegressor: MLRegressor
    let tlsClassifier: MLClassifier?
    let tlsRegressor: MLRegressor?
    
    init(groupName: String,
         entropyClassifier: MLClassifier,
         entropyRegressor: MLRegressor,
         timingClassifier: MLClassifier,
         timingRegressor: MLRegressor,
         packetLengthClassifier: MLClassifier,
         packetLengthRegressor: MLRegressor,
         tlsClassifier: MLClassifier?,
         tlsRegressor: MLRegressor?)
    {
        self.groupName = groupName
        self.entropyClassifier = entropyClassifier
        self.entropyRegressor = entropyRegressor
        self.timingClassifier = timingClassifier
        self.timingRegressor = timingRegressor
        self.packetLengthClassifier = packetLengthClassifier
        self.packetLengthRegressor = packetLengthRegressor
        self.tlsClassifier = tlsClassifier
        self.tlsRegressor = tlsRegressor
    }
}
