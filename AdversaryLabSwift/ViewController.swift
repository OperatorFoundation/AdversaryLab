//
//  ViewController.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 1/11/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Cocoa
import Auburn
import RedShot
import Datable

class ViewController: NSViewController
{
    var fakeConnectionID = 0
    var streaming: Bool = false
    
    @objc dynamic var allowedPacketsSeen = "Loading..."
    @objc dynamic var allowedPacketsAnalyzed = "Loading..."
    @objc dynamic var blockedPacketsSeen = "Loading..."
    @objc dynamic var blockedPacketsAnalyzed = "Loading..."
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        subscribeToAllowedConnections()
        subscribeToBlockedConnections()
        loadLabelData()
    }
    
    @IBAction func runClick(_ sender: NSButton)
    {
        self.addAllowedPackets()
        self.addblockedPackets()
    }
    
    @IBAction func streamPacketsClicked(_ sender: NSButton)
    {
        if sender.state == .off
        {
            streaming = false
        }
        else
        {
            streaming = true
            self.addAllowedPackets()
            self.addblockedPackets()
        }
    }
    
    func loadLabelData()
    {
        let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
        
        // Allowed Packets Seen
        if let allowedPacketsSeenValue: Int = packetStatsDict[allowedPacketsSeenKey], allowedPacketsSeenValue != 0
        {
            self.allowedPacketsSeen = "\(allowedPacketsSeenValue)"
        }
        
        // Allowed Packets Analyzed
        if let allowedPacketsAnalyzedValue: Int = packetStatsDict[allowedPacketsAnalyzedKey], allowedPacketsAnalyzedValue != 0
        {
            self.allowedPacketsAnalyzed = "\(allowedPacketsAnalyzedValue)"
        }
        
        // Blocked Packets Seen
        if let blockedPacketsSeenValue: Int = packetStatsDict[blockedPacketsSeenKey], blockedPacketsSeenValue != 0
        {
            self.blockedPacketsSeen = "\(blockedPacketsSeenValue)"
        }
        
        //Blocked Packets Analyzed
        if let blockedPacketsAnalyzedValue: Int = packetStatsDict[blockedPacketsAnalyzedKey], blockedPacketsAnalyzedValue != 0
        {
            self.blockedPacketsAnalyzed = "\(blockedPacketsAnalyzedValue)"
        }
    }
    
    func subscribeToAllowedConnections()
    {
        guard let redis = try? Redis(hostname: "localhost", port: 6379)
            else
        {
            print("Unable to connect to Redis")
            return
        }
        
        do
        {
            try redis.subscribe(channel:allowedChannel)
            { (maybeRedisType, maybeError) in
                
                guard let redisList = maybeRedisType as? [Datable]
                    else
                {
                    return
                }
                
                for each in redisList
                {
                    guard let thisElement = each as? Data
                        else
                    {
                        continue
                    }
                    
                    guard thisElement.string == newAllowedConnectionMessage
                        else
                    {
                        print(thisElement.string)
                        continue
                    }

                    self.analyzeAllowedConnections()
                }
            }
        }
        catch
        {
            print(error)
        }        
    }
    
    func subscribeToBlockedConnections()
    {
        guard let redis = try? Redis(hostname: "localhost", port: 6379)
            else
        {
            print("Unable to connect to Redis")
            return
        }
        
        do
        {
            try redis.subscribe(channel: blockedChannel)
            { (maybeRedisType, maybeError) in
                
                guard let redisList = maybeRedisType as? [Datable]
                    else
                {
                    return
                }
                
                for each in redisList
                {
                    guard let thisElement = each as? Data
                        else
                    {
                        continue
                    }
                    
                    guard thisElement.string == newBlockedConnectionMessage
                        else
                    {
                        print(thisElement.string)
                        continue
                    }
                    
                    self.analyzeBlockedConnections()
                }
            }
        }
        catch
        {
            print(error)
        }
    }
    
    func createFakePacket(minSize: UInt32, maxSize: UInt32) -> Data
    {
        let packetSize = Int(arc4random_uniform(1 + maxSize - minSize) + minSize)
        return Data(count: packetSize)
    }
    
    func addAllowedPackets()
    {
        let minSize: UInt32 = 200
        let maxSize: UInt32 = 500
        let allowedConnections: RList<String> = RList(key: allowedConnectionsKey)
        
        guard let redis = try? Redis(hostname: "localhost", port: 6379)
            else
        {
            return
        }
        analysisQueue.sync
        {
            for _ in 1...73
            {
                self.fakeConnectionID += 1
                let connectionIDString = String(self.fakeConnectionID)
                
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
                    let numberOfSubscribers = try redis.publish(channel: allowedChannel, message: newAllowedConnectionMessage)
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
                    DispatchQueue.main.async {
                        self.allowedPacketsSeen = "\(allowedPacketsSeenValue)"
                    }
                }
            }
        }
    }
    
    func addblockedPackets()
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
        analysisQueue.sync
        {
            for _ in 1...73
            {
                self.fakeConnectionID += 1
                let connectionIDString = String(self.fakeConnectionID)
                
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
                    let numberOfSubscribers = try redis.publish(channel: blockedChannel, message: newBlockedConnectionMessage)
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
                        self.blockedPacketsSeen = "\(blockedPacketsSeenValue)"
                    }
                }
            }
        }
    }
    
    func analyzeAllowedConnections()
    {
        let connectionList: RList<String> = RList(key: allowedConnectionsKey)
        analysisQueue.async
        {
            while connectionList.count != 0
            {
                // Get the first connection ID from the list
                guard let connectionID = connectionList.removeFirst()
                    else
                {
                    continue
                }
                
                if "\(type(of: connectionID))" == "NSNull"
                {
                    print("\nSkipping connectionID: \(connectionID)")
                    continue
                }
                
                let allowedConnection = ObservedConnection(connectionType: .allowed, connectionID: connectionID)
                let (successful, error) = self.processPacketLengths(forConnection: allowedConnection)
                if successful
                {
                    // Increment Packets Analyzed Field as we are done analyzing this connection
                    let packetsAnalyzedDictionary: RMap<String, Int> = RMap(key: packetStatsKey)
                    let _ = packetsAnalyzedDictionary.increment(field: allowedPacketsAnalyzedKey)
                }
                else if error != nil
                {
                    print(error!)
                    continue
                }
                
                // Get values to show in Text Labels
                let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
                
                // Allowed Packets Analyzed
                if let allowedPacketsAnalyzedValue: Int = packetStatsDict[allowedPacketsAnalyzedKey], allowedPacketsAnalyzedValue != 0
                {
                    DispatchQueue.main.async
                    {
                        self.allowedPacketsAnalyzed = "\(allowedPacketsAnalyzedValue)"
                    }
                }
                
                // Allowed Packets Seen
                if let allowedPacketsSeenValue: Int = packetStatsDict[allowedPacketsSeenKey], allowedPacketsSeenValue != 0
                {
                    DispatchQueue.main.async
                    {
                        self.allowedPacketsSeen = "\(allowedPacketsSeenValue)"
                    }
                }
            }
        }
    }
    
    func analyzeBlockedConnections()
    {
        let connectionList: RList<String> = RList(key: blockedConnectionsKey)
        analysisQueue.async
        {
            while connectionList.count != 0
            {
                // Get the first connection ID from the list
                guard let connectionID = connectionList.removeFirst()
                    else
                {
                    continue
                }
                
                if "\(type(of: connectionID))" == "NSNull"
                {
                    print("\nSkipping connectionID: \(connectionID)")
                    continue
                }
                
                let blockedConnection = ObservedConnection(connectionType: .blocked, connectionID: connectionID)
                
                // Process Packet Lengths
                let (successful, error) = self.processPacketLengths(forConnection: blockedConnection)
                if successful
                {
                    // Increment Packets Analyzed Field as we are done analyzing this connection
                    let packetsAnalyzedDictionary: RMap<String, Int> = RMap(key: packetStatsKey)
                    let _ = packetsAnalyzedDictionary.increment(field: blockedPacketsAnalyzedKey)
                }
                else if error != nil
                {
                    print(error!)
                    continue
                }
                
                //TODO: Other Tests
                
                // Get values to show in Text Labels
                let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
                
                // Blocked Packets Analyzed
                if let blockedPacketsAnalyzedValue: Int = packetStatsDict[blockedPacketsAnalyzedKey], blockedPacketsAnalyzedValue != 0
                {
                    DispatchQueue.main.async
                    {
                        self.blockedPacketsAnalyzed = "\(blockedPacketsAnalyzedValue)"
                    }
                }
                
                // Blocked Packets Seen
                if let blockedPacketsSeenValue: Int = packetStatsDict[blockedPacketsSeenKey], blockedPacketsSeenValue != 0
                {
                    DispatchQueue.main.async
                    {
                        self.blockedPacketsSeen = "\(blockedPacketsSeenValue)"
                    }
                }
            }
        }
    }
    
    func processPacketLengths(forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
    {
        let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
        let outgoingLengthSet: RSortedSet<Int> = RSortedSet(key: connection.outgoingLengthsKey)
        let inPacketDictionary: RMap<String, Data> = RMap(key: connection.incomingKey)
        let incomingLengthSet: RSortedSet<Int> = RSortedSet(key: connection.incomingLengthsKey)

        // Get the out packet that corresponds with this connection ID
        guard let outPacket: Data = outPacketHash[connection.connectionID]
            else
        {
            return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID))
        }
        
        /// DEBUG
        if outPacket.count < 100
        {
            print("\n### Outpacket count = \(String(outPacket.count))")
            print("\n⁉️  We got a weird out packet size... \(String(describing: String(data: outPacket, encoding: .utf8)))<----")
        }
        ///
        
        // Increment the score of this particular outgoing packet length
        let newOutScore = outgoingLengthSet.incrementScore(ofField: String(outPacket.count), byIncrement: 1)
        if newOutScore == nil
        {
            print("Error incrementing score for allowed out length of \(outPacket.count) for connection ID \(connection.connectionID)")
            print(outPacket.string)
        }
        
        // Get the in packet that corresponds with this connection ID
        guard let inPacket = inPacketDictionary[connection.connectionID]
            else
        {
            return(false, PacketLengthError.noInPacketForConnection(connection.connectionID))
        }
        
        /// DEBUG
        if inPacket.count < 100
        {
            print("\n### Inpacket count = \(String(inPacket.count))\n")
            print("\n⁉️  We got a weird in packet size... \(String(describing: String(data: outPacket, encoding: .utf8))) <---\n")
        }
        ///
        
        // Increment the score of this particular incoming packet length
        let newInScore = incomingLengthSet.incrementScore(ofField: String(inPacket.count), byIncrement: 1)
        if newInScore == nil
        {
            return(false, PacketLengthError.unableToIncremementScore(packetSize: inPacket.count, connectionID: connection.connectionID))
        }
        
        return(true, nil)
    }
    
//    func processPacketLengths(connectionKey: String,
//                              outgoingKey: String,
//                              outgoingLengthsKey: String,
//                              incomingKey: String,
//                              incomingLengthsKey: String,
//                              packetsAnalyzedKey: String)
//    {
//        let connectionList: RList<String> = RList(key: connectionKey)
//        analysisQueue.async
//        {
//            while connectionList.count != 0
//            {
//                print("\n🔛 Entered analyzing packet lengths loop. Connection list contains \(connectionList.count) elements. 🔛\n")
//
//                let packetsAnalyzedDictionary: RMap<String, Int> = RMap(key: packetStatsKey)
//                let outPacketDictionary: RMap<String, Data> = RMap(key: outgoingKey)
//                let outgoingLengthSet: RSortedSet<Int> = RSortedSet(key: outgoingLengthsKey)
//                let inPacketDictionary: RMap<String, Data> = RMap(key: incomingKey)
//                let incomingLengthSet: RSortedSet<Int> = RSortedSet(key: incomingLengthsKey)
//
//                // Get the first connection ID from the list
//                guard let connectionID = connectionList.removeFirst()
//                    else
//                {
//                    continue
//                }
//
//                if "\(type(of: connectionID))" == "NSNull"
//                {
//                    print("\nSkipping connectionID: \(connectionID)")
//                    continue
//                }
//
//                // Get the out packet that corresponds with this connection ID
//                guard let outPacket: Data = outPacketDictionary[connectionID]
//                    else
//                {
//                    print("Failed to find outgoing packet for connection \(connectionID)")
//                    continue
//                }
//
//                /// DEBUG
//                print("\n### Outpacket count = \(String(outPacket.count))")
//                if outPacket.count < 100
//                {
//                    print("\n⁉️  We got a weird out packet size... \(String(describing: String(data: outPacket, encoding: .utf8)))<----")
//                }
//                ///
//
//                // Increment the score of this particular outgoing packet length
//                let newOutScore = outgoingLengthSet.incrementScore(ofField: String(outPacket.count), byIncrement: 1)
//                if newOutScore == nil
//                {
//                    print("Error incrementing score for allowed out length of \(outPacket.count) for connection ID \(connectionID)")
//                    print(outPacket.string)
//                }
//
//                // Get the in packet that corresponds with this connection ID
//                guard let inPacket = inPacketDictionary[connectionID]
//                    else
//                {
//                    print("Failed to find incoming packet for connection \(connectionID)")
//                    return
//                }
//
//                /// DEBUG
//                print("\n### Inpacket count = \(String(inPacket.count))\n")
//                if inPacket.count < 100
//                {
//                    print("\n⁉️  We got a weird in packet size... \(String(describing: String(data: outPacket, encoding: .utf8))) <---\n")
//                }
//                ///
//
//                // Increment the score of this particular incoming packet length
//                let newInScore = incomingLengthSet.incrementScore(ofField: String(inPacket.count), byIncrement: 1)
//                if newInScore == nil
//                {
//                    print("Error incrementing score for allowed incoming length of \(inPacket.count) for connection ID \(connectionID)")
//                }
//
//                // Increment Packets Analyzed Field as we are done analyzing this connection
//                let _ = packetsAnalyzedDictionary.increment(field: packetsAnalyzedKey)
//
//                // Get values to show in Text Labels
//                let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
//
//                // Allowed Packets Analyzed
//                if let allowedPacketsAnalyzedValue: Int = packetStatsDict[allowedPacketsAnalyzedKey], allowedPacketsAnalyzedValue != 0
//                {
//                    DispatchQueue.main.async
//                    {
//                        self.allowedPacketsAnalyzed = "\(allowedPacketsAnalyzedValue)"
//                    }
//                }
//
//                // Blocked Packets Analyzed
//                if let blockedPacketsAnalyzedValue: Int = packetStatsDict[blockedPacketsAnalyzedKey], blockedPacketsAnalyzedValue != 0
//                {
//                    DispatchQueue.main.async
//                    {
//                        self.blockedPacketsAnalyzed = "\(blockedPacketsAnalyzedValue)"
//                    }
//                }
//
//                // Blocked Packets Seen
//                if let blockedPacketsSeenValue: Int = packetStatsDict[blockedPacketsSeenKey], blockedPacketsSeenValue != 0
//                {
//                    DispatchQueue.main.async
//                    {
//                        self.blockedPacketsSeen = "\(blockedPacketsSeenValue)"
//                    }
//                }
//
//                // Allowed Packets Seen
//                if let allowedPacketsSeenValue: Int = packetStatsDict[allowedPacketsSeenKey], allowedPacketsSeenValue != 0
//                {
//                    DispatchQueue.main.async
//                    {
//                        self.allowedPacketsSeen = "\(allowedPacketsSeenValue)"
//                    }
//                }
//            }
//
//            print("\n EXITED ANALYSIS LOOP. Connections in list: \(connectionList.count)")
//        }
//    }

}

