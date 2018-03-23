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
    
    @objc dynamic var requiredTiming = "--"
    @objc dynamic var requiredTimeAcc = "--"
    @objc dynamic var forbiddenTiming = "--"
    @objc dynamic var forbiddenTimingAcc = "--"
    
    @objc dynamic var requiredOutLength = "--"
    @objc dynamic var requiredOutLengthAcc = "--"
    @objc dynamic var forbiddenOutLength = "--"
    @objc dynamic var forbiddenOutLengthAcc = "--"
    @objc dynamic var requiredInLength = "--"
    @objc dynamic var requiredInLengthAcc = "--"
    @objc dynamic var forbiddenInLength = "--"
    @objc dynamic var forbiddenInLengthAcc = "--"
    
    @objc dynamic var requiredOutEntropy = "--"
    @objc dynamic var requiredOutEntropyAcc = "--"
    @objc dynamic var forbiddenOutEntropy = "--"
    @objc dynamic var forbiddenOutEntropyAcc = "--"
    @objc dynamic var requiredInEntropy = "--"
    @objc dynamic var requiredInEntropyAcc = "--"
    @objc dynamic var forbiddenInEntropy = "--"
    @objc dynamic var forbiddenInEntropyAcc = "--"
    
    @objc dynamic var requiredOutSequence = "--"
    @objc dynamic var requiredOutSequenceCount = "--"
    @objc dynamic var requiredOutSequenceAcc = "--"
    @objc dynamic var forbiddenOutSequence = "--"
    @objc dynamic var forbiddenOutSequenceCount = "--"
    @objc dynamic var forbiddenOutSequenceAcc = "--"
    @objc dynamic var requiredInSequence = "--"
    @objc dynamic var requiredInSequenceCount = "--"
    @objc dynamic var requiredInSequenceAcc = "--"
    @objc dynamic var forbiddenInSequence = "--"
    @objc dynamic var forbiddenInSequenceCount = "--"
    @objc dynamic var forbiddenInSequenceAcc = "--"
    
    @IBOutlet weak var removePacketsCheck: NSButton!
    @IBOutlet weak var enableSequencesCheck: NSButton!
    @IBOutlet weak var enableTLSCheck: NSButton!
    
    var enableSequenceAnalysis: Bool
    {
        get
        {
            switch enableSequencesCheck.state
            {
            case .on:
                return true
            case .off:
                return false
            default: //No Mixed State
                return false
            }
        }
    }
    
    var enableTLSAnalysis: Bool
    {
        get
        {
            switch enableTLSCheck.state
            {
            case .on:
                return true
            case .off:
                return false
            default: //No Mixed State
                return false
            }
        }
    }

    var removePackets: Bool
    {
        get
        {
            switch removePacketsCheck.state
            {
            case .on:
                return true
            case .off:
                return false
            default: //No Mixed State
                return false
            }
        }
    }
    
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
        self.connectionInspector.analyzeConnections(enableSequenceAnalysis: enableSequenceAnalysis, enableTLSAnalysis: enableTLSAnalysis, removePackets: removePackets)
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
                
                DispatchQueue.main.async
                {
                    self.loadLabelData()
                }
            }
        }
    }
    
    @objc func loadLabelData()
    {
        DispatchQueue.main.async
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
            
            // Blocked Packets Analyzed
            if let blockedPacketsAnalyzedValue: Int = packetStatsDict[blockedPacketsAnalyzedKey], blockedPacketsAnalyzedValue != 0
            {
                self.blockedPacketsAnalyzed = "\(blockedPacketsAnalyzedValue)"
            }
            
            /// Scores
            
            // Timing (milliseconds)
            let requiredTimingSet: RSortedSet<Int> = RSortedSet(key: requiredTimeDiffKey)
            if let (rtMember, rtScore) = requiredTimingSet.last
            {
                self.requiredTiming = "\(rtMember) ms"
                self.requiredTimeAcc = "\(rtScore)"
            }
            
            let forbiddenTimingSet: RSortedSet<Int> = RSortedSet(key: forbiddenTimeDiffKey)
            if let (ftMember, ftScore) = forbiddenTimingSet.last
            {
                self.forbiddenTiming = "\(ftMember) ms"
                self.forbiddenTimingAcc = "\(ftScore)"
            }
            
            // Lengths
            let requiredOutLengthSet: RSortedSet<Int> = RSortedSet(key: outgoingRequiredLengthsKey)
            if let (rolMember, rolScore) = requiredOutLengthSet.last
            {
                self.requiredOutLength = "\(rolMember)"
                self.requiredOutLengthAcc = "\(rolScore)"
            }
            
            let forbiddenOutLengthSet: RSortedSet<Int> = RSortedSet(key: outgoingForbiddenLengthsKey)
            if let (folMember, folScore) = forbiddenOutLengthSet.last
            {
                self.forbiddenOutLength = "\(folMember)"
                self.forbiddenOutLengthAcc = "\(folScore)"
            }
            
            let requiredInLengthSet: RSortedSet<Int> = RSortedSet(key: incomingRequiredLengthsKey)
            if let (rilMember, rilScore) = requiredInLengthSet.last
            {
                self.requiredInLength = "\(rilMember)"
                self.requiredInLengthAcc = "\(rilScore)"
            }
            
            let forbiddenInLengthSet: RSortedSet<Int> = RSortedSet(key: incomingForbiddenLengthsKey)
            if let (filMember, filScore) = forbiddenInLengthSet.last
            {
                self.forbiddenInLength = "\(filMember)"
                self.forbiddenInLengthAcc = "\(filScore)"
            }
            
            // Entropy
            let requiredOutEntropySet: RSortedSet<Int> = RSortedSet(key: outgoingRequiredEntropyKey)
            if let (roeMember, roeScore) = requiredOutEntropySet.last
            {
                self.requiredOutEntropy = "\(roeMember)"
                self.requiredOutEntropyAcc = "\(roeScore)"
            }
            
            let forbiddenOutEntropySet: RSortedSet<Int> = RSortedSet(key: outgoingForbiddenEntropyKey)
            if let (foeMember, foeScore) = forbiddenOutEntropySet.last
            {
                self.forbiddenOutEntropy = "\(foeMember)"
                self.forbiddenOutEntropyAcc = "\(foeScore)"
            }
            
            let requiredInEntropySet: RSortedSet<Int> = RSortedSet(key: incomingRequiredEntropyKey)
            if let (rieMember, rieScore) = requiredInEntropySet.last
            {
                self.requiredInEntropy = "\(rieMember)"
                self.requiredInEntropyAcc = "\(rieScore)"
            }
            
            let forbiddenInEntropySet: RSortedSet<Int> = RSortedSet(key: incomingForbiddenEntropyKey)
            if let (fieMember, fieScore) = forbiddenInEntropySet.last
            {
                self.forbiddenInEntropy = "\(fieMember)"
                self.forbiddenInEntropyAcc = "\(fieScore)"
            }
            
            // Subsequences
            let requiredOutSequenceSet: RSortedSet<Data> = RSortedSet(key: outgoingRequiredSequencesKey)
            if let (rosMember, rosScore) = requiredOutSequenceSet.last
            {
                self.requiredOutSequence = "\(rosMember.hexEncodedString())"
                self.requiredOutSequenceCount = "\(rosMember)"
                self.requiredOutSequenceAcc = "\(rosScore)"
            }
            
            let forbiddenOutSequenceSet: RSortedSet<Data> = RSortedSet(key: outgoingForbiddenSequencesKey)
            if let (fosMember, fosScore) = forbiddenOutSequenceSet.last
            {
                self.forbiddenOutSequence = "\(fosMember.hexEncodedString())"
                self.forbiddenOutSequenceCount = "\(fosMember)"
                self.forbiddenOutSequenceAcc = "\(fosScore)"
            }
            
            let requiredInSequenceSet: RSortedSet<Data> = RSortedSet(key: incomingRequiredSequencesKey)
            if let (risMemeber, risScore) = requiredInSequenceSet.last
            {
                self.requiredInSequence = "\(risMemeber.hexEncodedString())"
                self.requiredInSequenceCount = "\(risMemeber)"
                self.requiredInSequenceAcc = "\(risScore)"
            }
            
            let forbiddenInSequenceSet: RSortedSet<Data> = RSortedSet(key: incomingForbiddenSequencesKey)
            if let (fisMember, fisScore) = forbiddenInSequenceSet.last
            {
                self.forbiddenInSequence = "\(fisMember.hexEncodedString())"
                self.forbiddenInSequenceCount = "\(fisMember)"
                self.forbiddenInSequenceAcc = "\(fisScore)"
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

                    self.connectionInspector.analyzeConnections(enableSequenceAnalysis: self.enableSequenceAnalysis, enableTLSAnalysis: self.enableTLSAnalysis, removePackets: self.removePackets)
                }
            }
        }
        catch
        {
            print(error)
        }        
    }

}

