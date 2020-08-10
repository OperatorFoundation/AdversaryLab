//
//  PacketLengths.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 8/4/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation
import Abacus

class PacketLengths
{
    var incomingA: SortedMultiset<Int>
    var outgoingA: SortedMultiset<Int>

    var incomingB: SortedMultiset<Int>
    var outgoingB: SortedMultiset<Int>
    
    init(transportAIncoming: SortedMultiset<Int>,
         transportAOutgoing: SortedMultiset<Int>,
         transportBIncoming: SortedMultiset<Int>,
         transportBOutgoing: SortedMultiset<Int>)
    {
        incomingA = transportAIncoming
        outgoingA = transportAOutgoing
        incomingB = transportBIncoming
        outgoingB = transportBOutgoing
    }
}
