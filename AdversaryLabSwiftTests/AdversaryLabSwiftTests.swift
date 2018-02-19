//
//  AdversaryLabSwiftTests.swift
//  AdversaryLabSwiftTests
//
//  Created by Adelita Schule on 1/11/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import XCTest

@testable import AdversaryLabSwift

class AdversaryLabSwiftTests: XCTestCase
{
    let connectionGenerator = FakeConnectionGenerator()
    
    func testAddAllowedPackets()
    {
        connectionGenerator.addAllowedPackets()
    }
    
    func testAddblockedPackets()
    {
        connectionGenerator.addblockedPackets()
    }

}
