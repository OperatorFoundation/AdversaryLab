//
//  PacketTimings.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 8/18/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation

import Abacus

struct PacketTimings: Codable
{
    var transportA: [Double] = []
    var transportATestResults: TestResults?
    var transportB: [Double] = []
    var transportBTestResults: TestResults?
    
}
