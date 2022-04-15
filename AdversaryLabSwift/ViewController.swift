//
//  ViewController.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 1/11/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Cocoa
import CoreML
import SwiftUI

import Auburn
import Axis
import RedShot
import Datable
import Charts

class ViewController: NSViewController, NSTabViewDelegate, ChartViewDelegate
{
    @IBOutlet weak var enableTLSCheckButton: NSButton!
    @IBOutlet weak var enableSequencesCheckButton: NSButton!
    @IBOutlet weak var timingChartView: LineChartView!
    @IBOutlet weak var entropyChartView: LineChartView!
    @IBOutlet weak var lengthChartView: LineChartView!
    @IBOutlet weak var activityIndicator: NSProgressIndicator!
    @IBSegueAction func chartsSegue(_ coder: NSCoder) -> NSViewController? {
        return NSHostingController(coder: coder, rootView: ChartsUIView())
    }
    
    @objc dynamic var aConnectionsCountLabel = "Connections"
    @objc dynamic var allowedPacketsSeen = "Loading..."
    @objc dynamic var aConnectionsAnalyzedLabel = "Connections Analyzed"
    @objc dynamic var allowedPacketsAnalyzed = "Loading..."
    @objc dynamic var bConnectionsCountLabel = "Connections"
    @objc dynamic var blockedPacketsSeen = "Loading..."
    @objc dynamic var bConnectionsAnalyzedLabel = "Connections Analyzed"
    @objc dynamic var blockedPacketsAnalyzed = "Loading..."
    
    @objc dynamic var aConnectionsOutgoingTitleLabel = "Transport A Outgoing Packets"
    @objc dynamic var aConnectionsOutgoingValueLabel = "Loading..."
    @objc dynamic var aConnectionsIncomingTitleLabel = "Transport A Incoming Packets"
    @objc dynamic var aConnectionsIncomingValueLabel = "Loading..."
    @objc dynamic var bConnectionsOutgoingTitleLabel = "Transport B Outgoing Packets"
    @objc dynamic var bConnectionsOutgoingValueLabel = "Loading..."
    @objc dynamic var bConnectionsIncomingTitleLabel = "Transport B Incoming Packets"
    @objc dynamic var bConnectionsIncomingValueLabel = "Loading..."
    
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
    
    // MARK: All Features Training Labels
    @objc dynamic var allAllowedOutLength = "--"
    @objc dynamic var allBlockedOutLength = "--"
    @objc dynamic var allAllowedOutEntropy = "--"
    @objc dynamic var allBlockedOutEntropy = "--"
    @objc dynamic var allAllowedInLength = "--"
    @objc dynamic var allBlockedInLength = "--"
    @objc dynamic var allAllowedInEntropy = "--"
    @objc dynamic var allBlockedInEntropy = "--"
    @objc dynamic var allAllowedTiming = "--"
    @objc dynamic var allBlockedTiming = "--"
    @objc dynamic var allAllowedTLS = "--"
    @objc dynamic var allBlockedTLS = "--"
    @objc dynamic var allEvaluationAccuracy = "--"
    
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
    
    // MARK: - Test Mode Labels
    @objc dynamic var modelName = "--"

    @objc dynamic var allFeaturesAAccuracyLabel = "Predictions Accuracy"
    @objc dynamic var allFeaturesAllowAccuracy = "--"
    @objc dynamic var allFeaturesBAccuracyLabel = "Predictions Accuracy"
    @objc dynamic var allFeaturesBlockAccuracy = "--"
    
    @objc dynamic var aTimingLabel = "Timing: "
    @objc dynamic var timingAllowed = "--"
    @objc dynamic var aTimingAccuracyLabel = "Timing Accuracy: "
    @objc dynamic var timingAllowAccuracy = "--"
    @objc dynamic var bTimingLabel = "Timing: "
    @objc dynamic var timingBlocked = "--"
    @objc dynamic var bTimingAccuracyLabel = "Timing Accuracy: "
    @objc dynamic var timingBlockAccuracy = "--"
    
    @objc dynamic var aTLS12Label = "TLS: "
    @objc dynamic var tls12Allowed = "--"
    @objc dynamic var aTLS12AccuracyLabel = "TLS Accuracy: "
    @objc dynamic var tls12AllowAccuracy = "--"
    @objc dynamic var bTLS12Label = "TLS"
    @objc dynamic var tls12Blocked = "--"
    @objc dynamic var bTLS12AccuracyLabel = "TLS Accuracy: "
    @objc dynamic var tls12BlockAccuracy = "--"
    
    @objc dynamic var aOutLengthLabel = "Out Length: "
    @objc dynamic var outLengthAllowed = "--"
    @objc dynamic var aOutLengthAccuracyLabel = "Out Length Accuracy: "
    @objc dynamic var outLengthAllowAccuracy = "--"
    @objc dynamic var bOutLengthLabel = "Out Length: "
    @objc dynamic var outLengthBlocked = "--"
    @objc dynamic var bOutLengthAccuracyLabel = "Out Length Accuracy: "
    @objc dynamic var outLengthBlockAccuracy = "--"
    @objc dynamic var aInLengthLabel = "In Length: "
    @objc dynamic var inLengthAllowed = "--"
    @objc dynamic var aInLengthAccuracyLabel = "In Length Accuracy: "
    @objc dynamic var inLengthAllowAccuracy = "--"
    @objc dynamic var bInLengthLabel = "In Length: "
    @objc dynamic var inLengthBlocked = "--"
    @objc dynamic var bInLengthAccuracyLabel = "In Length Accuracy: "
    @objc dynamic var inLengthBlockAccuracy = "--"

    @objc dynamic var aOutEntropyLabel = "Out Entropy: "
    @objc dynamic var outAllowedEntropy = "--"
    @objc dynamic var aOutEntropyAccuracyLabel = "Out Entropy Accuracy: "
    @objc dynamic var outEntropyAllowAccuracy = "--"
    @objc dynamic var bOutEntropyLabel = "Out Entropy: "
    @objc dynamic var outBlockedEntropy = "--"
    @objc dynamic var bOutEntropyAccuracyLabel = "Out Entropy Accuracy: "
    @objc dynamic var outEntropyBlockAccuracy = "--"
    @objc dynamic var aInEntropyLabel = "In Entropy: "
    @objc dynamic var inAllowedEntropy = "--"
    @objc dynamic var aInEntropyAccuracyLabel = "In Entropy Accuracy: "
    @objc dynamic var inEntropyAllowAccuracy = "--"
    @objc dynamic var bInEntropyLabel = "In Entropy: "
    @objc dynamic var inBlockedEntropy = "--"
    @objc dynamic var bInEntropyAccuracyLabel = "In Entropy Accuracy: "
    @objc dynamic var inEntropyBlockAccuracy = "--"

    @objc dynamic var vcTransportAName = "Transport A"
    @objc dynamic var vcTransportBName = "Transport B"
    
    let dataProcessing = DataProcessing()
    let circleRadius: CGFloat = 2.5
    var modelDirectoryURL: URL?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Identify which tab was selected
        guard let identifier = tabView.selectedTabViewItem?.identifier as? String,
            let currentTab = TabIds(rawValue: identifier)
            else { return }
        
        updateButtons(currentTab: currentTab)
        updateCharts()
        updateConfigModel()
        
        // Launch Redis Server
        RedisServerController.sharedInstance.launchRedisServer
        {
            (result) in
            
            self.handleLaunchRedisResponse(result: result)
        }
        
        // Subscribe to pubsub to know when to inspect a new connection
        RedisServerController.sharedInstance.subscribeToNewConnectionsChannel()

        // Also update labels and progress indicator when new data is available
        NotificationCenter.default.addObserver(self, selector: #selector(updateStats), name: .updateStats, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateProgressIndicator), name: .updateProgressIndicator, object: nil)
    }
    
    @objc func updateStats()
    {
        DispatchQueue.main.async
        {
            if !self.activityIndicator.isHidden
            {
                self.activityIndicator.stopAnimation(nil)
            }
            
            if self.loadDataButton.state == .on
            {
                self.loadDataButton.state = .off
            }
            
            if self.processPacketsButton.state == .on
            {
                self.processPacketsButton.state = .off
            }
        }
        
        loadLabelData()
    }

    // MARK: - IBActions
    @IBAction func runClick(_ sender: NSButton)
    {
        activityIndicator.startAnimation(nil)
        print("\nYou clicked the process packets button 👻")
        updateConfigModel()
        
        if sender.state == .on
        {
            // Identify which tab we need to update
            guard let identifier = tabView.selectedTabViewItem?.identifier as? String,
                let currentTab = TabIds(rawValue: identifier)
                else
            {
                stopActivityIndicator()
                return
                
            }
            
            switch currentTab
            {
            case .TestMode:
                runTest()
            case .TrainingMode:
                runTraining()
            case .DataMode:
                print("Data mode selected. Nothing to do here.")
                stopActivityIndicator()
                return
            }
        }
        else
        {
            print("Pause bot engage!! 🤖")
            updateProgressIndicator()
            stopActivityIndicator()
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
    
    @IBAction func loadDataClicked(sender: NSButton)
    {
        loadDataButton.isEnabled = false
        activityIndicator.startAnimation(nil)
        
        guard let identifier = tabView.selectedTabViewItem?.identifier as? String,
            let currentTab = TabIds(rawValue: identifier)
            else { return }
        
        switch currentTab
        {
        case .TestMode:
            // Get the user to select the correct .adversary file
            if let selectedURL = showSelectAdversaryFileAlert()
            {
                // Model Group Name should be the same as the directory
                modelName = selectedURL.deletingPathExtension().lastPathComponent
                configModel.modelName = modelName
                
                // Unpack to a temporary directory
                if let maybeModelDirectory = FileController().unpack(adversaryURL: selectedURL)
                {
                    modelDirectoryURL = maybeModelDirectory
                    runTest()
                }
                else
                {
                    print("🚨  Failed to unpack the selected adversary file.  🚨")
                }
            }
            
            loadDataButton.isEnabled = true
            stopActivityIndicator()
  
        case .TrainingMode:
            DispatchQueue.main.async {
                self.activityIndicator.startAnimation(nil)
            }
            
            if let selectedFileURL = showRethinkFileAlert()
            {
                FileController().loadSongFile(fileURL: selectedFileURL)
                { (_) in
                    self.refreshDBUI()
                }

            }
            else
            {
                refreshDBUI()
            }
            
        case .DataMode:
            print("Data mode selected. Nothing to do here.")
        }
    }
    
    func refreshDBUI()
    {
        // TODO: Replace this
        let databaseName = "--"
        
        DispatchQueue.main.async
        {
            self.databaseNameLabel.stringValue = databaseName
            self.loadDataButton.isEnabled = true
            self.loadLabelData()
            self.activityIndicator.stopAnimation(nil)
        }
    }
    
    func stopActivityIndicator()
    {
        DispatchQueue.main.async
        {
            self.activityIndicator.stopAnimation(nil)
        }
    }
    
    // MARK: - Charts
    
//    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight)
//    {
//        let chartViewController = ConnectionChartViewController()
//        var chartDescription = ""
//        if let description = chartView.chartDescription, let descriptionText = description.text
//        {
//            chartDescription = descriptionText
//        }
//
//        chartViewController.titleString = "\(chartDescription): \(entry.y)"
//
//
//        let popover = NSPopover()
//        popover.behavior = .transient
//        popover.contentViewController = chartViewController
//        popover.show(relativeTo: chartView.bounds, of: chartView, preferredEdge: NSRectEdge.minY)
//    }
    
    func updateCharts()
    {
        updateTimeChart()
        updateEntropyChart()
        updateLengthChart()
    }
    
    func updateLengthChart()
    {
        let aOutLengths = packetLengths.outgoingA.expanded
        let aInLengths = packetLengths.incomingA.expanded
        let bOutLengths = packetLengths.outgoingB.expanded
        let bInLengths = packetLengths.incomingB.expanded
        
        let allowedInLengthsEntry = chartDataEntry(fromArray: aInLengths)
        let allowedOutLengthsEntry = chartDataEntry(fromArray: aOutLengths)
        let blockedInLengthsEntry = chartDataEntry(fromArray: bInLengths)
        let blockedOutLengthsEntry = chartDataEntry(fromArray: bOutLengths)
        
        let allowedInLine = LineChartDataSet(entries: allowedInLengthsEntry, label: "\(transportA) Incoming Packet Lengths")
        allowedInLine.colors = [NSUIColor.blue]
        allowedInLine.circleColors = [NSUIColor.blue]
        allowedInLine.circleRadius = 3
        allowedInLine.drawCirclesEnabled = true
        allowedInLine.circleHoleRadius = 1
        allowedInLine.circleHoleColor = NSUIColor.clear
        allowedInLine.drawValuesEnabled = false
        let allowedOutLine = LineChartDataSet(entries: allowedOutLengthsEntry, label: "\(transportA) Outgoing Packet Lengths")
        allowedOutLine.colors = [NSUIColor.magenta]
        allowedOutLine.circleColors = [NSUIColor.magenta]
        allowedOutLine.circleRadius = 4.5
        allowedOutLine.drawCirclesEnabled = true
        allowedOutLine.circleHoleRadius = 2.5
        allowedOutLine.circleHoleColor = NSUIColor.clear
        allowedOutLine.drawValuesEnabled = false
        let blockedInLine = LineChartDataSet(entries: blockedInLengthsEntry, label: "\(transportB) Incoming Packet Lengths")
        blockedInLine.colors = [NSUIColor.red]
        blockedInLine.circleColors = [NSUIColor.red]
        blockedInLine.circleRadius = 6
        blockedInLine.drawCirclesEnabled = true
        blockedInLine.circleHoleRadius = 4.5
        blockedInLine.circleHoleColor = NSUIColor.clear
        blockedInLine.drawValuesEnabled = false
        let blockedOutLine = LineChartDataSet(entries: blockedOutLengthsEntry, label: "\(transportB) Outgoing Packet Lengths")
        blockedOutLine.colors = [NSUIColor.systemGreen ]
        blockedOutLine.circleColors = [NSUIColor.systemGreen]
        blockedOutLine.circleRadius = 7.5
        blockedOutLine.drawCirclesEnabled = true
        blockedOutLine.circleHoleRadius = 5.5
        blockedOutLine.circleHoleColor = NSUIColor.clear
        blockedOutLine.drawValuesEnabled = false
        
        let data = LineChartData()
        data.addDataSet(allowedInLine)
        data.addDataSet(allowedOutLine)
        data.addDataSet(blockedInLine)
        data.addDataSet(blockedOutLine)
        
        lengthChartView.delegate = self
        lengthChartView.highlightPerDragEnabled = true
        lengthChartView.data = data
        lengthChartView.chartDescription?.text = "Packet Length"
    }
    
    func updateEntropyChart()
    {
        var aInEntropy = packetEntropies.incomingA.sorted()
        for index in 0 ..< aInEntropy.count
        {
            aInEntropy[index] = (aInEntropy[index]*1000).rounded()/1000
        }
        
        var aOutEntropy = packetEntropies.outgoingA.sorted()
        for index in 0 ..< aOutEntropy.count
        {
            aOutEntropy[index] = (aOutEntropy[index]*1000).rounded()/1000
        }
        
        var bInEntropy = packetEntropies.incomingB.sorted()
        for index in 0 ..< bInEntropy.count
        {
            bInEntropy[index] = (bInEntropy[index]*1000).rounded()/1000
        }
        
        var bOutEntropy = packetEntropies.outgoingB.sorted()
        for index in 0 ..< bOutEntropy.count
        {
            bOutEntropy[index] = (bOutEntropy[index]*1000).rounded()/1000
        }
        
        let aInEntropyEntry = chartDataEntry(fromArray: aInEntropy)
        let aOutEntropyEntry = chartDataEntry(fromArray: aOutEntropy)
        let bInEntropyEntry = chartDataEntry(fromArray: bInEntropy)
        let bOutEntropyEntry = chartDataEntry(fromArray: bOutEntropy)
        
        let aInLine = LineChartDataSet(entries: aInEntropyEntry, label: "\(transportA) Incoming Entropy")
        aInLine.colors = [NSUIColor.blue]
        aInLine.circleColors = [NSUIColor.blue]
        aInLine.circleRadius = 2
        aInLine.drawCirclesEnabled = true
        aInLine.circleHoleRadius = 1
        aInLine.circleHoleColor = NSUIColor.clear
        aInLine.drawValuesEnabled = false
        let aOutLine = LineChartDataSet(entries: aOutEntropyEntry, label: "\(transportA) Outgoing Entropy")
        aOutLine.colors = [NSUIColor.magenta]
        aOutLine.circleColors = [NSUIColor.magenta]
        aOutLine.circleRadius = 3.5
        aOutLine.drawCirclesEnabled = true
        aOutLine.circleHoleRadius = 2.5
        aOutLine.circleHoleColor = NSUIColor.clear
        aOutLine.drawValuesEnabled = false
        let bInLine = LineChartDataSet(entries: bInEntropyEntry, label: "\(transportB) Incoming Entropy")
        bInLine.colors = [NSUIColor.red]
        bInLine.circleColors = [NSUIColor.red]
        bInLine.circleRadius = 5
        bInLine.drawCirclesEnabled = true
        bInLine.circleHoleRadius = 4.5
        bInLine.circleHoleColor = NSUIColor.clear
        bInLine.drawValuesEnabled = false
        let bOutLine = LineChartDataSet(entries: bOutEntropyEntry, label: "\(transportB) Outgoing Entropy")
        bOutLine.colors = [NSUIColor.systemGreen ]
        bOutLine.circleColors = [NSUIColor.systemGreen]
        bOutLine.circleRadius = 6.5
        bOutLine.drawCirclesEnabled = true
        bOutLine.circleHoleRadius = 5.5
        bOutLine.circleHoleColor = NSUIColor.clear
        bOutLine.drawValuesEnabled = false
        
        let data = LineChartData()
        data.addDataSet(aInLine)
        data.addDataSet(aOutLine)
        data.addDataSet(bInLine)
        data.addDataSet(bOutLine)
        
        entropyChartView.delegate = self
        entropyChartView.data = data
        entropyChartView.chartDescription?.text = "Entropy"
    }
        
    func updateTimeChart()
    {
        var aTimeDifferences = packetTimings.transportA.sorted()
        for index in 0 ..< aTimeDifferences.count
        {
            // Convert microseconds to milliseconds
            aTimeDifferences[index] = aTimeDifferences[index]/1000
        }
        
        var bTimeDifferences = packetTimings.transportB.sorted()
        for index in 0 ..< bTimeDifferences.count
        {
            // Convert microseconds to milliseconds
            bTimeDifferences[index] = bTimeDifferences[index]/1000
        }
        
        let aLineChartEntry = chartDataEntry(fromArray: aTimeDifferences)
        let bLineChartEntry = chartDataEntry(fromArray: bTimeDifferences)
        
        let line1 = LineChartDataSet(entries: aLineChartEntry, label: "\(transportA)")
        line1.colors = [NSUIColor.blue]
        line1.circleColors = [NSUIColor.blue]
        line1.circleRadius = circleRadius
        line1.drawCirclesEnabled = true
        line1.circleHoleColor = NSUIColor.clear
        
        let line2 = LineChartDataSet(entries: bLineChartEntry, label: "\(transportB)")
        line2.colors = [NSUIColor.red]
        line2.circleColors = [NSUIColor.red]
        line2.circleRadius = circleRadius + 0.5
        line2.drawCirclesEnabled = true
        line2.circleHoleRadius = circleRadius - 0.5
        line2.circleHoleColor = NSUIColor.clear
        
        let data = LineChartData()
        data.addDataSet(line1)
        data.addDataSet(line2)
        
        timingChartView.delegate = self
        timingChartView.data = data
        timingChartView.chartDescription?.text = "Time Interval"
    }
    
    func chartDataEntry(fromArray dataArray:[Double]) -> [ChartDataEntry]
    {
        var lineChartData = [ChartDataEntry]()
        for i in 0..<dataArray.count
        {
            let value = ChartDataEntry(x: Double(i), y: Double(dataArray[i]))
            lineChartData.append(value)
        }
        
        return lineChartData
    }
    
    func chartDataEntry(fromArray dataArray:[Int]) -> [ChartDataEntry]
    {
        var lineChartData = [ChartDataEntry]()
        for i in 0..<dataArray.count
        {
            let value = ChartDataEntry(x: Double(i), y: Double(dataArray[i]))
            lineChartData.append(value)
        }
        
        return lineChartData
    }
    
    // MARK: - TabView Delegate
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?)
    {
        // Identify which tab was selected
        guard let identifier = tabView.selectedTabViewItem?.identifier as? String,
            let currentTab = TabIds(rawValue: identifier)
            else { return }
        
        updateButtons(currentTab: currentTab)
        loadLabelData()
    }
    
    func updateButtons(currentTab: TabIds)
    {
        // Checkbox button title color cannot be set in storyboard
        enableTLSCheck.attributedTitle = NSAttributedString(
            string: enableTLSCheck.title,
            attributes: [ NSAttributedString.Key.foregroundColor: NSColor.lightGray])
        
        enableSequencesCheck.attributedTitle = NSAttributedString(
            string: enableSequencesCheck.title,
            attributes: [ NSAttributedString.Key.foregroundColor: NSColor.lightGray])
        
        switch currentTab
        {
        case .TrainingMode:
            configModel.trainingMode = true
            self.loadDataButton.isEnabled = true
            self.loadDataButton.title = "Load Data"
            self.processPacketsButton.isEnabled = true
            self.processPacketsButton.title = "Train With Data"
        case .TestMode:
            configModel.trainingMode = false
            self.loadDataButton.isEnabled = true
            self.loadDataButton.title = "Load Model File"
            self.processPacketsButton.isEnabled = true
            self.processPacketsButton.title = "Test Data"
        case .DataMode:
            configModel.trainingMode = false
            self.updateCharts()
            self.loadDataButton.isEnabled = false
            self.processPacketsButton.isEnabled = false
        }
    }
    
    // MARK: - Test Mode
    func runTest()
    {
        configModel.processingEnabled = true
        
        if connectionGroupData.bConnectionData.connections.count < 1
        {
            // Prompt the user to select a data file to load
            showNoDataAlert
            { (dataLoaded) in
                
                if dataLoaded
                {
                    self.runTest()
                }
                else
                {
                    self.stopActivityIndicator()
                    return
                }
            }
        }
        else
        {
            // Make sure that we have gotten an Adversary file and unpacked it to a temporary directory
            // TODO: Delete this directory on program exit
            if modelDirectoryURL == nil
            {
                // Get the user to select the correct .adversary file
                if let selectedURL = showSelectAdversaryFileAlert()
                {
                    // Model Group Name should be the same as the directory
                    modelName = selectedURL.deletingPathExtension().lastPathComponent
                    
                    // Unpack to a temporary directory
                    modelDirectoryURL = FileController().unpack(adversaryURL: selectedURL)
                    runTest()
                }
                else
                {
                    processPacketsButton.state = .off
                    stopActivityIndicator()
                    return
                }
            }
            
            if !modelDirectoryURL!.hasDirectoryPath
            {
                // Unpack to a temporary directory
                modelDirectoryURL = FileController().unpack(adversaryURL: modelDirectoryURL!)
            }
            
            configModel.modelName = modelDirectoryURL!.deletingPathExtension().lastPathComponent
            connectionInspector.analyzeConnections(configModel: configModel, resetTrainingData: false, resetTestingData: true)
            updateProgressIndicator()
            stopActivityIndicator()
        }
    }
    
    func runTraining()
    {
        // In Training mode we need a name so we can save the model files
        if connectionGroupData.aConnectionData.connections.count < 6, connectionGroupData.bConnectionData.connections.count < 6
        {
            showNoDataAlert
            {
                (dataLoaded) in
                
                if dataLoaded
                {
                    self.runTraining()
                }
                else
                {
                    self.stopActivityIndicator()
                    return
                }
            }
        }
        
        if let name = showNameModelAlert()
        {
            print("Time to analyze some things.")
            configModel.modelName = name
            connectionInspector.analyzeConnections(configModel: configModel, resetTrainingData: true, resetTestingData: false)
            updateProgressIndicator()
            stopActivityIndicator()
            return
        }
        else
        {
            stopActivityIndicator()
            return
        }
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
                print("User chose to quit Adversary Lab rather than kill server.")
                quitAdversaryLab()
            case .alertSecondButtonReturn:
                // TODO: Kill Redis Server
                print("User chose to manually kill Redis server with PID: \(processPID)")
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
                            print("Received failure on launch server: \(failureString ?? "")")
                            quitAdversaryLab()
                        }
                    }
                })
            default:
                print("Unknown error user chose unknown option for redis server alert.")
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
        default:
            configModel.trainingMode = false
        }
    }
    
    func handleLaunchRedisResponse(result:ServerCheckResult)
    {
        switch result
        {
        case .okay(_):
            // Update Labels and Progress Indicator
            self.loadLabelData()
            self.updateProgressIndicator()
        case .otherProcessOnPort(let processName):
            print("Process on port")
            showOtherProcessAlert(processName: processName)
        case .corruptRedisOnPort(let pidString):
            print("Corrupt Redis")
            self.showCorruptRedisAlert(processPID: pidString)
        case .failure(let failureString):
            print("Received failure on launch server: \(failureString ?? "")")
            quitAdversaryLab()
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
                self.progressIndicator.isHidden = true
                self.processPacketsButton.state = .off
            }
            else
            {
                self.progressIndicator.isHidden = false
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
    
    // MARK: Update Labels
    
    @objc func loadLabelData()
    {
        // Updates Labels that are in the main window (always visible)
        // Get redis data in the utility queue and update the labels with the data in the main queue
        //print("Main thread?: \(Thread.isMainThread)")
        let redisDatabaseFilename = Auburn.dbfilename ?? "--"
        
        DispatchQueue.main.async
        {
            // Header Labels
            self.vcTransportAName = transportA
            self.vcTransportBName = transportB
            
            self.databaseNameLabel.stringValue = redisDatabaseFilename
            
            let aConnectionData = connectionGroupData.aConnectionData
            self.aConnectionsCountLabel = "\(transportA) connections: "
            self.allowedPacketsSeen = "\(aConnectionData.connections.count)"
            self.aConnectionsOutgoingTitleLabel = "\(transportA) total outgoing packets: "
            self.aConnectionsOutgoingValueLabel = "\(aConnectionData.outgoingPackets.count)"
            self.aConnectionsIncomingTitleLabel = "\(transportA) total incoming packets: "
            self.aConnectionsIncomingValueLabel = "\(aConnectionData.incomingPackets.count)"
            self.aConnectionsAnalyzedLabel = "\(transportA) connections analyzed: "
            self.allowedPacketsAnalyzed = "\(connectionGroupData.aPacketsAnalyzed)"
            
            let bConnectionData = connectionGroupData.bConnectionData
            self.bConnectionsCountLabel = "\(transportB) connections: "
            self.blockedPacketsSeen = "\(bConnectionData.connections.count)"
            self.bConnectionsAnalyzedLabel = "\(transportB) connections analyzed: "
            self.blockedPacketsAnalyzed = "\(connectionGroupData.bPacketsAnalyzed)"
            self.bConnectionsIncomingTitleLabel = "\(transportB) total incoming packets: "
            self.bConnectionsIncomingValueLabel = "\(bConnectionData.incomingPackets.count)"
            self.bConnectionsOutgoingTitleLabel = "\(transportB) total outgoing packets: "
            self.bConnectionsOutgoingValueLabel = "\(bConnectionData.outgoingPackets.count)"
            
            guard let identifier = self.tabView.selectedTabViewItem?.identifier as? String,
                let currentTab = TabIds(rawValue: identifier)
                else { return }
            
            // Main body labels
            switch currentTab
            {
            case .TrainingMode:
                self.loadTrainingLabelData()
            case .TestMode:
                self.loadTestLabelData()
            case .DataMode:
                return
            }
        }   
    }
    
    func loadTestLabelData()
    {
        // Get redis data in the utility queue and update the labels with the data in the main queue
        let testResults: RMap<String,Double> = RMap(key: testResultsKey)
        
        // TLS Common Names
        let tlsBlockAccuracy = testResults[blockedTLSAccuracyKey]
        let tlsAllowAccuracy = testResults[allowedTLSAccuracyKey]
        let tlsResultsDictionary: RMap<String,String> = RMap(key: tlsTestResultsKey)
        let tlsAllowed = tlsResultsDictionary[allowedTLSKey]
        let tlsBlocked = tlsResultsDictionary[blockedTLSKey]

        // All Features
        let allAllowAccuracy = testResults[allowedAllFeaturesAccuracyKey]
        let allBlockAccuracy = testResults[blockedAllFeaturesAccuracyKey]
        
        DispatchQueue.main.async
        {
            self.activityIndicator.stopAnimation(nil)
            
            // Timing (microseconds)
            let transportBTiming = packetTimings.transportBTestResults?.prediction
            let transportBTimingAccuracy = packetTimings.transportBTestResults?.accuracy
            let transportATiming = packetTimings.transportATestResults?.prediction
            let transportATimingAccuracy = packetTimings.transportATestResults?.accuracy
            
            self.aTimingLabel = "\(transportA) Timing: "
            self.aTimingAccuracyLabel = "\(transportA) Timing Accuracy: "
            self.bTimingLabel = "\(transportB)"
            self.bTimingAccuracyLabel = "\(transportB) Timing Accuracy: "
            if transportATiming != nil, transportATimingAccuracy != nil, transportBTiming != nil, transportBTimingAccuracy != nil
            {
                self.timingAllowed = String(format: "%.2f", transportATiming!/1000)
                self.timingAllowAccuracy = String(format: "%.2f", transportATimingAccuracy!)
                self.timingBlocked = String(format: "%.2f", transportBTiming!/1000)
                self.timingBlockAccuracy = String(format: "%.2f", transportBTimingAccuracy!)
            }
            else
            {
                self.timingAllowed = "--"
                self.timingAllowAccuracy = "--"
                self.timingBlocked = "--"
                self.timingBlockAccuracy = "--"
            }
            
            self.aTLS12Label = "\(transportA) TLS: "
            self.aTLS12AccuracyLabel = "\(transportA) TLS Accuracy: "
            self.bTLS12Label = "\(transportB) TLS: "
            self.bTLS12AccuracyLabel = "\(transportB) TLS Accuracy: "
            if tlsAllowAccuracy != nil, tlsBlockAccuracy != nil, tlsAllowed != nil, tlsBlocked != nil
            {
                self.tls12Allowed = String(format: "%.2f", tlsAllowed!)
                self.tls12AllowAccuracy = String(format: "%.2f", tlsAllowAccuracy!)
                self.tls12Blocked = String(format: "%.2f", tlsBlocked!)
                self.tls12BlockAccuracy = String(format: "%.2f", tlsBlockAccuracy!)
            }
            else
            {
                self.tls12Allowed = "--"
                self.tls12AllowAccuracy = "--"
                self.tls12Blocked = "--"
                self.tls12BlockAccuracy = "--"
            }
            
            // Entropy
            let transportAInEntropyPrediction = packetEntropies.incomingATestResults?.prediction
            let transportAInEntropyAccuracy = packetEntropies.incomingATestResults?.accuracy
            let transportBInEntropyPrediction = packetEntropies.incomingBTestResults?.prediction
            let transportBInEntropyAccuracy = packetEntropies.incomingBTestResults?.accuracy

            let transportAOutEntropyPrediction = packetEntropies.outgoingATestResults?.prediction
            let transportAOutEntropyAccuracy = packetEntropies.outgoingATestResults?.accuracy
            let transportBOutEntropyPrediction = packetEntropies.outgoingBTestResults?.prediction
            let transportBOutEntropyAccuracy = packetEntropies.outgoingBTestResults?.accuracy
            
            self.aInEntropyLabel = "\(transportA) In Entropy: "
            self.aInEntropyAccuracyLabel = "\(transportA) In Entropy Accurcy: "
            self.aOutEntropyLabel = "\(transportA) Out Entropy: "
            self.aOutEntropyAccuracyLabel = "\(transportA) Out Entropy Accuracy: "
            self.bInEntropyLabel = "\(transportB) In Entropy: "
            self.bInEntropyAccuracyLabel = "\(transportB) In Entropy Accuracy: "
            self.bOutEntropyLabel = "\(transportB) Out Entropy: "
            self.bOutEntropyAccuracyLabel = "\(transportB) Out Entropy Accuracy: "
            
            if
                transportAInEntropyPrediction != nil,
                transportBInEntropyPrediction != nil,
                transportAInEntropyAccuracy != nil,
                transportBInEntropyAccuracy != nil
            {
                self.inAllowedEntropy = String(format: "%.2f", transportAInEntropyPrediction!)
                self.inEntropyAllowAccuracy = String(format: "%.2f", transportAInEntropyAccuracy!)
                self.inBlockedEntropy = String(format: "%.2f", transportBInEntropyPrediction!)
                self.inEntropyBlockAccuracy = String(format: "%.2f", transportBInEntropyAccuracy!)
            }
            else
            {
                self.inAllowedEntropy = "--"
                self.inEntropyAllowAccuracy = "--"
                self.inBlockedEntropy = "--"
                self.inEntropyBlockAccuracy = "--"
            }
            
            if
                transportAOutEntropyPrediction != nil,
                transportBOutEntropyPrediction != nil,
                transportAOutEntropyAccuracy != nil,
                transportBOutEntropyAccuracy != nil
            {
                self.outAllowedEntropy = String(format: "%.2f", transportAOutEntropyPrediction!)
                self.outBlockedEntropy = String(format: "%.2f", transportBOutEntropyPrediction!)
                self.outEntropyAllowAccuracy = String(format: "%.2f", transportAOutEntropyAccuracy!)
                self.outEntropyBlockAccuracy = String(format: "%.2f", transportBOutEntropyAccuracy!)
            }
            else
            {
                self.outAllowedEntropy = "--"
                self.outBlockedEntropy = "--"
                self.outEntropyAllowAccuracy = "--"
                self.outEntropyBlockAccuracy = "--"
            }
            
            // Lengths
            let transportAInLengthPrediction = packetLengths.incomingATestResults?.prediction
            let transportAInLengthAccuracy = packetLengths.incomingATestResults?.accuracy
            let transportBInLengthPrediction = packetLengths.incomingBTestResults?.prediction
            let transportBInLengthAccuracy = packetLengths.incomingBTestResults?.accuracy
            let transportAOutLengthPrediction = packetLengths.outgoingATestResults?.prediction
            let transportAOutLengthAccuracy = packetLengths.outgoingATestResults?.accuracy
            let transportBOutLengthPrediction = packetLengths.outgoingBTestResults?.prediction
            let transportBOutLengthAccuracy = packetLengths.outgoingBTestResults?.accuracy
            
            self.aInLengthLabel = "\(transportA) In Length: "
            self.aInLengthAccuracyLabel = "\(transportA) In Length Accuracy: "
            self.aOutLengthLabel = "\(transportA) Out Length: "
            self.aOutLengthAccuracyLabel = "\(transportA) Out Length Accuracy: "
            self.bInLengthLabel = "\(transportB) In Length: "
            self.bInLengthAccuracyLabel = "\(transportB) In Length Accuracy: "
            self.bOutLengthLabel = "\(transportB) Out Length: "
            self.bOutLengthAccuracyLabel = "\(transportB) Out Length Accuracy: "
            
            if transportAInLengthAccuracy != nil, transportBInLengthAccuracy != nil
            {
                self.inLengthAllowAccuracy = String(format: "%.2f", transportAInLengthAccuracy!)
                self.inLengthBlockAccuracy = String(format: "%.2f", transportBInLengthAccuracy!)
            }
            else
            {
                self.inLengthAllowAccuracy = "--"
                self.inLengthBlockAccuracy = "--"
            }
            
            if transportAInLengthPrediction != nil, transportBInLengthPrediction != nil
            {
                self.inLengthAllowed = "\(Int(transportAInLengthPrediction!))"
                self.inLengthBlocked = "\(Int(transportBInLengthPrediction!))"
            }
            else
            {
                self.inLengthAllowed = "--"
                self.inLengthBlocked = "--"
            }
            
            if transportAOutLengthAccuracy != nil, transportBOutLengthAccuracy != nil
            {
                self.outLengthAllowAccuracy = String(format: "%.2f", transportAOutLengthAccuracy!)
                self.outLengthBlockAccuracy = String(format: "%.2f", transportBOutLengthAccuracy!)
            }
            else
            {
                self.outLengthAllowAccuracy = "--"
                self.outLengthBlockAccuracy = "--"
            }
            
            if transportAOutLengthPrediction != nil, transportBOutLengthPrediction != nil
            {
                self.outLengthAllowed = "\(Int(transportAOutLengthPrediction!))"
                self.outLengthBlocked = "\(Int(transportBOutLengthPrediction!))"
            }
            else
            {
                self.outLengthAllowed = "--"
                self.outLengthBlocked = "--"
            }
            
            // All Features
            self.allFeaturesAAccuracyLabel = "\(transportA) Prediction Accuracy: "
            self.allFeaturesAllowAccuracy = "--"
            self.allFeaturesBAccuracyLabel = "\(transportB) Prediction Accuracy: "
            self.allFeaturesBlockAccuracy = "--"

            if allAllowAccuracy != nil
            { self.allFeaturesAllowAccuracy = String(format: "%.2f", allAllowAccuracy!) }
            
            if allBlockAccuracy != nil
            { self.allFeaturesBlockAccuracy = String(format: "%.2f", allBlockAccuracy!) }
        }
    }
    
    func loadTrainingLabelData()
    {
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
        
        // TLS Common Names
        let tlsResults: RMap <String, String> = RMap(key: tlsTrainingResultsKey)
        let tlsAccuracy: RMap <String, Double> = RMap(key: tlsTrainingAccuracyKey)
        let rTLS = tlsResults[requiredTLSKey]
        let fTLS = tlsResults[forbiddenTLSKey]
        let tlsTrainingAccuracy = tlsAccuracy[tlsTAccKey]
        let tlsValidationAccuracy = tlsAccuracy[tlsVAccKey]
        let tlsEvaluationAccuracy = tlsAccuracy[tlsEAccKey]
        
        // Float Subsequences
        let requiredOutFloatSequenceSet: RSortedSet<Data> = RSortedSet(key: outgoingRequiredFloatSequencesKey)
        let requiredOutFloatSequenceTuple: (Data, Float)? = requiredOutFloatSequenceSet.last
        
        let forbiddenOutFloatSequenceSet: RSortedSet<Data> = RSortedSet(key: outgoingForbiddenFloatSequencesKey)
        let forbiddenOutFloatSequenceTuple: (Data, Float)? = forbiddenOutFloatSequenceSet.last
        
        let requiredInFloatSequenceSet: RSortedSet<Data> = RSortedSet(key: incomingRequiredFloatSequencesKey)
        let requiredInFloatSequenceTuple: (Data, Float)? = requiredInFloatSequenceSet.last
        
        let forbiddenInFloatSequenceSet: RSortedSet<Data> = RSortedSet(key: incomingForbiddenFloatSequencesKey)
        let forbiddenInFloatSequenceTuple: (Data, Float)? = forbiddenInFloatSequenceSet.last
        
        // All Features
        let allFeaturesDictionary: RMap<String, Double> = RMap(key: allFeaturesTrainingAccuracyKey)
        let allTimingDictionary: RMap<String, Double> = RMap(key: allFeaturesTimeTrainingResultsKey)
        let allEntropyDictionary: RMap<String, Double> = RMap(key: allFeaturesEntropyTrainingResultsKey)
        let allLengthDictionary: RMap<String, Double> = RMap(key: allFeaturesLengthTrainingResultsKey)
        let tlsDictionary: RMap<String, String> = RMap(key: allFeaturesTLSTraininResultsKey)
        
        let allFeaturesEvalAccuracy = allFeaturesDictionary[allFeaturesEAccKey]
        
        let allFeaturesTrainAllowedOutLength = allLengthDictionary[outgoingRequiredLengthKey]
        let allFeaturesTrainBlockedOutLength = allLengthDictionary[outgoingForbiddenLengthKey]
        let allFeaturesTrainAllowedOutEntropy = allEntropyDictionary[outgoingRequiredEntropyKey]
        let allFeaturesTrainBlockedOutEntropy = allEntropyDictionary[outgoingForbiddenEntropyKey]
        let allFeaturesTrainAllowedInLength = allLengthDictionary[incomingRequiredLengthKey]
        let allFeaturesTrainBlockedInLength = allLengthDictionary[incomingForbiddenLengthKey]
        let allFeaturesTrainAllowedInEntropy = allEntropyDictionary[incomingRequiredEntropyKey]
        let allFeaturesTrainBlockedInEntropy = allEntropyDictionary[incomingForbiddenEntropyKey]
        let allFeaturesTrainAllowedTiming = allTimingDictionary[requiredTimeDiffKey]
        let allFeaturesTrainBlockedTiming = allTimingDictionary[forbiddenTimeDiffKey]
        let allFeaturesTrainAllowedTLS = tlsDictionary[requiredTLSKey]
        let allFeaturesTrainBlockedTLS = tlsDictionary[forbiddenTLSKey]
        
        DispatchQueue.main.async
        {
            self.activityIndicator.stopAnimation(nil)
            
            self.allEvaluationAccuracy = "--"
            self.allAllowedOutLength = "--"
            self.allBlockedOutLength = "--"
            self.allAllowedOutEntropy = "--"
            self.allBlockedOutEntropy = "--"
            self.allAllowedInLength = "--"
            self.allBlockedInLength = "--"
            self.allAllowedInEntropy = "--"
            self.allBlockedInEntropy = "--"
            self.allAllowedTiming = "--"
            self.allBlockedTiming = "--"
            
            // All Features
            if allFeaturesEvalAccuracy != nil
            { self.allEvaluationAccuracy = String(format: "%.2f", allFeaturesEvalAccuracy!) }
            
            if allFeaturesTrainAllowedOutLength != nil
            { self.allAllowedOutLength = String(format: "%.2f", allFeaturesTrainAllowedOutLength!) }
            
            if allFeaturesTrainBlockedOutLength != nil
            { self.allBlockedOutLength = String(format: "%.2f", allFeaturesTrainBlockedOutLength!) }
            
            if allFeaturesTrainAllowedOutEntropy != nil
            { self.allAllowedOutEntropy = String(format: "%.2f", allFeaturesTrainAllowedOutEntropy!) }
            
            if allFeaturesTrainBlockedOutEntropy != nil
            { self.allBlockedOutEntropy = String(format: "%.2f", allFeaturesTrainBlockedOutEntropy!) }
            
            if allFeaturesTrainAllowedInLength != nil
            { self.allAllowedInLength = String(format: "%.2f", allFeaturesTrainAllowedInLength!) }
            
            if allFeaturesTrainBlockedInLength != nil
            { self.allBlockedInLength = String(format: "%.2f", allFeaturesTrainBlockedInLength!) }
            
            if allFeaturesTrainAllowedInEntropy != nil
            { self.allAllowedInEntropy = String(format: "%.2f", allFeaturesTrainAllowedInEntropy!) }
            
            if allFeaturesTrainBlockedInEntropy != nil
            { self.allBlockedInEntropy = String(format: "%.2f", allFeaturesTrainBlockedInEntropy!) }
            
            if allFeaturesTrainAllowedTiming != nil
            { self.allAllowedTiming = String(format: "%.2f", allFeaturesTrainAllowedTiming!/1000) }
            
            if allFeaturesTrainBlockedTiming != nil
            { self.allBlockedTiming = String(format: "%.2f", allFeaturesTrainBlockedTiming!/1000) }

            self.allAllowedTLS = allFeaturesTrainAllowedTLS ?? "--"
            self.allBlockedTLS = allFeaturesTrainBlockedTLS ?? "--"

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
            
            // Timing (microseconds displayed in milliseconds)
            self.requiredTiming = "--"
            self.forbiddenTiming = "--"
            self.timeTAcc = "--"
            self.timeVAcc = "--"
            self.timeEAcc = "--"
            
            // Timing (microseconds)
            let transportATiming = trainingData.timingTrainingResults?.transportAPrediction
            let transportBTiming = trainingData.timingTrainingResults?.transportBPrediction
            let timeDiffTAcc = trainingData.timingTrainingResults?.trainingAccuracy
            let timeDiffVAcc = trainingData.timingTrainingResults?.validationAccuracy
            let timeDiffEAcc = trainingData.timingTrainingResults?.evaluationAccuracy
            
            if transportATiming != nil
            { self.requiredTiming = String(format: "%.2f", transportATiming!/1000) + "ms" }
            if transportBTiming != nil
            { self.forbiddenTiming = String(format: "%.2f", transportBTiming!/1000) + "ms" }
            if timeDiffTAcc != nil
            { self.timeTAcc = String(format: "%.2f", timeDiffTAcc!) }
            if timeDiffVAcc != nil
            { self.timeVAcc = String(format: "%.2f", timeDiffVAcc!) }
            if timeDiffEAcc != nil
            { self.timeEAcc = String(format: "%.2f", timeDiffEAcc!) }
            
            // TLS Common Names
            self.requiredTLSName = "--"
            self.forbiddenTLSName = "--"
            self.tlsTAcc = "--"
            self.tlsVAcc = "--"
            self.tlsEAcc = "--"
            
            if rTLS != nil
            { self.requiredTLSName = rTLS! }
            if fTLS != nil
            { self.forbiddenTLSName = fTLS! }
            if tlsTrainingAccuracy != nil
            { self.tlsTAcc = String(format: "%.2f", tlsTrainingAccuracy!) }
            if tlsValidationAccuracy != nil
            { self.tlsVAcc = String(format: "%.2f", tlsValidationAccuracy!) }
            if tlsEvaluationAccuracy != nil
            { self.tlsEAcc = String(format: "%.2f", tlsEvaluationAccuracy!) }
            
            // Lengths
            let transportAPredictedOutLength = trainingData.outgoingLengthsTrainingResults?.transportAPrediction
            let transportBPredictedOutLength = trainingData.outgoingLengthsTrainingResults?.transportBPrediction
            let outTrainingAcc = trainingData.outgoingLengthsTrainingResults?.trainingAccuracy
            let outValidationAcc = trainingData.outgoingLengthsTrainingResults?.validationAccuracy
            let outEvaluationAcc = trainingData.outgoingLengthsTrainingResults?.evaluationAccuracy
            
            let transportAPredictedInLength = trainingData.incomingLengthsTrainingResults?.transportAPrediction
            let transportBPredictedInLength = trainingData.incomingLengthsTrainingResults?.transportBPrediction
            let inTrainingAcc = trainingData.incomingLengthsTrainingResults?.trainingAccuracy
            let inValidationAcc = trainingData.incomingLengthsTrainingResults?.validationAccuracy
            let inEvaluationAcc = trainingData.incomingLengthsTrainingResults?.evaluationAccuracy
            
            self.requiredOutLength = "--"
            self.forbiddenOutLength = "--"
            self.outLengthTAcc = "--"
            self.outLengthVAcc = "--"
            self.outLengthEAcc = "--"
            
            self.requiredInLength = "--"
            self.forbiddenInLength = "--"
            self.inLengthTAcc = "--"
            self.inLengthVAcc = "--"
            self.inLengthEAcc = "--"
            
            if transportAPredictedOutLength != nil
            { self.requiredOutLength = String(format: "%.2f", transportAPredictedOutLength!) }
            if transportBPredictedOutLength != nil
            { self.forbiddenOutLength = String(format: "%.2f", transportBPredictedOutLength!) }
            if outTrainingAcc != nil
            { self.outLengthTAcc = String(format: "%.2f", outTrainingAcc!) }
            if outValidationAcc != nil
            { self.outLengthVAcc = String(format: "%.2f", outValidationAcc!) }
            if outEvaluationAcc != nil
            { self.outLengthEAcc = String(format: "%.2f", outEvaluationAcc!) }
            if transportAPredictedInLength != nil
            { self.requiredInLength = String(format: "%.2f", transportAPredictedInLength!) }
            if transportBPredictedInLength != nil
            { self.forbiddenInLength = String(format: "%.2f", transportBPredictedInLength!) }
            if inTrainingAcc != nil
            { self.inLengthTAcc = String(format: "%.2f", inTrainingAcc!) }
            if inValidationAcc != nil
            { self.inLengthVAcc = String(format: "%.2f", inValidationAcc!) }
            if inEvaluationAcc != nil
            { self.inLengthEAcc = String(format: "%.2f", inEvaluationAcc!) }
            
            // Entropy
            let transportAPredictedOutEntropy =
                trainingData.outgoingEntropyTrainingResults?.transportAPrediction
            let transportBPredictedOutEntropy = trainingData.outgoingEntropyTrainingResults?.transportBPrediction
                
            let outEntropyTrainingAccuracy = trainingData.outgoingEntropyTrainingResults?.trainingAccuracy
            let outEntropyValidationAccuracy = trainingData.outgoingEntropyTrainingResults?.validationAccuracy
            let outEntropyEvaluationAccuracy = trainingData.outgoingEntropyTrainingResults?.evaluationAccuracy
            let transportAPredictedInEntropy = trainingData.incomingEntropyTrainingResults?.transportAPrediction
            let transportBPredictedInEntropy = trainingData.incomingEntropyTrainingResults?.transportBPrediction
            let inEntropyTrainingAccuracy = trainingData.incomingEntropyTrainingResults?.trainingAccuracy
            let inEntropyValidationAccuracy = trainingData.incomingEntropyTrainingResults?.validationAccuracy
            let inEntropyEvaluationAccuracy = trainingData.incomingEntropyTrainingResults?.evaluationAccuracy
            
            self.requiredOutEntropy = "--"
            self.forbiddenOutEntropy = "--"
            self.outEntropyTAcc = "--"
            self.outEntropyEAcc = "--"
            self.outEntropyVAcc = "--"
            if transportAPredictedOutEntropy != nil
            { self.requiredOutEntropy = String(format: "%.2f", transportAPredictedOutEntropy!) }
            if transportBPredictedOutEntropy != nil
            { self.forbiddenOutEntropy = String(format: "%.2f", transportBPredictedOutEntropy!) }
            if outEntropyTrainingAccuracy != nil
            { self.outEntropyTAcc = String(format: "%.2f", outEntropyTrainingAccuracy!) }
            if outEntropyEvaluationAccuracy != nil
            { self.outEntropyEAcc = String(format: "%.2f", outEntropyEvaluationAccuracy!) }
            if outEntropyValidationAccuracy != nil
            { self.outEntropyVAcc = String(format: "%.2f", outEntropyValidationAccuracy!) }
              
            self.inEntropyVAcc = "--"
            self.requiredInEntropy = "--"
            self.forbiddenInEntropy = "--"
            self.inEntropyTAcc = "--"
            self.inEntropyEAcc = "--"
            if transportAPredictedInEntropy != nil
            { self.requiredInEntropy = String(format: "%.2f", transportAPredictedInEntropy!) }
            if transportBPredictedInEntropy != nil
            { self.forbiddenInEntropy = String(format: "%.2f", transportBPredictedInEntropy!) }
            if inEntropyTrainingAccuracy != nil
            { self.inEntropyTAcc = String(format: "%.2f", inEntropyTrainingAccuracy!) }
            if inEntropyEvaluationAccuracy != nil
            { self.inEntropyEAcc = String(format: "%.2f", inEntropyEvaluationAccuracy!) }
            if inEntropyValidationAccuracy != nil
            { self.inEntropyVAcc = String(format: "%.2f", inEntropyValidationAccuracy!) }
            
            //Float Subsequences
            self.requiredOutSequence = "--"
            self.requiredOutSequenceCount = "--"
            self.requiredOutSequenceAcc = "--"
            if let roFloatSeqMember = requiredOutFloatSequenceTuple?.0
            {
                self.requiredOutSequence = "\(roFloatSeqMember.hexEncodedString())"
                self.requiredOutSequenceCount = "\(roFloatSeqMember)"
            }
            if let roFloatSeqScore = requiredOutFloatSequenceTuple?.1
            { self.requiredOutSequenceAcc = "\(roFloatSeqScore)" }
            
            self.forbiddenOutSequence = "--"
            self.forbiddenOutSequenceCount = "--"
            self.forbiddenOutSequenceAcc = "--"
            if let foFloatSeqMember = forbiddenOutFloatSequenceTuple?.0
            {
                self.forbiddenOutSequence = "\(foFloatSeqMember.hexEncodedString())"
                self.forbiddenOutSequenceCount = "\(foFloatSeqMember)"
            }
            if let foFloatSeqScore = forbiddenOutFloatSequenceTuple?.1
            { self.forbiddenOutSequenceAcc = "\(foFloatSeqScore)" }
            
            self.requiredInSequence = "--"
            self.requiredInSequenceCount = "--"
            self.requiredInSequenceAcc = "--"
            if let riFloatSeqMemeber = requiredInFloatSequenceTuple?.0
            {
                self.requiredInSequence = "\(riFloatSeqMemeber.hexEncodedString())"
                self.requiredInSequenceCount = "\(riFloatSeqMemeber)"
            }
            if let riFloatSeqScore = requiredInFloatSequenceTuple?.1
            { self.requiredInSequenceAcc = "\(riFloatSeqScore)" }
            
            self.forbiddenInSequence = "--"
            self.forbiddenInSequenceCount = "--"
            self.forbiddenInSequenceAcc = "--"
            if let fiFloatSeqMember = forbiddenInFloatSequenceTuple?.0
            {
                self.forbiddenInSequence = "\(fiFloatSeqMember.hexEncodedString())"
                self.forbiddenInSequenceCount = "\(fiFloatSeqMember)"
                
            }
            if let fiFloatSeqScore = forbiddenInFloatSequenceTuple?.1
            { self.forbiddenInSequenceAcc = "\(fiFloatSeqScore)" }
        }
    }
    
   

}

// MARK: - TabView Identifiers

enum TabIds: String
{
    case TrainingMode
    case TestMode
    case DataMode
}

