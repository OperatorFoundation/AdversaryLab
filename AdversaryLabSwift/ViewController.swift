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
    let connectionInspector = ConnectionInspector()
    
    var streaming: Bool = false
    
    @objc dynamic var allowedPacketsSeen = "Loading..."
    @objc dynamic var allowedPacketsAnalyzed = "Loading..."
    @objc dynamic var blockedPacketsSeen = "Loading..."
    @objc dynamic var blockedPacketsAnalyzed = "Loading..."
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Subscribe to pubsub to know when to inspect a new connection
        //subscribeToNewConnectionsChannel()
        
        // Update Labels
        loadLabelData()
        
        // Also update labels when new data is available
        NotificationCenter.default.addObserver(self, selector: #selector(loadLabelData), name: .updateStats, object: nil)
    }
    
    @IBAction func runClick(_ sender: NSButton)
    {
        self.connectionInspector.analyzeConnections()
        
        self.loadLabelData()
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
            streamConnections()
        }
    }
    
    func streamConnections()
    {
        analysisQueue.async
            {
        while self.streaming == true
        {
            
            let connectionGenerator = FakeConnectionGenerator()
            connectionGenerator.addConnections()
                    
                    DispatchQueue.main.async {
                        self.loadLabelData()
                    }
            }
            
        }
    }
    
    @objc func loadLabelData()
    {
        DispatchQueue.main.async {
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
    }
    
    func subscribeToNewConnectionsChannel()
    {
        guard let redis = try? Redis(hostname: "localhost", port: 6379)
            else
        {
            print("Unable to connect to Redis")
            return
        }
        
        do
        {
            try redis.subscribe(channel:newConnectionsChannel)
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
                    
                    guard thisElement.string == newConnectionMessage
                        else
                    {
                        continue
                    }

                    self.connectionInspector.analyzeConnections()
                }
            }
        }
        catch
        {
            print(error)
        }        
    }

}

