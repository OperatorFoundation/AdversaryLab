//
//  AdversaryLabSwiftPackageTests.swift
//  AdversaryLabSwiftPackageTests
//
//  Created by Adelita Schule on 1/15/18.
//

import XCTest
import Auburn
import RedShot

class AdversaryLabSwiftPackageTests: XCTestCase
{
    let allowedConnectionID = "5678"
    let blockedConnectionID = "1234"
    
    let allowedIncomingKey = "Allowed:Incoming:Packets"
    let allowedOutgoingKey = "Allowed:Outgoing:Packets"
    let blockedIncomingKey = "Blocked:Incoming:Packets"
    let blockedOutgoingKey = "Blocked:Outgoing:Packets"
    let blockedConnectionsKey = "Blocked:Connections"
    let allowedConnectionsKey = "Allowed:Connections"
    
    let allowedChannel = "AllowedConnections"
    let blockedChannel = "BlockedConnections"
    
    
    let packetData = Data(count: 576)
    func testExample()
    {
        let testList: RList<String> = ["AA", "AB", "AC"]
        testList.key = "unitTestListKey"
        
        let fetchedList: RList<String> = RList(key: "unitTestListKey")
        for x in 0...2 {
            XCTAssertEqual(testList[x], fetchedList[x])
        }
        
        testList.delete()
    }
    
    func testRedisInput()
    {
        let packetString = String(bytes: packetData, encoding: .utf8)!
        
        let allowedIncomingPackets: RMap<String, String> = [allowedConnectionID: packetString]
        allowedIncomingPackets.key = allowedIncomingKey
        
        let fetchedAIP: RMap<String, String> = RMap(key: allowedIncomingKey)
        XCTAssertNotNil(fetchedAIP[allowedConnectionID])
        
        let allowedOutgoingPackets: RMap<String, String> = [allowedConnectionID: packetString]
        allowedOutgoingPackets.key = allowedOutgoingKey
        
        let fetchedAOP: RMap <String, String> = RMap(key: allowedOutgoingKey)
        
        XCTAssertNotNil(fetchedAOP)
        
        let blockedIncomingPackets: RMap<String, String> = [blockedConnectionID: packetString]
        blockedIncomingPackets.key = blockedIncomingKey
        let fetchedBIP: RMap<String, String> = RMap(key: blockedIncomingKey)
        XCTAssertNotNil(fetchedBIP)
        
        let blockedOutgoingPackets: RMap<String, String> = [blockedConnectionID: packetString]
        blockedOutgoingPackets.key = blockedOutgoingKey
        let fetchedBOP: RMap<String, String> = RMap(key: blockedOutgoingKey)
        XCTAssertNotNil(fetchedBOP)
        
        let blockedConnections: RList<String> = [blockedConnectionID]
        blockedConnections.key = blockedConnectionsKey
        let fetchedBC: RList<String> = RList(key: blockedConnectionsKey)
        XCTAssertNotNil(fetchedBC)
        
        let allowedConnections: RList<String> = [allowedConnectionID]
        allowedConnections.key = allowedConnectionsKey
        let fetchedAC: RList<String> = RList(key: allowedConnectionsKey)
    }
    
    func testFetch()
    {
        let fetchedAllowedIncomingPackets: RMap<String, String> = RMap(key: allowedIncomingKey)
        print("Fetched Allowed Incoming Packets")
        print(fetchedAllowedIncomingPackets[allowedConnectionID].debugDescription)
    }
    
    func testPacketStuff()
    {
        let outPacketData = Data(count: 576)
        let outPacketString = String(bytes: outPacketData, encoding: .utf8)!
        let outPacket: RString = RString(outPacketString)
        outPacket.key = "OutPacket"
        
        outPacket.delete()
    }
    
}
