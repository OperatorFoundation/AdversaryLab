//
//  PacketLengths.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 8/4/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation

import Abacus

struct PacketLengths
{
    var incomingA: SortedMultiset<Int> = SortedMultiset(sortingStyle: .highFirst)
    var incomingATestResults: TestResults?
    var incomingB: SortedMultiset<Int> = SortedMultiset(sortingStyle: .highFirst)
    var incomingBTestResults: TestResults?
    
    var outgoingA: SortedMultiset<Int> = SortedMultiset(sortingStyle: .highFirst)
    var outgoingATestResults: TestResults?
    var outgoingB: SortedMultiset<Int> = SortedMultiset(sortingStyle: .highFirst)
    var outgoingBTestResults: TestResults?
}
