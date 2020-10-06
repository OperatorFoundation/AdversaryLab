//
//  PacketEntropies.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 8/18/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation

import Abacus

struct PacketEntropies: Codable
{
    var incomingA: [Double] = []
    var incomingATestResults: TestResults?
    var incomingB: [Double] = []
    var incomingBTestResults: TestResults?
    
    var outgoingA: [Double] = []
    var outgoingATestResults: TestResults?
    var outgoingB: [Double] = []
    var outgoingBTestResults: TestResults?
    
}
