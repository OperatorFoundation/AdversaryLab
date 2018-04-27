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
    
    @objc dynamic var processingMessage = ""
    
    @IBOutlet weak var removePacketsCheck: NSButton!
    @IBOutlet weak var enableSequencesCheck: NSButton!
    @IBOutlet weak var enableTLSCheck: NSButton!
    @IBOutlet weak var processPacketsButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    let connectionInspector = ConnectionInspector()
    
    var streaming: Bool = false
    var configModel = ProcessingConfigurationModel()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        updateConfigModel()
        
        // Launch Redis Server
        RedisServerController.sharedInstance.launchRedisServer()
        
        // Subscribe to pubsub to know when to inspect a new connection
        //subscribeToNewConnectionsChannel()
        
        // Update Labels and Progress Indicator
        loadLabelData()
        updateProgressIndicator()
        
        // Also update labels and progress indicator when new data is available
        NotificationCenter.default.addObserver(self, selector: #selector(loadLabelData), name: .updateStats, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateProgressIndicator), name: .updateProgressIndicator, object: nil)
    }
    
    @IBAction func runClick(_ sender: NSButton)
    {
        print("\nYou clicked the process packets button 👻")
        updateConfigModel()
        
        if sender.state == .on
        {
            print("Time to analyze some things.")
            self.connectionInspector.analyzeConnections(configModel: configModel)
        }
        else
        {
            print("Pause bot engage!! 🤖")
            self.processingMessage = ""
            self.progressIndicator.maxValue = 0
            self.progressIndicator.doubleValue = 0
            self.progressIndicator.stopAnimation(self)
        }
        
        self.loadLabelData()
    }
    
    @IBAction func removePacketsClicked(_ sender: NSButton)
    {
        updateConfigModel()
    }
    
    @IBAction func enableSequenceAnalysisClicked(_ sender: NSButton)
    {
        updateConfigModel()
    }
    
    @IBAction func enableTLSAnslysisClicked(_ sender: NSButton)
    {
        updateConfigModel()
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
    
    func updateConfigModel()
    {
        // Update Configuration Model based on button states
        configModel.enableSequenceAnalysis = self.enableSequencesCheck.state == .on
        configModel.enableTLSAnalysis = self.enableTLSCheck.state == .on
        configModel.removePackets = self.removePacketsCheck.state == .on
        configModel.processingEnabled = self.processPacketsButton.state == .on
    }
    
    @objc func updateProgressIndicator()
    {
        DispatchQueue.main.async
        {
            self.progressIndicator.maxValue = Double(ProgressBot.sharedInstance.totalToAnalyze)
            self.progressIndicator.doubleValue = Double(ProgressBot.sharedInstance.currentProgress)
            self.processingMessage = ProgressBot.sharedInstance.progressMessage
            
            if ProgressBot.sharedInstance.analysisComplete
            {
                self.processingMessage = ""
                self.progressIndicator.stopAnimation(self)
                self.processPacketsButton.state = .off
            }
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
        // Get redis data in the utility clue and update the labels with the data in the main queue
        
        DispatchQueue.global(qos: .utility).async
        {
            let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
            let allowedPacketsSeenValue: Int? = packetStatsDict[allowedPacketsSeenKey]
            let allowedPacketsAnalyzedValue: Int? = packetStatsDict[allowedPacketsAnalyzedKey]
            let blockedPacketsSeenValue: Int? = packetStatsDict[blockedPacketsSeenKey]
            let blockedPacketsAnalyzedValue: Int? = packetStatsDict[blockedPacketsAnalyzedKey]
            
            /// Scores
            
            // Offset Subsequences
            let outRequiredOffsetHash: RMap<String, String> = RMap(key: outgoingRequiredOffsetKey)
            let requiredOutOffsetString = outRequiredOffsetHash[requiredOffsetSequenceKey] ?? "--"
            let requiredOutOffsetCountString = outRequiredOffsetHash[requiredOffsetByteCountKey] ?? "--"
            let requiredOutOffsetIndexString = outRequiredOffsetHash[requiredOffsetIndexKey] ?? "--"
            let requiredOutOffsetAccString = outRequiredOffsetHash[requiredOffsetAccuracyKey] ?? "--"
            
            let outForbiddenOffsetHash: RMap<String, String> = RMap(key: outgoingForbiddenOffsetKey)
            let forbiddenOutOffsetString = outForbiddenOffsetHash[forbiddenOffsetSequenceKey] ?? "--"
            let forbiddenOutOffsetCountString = outForbiddenOffsetHash[forbiddenOffsetByteCountKey] ?? "--"
            let forbiddenOutOffsetIndexString = outForbiddenOffsetHash[forbiddenOffsetIndexKey] ?? "--"
            let forbiddenOutOffsetAccString = outForbiddenOffsetHash[forbiddenOffsetAccuracyKey] ?? "--"
            
            let inRequiredOffsetHash: RMap<String, String> = RMap(key: incomingRequiredOffsetKey)
            let requiredInOffsetString = inRequiredOffsetHash[requiredOffsetSequenceKey] ?? "--"
            let requiredInOffsetCountString = inRequiredOffsetHash[requiredOffsetByteCountKey] ?? "--"
            let requiredInOffsetIndexString = inRequiredOffsetHash[requiredOffsetIndexKey] ?? "--"
            let requiredInOffsetAccString = inRequiredOffsetHash[requiredOffsetAccuracyKey] ?? "--"
            
            let inForbiddenOffsetHash: RMap<String, String> = RMap(key: incomingForbiddenOffsetKey)
            let forbiddenInOffsetString: String = inForbiddenOffsetHash[forbiddenOffsetSequenceKey] ?? "--"
            let forbiddenInOffsetCountString = inForbiddenOffsetHash[forbiddenOffsetByteCountKey] ?? "--"
            let forbiddenInOffsetIndexString = inForbiddenOffsetHash[forbiddenOffsetIndexKey] ?? "--"
            let forbiddenInOffsetAccString = inForbiddenOffsetHash[forbiddenOffsetAccuracyKey] ?? "--"
            
            // Timing (milliseconds)
            let requiredTimingSet: RSortedSet<Int> = RSortedSet(key: requiredTimeDiffKey)
            let requiredTimingTuple: (Int, Float)? = requiredTimingSet.last
            let forbiddenTimingSet: RSortedSet<Int> = RSortedSet(key: forbiddenTimeDiffKey)
            let forbiddenTimingTuple: (Int, Float)? = forbiddenTimingSet.last
            
            // TLS Common Names
            let requiredTLSNamesSet: RSortedSet<String> = RSortedSet(key: allowedTlsScoreKey)
            let requiredTLSNamesTuple: (String, Float)? = requiredTLSNamesSet.last
            
            let forbiddenTLSNamesSet: RSortedSet<String> = RSortedSet(key: blockedTlsScoreKey)
            let forbiddenTLSNamesTuple: (String, Float)? = forbiddenTLSNamesSet.last
            
            // Lengths
            let requiredOutLengthSet: RSortedSet<Int> = RSortedSet(key: outgoingRequiredLengthsKey)
            let requiredOutLengthTuple: (Int, Float)? = requiredOutLengthSet.last
            
            let forbiddenOutLengthSet: RSortedSet<Int> = RSortedSet(key: outgoingForbiddenLengthsKey)
            let forbiddenOutLengthTuple: (Int, Float)? = forbiddenOutLengthSet.last
            
            let requiredInLengthSet: RSortedSet<Int> = RSortedSet(key: incomingRequiredLengthsKey)
            let requiredInLengthTuple: (Int, Float)? = requiredInLengthSet.last
            
            let forbiddenInLengthSet: RSortedSet<Int> = RSortedSet(key: incomingForbiddenLengthsKey)
            let forbiddenInLengthTuple: (Int, Float)? = forbiddenInLengthSet.last
            
            // Entropy
            let requiredOutEntropySet: RSortedSet<Int> = RSortedSet(key: outgoingRequiredEntropyKey)
            let requiredOutEntropyTuple: (Int, Float)? = requiredOutEntropySet.last
            
            let forbiddenOutEntropySet: RSortedSet<Int> = RSortedSet(key: outgoingForbiddenEntropyKey)
            let forbiddenOutEntropyTuple: (Int, Float)? = forbiddenOutEntropySet.last
            
            let requiredInEntropySet: RSortedSet<Int> = RSortedSet(key: incomingRequiredEntropyKey)
            let requiredInEntropyTuple: (Int, Float)? = requiredInEntropySet.last
            
            let forbiddenInEntropySet: RSortedSet<Int> = RSortedSet(key: incomingForbiddenEntropyKey)
            let forbiddenInEntropyTuple: (Int, Float)? = forbiddenInEntropySet.last
            
            //Float Subsequences
            let requiredOutFloatSequenceSet: RSortedSet<Data> = RSortedSet(key: outgoingRequiredFloatSequencesKey)
            let requiredOutFloatSequenceTuple: (Data, Float)? = requiredOutFloatSequenceSet.last
            
            let forbiddenOutFloatSequenceSet: RSortedSet<Data> = RSortedSet(key: outgoingForbiddenFloatSequencesKey)
            let forbiddenOutFloatSequenceTuple: (Data, Float)? = forbiddenOutFloatSequenceSet.last
            
            let requiredInFloatSequenceSet: RSortedSet<Data> = RSortedSet(key: incomingRequiredFloatSequencesKey)
            let requiredInFloatSequenceTuple: (Data, Float)? = requiredInFloatSequenceSet.last
            
            let forbiddenInFloatSequenceSet: RSortedSet<Data> = RSortedSet(key: incomingForbiddenFloatSequencesKey)
            let forbiddenInFloatSequenceTuple: (Data, Float)? = forbiddenInFloatSequenceSet.last
            
            DispatchQueue.main.async
                {
                    self.allowedPacketsSeen = "\(allowedPacketsSeenValue ?? 0)"
                    self.allowedPacketsAnalyzed = "\(allowedPacketsAnalyzedValue ?? 0)"
                    self.blockedPacketsSeen = "\(blockedPacketsSeenValue ?? 0)"
                    self.blockedPacketsAnalyzed = "\(blockedPacketsAnalyzedValue ?? 0)"
                    
                    // Offset Subsequences
                    self.requiredOutOffset = requiredOutOffsetString
                    self.requiredOutOffsetCount = requiredOutOffsetCountString
                    self.requiredOutOffsetIndex = requiredOutOffsetIndexString
                    self.requiredOutOffsetAcc = requiredOutOffsetAccString
                    
                    self.forbiddenOutOffset = forbiddenOutOffsetString
                    self.forbiddenOutOffsetCount = forbiddenOutOffsetCountString
                    self.forbiddenOutOffsetIndex = forbiddenOutOffsetIndexString
                    self.forbiddenOutOffsetAcc = forbiddenOutOffsetAccString
                    
                    self.requiredInOffset = requiredInOffsetString
                    self.requiredInOffsetCount = requiredInOffsetCountString
                    self.requiredInOffsetIndex = requiredInOffsetIndexString
                    self.requiredInOffsetAcc = requiredInOffsetAccString
                    
                    self.forbiddenInOffset = forbiddenInOffsetString
                    self.forbiddenInOffsetCount = forbiddenInOffsetCountString
                    self.forbiddenInOffsetIndex = forbiddenInOffsetIndexString
                    self.forbiddenInOffsetAcc = forbiddenInOffsetAccString
                    
                    // Timing (milliseconds)
                    if let rtMember: Int = requiredTimingTuple?.0, let rtScore: Float = requiredTimingTuple?.1
                    {
                        self.requiredTiming = "\(rtMember) ms"
                        self.requiredTimeAcc = "\(rtScore)"
                    }
                    else
                    {
                        self.requiredTiming = "--"
                        self.requiredTimeAcc = "--"
                    }
                    
                    if let ftMember = forbiddenTimingTuple?.0, let ftScore = forbiddenTimingTuple?.1
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
                    if let rTLSMember = requiredTLSNamesTuple?.0, let rTLSScore = requiredTLSNamesTuple?.1
                    {
                        self.requiredTLSName = rTLSMember
                        self.requiredTLSNameAcc = "\(rTLSScore)"
                    }
                    else
                    {
                        self.requiredTLSName = "--"
                        self.requiredTLSNameAcc = "--"
                    }
                    
                    if let fTLSMember = forbiddenTLSNamesTuple?.0, let fTLSScore = forbiddenTLSNamesTuple?.1
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
                    if let rolMember = requiredOutLengthTuple?.0, let rolScore = requiredOutLengthTuple?.1
                    {
                        self.requiredOutLength = "\(rolMember)"
                        self.requiredOutLengthAcc = "\(rolScore)"
                    }
                    else
                    {
                        self.requiredOutLength = "--"
                        self.requiredOutLengthAcc = "--"
                    }
                    
                    if let folMember = forbiddenOutLengthTuple?.0, let folScore = forbiddenOutLengthTuple?.1
                    {
                        self.forbiddenOutLength = "\(folMember)"
                        self.forbiddenOutLengthAcc = "\(folScore)"
                    }
                    else
                    {
                        self.forbiddenOutLength = "--"
                        self.forbiddenOutLengthAcc = "--"
                    }
                    
                    if let rilMember = requiredInLengthTuple?.0, let rilScore = requiredInLengthTuple?.1
                    {
                        self.requiredInLength = "\(rilMember)"
                        self.requiredInLengthAcc = "\(rilScore)"
                    }
                    else
                    {
                        self.requiredInLength = "--"
                        self.requiredInLengthAcc = "--"
                    }
                    
                    if let filMember = forbiddenInLengthTuple?.0, let filScore = forbiddenInLengthTuple?.1
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
                    if let roeMember = requiredOutEntropyTuple?.0, let roeScore = requiredOutEntropyTuple?.1
                    {
                        self.requiredOutEntropy = "\(roeMember)"
                        self.requiredOutEntropyAcc = "\(roeScore)"
                    }
                    else
                    {
                        self.requiredOutEntropy = "--"
                        self.requiredOutEntropyAcc = "--"
                    }
                    
                    if let foeMember = forbiddenOutEntropyTuple?.0, let foeScore = forbiddenOutEntropyTuple?.1
                    {
                        self.forbiddenOutEntropy = "\(foeMember)"
                        self.forbiddenOutEntropyAcc = "\(foeScore)"
                    }
                    else
                    {
                        self.forbiddenOutEntropy = "--"
                        self.forbiddenOutEntropyAcc = "--"
                    }
                    
                    if let rieMember = requiredInEntropyTuple?.0, let rieScore = requiredInEntropyTuple?.1
                    {
                        self.requiredInEntropy = "\(rieMember)"
                        self.requiredInEntropyAcc = "\(rieScore)"
                    }
                    else
                    {
                        self.requiredInEntropy = "--"
                        self.requiredInEntropyAcc = "--"
                    }
                    
                    if let fieMember = forbiddenInEntropyTuple?.0, let fieScore = forbiddenInEntropyTuple?.1
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
                    if let roFloatSeqMember = requiredOutFloatSequenceTuple?.0, let roFloatSeqScore = requiredOutFloatSequenceTuple?.1
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
                    
                    if let foFloatSeqMember = forbiddenOutFloatSequenceTuple?.0, let foFloatSeqScore = forbiddenOutFloatSequenceTuple?.1
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
                    
                    if let riFloatSeqMemeber = requiredInFloatSequenceTuple?.0, let riFloatSeqScore = requiredInFloatSequenceTuple?.1
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
                    
                    if let fiFloatSeqMember = forbiddenInFloatSequenceTuple?.0, let fiFloatSeqScore = forbiddenInFloatSequenceTuple?.1
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

                    self.connectionInspector.analyzeConnections(configModel: self.configModel)
                }
            }
        }
        catch
        {
            print(error)
        }        
    }

}

