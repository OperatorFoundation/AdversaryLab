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
import CoreML

class ViewController: NSViewController, NSTabViewDelegate
{
    @objc dynamic var allowedPacketsSeen = "Loading..."
    @objc dynamic var allowedPacketsAnalyzed = "Loading..."
    @objc dynamic var blockedPacketsSeen = "Loading..."
    @objc dynamic var blockedPacketsAnalyzed = "Loading..."
    
    @objc dynamic var requiredTiming = "--"
    @objc dynamic var forbiddenTiming = "--"
    @objc dynamic var timeTAcc = "--"
    @objc dynamic var timeVAcc = "--"
    @objc dynamic var timeEAcc = "--"
    
    @objc dynamic var requiredTLSName = "--"
    @objc dynamic var forbiddenTLSName = "--"
    @objc dynamic var tlsTAcc = "--"
    @objc dynamic var tlsVAcc = "--"
    @objc dynamic var tlsEAcc = "--"
    
    @objc dynamic var requiredOutLength = "--"
    @objc dynamic var forbiddenOutLength = "--"
    @objc dynamic var outLengthTAcc = "--"
    @objc dynamic var outLengthVAcc = "--"
    @objc dynamic var outLengthEAcc = "--"
    
    @objc dynamic var requiredInLength = "--"
    @objc dynamic var forbiddenInLength = "--"
    @objc dynamic var inLengthTAcc = "--"
    @objc dynamic var inLengthVAcc = "--"
    @objc dynamic var inLengthEAcc = "--"
    
    @objc dynamic var requiredOutEntropy = "--"
    @objc dynamic var forbiddenOutEntropy = "--"
    @objc dynamic var outEntropyTAcc = "--"
    @objc dynamic var outEntropyVAcc = "--"
    @objc dynamic var outEntropyEAcc = "--"
    @objc dynamic var requiredInEntropy = "--"
    @objc dynamic var forbiddenInEntropy = "--"
    @objc dynamic var inEntropyTAcc = "--"
    @objc dynamic var inEntropyVAcc = "--"
    @objc dynamic var inEntropyEAcc = "--"
    
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
    
    @IBOutlet weak var tabView: NSTabView!
    @IBOutlet weak var databaseNameLabel: NSTextField!
    @IBOutlet weak var removePacketsCheck: NSButton!
    @IBOutlet weak var enableSequencesCheck: NSButton!
    @IBOutlet weak var enableTLSCheck: NSButton!
    @IBOutlet weak var processPacketsButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var loadDataButton: NSButtonCell!
    
    let connectionInspector = ConnectionInspector()
    
    var streaming: Bool = false
    var configModel = ProcessingConfigurationModel()
    
    // MARK: - Test Mode
    @objc dynamic var modelName = ""
    @objc dynamic var timingAccuracy = ""
    @objc dynamic var tlsAccuracy = ""
    @objc dynamic var inLengthAccuracy = ""
    @objc dynamic var outLengthAccuracy = ""
    @objc dynamic var inEntropyAccuracy = ""
    @objc dynamic var outEntropyAccuracy = ""
    
    @objc dynamic var inLengthProbability = ""
    @objc dynamic var outLengthProbability = ""
    @objc dynamic var inLengthClassification = ""
    @objc dynamic var outLengthClassification = ""
    
    
    var modelDirectoryURL: URL?
    
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        updateConfigModel()
        
        // Launch Redis Server
        RedisServerController.sharedInstance.launchRedisServer
        {
            (result) in
            
            switch result
            {
            case .okay(_):
                // Update Labels and Progress Indicator
                self.loadLabelData()
                self.updateProgressIndicator()
            case .otherProcessOnPort(let processName):
                showOtherProcessAlert(processName: processName)
            case .corruptRedisOnPort(let pidString):
                self.showCorruptRedisAlert(processPID: pidString)
            case .failure(let failureString):
                print("\nReceived failure on launch server: \(failureString ?? "")")
                quitAdversaryLab()
            }
        }
        
        // Subscribe to pubsub to know when to inspect a new connection
        subscribeToNewConnectionsChannel()

        // Also update labels and progress indicator when new data is available
        NotificationCenter.default.addObserver(self, selector: #selector(loadLabelData), name: .updateStats, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateProgressIndicator), name: .updateProgressIndicator, object: nil)
        
        // FIXME: getting the filename after switching files jams us up
        NotificationCenter.default.addObserver(forName: .updateDBFilename, object: nil, queue: .main)
        { (notification) in
            self.databaseNameLabel.stringValue = Auburn.dbfilename ?? "unknown"
        }
    }
    
    override func viewWillAppear()
    {
        super.viewWillAppear()
        
        self.databaseNameLabel.stringValue = Auburn.dbfilename ?? "--"
    }
    
    // MARK: - IBActions
    @IBAction func runClick(_ sender: NSButton)
    {
        print("\nYou clicked the process packets button 👻")
        updateConfigModel()
        
        if sender.state == .on
        {
            // Identify which tab we need to update
            guard let identifier = tabView.selectedTabViewItem?.identifier as? String,
                let currentTab = TabIds(rawValue: identifier)
                else { return }
            
            switch currentTab
            {
            case .TestMode:
                configModel.modelName = modelName
                connectionInspector.analyzeConnections(configModel: configModel)
                updateProgressIndicator()
            case .TrainingMode: // In Training mode we need a name so we can save the model files
                if let name = showNameModelAlert()
                {
                    print("Time to analyze some things.")
                    configModel.modelName = name
                    connectionInspector.analyzeConnections(configModel: configModel)
                    updateProgressIndicator()
                }
                else
                {
                    sender.state = .off
                }
            }
        }
        else
        {
            print("Pause bot engage!! 🤖")
            updateProgressIndicator()
        }
        
        self.loadLabelData()
    }
    
    @IBAction func testModeClicked(_ sender: NSButton)
    {
        guard let window = view.window
            else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["adversary"]
        
        panel.beginSheetModal(for: window)
        {
            (result) in
            
            guard result == NSApplication.ModalResponse.OK
                else { return }
            
            let selectedDirURL = panel.urls[0]

            self.performSegue(withIdentifier: "TestModeSegue", sender: selectedDirURL)
        }
    }
    
    @IBAction func liveCaptureClick(_ sender: NSButton)
    {
        print("\n⏺  You clicked the live capture button 👻")
        
        if sender.state == .on
        {
            print("Time to record some packets.")
            showCaptureAlert()
        }
        else
        {
            print("🛑  Stop recording!! 🛑")
            guard let helper = helperClient
                else { return }
            
            helper.stopAdversaryLabClient()
        }
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
    
    @IBAction func loadDataClicked(_ sender: NSButton)
    {
        guard let window = view.window
            else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["rdb"]
        
        panel.beginSheetModal(for: window)
        {
            (result) in
            
            guard result == NSApplication.ModalResponse.OK
                else { return }
            
            let selectedFileURL = panel.urls[0]
            
            RedisServerController.sharedInstance.switchDatabaseFile(withFile: selectedFileURL, completion:
            {
                (success) in
                
                self.databaseNameLabel.stringValue = Auburn.dbfilename ?? "--"
                self.loadLabelData()
            })
        }
    }
    
    // MARK: - TabView Delegate
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?)
    {
        // Identify which tab was selected
        guard let identifier = tabView.selectedTabViewItem?.identifier as? String,
            let currentTab = TabIds(rawValue: identifier)
            else { return }
        
        switch currentTab
        {
        case .TrainingMode:
            configModel.trainingMode = true
        case .TestMode:
            configModel.trainingMode = false
            testModeSelected()
        }
        
        loadLabelData()
    }
    
    // MARK: - Test Mode
    
    func testModeSelected()
    {
        // Make sure that we have gotten an Adversary file and unpacked it to a temporary directory
        // TODO: Delete this directory on program exit
        guard modelDirectoryURL != nil
            else
        {
            // Get the user to select the correct .adversary file
            if let selectedURL = showSelectAdversaryFileAlert()
            {
                // Model Group Name should be the same as the directory
                modelName = selectedURL.deletingPathExtension().lastPathComponent
                
                // Unpack to a temporary directory
                modelDirectoryURL = MLModelController().unpack(adversaryURL: selectedURL)
            }
            else
            {
                // User likely selected  cancel in the choose file alert
                // Return to the training tab
                let trainingTab = NSTabViewItem(identifier: TabIds.TrainingMode)
                tabView.selectTabViewItem(trainingTab)
            }
            
            return
        }
        
        loadLabelData()
    }

    // MARK: - Alerts
    func showCorruptRedisAlert(processPID: String)
    {
        let alert = NSAlert()
        alert.messageText = "A redis server is already running"
        alert.informativeText = "This server will need to be shut down in order to proceed. Manually shut down this server?"
        
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "Quit")
        
        alert.beginSheetModal(for: self.view.window!)
        {
            (response) in
            
            switch response
            {
            case .alertFirstButtonReturn:
                print("\nUser chose to quit Adversary Lab rather than kill server.")
                quitAdversaryLab()
            case .alertSecondButtonReturn:
                // TODO: Kill Redis Server
                print("\nUser chose to manually kill Redis server with PID: \(processPID)")
                RedisServerController.sharedInstance.killProcess(pid: processPID, completion:
                {
                    (_) in
                    
                    // Launch Redis Server
                    RedisServerController.sharedInstance.launchRedisServer
                    {
                        (result) in
                        
                        switch result
                        {
                        case .okay(_):
                            // Update Labels and Progress Indicator
                            self.loadLabelData()
                            self.updateProgressIndicator()
                        case .otherProcessOnPort(let processName):
                            showOtherProcessAlert(processName: processName)
                        case .corruptRedisOnPort(let pidString):
                            self.showCorruptRedisAlert(processPID: pidString)
                        case .failure(let failureString):
                            print("\nReceived failure on launch server: \(failureString ?? "")")
                            quitAdversaryLab()
                        }
                    }
                })
            default:
                print("\nUnknown error user chose unknown option for redis server alert.")
            }
        }
    }
    
    func updateConfigModel()
    {
        // Update Configuration Model based on button states
        configModel.enableSequenceAnalysis = self.enableSequencesCheck.state == .on
        configModel.enableTLSAnalysis = self.enableTLSCheck.state == .on
        configModel.removePackets = self.removePacketsCheck.state == .on
        configModel.processingEnabled = self.processPacketsButton.state == .on
        
        guard let identifier = tabView.selectedTabViewItem?.identifier as? String,
            let currentTab = TabIds(rawValue: identifier)
            else { return }
        
        switch currentTab
        {
        case .TrainingMode:
            configModel.trainingMode = true
        case .TestMode:
            configModel.trainingMode = false
            testModeSelected()
        }
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
                
               self.loadLabelData()
            }
        }
    }
    
    @objc func loadLabelData()
    {
        // Updates Labels that are in the main window (always visible)
        
        // Get redis data in the utility queue and update the labels with the data in the main queue
        DispatchQueue.global(qos: .utility).async
        {
            let packetStatsDict: RMap<String, Int> = RMap(key: packetStatsKey)
            let allowedPacketsSeenValue: Int? = packetStatsDict[allowedPacketsSeenKey]
            let allowedPacketsAnalyzedValue: Int? = packetStatsDict[allowedPacketsAnalyzedKey]
            let blockedPacketsSeenValue: Int? = packetStatsDict[blockedPacketsSeenKey]
            let blockedPacketsAnalyzedValue: Int? = packetStatsDict[blockedPacketsAnalyzedKey]
            
            DispatchQueue.main.async
            {
                self.allowedPacketsSeen = "\(allowedPacketsSeenValue ?? 0)"
                self.allowedPacketsAnalyzed = "\(allowedPacketsAnalyzedValue ?? 0)"
                self.blockedPacketsSeen = "\(blockedPacketsSeenValue ?? 0)"
                self.blockedPacketsAnalyzed = "\(blockedPacketsAnalyzedValue ?? 0)"
                
                guard let identifier = self.tabView.selectedTabViewItem?.identifier as? String,
                    let currentTab = TabIds(rawValue: identifier)
                    else { return }
                
                switch currentTab
                {
                case .TrainingMode:
                    self.loadTrainingLabelData()
                case .TestMode:
                    self.loadTestLabelData()
                }
            }
        }
        
        // Identify which tab we need to update
    }
    
    func loadTestLabelData()
    {
        // Get redis data in the utility queue and update the labels with the data in the main queue
        DispatchQueue.global(qos: .utility).async
        {
            // Timing (milliseconds)
            let timingDictionary: RMap<String, Double> = RMap(key: timeDifferenceTestResultsKey)
            
            // TLS Common Names
            let tlsResults: RMap <String, String> = RMap(key: tlsTestResultsKey)
            let tlsAccuracy: RMap <String, Double> = RMap(key: tlsTestResultsKey)
            
            // Lengths
            let outLengthClassificationDictionary: RMap<String, String> = RMap(key: outgoingLengthClassificationKey)
            let outLengthClassification = outLengthClassificationDictionary[ColumnLabel.classification.rawValue]
            let outLengthClassificationProbabilityDictionary: RMap<String, String> = RMap(key: outgoingLengthClassificationProbKey)
            let outLengthClassificationProbability =  outLengthClassificationProbabilityDictionary[PredictionKey.classificationProbability.rawValue]
            
            let inLengthClassificationDictionary: RMap<String, String> = RMap(key: incomingLengthClassificationKey)
            let inLengthClassification = inLengthClassificationDictionary[ColumnLabel.classification.rawValue]
            let inLengthClassificationProbabilityDictionary: RMap<String, String> = RMap(key: incomingLengthClassificationProbKey)
            let inLengthClassificationProbability = inLengthClassificationProbabilityDictionary[PredictionKey.classificationProbability.rawValue]
            
            // TODO: Entropy
            
            DispatchQueue.main.async
            {
                if let testTimeEAcc = timingDictionary[timeDiffEAccKey]
                {
                    self.timingAccuracy = String(format: "%.2f", testTimeEAcc)
                }
                else
                {
                    self.timingAccuracy = "--"
                }
               
                self.loadDataButton.title = "Load Model File"
            }
        }
    }
    
    func loadTrainingLabelData()
    {
        // Get redis data in the utility queue and update the labels with the data in the main queue
        
        DispatchQueue.global(qos: .utility).async
        {
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
            let timingDictionary: RMap<String, Double> = RMap(key: timeDifferenceTrainingResultsKey)
            
            // TLS Common Names
            let tlsResults: RMap <String, String> = RMap(key: tlsTrainingResultsKey)
            let tlsAccuracy: RMap <String, Double> = RMap(key: tlsTrainingAccuracyKey)

            // Lengths
            let packetLengthsResults: RMap <String, Double> = RMap(key: packetLengthsTrainingResultsKey)
            
            // Entropy
            let entropyResults: RMap <String, Double> = RMap(key: entropyTrainingResultsKey)
            
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
                self.loadDataButton.title = "Load DB File"
                
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
                if let rTiming = timingDictionary[requiredTimeDiffKey],
                    let fTiming = timingDictionary[forbiddenTimeDiffKey],
                    let timeDiffTAcc = timingDictionary[timeDiffTAccKey],
                    let timeDiffVAcc = timingDictionary[timeDiffVAccKey],
                    let timeDiffEAcc = timingDictionary[timeDiffEAccKey]
                {
                    self.requiredTiming = String(format: "%.2f", rTiming) + "ms"
                    self.forbiddenTiming = String(format: "%.2f", fTiming) + "ms"
                    self.timeTAcc = String(format: "%.2f", timeDiffTAcc)
                    self.timeVAcc = String(format: "%.2f", timeDiffVAcc)
                    self.timeEAcc = String(format: "%.2f", timeDiffEAcc)
                }
                else
                {
                    self.requiredTiming = "--"
                    self.forbiddenTiming = "--"
                    self.timeTAcc = "--"
                    self.timeVAcc = "--"
                    self.timeEAcc = "--"
                }
                
                // TLS Common Names
                if let rTLS = tlsResults[requiredTLSKey],
                    let fTLS = tlsResults[forbiddenTLSKey],
                    let tlsTrainingAccuracy = tlsAccuracy[tlsTAccKey],
                    let tlsValidationAccuracy = tlsAccuracy[tlsVAccKey],
                    let tlsEvaluationAccuracy = tlsAccuracy[tlsEAccKey]
                {
                    self.requiredTLSName = rTLS
                    self.forbiddenTLSName = fTLS
                    self.tlsTAcc = String(format: "%.2f", tlsTrainingAccuracy)
                    self.tlsVAcc = String(format: "%.2f", tlsValidationAccuracy)
                    self.tlsEAcc = String(format: "%.2f", tlsEvaluationAccuracy)
                }
                else
                {
                    self.requiredTLSName = "--"
                    self.forbiddenTLSName = "--"
                    self.tlsTAcc = "--"
                    self.tlsVAcc = "--"
                    self.tlsEAcc = "--"
                }
                
                // Lengths
                if let outRequiredLength = packetLengthsResults[outgoingRequiredLengthKey],
                    let outForbiddenLength = packetLengthsResults[outgoingForbiddenLengthKey],
                    let outTrainingAcc = packetLengthsResults[outgoingLengthsTAccKey],
                    let outValidationAcc = packetLengthsResults[outgoingLengthsVAccKey],
                    let outEvaluationAcc = packetLengthsResults[outgoingLengthsEAccKey]
                {
                    self.requiredOutLength = String(format: "%.2f", outRequiredLength)
                    self.forbiddenOutLength = String(format: "%.2f", outForbiddenLength)
                    self.outLengthTAcc = String(format: "%.2f", outTrainingAcc)
                    self.outLengthVAcc = String(format: "%.2f", outValidationAcc)
                    self.outLengthEAcc = String(format: "%.2f", outEvaluationAcc)
                }
                else
                {
                    self.requiredOutLength = "--"
                    self.forbiddenOutLength = "--"
                    self.outLengthTAcc = "--"
                    self.outLengthVAcc = "--"
                    self.outLengthEAcc = "--"
                }
                
                if let inRequiredLength = packetLengthsResults[incomingRequiredLengthKey],
                    let inForbiddenLength = packetLengthsResults[incomingForbiddenLengthKey],
                    let inTrainingAcc = packetLengthsResults[incomingLengthsTAccKey],
                    let inValidationAcc = packetLengthsResults[incomingLengthsVAccKey],
                    let inEvaluationAcc = packetLengthsResults[incomingLengthsEAccKey]
                {
                    self.requiredInLength = String(format: "%.2f", inRequiredLength)
                    self.forbiddenInLength = String(format: "%.2f", inForbiddenLength)
                    self.inLengthTAcc = String(format: "%.2f", inTrainingAcc)
                    self.inLengthVAcc = String(format: "%.2f", inValidationAcc)
                    self.inLengthEAcc = String(format: "%.2f", inEvaluationAcc)
                }
                else
                {
                    self.requiredInLength = "--"
                    self.forbiddenInLength = "--"
                    self.inLengthTAcc = "--"
                    self.inLengthVAcc = "--"
                    self.inLengthEAcc = "--"
                }
                
                // Entropy
                if let rOutEntropy = entropyResults[outgoingRequiredEntropyKey],
                    let fOutEntropy = entropyResults[outgoingForbiddenEntropyKey],
                    let outEntropyTrainingAccuracy = entropyResults[outgoingEntropyTAccKey],
                    let outEntropyValidationAccuracy = entropyResults[outgoingEntropyVAccKey],
                    let outEntropyEvaluationAccuracy = entropyResults[outgoingEntropyEAccKey]
                {
                    self.requiredOutEntropy = String(format: "%.2f", rOutEntropy)
                    self.forbiddenOutEntropy = String(format: "%.2f", fOutEntropy)
                    self.outEntropyTAcc = String(format: "%.2f", outEntropyTrainingAccuracy)
                    self.outEntropyVAcc = String(format: "%.2f", outEntropyValidationAccuracy)
                    self.outEntropyEAcc = String(format: "%.2f", outEntropyEvaluationAccuracy)
                }
                else
                {
                    self.requiredOutEntropy = "--"
                    self.forbiddenOutEntropy = "--"
                    self.outEntropyTAcc = "--"
                    self.outEntropyVAcc = "--"
                    self.outEntropyEAcc = "--"
                }
                
                if let rInEntropy = entropyResults[incomingRequiredEntropyKey],
                    let fInEntropy = entropyResults[incomingForbiddenEntropyKey],
                    let inEntropyTrainingAccuracy = entropyResults[incomingEntropyTAccKey],
                    let inEntropyValidationAccuracy = entropyResults[incomingEntropyVAccKey],
                    let inEntropyEvaluationAccuracy = entropyResults[incomingEntropyEAccKey]
                {
                    self.requiredInEntropy = String(format: "%.2f", rInEntropy)
                    self.forbiddenInEntropy = String(format: "%.2f", fInEntropy)
                    self.inEntropyTAcc = String(format: "%.2f", inEntropyTrainingAccuracy)
                    self.inEntropyVAcc = String(format: "%.2f", inEntropyValidationAccuracy)
                    self.inEntropyEAcc = String(format: "%.2f", inEntropyEvaluationAccuracy)
                }
                else
                {
                    self.requiredInEntropy = "--"
                    self.forbiddenInEntropy = "--"
                    self.inEntropyTAcc = "--"
                    self.inEntropyVAcc = "--"
                    self.inEntropyEAcc = "--"
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
            print("\nSubscribing to redis channel.")
            try redis.subscribe(channel:newConnectionsChannel)
            { (maybeRedisType, maybeError) in
               
                print("\nReceived redis subscribe callback.")
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
                        print("\nReceived a message: \(thisElement.string)")
                        continue
                    }

                    self.connectionInspector.analyzeConnections(configModel: self.configModel)
                    
                }
                self.loadLabelData()
            }
        }
        catch
        {
            print(error)
        }        
    }

}

// MARK: - TabView Identifiers

enum TabIds: String
{
    case TrainingMode
    case TestMode
}

