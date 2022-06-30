//
//  LabData.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 6/29/22.
//  Copyright © 2022 Operator Foundation. All rights reserved.
//

import Foundation

class LabData
{
    var transportA = ""
    var transportB = ""
    var connectionGroupData = ConnectionGroupData()
    var packetLengths = PacketLengths()
    var packetTimings = PacketTimings()
    var packetEntropies = PacketEntropies()
    var trainingData = TrainingData()
}

class LabViewData: ObservableObject
{
    @Published var transportA = ""
    @Published var transportB = ""
    @Published var connectionGroupData = ConnectionViewGroupData()
    @Published var packetLengths = PacketLengths()
    @Published var packetTimings = PacketTimings()
    @Published var packetEntropies = PacketEntropies()
    @Published var trainingData = TrainingData()
    
    func copyAllLabData(labData: LabData)
    {
        copyLabConnectionData(labData: labData)
        copyLabTrainingData(labData: labData)
        copyLabTestingData(labData: labData)
    }
    
    func copyLabConnectionData(labData: LabData)
    {
        transportA = labData.transportA
        transportB = labData.transportB
        
        connectionGroupData.copyLabConnectionData(connectionGroupData: labData.connectionGroupData)
    }
    
    func copyLabTrainingData(labData: LabData)
    {
        connectionGroupData.aConnectionData.packetsAnalyzed = labData.connectionGroupData.aConnectionData.packetsAnalyzed
        connectionGroupData.bConnectionData.packetsAnalyzed = labData.connectionGroupData.bConnectionData.packetsAnalyzed

        trainingData.incomingEntropyTrainingResults = labData.trainingData.incomingEntropyTrainingResults
        trainingData.outgoingEntropyTrainingResults = labData.trainingData.outgoingEntropyTrainingResults
        trainingData.outgoingLengthsTrainingResults = labData.trainingData.outgoingLengthsTrainingResults
        trainingData.incomingLengthsTrainingResults = labData.trainingData.incomingLengthsTrainingResults
        trainingData.timingTrainingResults = labData.trainingData.timingTrainingResults
        
        packetEntropies.incomingA = labData.packetEntropies.incomingA
        packetEntropies.outgoingA = labData.packetEntropies.outgoingA
        packetEntropies.incomingB = labData.packetEntropies.incomingB
        packetEntropies.outgoingB = labData.packetEntropies.outgoingB
        
        packetTimings.transportA = labData.packetTimings.transportA
        packetTimings.transportB = labData.packetTimings.transportB
        
        packetLengths.outgoingA = labData.packetLengths.outgoingA
        packetLengths.incomingA = labData.packetLengths.incomingA
        packetLengths.outgoingB = labData.packetLengths.outgoingB
        packetLengths.incomingB = labData.packetLengths.incomingB
    }
    
    func copyLabTestingData(labData: LabData)
    {
        connectionGroupData.aConnectionData.packetsAnalyzed = labData.connectionGroupData.aConnectionData.packetsAnalyzed
        connectionGroupData.bConnectionData.packetsAnalyzed = labData.connectionGroupData.bConnectionData.packetsAnalyzed

        packetEntropies.incomingATestResults = labData.packetEntropies.incomingATestResults
        packetEntropies.incomingBTestResults = labData.packetEntropies.incomingBTestResults
        packetEntropies.outgoingATestResults = labData.packetEntropies.outgoingATestResults
        packetEntropies.outgoingBTestResults = labData.packetEntropies.outgoingBTestResults
        packetLengths.incomingATestResults = labData.packetLengths.incomingATestResults
        packetLengths.incomingBTestResults = labData.packetLengths.incomingBTestResults
        packetLengths.outgoingATestResults = labData.packetLengths.outgoingATestResults
        packetLengths.outgoingBTestResults = labData.packetLengths.outgoingBTestResults
        packetTimings.transportATestResults = labData.packetTimings.transportATestResults
        packetTimings.transportBTestResults = labData.packetTimings.transportBTestResults
    }

}
