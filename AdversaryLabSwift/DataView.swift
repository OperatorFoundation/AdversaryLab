//
//  SwiftUIView.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 6/27/22.
//  Copyright © 2022 Operator Foundation. All rights reserved.
//

import SwiftUI

struct DataView: View
{
    @EnvironmentObject var labViewData: LabViewData
    @State var modelName = ""
    @State private var isLoading = false
    
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
                        makeResultsBox(trainingResults: labViewData.trainingData.timingTrainingResults, labelText: "Timing")
                        Spacer()
                        GroupBox(label: Text("Packet Lengths"))
                        {
                            makeResultsBox(trainingResults: labViewData.trainingData.outgoingLengthsTrainingResults, labelText: "Outgoing Rules")
                            makeResultsBox(trainingResults: labViewData.trainingData.incomingLengthsTrainingResults, labelText: "Incoming Rules")
                        }
                        Spacer()
                        GroupBox(label: Text("Entropy"))
                        {
                            makeResultsBox(trainingResults: labViewData.trainingData.outgoingEntropyTrainingResults, labelText: "Outgoing Rules")
                            makeResultsBox(trainingResults: labViewData.trainingData.incomingEntropyTrainingResults, labelText: "Incoming Rules")
                        }
                    }
                    
                    HStack
                    {
                        Button
                        {
                            if let selectedFileURL = showRethinkFileAlert()
                            {
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
                
                GroupBox(label: Text("Test Data: \(modelName)")) // Test Data
                {
                    HStack
                    {
                        GroupBox(label: Text("Timing"))
                        {
                            makeResultsBox(testResults: labViewData.packetTimings.transportATestResults, labelText: labViewData.transportA)
                            makeResultsBox(testResults: labViewData.packetTimings.transportBTestResults, labelText: labViewData.transportB)
                        }
                        Spacer()
                        GroupBox(label: Text("Packet Lengths"))
                        {
                            makeResultsBox(testResults: labViewData.packetLengths.outgoingATestResults, labelText: "\(labViewData.transportA) Outgoing")
                            makeResultsBox(testResults: labViewData.packetLengths.outgoingBTestResults, labelText: "\(labViewData.transportB) Outgoing")
                            makeResultsBox(testResults: labViewData.packetLengths.incomingATestResults, labelText: "\(labViewData.transportA) Incoming")
                            makeResultsBox(testResults: labViewData.packetLengths.incomingBTestResults, labelText: "\(labViewData.transportB) Incoming")
                        }
                        Spacer()
                        GroupBox(label: Text("Entropy"))
                        {
                            makeResultsBox(testResults: labViewData.packetEntropies.outgoingATestResults, labelText: "\(labViewData.transportA) Outgoing")
                            makeResultsBox(testResults: labViewData.packetEntropies.outgoingBTestResults, labelText: "\(labViewData.transportB) Outgoing")
                            makeResultsBox(testResults: labViewData.packetEntropies.incomingATestResults, labelText: "\(labViewData.transportA) Incoming")
                            makeResultsBox(testResults: labViewData.packetEntropies.incomingBTestResults, labelText: "\(labViewData.transportB) Incoming")
                        }
                    }
                    
                    HStack
                    {
                        Button
                        {
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
                                }
                                else
                                {
                                    print("🚨  Failed to unpack the selected adversary file.  🚨")
                                }
                            }
                        }
                        label: {
                            Text("Load Model")
                                .opacity(isLoading ? 0.3 : 1)
                        }
                        .disabled(isLoading)
                        
                        Button
                        {
                            Task
                            {
                                await runTest()
                            }
                            
                        }
                        label: {
                            Text("Test")
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
    
    fileprivate func makeResultsBox(trainingResults: TrainingResults?, labelText: String) -> GroupBox<Text, TupleView<(Text, Text, Text, Text, Text)>>
    {
        if let trainingResults = trainingResults
        {
            let aPrediction = (String(format: "%.2f", trainingResults.transportAPrediction))
            let bPrediction = (String(format: "%.2f", trainingResults.transportBPrediction))
            let trainingAccuracy = trainingResults.trainingAccuracy != nil ? String(format: "%.2f", trainingResults.trainingAccuracy!) : "--"
            let validationAccuracy = trainingResults.validationAccuracy != nil ? String(format: "%.2f", trainingResults.validationAccuracy!) : "--"
            let evaluationAccuracy = trainingResults.evaluationAccuracy != nil ? String(format: "%.2f", trainingResults.evaluationAccuracy!) : "--"
            
            return GroupBox(label: Text(labelText))
            {
                Text("\(labViewData.transportA): \(aPrediction)")
                Text("\(labViewData.transportB): \(bPrediction)")
                Text("Training Accuracy: \(trainingAccuracy)")
                Text("Validation Accuracy: \(validationAccuracy)")
                Text("Evaluation Accuracy: \(evaluationAccuracy)")
            }
        }
        else
        {
            return GroupBox(label: Text(labelText))
            {
                Text("\(labViewData.transportA): --")
                Text("\(labViewData.transportB): --")
                Text("Training Accuracy: --")
                Text("Validation Accuracy: --")
                Text("Evaluation Accuracy: --")
            }
        }
    }
    
    fileprivate func makeResultsBox(testResults: TestResults?, labelText: String) -> GroupBox<Text, TupleView<(Text, Text)>>
    {
        if let testResults = testResults
        {
            let testPrediction = String(format: "%.2f", testResults.prediction)
            let testAccuracy = testResults.accuracy != nil ? String(format: "%.2f", testResults.accuracy!) : "--"

            return GroupBox(label: Text(labelText))
            {
                Text("Prediction: \(testPrediction)")
                Text("Accuracy: \(testAccuracy)")
            }
        }
        else
        {
            return GroupBox(label: Text(labelText))
            {
                Text("Prediction: --")
                Text("Accuracy: --")
            }
        }
    }
    
    fileprivate func makeConnectionsBox(transportConnectionData: ConnectionViewData, labelText: String) -> GroupBox<Text, TupleView<(Text, Text, Text, Text, Text)>>
    {
        let totalConnections = transportConnectionData.connectionsCount
        var connectionOverhead = 0
        
        if totalConnections > 0
        {
            connectionOverhead = transportConnectionData.totalPayloadBytes/totalConnections
        }
        
        return GroupBox(label: Text(labelText))
        {
            Text("Connections Seen: \(totalConnections)")
            Text("Connections Analyzed: \(transportConnectionData.packetsAnalyzed)")
            Text("Outgoing Packets: \(transportConnectionData.outgoingPacketsCount)")
            Text("Incoming Packets: \(transportConnectionData.incomingPacketsCount)")
            Text("Transport Overhead: \(connectionOverhead) bytes")
            
        }
    }

}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        DataView(labData: LabData())
    }
}
