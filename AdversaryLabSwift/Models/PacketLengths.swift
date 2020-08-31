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
    var incomingA: SortedMultiset<Int> = SortedMultiset(sortingStyle: .highFirst)
    var outgoingA: SortedMultiset<Int> = SortedMultiset(sortingStyle: .highFirst)

    var incomingB: SortedMultiset<Int> = SortedMultiset(sortingStyle: .highFirst)
    var outgoingB: SortedMultiset<Int> = SortedMultiset(sortingStyle: .highFirst)
}
