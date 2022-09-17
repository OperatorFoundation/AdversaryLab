////
////  FakeConnectionGenerator.swift
////  AdversaryLabSwift
////
////  Created by Adelita Schule on 2/2/18.
////  Copyright © 2018 Operator Foundation. All rights reserved.
////
//
//import Foundation
//
//import Datable
//
//class FakeConnectionGenerator
//{    
//    func createFakePacket(minSize: UInt32, maxSize: UInt32) -> Data
//    {
//        let packetSize = Int(arc4random_uniform(1 + maxSize - minSize) + minSize)
//        return Data(count: packetSize)
//    }
//    
//    func addConnections()
//    {
//        addAllowedPackets()
//        addblockedPackets()
//        
//        NotificationCenter.default.post(name: .updateStats, object: nil)
//    }
//    
//    func addAllowedPackets()
//    {
//        let minSize: UInt32 = 20
//        let maxSize: UInt32 = 50
//        let allowedConnections: RList<String> = RList(key: allowedConnectionsKey)
//
//        for _ in 1...5
//        {
//            let connectionIDString = UUID().uuidString
//            
//            // Adding a fake incoming packet
//            let inPacket = self.createFakePacket(minSize: minSize, maxSize: maxSize)
//            let inHash: RMap<String, Data> = RMap(key: allowedIncomingKey)
//            inHash[connectionIDString] = inPacket
//            
//            //Adding incoming time stamp
//            let inTimeInterval = Date().timeIntervalSince1970
//            let inTimeHash: RMap<String, Double> = RMap(key: allowedIncomingDatesKey)
//            inTimeHash[connectionIDString] = inTimeInterval
//            
//            // Adding a fake outgoing packet
//            let outPacket = self.createFakePacket(minSize: minSize, maxSize: maxSize)
//            let outMap: RMap<String, Data> = RMap(key: allowedOutgoingKey)
//            outMap[connectionIDString] = outPacket
//            
//            // Adding outgoing timestamp
//            let outTimeInterval = Date().timeIntervalSince1970
//            let outTimeHash: RMap<String, Double> = RMap(key: allowedOutgoingDatesKey)
//            outTimeHash[connectionIDString] = outTimeInterval
//            
//            // Both packets have been added, update the list of connections to process.
//            print("Appending Connection ID \(connectionIDString) to the allowed connections list.\n🎈 🎈 🎈 🎈 🎈")
//            allowedConnections.append(connectionIDString)
//            
//            // Increment the allowed packets seen field.
//            let packetStatsDictionary: RMap<String, Int> = RMap(key: packetStatsKey)
//            let _ = packetStatsDictionary.increment(field: allowedPacketsSeenKey)
//        }
//    }
//    
//    func addblockedPackets()
//    {
//        let minSize: UInt32 = 40
//        let maxSize: UInt32 = 70
//        let blockedConnections: RList<String> = RList(key: blockedConnectionsKey)
//        
//        for _ in 1...5
//        {
//            let connectionIDString = UUID().uuidString
//            
//            // Adding a fake incoming packet
//            let inPacket = self.createFakePacket(minSize: minSize, maxSize: maxSize)
//            let inMap: RMap<String, Data> = RMap(key: blockedIncomingKey)
//            inMap[connectionIDString] = inPacket
//            
//            //Adding incoming time stamp
//            let inTimeInterval = Date().timeIntervalSince1970
//            let inTimeHash: RMap<String, Double> = RMap(key: blockedIncomingDatesKey)
//            inTimeHash[connectionIDString] = inTimeInterval
//            
//            // Adding a fake outgoing packet
//            let outPacket = self.createFakePacket(minSize: minSize, maxSize: maxSize)
//            let outMap: RMap<String, Data> = RMap(key: blockedOutgoingKey)
//            outMap[connectionIDString] = outPacket
//            
//            // Adding outgoing timestamp
//            let outTimeInterval = Date().timeIntervalSince1970
//            let outTimeHash: RMap<String, Double> = RMap(key: blockedOutgoingDatesKey)
//            outTimeHash[connectionIDString] = outTimeInterval
//            
//            // Both packets have been added, update the list of connections to process.
//            print("Appending Connection ID \(connectionIDString) to the blocked connections list.\n🎁 🎁 🎁 🎁")
//            blockedConnections.append(connectionIDString)
//            
//            // Increment the allowed packets seen field.
//            let packetStatsDictionary: RMap<String, Int> = RMap(key: packetStatsKey)
//            let _ = packetStatsDictionary.increment(field: blockedPacketsSeenKey)
//        }
//    }
//    
//}
