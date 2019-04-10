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
    
    func testURLBrowse()
    {
        goTo(urlPath: "https://slashdot.org")
        goTo(urlPath: "https://github.com")
        goTo(urlPath: "https://www.clcboats.com")
        goTo(urlPath: "https://imgur.com")
        goTo(urlPath: "https://www.cooksillustrated.com")
        goTo(urlPath: "https://www.npr.org")
        goTo(urlPath: "https://store.dftba.com")
        goTo(urlPath: "https://www.livescience.com/countdowns")
    }
    
    func testCreateEntropyTable()
    {
        let entropyML = EntropyCoreML()
        let filePath = "/Users/mafalda/Documents/Operator/AdversaryLab/AdversaryLabSwift/exampleData.csv"
        let fileURL = URL(fileURLWithPath: filePath)
        
        guard let (inEntropyTable, outEntropyTable) = entropyML.createEntropyTable(fromFile: fileURL)
            else
        {
                XCTFail()
                return
        }
        
        print("\nIncoming Entropy Table: \(inEntropyTable)")
        print("\nOutgoing Entropy Table: \(outEntropyTable)")
    }
    
    func goTo(urlPath: String)
    {
        print("\nRequesting \(urlPath)")
        testQueue.async
        {
            let url = URL(string: urlPath)!
            let task = URLSession.shared.dataTask(with: url)
            { (maybeData, maybeResponse, maybeError) in
//                print("\nTouched \(urlPath)")
//                print("Response - \(String(describing: maybeResponse))\n")
            }
            task.resume()
        }
    }

}
