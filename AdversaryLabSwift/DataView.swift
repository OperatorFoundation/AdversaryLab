//
//  SwiftUIView.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 6/27/22.
//  Copyright © 2022 Operator Foundation. All rights reserved.
//

import SwiftUI
//rgb(1.00,0.70,0.95)
let adLabPink = Color(red: 1.00, green: 0.70, blue: 0.95)
struct DataView: View
{
    @EnvironmentObject var labViewData: LabViewData
    @State var modelName = ""
    @State private var isLoading = false
    
    let packetLengthUnits = "bytes"
    let timeIntervalUnits = "ms"
    
    var configModel = ProcessingConfigurationModel()
    var labData: LabData
    
    init(labData: LabData)
    {
        self.labData = labData
    }

    var body: some View
    {
        VStack
        {
            GroupBox(label: Text("Connection Data")) // Connection Data
            {
                ZStack {
                    Image("al-256")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 75)
                    
                    HStack
                    {
                        makeConnectionsBox(transportConnectionData: labViewData.connectionGroupData.aConnectionData, labelText: labViewData.transportA)
                        
                        Spacer()
                        
                        makeConnectionsBox(transportConnectionData: labViewData.connectionGroupData.bConnectionData, labelText: labViewData.transportB)
                    }
                }
            }
            .foregroundColor(.white)
            .padding()
            .background(.black)
            
            HStack {
                GroupBox(label: Text("Training Data")) // Training Data
                {
                    HStack
                    {
                        GroupBox(label: Text("Timing"))
                        {
                            makeResultsBox(trainingResults: labViewData.trainingData.timingTrainingResults, labelText: "", unitLabel: timeIntervalUnits, valueIsInt: false)
                        }
                        Spacer()
                        
                        GroupBox(label: Text("Packet Lengths"))
                        {
                            makeResultsBox(trainingResults: labViewData.trainingData.outgoingLengthsTrainingResults, labelText: "Outgoing Rules", unitLabel: packetLengthUnits, valueIsInt: true)
                            makeResultsBox(trainingResults: labViewData.trainingData.incomingLengthsTrainingResults, labelText: "Incoming Rules", unitLabel: packetLengthUnits, valueIsInt: true)
                        }
                        Spacer()
                        
                        GroupBox(label: Text("Entropy"))
                        {
                            makeResultsBox(trainingResults: labViewData.trainingData.outgoingEntropyTrainingResults, labelText: "Outgoing Rules", unitLabel: "", valueIsInt: false)
                            makeResultsBox(trainingResults: labViewData.trainingData.incomingEntropyTrainingResults, labelText: "Incoming Rules", unitLabel: "", valueIsInt: false)
                        }
                    }
                    
                    HStack
                    {
                        Button
                        {
                            if let selectedFileURL = showSelectAdversaryLabDataAlert()
                            {
                                ConnectionInspector().resetAnalysisData(labData: labData, resetConnectionData: true, resetTrainingData: true, resetTestingData: false)
                                labViewData.resetLabConnectionData(labData: labData)
                                
                                let symphony = SymphonyController()
                                
                                guard let possibleTransports = symphony.launchSymphony(fromFile: selectedFileURL, labData: labData) else
                                { return }
                                guard selectTransports(transportNames: possibleTransports) else
                                { return }

                                Task
                                {
                                    isLoading = true
                                    _ = await symphony.processConnectionData(labData: labData)
                                    labViewData.copyLabConnectionData(labData: labData)
                                    isLoading = false
                                }
                                
                            }
                        } label: {
                            Text("Load Data")
                                .opacity(isLoading ? 0.3 : 1)
                        }
                        .disabled(isLoading)
                        
                        Button
                        {
                            Task
                            {
                                await runTraining()
                            }
                            
                        }
                        label: {
                            Text("Train")
                                .opacity(isLoading ? 0.3 : 1)
                        }
                        .disabled(isLoading)
                    }
                }
                .foregroundColor(.black)
                .padding()
                .background(.white)
                .overlay
                {
                    if isLoading
                    {
                        ProgressView()
                    }
                }
                
//                GroupBox(label: Text("Test Data: \(modelName)")) // Test Data
//                {
//                    HStack
//                    {
//                        GroupBox(label: Text("Timing"))
//                        {
//                            makeResultsBox(testResults: labViewData.packetTimings.transportATestResults, labelText: labViewData.transportA, unitLabel: timeIntervalUnits)
//                            makeResultsBox(testResults: labViewData.packetTimings.transportBTestResults, labelText: labViewData.transportB, unitLabel: timeIntervalUnits)
//                        }
//                        Spacer()
//                        GroupBox(label: Text("Packet Lengths"))
//                        {
//                            makeResultsBox(testResults: labViewData.packetLengths.outgoingATestResults, labelText: "\(labViewData.transportA) Outgoing", unitLabel: packetLengthUnits)
//                            makeResultsBox(testResults: labViewData.packetLengths.outgoingBTestResults, labelText: "\(labViewData.transportB) Outgoing", unitLabel: packetLengthUnits)
//                            makeResultsBox(testResults: labViewData.packetLengths.incomingATestResults, labelText: "\(labViewData.transportA) Incoming", unitLabel: packetLengthUnits)
//                            makeResultsBox(testResults: labViewData.packetLengths.incomingBTestResults, labelText: "\(labViewData.transportB) Incoming", unitLabel: packetLengthUnits)
//                        }
//                        Spacer()
//                        GroupBox(label: Text("Entropy"))
//                        {
//                            makeResultsBox(testResults: labViewData.packetEntropies.outgoingATestResults, labelText: "\(labViewData.transportA) Outgoing", unitLabel: "")
//                            makeResultsBox(testResults: labViewData.packetEntropies.outgoingBTestResults, labelText: "\(labViewData.transportB) Outgoing", unitLabel: "")
//                            makeResultsBox(testResults: labViewData.packetEntropies.incomingATestResults, labelText: "\(labViewData.transportA) Incoming", unitLabel: "")
//                            makeResultsBox(testResults: labViewData.packetEntropies.incomingBTestResults, labelText: "\(labViewData.transportB) Incoming", unitLabel: "")
//                        }
//                    }
//
//                    HStack
//                    {
//                        Button
//                        {
//                            // Get the user to select the correct .adversary file
//                            if let selectedURL = showSelectAdversaryFileAlert()
//                            {
//                                // Model Group Name should be the same as the directory
//                                modelName = selectedURL.deletingPathExtension().lastPathComponent
//                                configModel.modelName = modelName
//
//                                // Unpack to a temporary directory
//                                if let maybeModelDirectory = FileController().unpack(adversaryURL: selectedURL)
//                                {
//                                    modelDirectoryURL = maybeModelDirectory
//                                }
//                                else
//                                {
//                                    print("🚨  Failed to unpack the selected adversary file.  🚨")
//                                }
//                            }
//                        }
//                        label: {
//                            Text("Load Model")
//                                .opacity(isLoading ? 0.3 : 1)
//                        }
//                        .disabled(isLoading)
//
//                        Button
//                        {
//                            Task
//                            {
//                                await runTest()
//                            }
//
//                        }
//                        label: {
//                            Text("Test")
//                                .opacity(isLoading ? 0.3 : 1)
//
//                        }
//                        .disabled(isLoading)
//
//                    }
//                }
//                .foregroundColor(.black)
//                .padding()
//                .background(.white)
//                .overlay
//                {
//                    if isLoading
//                    {
//                        ProgressView()
//                    }
//                }
            }
        }
    }
    
    func runTest() async
    {
        if labData.connectionGroupData.bConnectionData.connections.count < 1
        {
            // Prompt the user
            showNoDataAlert(labData: labData)
        }
        else
        {
            // Make sure that we have gotten an Adversary file and unpacked it to a temporary directory
            if modelDirectoryURL == nil
            {
                // Get the user to select the correct .adversary file
                if let selectedURL = showSelectAdversaryFileAlert()
                {
                    // Model Group Name should be the same as the directory
                    modelName = selectedURL.deletingPathExtension().lastPathComponent
                    
                    // Unpack to a temporary directory
                    modelDirectoryURL = FileController().unpack(adversaryURL: selectedURL)
                    await runTest()
                }
            }
            else
            {
                if !modelDirectoryURL!.hasDirectoryPath
                {
                    // Unpack to a temporary directory
                    modelDirectoryURL = FileController().unpack(adversaryURL: modelDirectoryURL!)
                }
                
                modelName = modelDirectoryURL!.deletingPathExtension().lastPathComponent
                configModel.modelName = modelDirectoryURL!.deletingPathExtension().lastPathComponent
                configModel.trainingMode = false
                
                Task
                {
                    isLoading = true
                    _ = await ConnectionInspector().analyzeConnections(labData: labData, configModel: configModel, resetTrainingData: false, resetTestingData: true)
                    labViewData.copyAllLabData(labData: labData)
                    isLoading = false
                }
            }
        }
    }
    
    func runTraining() async
    {
        // In Training mode we need a name so we can save the model files
        if labData.connectionGroupData.aConnectionData.connections.count < 6, labData.connectionGroupData.bConnectionData.connections.count < 6
        {
            showNoDataAlert(labData: labData)
        }
        else
        {
            if let name = showNameModelAlert()
            {
                print("Time to analyze some things.")
                configModel.modelName = name
                configModel.trainingMode = true
                
                Task
                {
                    isLoading = true
                    _ = await ConnectionInspector().analyzeConnections(labData: labData, configModel: configModel, resetTrainingData: true, resetTestingData: false)
                    labViewData.copyAllLabData(labData: labData)
                    isLoading = false
                }
            }
        }
        
    }
    
    func selectTransports(transportNames: [String]) -> Bool
    {
        guard transportNames.count > 1 else
        {
            // TODO: Notify User
            print("Found \(transportNames.count) transport categories, we need at least 2.")
            return false
        }
        
        print("Found transports in database: \(transportNames)")
        
        ///Ask the user which transport is allowed and which is blocked
        showChooseAConnectionsAlert(labData: labData, transportNames: transportNames)
        showChooseBConnectionsAlert(labData: labData, transportNames: transportNames)
        
        let transportA = labData.transportA
        let transportB = labData.transportB
        
        // User cancelled out of selecting which transports to load
        guard !transportA.isEmpty, !transportB.isEmpty else
        { return false }
        
        return true
    }
    
    fileprivate func makeResultsBox(trainingResults: NumericTrainingResults?, labelText: String, unitLabel: String, valueIsInt: Bool) -> GroupBox<Text, VStack<TupleView<(HStack<TupleView<(Text, Text)>>, HStack<TupleView<(Text, Text)>>, HStack<TupleView<(Text, Text)>>, HStack<TupleView<(Text, Text)>>, HStack<TupleView<(Text, Text)>>)>>>
    {
        var aPrediction = "--"
        var bPrediction = "--"
        var trainingAccuracy = "--"
        var validationAccuracy = "--"
        var evaluationAccuracy = "--"
        
        if let trainingResults = trainingResults
        {
            if valueIsInt
            {
                aPrediction = (String(Int(trainingResults.transportAPrediction)))
                bPrediction = (String(Int(trainingResults.transportBPrediction)))
            }
            else
            {
                aPrediction = (String(format: "%.2f", trainingResults.transportAPrediction))
                bPrediction = (String(format: "%.2f", trainingResults.transportBPrediction))
            }
            trainingAccuracy = trainingResults.trainingAccuracy != nil ? String(format: "%.2f", trainingResults.trainingAccuracy!) : "--"
            validationAccuracy = trainingResults.validationAccuracy != nil ? String(format: "%.2f", trainingResults.validationAccuracy!) : "--"
            evaluationAccuracy = trainingResults.evaluationAccuracy != nil ? String(format: "%.2f", trainingResults.evaluationAccuracy!) : "--"
        }
        
        return GroupBox(label: Text(labelText))
        {
            VStack(alignment: .leading)
            {
                HStack
                {
                    Text("\(labViewData.transportA): ")
                    Text("\(aPrediction) \(unitLabel)")
                }
                
                HStack
                {
                    Text("\(labViewData.transportB): ")
                    Text("\(bPrediction) \(unitLabel)")
                }
                
                HStack
                {
                    Text("Training Accuracy: ")
                    Text("\(trainingAccuracy)%")
                }
                
                HStack
                {
                    Text("Validation Accuracy: ")
                    Text("\(validationAccuracy)%")
                }
                
                HStack
                {
                    Text("Evaluation Accuracy: ")
                    Text("\(evaluationAccuracy)%")
                }
            }
        }
    }
    
    fileprivate func makeResultsBox(testResults: TestResults?, labelText: String, unitLabel: String) ->  GroupBox<Text, VStack<TupleView<(HStack<TupleView<(Text, Text)>>, HStack<TupleView<(Text, Text)>>)>>>
    {
        let testPrediction: String
        let testAccuracy: String
        
        if let testResults = testResults
        {
            testPrediction = String(format: "%.2f", testResults.prediction)
            testAccuracy = testResults.accuracy != nil ? String(format: "%.2f", testResults.accuracy!) : "--"
        }
        else
        {
            testPrediction = "--"
            testAccuracy = "--"
        }
        
        let resultsBox = GroupBox(label: Text(labelText))
        {
            VStack(alignment: .leading)
            {
                HStack
                {
                    Text("Prediction: ")
                    Text("\(testPrediction) \(unitLabel)")
                }
                
                HStack
                {
                    Text("Accuracy: ")
                    Text("\(testAccuracy)%")
                }
            }
        }
        
        return resultsBox
    }
    
    fileprivate func makeConnectionsBox(transportConnectionData: ConnectionViewData, labelText: String) -> GroupBox<Text, VStack<TupleView<(Text, Text, Text, Text, Text)>>>
    {
        let totalConnections = transportConnectionData.connectionsCount
        var connectionOverhead = 0
        
        if totalConnections > 0
        {
            connectionOverhead = transportConnectionData.totalPayloadBytes/totalConnections
        }
        
        let connectionsBox = GroupBox(label: Text(labelText).font(.title).foregroundColor(adLabPink))
        {
            VStack(alignment: .leading) {
                Text("Connections Seen: \(totalConnections)")
                Text("Connections Analyzed: \(transportConnectionData.packetsAnalyzed)")
                Text("Outgoing Packets: \(transportConnectionData.outgoingPacketsCount)")
                Text("Incoming Packets: \(transportConnectionData.incomingPacketsCount)")
                Text("Transport Overhead: \(connectionOverhead) bytes")
            }
            
        }
        
        return connectionsBox
    }

}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        DataView(labData: LabData())
    }
}
