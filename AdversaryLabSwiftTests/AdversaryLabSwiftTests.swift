//
//  AdversaryLabSwiftTests.swift
//  AdversaryLabSwiftTests
//
//  Created by Adelita Schule on 1/11/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import XCTest
import Auburn
import RedShot
import Datable


@testable import AdversaryLabSwift

class AdversaryLabSwiftTests: XCTestCase
{
    let packetStatsKey = "Packet:Stats"
    
    let allowedChannel = "Allowed:Connections:Channel"
    let allowedConnectionsKey = "Allowed:Connections"
    let allowedIncomingKey = "Allowed:Incoming:Packets"
    let allowedOutgoingKey = "Allowed:Outgoing:Packets"
    let allowedIncomingLengthsKey = "Allowed:Incoming:Lengths"
    let allowedOutgoingLengthsKey = "Allowed:Outgoing:Lengths"
    let allowedPacketsSeenKey = "Allowed:Packets:Seen"
    let allowedPacketsAnalyzedKey = "Allowed:Packets:Analyzed"
    
    let blockedChannel = "Blocked:Connections:Channel"
    let blockedConnectionsKey = "Blocked:Connections"
    let blockedIncomingKey = "Blocked:Incoming:Packets"
    let blockedOutgoingKey = "Blocked:Outgoing:Packets"
    let blockedIncomingLengthsKey = "Blocked:Incoming:Lengths"
    let blockedOutgoingLengthsKey = "Blocked:Outgoing:Lengths"
    let blockedPacketsSeenKey = "Blocked:Packets:Seen"
    let blockedPacketsAnalyzedKey = "Blocked:Packets:Analyzed"
    let newAllowedConnectionMessage = "NewAllowedConnectionAdded"
    let newBlockedConnectionMessage = "NewBlockedConnectionAdded"
    
    let addPacketsQueue = DispatchQueue(label: "AnalysisQueue")
    var connectionID = 0
    
    func createFakePacket(minSize: UInt32, maxSize: UInt32) -> Data
    {
        let packetSize = Int(arc4random_uniform(1 + maxSize - minSize) + minSize)
        return Data(count: packetSize)
    }
    
    func testAddAllowedPackets()
    {
        let minSize: UInt32 = 200
        let maxSize: UInt32 = 500
        let allowedConnections: RList<String> = RList(key: allowedConnectionsKey)
        
        guard let redis = try? Redis(hostname: "localhost", port: 6379)
            else
        {
            return
        }
        addPacketsQueue.sync
            {
                for _ in 1...73
                {
                    self.connectionID += 1
                    print("\n----------> Adding packets for connection ID \(self.connectionID) <----------")
                    let connectionIDString = String(self.connectionID)
                    
                    // Adding a fake incoming packet
                    let inPacket = self.createFakePacket(minSize: minSize, maxSize: maxSize)
                    let inMap: RMap<String, Data> = RMap(key: allowedIncomingKey)
                    inMap[connectionIDString] = inPacket
                    print("📥  In Packet for \(connectionIDString) added.")
                    
                    // Adding a fake outgoing packet
                    let outPacket = self.createFakePacket(minSize: minSize, maxSize: maxSize)
                    let outMap: RMap<String, Data> = RMap(key: allowedOutgoingKey)
                    outMap[connectionIDString] = outPacket
                    print("📤  Out packet for \(connectionIDString) added.")
                    
                    // Both packets have been added, update the list of connections to process.
                    print("Appending Connection ID \(connectionIDString) to the allowed connections list.\n🎈 🎈 🎈 🎈 🎈")
                    allowedConnections.append(connectionIDString)
                    
                    // Publish: A new allowed connection is ready to be analyzed.
                    do
                    {
                        let numberOfSubscribers = try redis.publish(channel: allowedChannel, message: self.newAllowedConnectionMessage)
                        print("\(numberOfSubscribers as! Int) subscriber(s)")
                    }
                    catch
                    {
                        print(error)
                    }
                    
                    // Increment the allowed packets seen field.
                    let packetStatsDictionary: RMap<String, Int> = RMap(key: packetStatsKey)
                    
                    if let allowedPacketsSeenValue = packetStatsDictionary.increment(field: allowedPacketsSeenKey), allowedPacketsSeenValue > 0
                    {
                        //                        DispatchQueue.main.async {
                        //                            self.allowedPacketsSeen = "\(allowedPacketsSeenValue)"
                        //                        }
                    }
                }
        }
        print("FINISHED TEST LOOP")
    }
    
    func testAddblockedPackets()
    {
        let minSize: UInt32 = 400
        let maxSize: UInt32 = 700
        
        //TODO: This should be a var, append should be a mutating function...
        let blockedConnections: RList<String> = RList(key: blockedConnectionsKey)
        
        guard let redis = try? Redis(hostname: "localhost", port: 6379)
            else
        {
            return
        }
        addPacketsQueue.sync
            {
                for _ in 1...73
                {
                    self.connectionID += 1
                    print("\n----------> Adding packets for connection ID \(self.connectionID) <----------")
                    let connectionIDString = String(self.connectionID)
                    
                    // Adding a fake incoming packet
                    let inPacket = self.createFakePacket(minSize: minSize, maxSize: maxSize)
                    let inMap: RMap<String, Data> = RMap(key: blockedIncomingKey)
                    inMap[connectionIDString] = inPacket
                    print("📥  In Packet for \(connectionIDString) added.")
                    
                    // Adding a fake outgoing packet
                    let outPacket = self.createFakePacket(minSize: minSize, maxSize: maxSize)
                    let outMap: RMap<String, Data> = RMap(key: blockedOutgoingKey)
                    outMap[connectionIDString] = outPacket
                    print("📤  Out packet for \(connectionIDString) added.")
                    
                    // Both packets have been added, update the list of connections to process.
                    print("Appending Connection ID \(connectionIDString) to the blocked connections list.\n🎁 🎁 🎁 🎁")
                    blockedConnections.append(connectionIDString)
                    
                    // Publish: A new blocked connection is ready to be analyzed.
                    do
                    {
                        let numberOfSubscribers = try redis.publish(channel: blockedChannel, message: self.newBlockedConnectionMessage)
                        print("\(numberOfSubscribers as! Int) subscriber(s)")
                    }
                    catch
                    {
                        print(error)
                    }
                    
                    // Increment the allowed packets seen field.
                    let packetStatsDictionary: RMap<String, Int> = RMap(key: packetStatsKey)
                    
                    if let blockedPacketsSeenValue = packetStatsDictionary.increment(field: blockedPacketsSeenKey), blockedPacketsSeenValue > 0
                    {
                        DispatchQueue.main.async
                            {
                                //self.blockedPacketsSeen = "\(blockedPacketsSeenValue)"
                        }
                    }
                }
        }
    }

}
