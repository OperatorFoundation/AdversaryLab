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
    var connectionID = 0
    var streaming = false
    var allowedConnectionsMessage = ""
    @objc dynamic var allowedPacketsSeen: String
    {
        get
        {
            let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
            if let allowedPacketsSeenValue: Int = packetStatsDict[allowedPacketsSeenKey], allowedPacketsSeenValue > 0
            {
                return "\(allowedPacketsSeenValue)"
            }
            else
            {
                return "Loading..."
            }
        }
        set
        {
            //
        }
    }
    
    @objc dynamic var allowedPacketsAnalyzed: String
    {
        get
        {
            let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
            if let allowedPacketsAnalyzedValue: Int = packetStatsDict[allowedPacketsAnalyzedKey], allowedPacketsAnalyzedValue > 0
            {
                return "\(allowedPacketsAnalyzedValue)"
            }
            else
            {
                return "Loading..."
            }
        }
        set
        {
            //
        }
    }
    
    @objc dynamic var blockedPacketsSeen: String
        {
        get
        {
            let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
            if let blockedPacketsSeenValue: Int = packetStatsDict[blockedPacketsSeenKey], blockedPacketsSeenValue > 0
            {
                return "\(blockedPacketsSeenValue)"
            }
            else
            {
                return "Loading..."
            }
        }
        set
        {
            //
        }
    }

    @objc dynamic var blockedPacketsAnalyzed: String
        {
        get
        {
            let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
            if let blockedPacketsAnalyzedValue: Int = packetStatsDict[blockedPacketsAnalyzedKey], blockedPacketsAnalyzedValue > 0
            {
                return "\(blockedPacketsAnalyzedValue)"
            }
            else
            {
                return "Loading..."
            }
        }
        set
        {
            //
        }
    }
    
    @objc dynamic var numberOfAOPLengthsMessage: String
    {
        get
        {
            let allowedOutgoingLengths: RSortedSet<Int> = RSortedSet(key: allowedOutgoingLengthsKey)
            return "Recorded \(allowedOutgoingLengths.count) allowed unique outgoing packet lengths."
        }
        
        set
        {
            //
        }
    }
    
    @objc dynamic var numberOfAIPLengthsMessage: String
    {
        get
        {
            let allowedIncomingLengths: RSortedSet<Int> = RSortedSet(key: allowedIncomingLengthsKey)
            return "Recorded \(allowedIncomingLengths.count) allowed unique incoming packet lengths."
        }
        
        set
        {
            //
        }
    }
    
    @IBAction func runClick(_ sender: NSButton)
    {
        addAllowedPackets()
        addBlockedPackets()
        processPacketLengths()
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
        }
        
        DispatchQueue.global(qos: .background).async
        {
            while self.streaming
            {
                self.addAllowedPackets()

                DispatchQueue.main.async
                {
                    let apsValue = self.allowedPacketsSeen
                    if apsValue != "0"
                    {
                        self.allowedPacketsSeen = apsValue
                    }
                }
            }
        }
        
        DispatchQueue.global(qos: .background).async
        {
            while self.streaming
            {
                self.addBlockedPackets()

                DispatchQueue.main.async
                {
                    let bpsValue = self.blockedPacketsSeen
                    if bpsValue != "0"
                    {
                        self.blockedPacketsSeen = bpsValue
                    }
                }
            }
        }

//        DispatchQueue.global(qos: .background).async
//        {
//            while self.streaming
//            {
//                self.processPacketLengths()
//
//                DispatchQueue.main.async
//                {
//                    let apaValue = self.allowedPacketsAnalyzed
//                    self.allowedPacketsAnalyzed = apaValue
//
//                    let bpaValue = self.blockedPacketsAnalyzed
//                    self.blockedPacketsAnalyzed = bpaValue
//                }
//            }
//        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

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
                if let redisList = maybeRedisType as? [Datable]
                {
                    for each in redisList
                    {
                        if let eachData = each as? Data
                        {
                            print("\nReceived a message list:")
                            print("\(eachData.string)\n")
//                            DispatchQueue.main.async {
//                                self.label3.stringValue = eachData.string
//                            }
                        }
                    }
                }
                else
                {
                    print(String(describing: maybeRedisType))
                }
            }
        }
        catch
        {
            print("\nError subscribing to pubsub.")
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
        var allowedConnections: RList<String> = RList(key: allowedConnectionsKey)
        
        guard let redis = try? Redis(hostname: "localhost", port: 6379)
            else
        {
            print("Unable to connect to Redis")
            return
        }
        
        for _ in 1...100
        {
            let connectionIDString = String(connectionID)
            
            let inPacket = createFakePacket(minSize: minSize, maxSize: maxSize)
            let inMap: RMap<String, Data> = RMap(key: allowedIncomingKey)
            inMap[connectionIDString] = inPacket
            
            let outPacket = createFakePacket(minSize: minSize, maxSize: maxSize)
            let outMap: RMap<String, Data> = RMap(key: allowedOutgoingKey)
            outMap[connectionIDString] = outPacket

            
            allowedConnections.append(connectionIDString)
            
            do
            {
                let _ = try redis.publish(channel: allowedChannel, message: "Added allowed connection. Total: \(allowedConnections.count)")
            }
            catch
            {
                print("\nError trying to publish message.")
                print(error)
            }
            
            connectionID += 1
            let packetStatsDictionary: RMap<String, Data> = RMap(key: packetStatsKey)
            let _ = packetStatsDictionary.increment(field: allowedPacketsSeenKey)
        }
        
        allowedConnections = RList(key: allowedConnectionsKey)
    }
    
    func addBlockedPackets()
    {
        let minSize: UInt32 = 200
        let maxSize: UInt32 = 500
        var blockedConnections: RList<String> = RList(key: blockedConnectionsKey)
        
        guard let redis = try? Redis(hostname: "localhost", port: 6379)
            else
        {
            print("Unable to connect to Redis")
            return
        }
        
        for _ in 1...100
        {
            let connectionIDString = String(connectionID)
            
            let inPacket = createFakePacket(minSize: minSize, maxSize: maxSize)
            let inMap: RMap<String, Data> = RMap(key: blockedIncomingKey)
            inMap[connectionIDString] = inPacket
            
            let outPacket = createFakePacket(minSize: minSize, maxSize: maxSize)
            let outMap: RMap<String, Data> = RMap(key: blockedOutgoingKey)
            outMap[connectionIDString] = outPacket
            
            
            blockedConnections.append(connectionIDString)
            
            do
            {
                let _ = try redis.publish(channel: blockedChannel, message: "Added blocked connection. Total: \(blockedConnections.count)")
            }
            catch
            {
                print("\nError trying to publish message.")
                print(error)
            }
            
            connectionID += 1
            let packetStatsDictionary: RMap<String, Data> = RMap(key: packetStatsKey)
            let _ = packetStatsDictionary.increment(field: blockedPacketsSeenKey)
        }
        
        blockedConnections = RList(key: blockedConnectionsKey)
    }
    
    func processPacketLengths(connectionKey: String, outgoingKey: String, outgoingLengthsKey: String, incomingKey: String, incomingLengthsKey: String, packetsAnalyzedKey: String)
    {
        var connectionList: RList<String> = RList(key: connectionKey)
        let packetsAnalyzedDictionary: RMap<String, Int> = RMap(key: packetStatsKey)
        
        while connectionList.count > 0
        {
            let outPacketDictionary: RMap<String, Data> = RMap(key: outgoingKey)
            let outgoingLengthSet: RSortedSet<Int> = RSortedSet(key: outgoingLengthsKey)
            let inPacketDictionary: RMap<String, Data> = RMap(key: incomingKey)
            let incomingLengthSet: RSortedSet<Int> = RSortedSet(key: incomingLengthsKey)
            
            guard let connectionID = connectionList.removeFirst()
                else
            {
                print("Failed to remove first connection ID from allowed connections list.")
                continue
            }
            
            guard let outPacket: Data = outPacketDictionary[connectionID]
                else
            {
                print("Failed to find outgoing packet for connection \(connectionID)")
                continue
            }
            
            let newOutScore = outgoingLengthSet.incrementScore(ofField: String(outPacket.count), byIncrement: 1)
            if newOutScore == nil
            {
                print("Error incrementing score for allowed out length of:\(outPacket.count)")
            }
            
            guard let inPacket = inPacketDictionary[connectionID]
                else
            {
                print("Failed to find incoming packet for connection \(connectionID)")
                continue
            }
            
            let newInScore = incomingLengthSet.incrementScore(ofField: String(inPacket.count), byIncrement: 1)
            if newInScore == nil
            {
                print("Error incrementing score for allowed incoming length of:\(inPacket.count)")
            }
            
            let _ = packetsAnalyzedDictionary.increment(field: packetsAnalyzedKey)
            connectionList = RList(key: connectionKey)
        }
    }
    
    func processPacketLengths()
    {
        processPacketLengths(connectionKey: allowedConnectionsKey, outgoingKey: allowedOutgoingKey, outgoingLengthsKey: allowedOutgoingLengthsKey, incomingKey: allowedIncomingKey, incomingLengthsKey: allowedIncomingLengthsKey, packetsAnalyzedKey: allowedPacketsAnalyzedKey)
        
        let allowedOutgoingLengths: RSortedSet<Int> = RSortedSet(key: allowedOutgoingLengthsKey)
        numberOfAOPLengthsMessage = "Recorded \(allowedOutgoingLengths.count) allowed unique outgoing packet lengths."
        let allowedIncomingLengths: RSortedSet<Int> = RSortedSet(key: allowedIncomingLengthsKey)
        numberOfAIPLengthsMessage = "Recorded \(allowedIncomingLengths.count) allowed unique incoming packet lengths"
        
        processPacketLengths(connectionKey: blockedConnectionsKey, outgoingKey: blockedOutgoingKey, outgoingLengthsKey: blockedOutgoingLengthsKey, incomingKey: blockedIncomingKey, incomingLengthsKey: blockedIncomingLengthsKey, packetsAnalyzedKey: blockedPacketsAnalyzedKey)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

