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
    
    @objc dynamic var requiredTLSName = "--"
    @objc dynamic var requiredTLSNameAcc = "--"
    @objc dynamic var forbiddenTLSName = "--"
    @objc dynamic var forbiddenTLSNameAcc = "--"
    
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
    
    @objc dynamic var requiredOutOffset = "--"
    @objc dynamic var requiredOutOffsetCount = "--"
    @objc dynamic var requiredOutOffsetIndex = "--"
    @objc dynamic var requiredOutOffsetAcc = "--"
    @objc dynamic var forbiddenOutOffset = "--"
    @objc dynamic var forbiddenOutOffsetCount = "--"
    @objc dynamic var forbiddenOutOffsetIndex = "--"
    @objc dynamic var forbiddenOutOffsetAcc = "--"
    
    @objc dynamic var requiredInOffset = "--"
    @objc dynamic var requiredInOffsetCount = "--"
    @objc dynamic var requiredInOffsetIndex = "--"
    @objc dynamic var requiredInOffsetAcc = "--"
    @objc dynamic var forbiddenInOffset = "--"
    @objc dynamic var forbiddenInOffsetCount = "--"
    @objc dynamic var forbiddenInOffsetIndex = "--"
    @objc dynamic var forbiddenInOffsetAcc = "--"
    
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
        
        // Launch Redis Server
        print("Launching Redis Server!")
        RedisServerController.sharedInstance.launchRedisServer()
        
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
            if let allowedPacketsSeenValue: Int = packetStatsDict[allowedPacketsSeenKey]
            {
                self.allowedPacketsSeen = "\(allowedPacketsSeenValue)"
            }
            else
            {
                self.allowedPacketsSeen = "Loading..."
            }
            
            // Allowed Packets Analyzed
            if let allowedPacketsAnalyzedValue: Int = packetStatsDict[allowedPacketsAnalyzedKey]
            {
                self.allowedPacketsAnalyzed = "\(allowedPacketsAnalyzedValue)"
            }
            else
            {
                self.allowedPacketsAnalyzed = "Loading..."
            }
            
            // Blocked Packets Seen
            if let blockedPacketsSeenValue: Int = packetStatsDict[blockedPacketsSeenKey]
            {
                self.blockedPacketsSeen = "\(blockedPacketsSeenValue)"
            }
            else
            {
                self.blockedPacketsSeen = "Loading..."
            }
            
            // Blocked Packets Analyzed
            if let blockedPacketsAnalyzedValue: Int = packetStatsDict[blockedPacketsAnalyzedKey]
            {
                self.blockedPacketsAnalyzed = "\(blockedPacketsAnalyzedValue)"
            }
            else
            {
                self.blockedPacketsAnalyzed = "Loading..."
            }
            
            /// Scores
            
            // Timing (milliseconds)
            let requiredTimingSet: RSortedSet<Int> = RSortedSet(key: requiredTimeDiffKey)
            if let (rtMember, rtScore) = requiredTimingSet.last
            {
                self.requiredTiming = "\(rtMember) ms"
                self.requiredTimeAcc = "\(rtScore)"
            }
            else
            {
                self.requiredTiming = "--"
                self.requiredTimeAcc = "--"
            }
            
            let forbiddenTimingSet: RSortedSet<Int> = RSortedSet(key: forbiddenTimeDiffKey)
            if let (ftMember, ftScore) = forbiddenTimingSet.last
            {
                self.forbiddenTiming = "\(ftMember) ms"
                self.forbiddenTimingAcc = "\(ftScore)"
            }
            else
            {
                self.forbiddenTiming = "--"
                self.forbiddenTimingAcc = "--"
            }
            
            // TLS Common Names
            
            let requiredTLSNamesSet: RSortedSet<String> = RSortedSet(key: allowedTlsScoreKey)
            if let (rTLSMember, rTLSScore) = requiredTLSNamesSet.last
            {
                self.requiredTLSName = rTLSMember
                self.requiredTLSNameAcc = "\(rTLSScore)"
            }
            else
            {
                self.requiredTLSName = "--"
                self.requiredTLSNameAcc = "--"
            }
            
            let forbiddenTLSNamesSet: RSortedSet<String> = RSortedSet(key: blockedTlsScoreKey)
            if let (fTLSMember, fTLSScore) = forbiddenTLSNamesSet.last
            {
                self.forbiddenTLSName = fTLSMember
                self.forbiddenTLSNameAcc = "\(fTLSScore)"
            }
            else
            {
                self.forbiddenTLSName = "--"
                self.forbiddenTLSNameAcc = "--"
            }
            
            // Lengths
            let requiredOutLengthSet: RSortedSet<Int> = RSortedSet(key: outgoingRequiredLengthsKey)
            if let (rolMember, rolScore) = requiredOutLengthSet.last
            {
                self.requiredOutLength = "\(rolMember)"
                self.requiredOutLengthAcc = "\(rolScore)"
            }
            else
            {
                self.requiredOutLength = "--"
                self.requiredOutLengthAcc = "--"
            }
            
            let forbiddenOutLengthSet: RSortedSet<Int> = RSortedSet(key: outgoingForbiddenLengthsKey)
            if let (folMember, folScore) = forbiddenOutLengthSet.last
            {
                self.forbiddenOutLength = "\(folMember)"
                self.forbiddenOutLengthAcc = "\(folScore)"
            }
            else
            {
                self.forbiddenOutLength = "--"
                self.forbiddenOutLengthAcc = "--"
            }
            
            let requiredInLengthSet: RSortedSet<Int> = RSortedSet(key: incomingRequiredLengthsKey)
            if let (rilMember, rilScore) = requiredInLengthSet.last
            {
                self.requiredInLength = "\(rilMember)"
                self.requiredInLengthAcc = "\(rilScore)"
            }
            else
            {
                self.requiredInLength = "--"
                self.requiredInLengthAcc = "--"
            }
            
            let forbiddenInLengthSet: RSortedSet<Int> = RSortedSet(key: incomingForbiddenLengthsKey)
            if let (filMember, filScore) = forbiddenInLengthSet.last
            {
                self.forbiddenInLength = "\(filMember)"
                self.forbiddenInLengthAcc = "\(filScore)"
            }
            else
            {
                self.forbiddenInLength = "--"
                self.forbiddenInLengthAcc = "--"
            }
            
            // Entropy
            let requiredOutEntropySet: RSortedSet<Int> = RSortedSet(key: outgoingRequiredEntropyKey)
            if let (roeMember, roeScore) = requiredOutEntropySet.last
            {
                self.requiredOutEntropy = "\(roeMember)"
                self.requiredOutEntropyAcc = "\(roeScore)"
            }
            else
            {
                self.requiredOutEntropy = "--"
                self.requiredOutEntropyAcc = "--"
            }
            
            let forbiddenOutEntropySet: RSortedSet<Int> = RSortedSet(key: outgoingForbiddenEntropyKey)
            if let (foeMember, foeScore) = forbiddenOutEntropySet.last
            {
                self.forbiddenOutEntropy = "\(foeMember)"
                self.forbiddenOutEntropyAcc = "\(foeScore)"
            }
            else
            {
                self.forbiddenOutEntropy = "--"
                self.forbiddenOutEntropyAcc = "--"
            }
            
            let requiredInEntropySet: RSortedSet<Int> = RSortedSet(key: incomingRequiredEntropyKey)
            if let (rieMember, rieScore) = requiredInEntropySet.last
            {
                self.requiredInEntropy = "\(rieMember)"
                self.requiredInEntropyAcc = "\(rieScore)"
            }
            else
            {
                self.requiredInEntropy = "--"
                self.requiredInEntropyAcc = "--"
            }
            
            let forbiddenInEntropySet: RSortedSet<Int> = RSortedSet(key: incomingForbiddenEntropyKey)
            if let (fieMember, fieScore) = forbiddenInEntropySet.last
            {
                self.forbiddenInEntropy = "\(fieMember)"
                self.forbiddenInEntropyAcc = "\(fieScore)"
            }
            else
            {
                self.forbiddenInEntropy = "--"
                self.forbiddenInEntropyAcc = "--"
            }
            
            //Float Subsequences
            let requiredOutFloatSequenceSet: RSortedSet<Data> = RSortedSet(key: outgoingRequiredFloatSequencesKey)
            if let (roFloatSeqMember, roFloatSeqScore) = requiredOutFloatSequenceSet.last
            {
                self.requiredOutSequence = "\(roFloatSeqMember.hexEncodedString())"
                self.requiredOutSequenceCount = "\(roFloatSeqMember)"
                self.requiredOutSequenceAcc = "\(roFloatSeqScore)"
            }
            else
            {
                self.requiredOutSequence = "--"
                self.requiredOutSequenceCount = "--"
                self.requiredOutSequenceAcc = "--"
            }
            
            let forbiddenOutFloatSequenceSet: RSortedSet<Data> = RSortedSet(key: outgoingForbiddenFloatSequencesKey)
            if let (foFloatSeqMember, foFloatSeqScore) = forbiddenOutFloatSequenceSet.last
            {
                self.forbiddenOutSequence = "\(foFloatSeqMember.hexEncodedString())"
                self.forbiddenOutSequenceCount = "\(foFloatSeqMember)"
                self.forbiddenOutSequenceAcc = "\(foFloatSeqScore)"
            }
            else
            {
                self.forbiddenOutSequence = "--"
                self.forbiddenOutSequenceCount = "--"
                self.forbiddenOutSequenceAcc = "--"
            }
            
            let requiredInFloatSequenceSet: RSortedSet<Data> = RSortedSet(key: incomingRequiredFloatSequencesKey)
            if let (riFloatSeqMemeber, riFloatSeqScore) = requiredInFloatSequenceSet.last
            {
                self.requiredInSequence = "\(riFloatSeqMemeber.hexEncodedString())"
                self.requiredInSequenceCount = "\(riFloatSeqMemeber)"
                self.requiredInSequenceAcc = "\(riFloatSeqScore)"
            }
            else
            {
                self.requiredInSequence = "--"
                self.requiredInSequenceCount = "--"
                self.requiredInSequenceAcc = "--"
            }
            
            let forbiddenInFloatSequenceSet: RSortedSet<Data> = RSortedSet(key: incomingForbiddenFloatSequencesKey)
            if let (fiFloatSeqMember, fiFloatSeqScore) = forbiddenInFloatSequenceSet.last
            {
                self.forbiddenInSequence = "\(fiFloatSeqMember.hexEncodedString())"
                self.forbiddenInSequenceCount = "\(fiFloatSeqMember)"
                self.forbiddenInSequenceAcc = "\(fiFloatSeqScore)"
            }
            else
            {
                self.forbiddenInSequence = "--"
                self.forbiddenInSequenceCount = "--"
                self.forbiddenInSequenceAcc = "--"
            }
            
            // Offset Subsequences
            let outRequiredOffsetHash: RMap<String, String> = RMap(key: outgoingRequiredOffsetKey)
            self.requiredOutSequence = outRequiredOffsetHash[requiredOffsetSequenceKey] ?? "--"
            self.requiredOutOffsetAcc = outRequiredOffsetHash[requiredOffsetAccuracyKey] ?? "--"

            let outForbiddenOffsetHash: RMap<String, String> = RMap(key: outgoingForbiddenOffsetKey)
            self.forbiddenOutOffset = outForbiddenOffsetHash[forbiddenOffsetSequenceKey] ?? "--"
            self.forbiddenOutOffsetCount = "--"
            self.forbiddenOutOffsetAcc = outForbiddenOffsetHash[forbiddenOffsetAccuracyKey] ?? "--"
                        
            let inRequiredOffsetHash: RMap<String, String> = RMap(key: incomingRequiredOffsetKey)
            self.requiredInOffset = inRequiredOffsetHash[requiredOffsetSequenceKey] ?? "--"
            self.requiredInOffsetCount = "--"
            self.requiredInOffsetAcc = inRequiredOffsetHash[requiredOffsetAccuracyKey] ?? "--"
            
            let inForbiddenOffsetHash: RMap<String, String> = RMap(key: incomingForbiddenOffsetKey)
            self.forbiddenInOffset = inForbiddenOffsetHash[forbiddenOffsetSequenceKey] ?? "--"
            self.forbiddenInOffsetCount = "--"
            self.forbiddenInOffsetAcc = inForbiddenOffsetHash[forbiddenOffsetAccuracyKey] ?? "--"
            
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

