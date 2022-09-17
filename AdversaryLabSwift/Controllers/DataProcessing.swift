//
//  DataProcessing.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 7/7/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation

import RawPacket
import Symphony

class DataProcessing
{
    func updateConnectionGroupData(labData: LabData, aRawPackets: ValueSequence<RawPacket>, bRawPackets: ValueSequence<RawPacket>) async -> Bool
    {
        print("2) Calling updateConnectionGroupData for Transport A")
        let processedA = await self.updateConnectionGroupData(labData: labData, forConnectionType: .transportA, fromRawPackets: aRawPackets)
        
        print("3) Calling updateConnectionGroupData for Transport B")
        let processedB = await self.updateConnectionGroupData(labData: labData, forConnectionType: .transportB, fromRawPackets: bRawPackets)

        if processedB && processedA
        {
            return true
        }
        else
        {
            return false
        }
        
    }
    
    func updateConnectionGroupData(labData: LabData, forConnectionType connectionType: ClassificationLabel, fromRawPackets rawPackets: ValueSequence<RawPacket>) async -> Bool
    {
        for packet in rawPackets
        {
                switch connectionType
                {
                    case .transportA:
                        labData.connectionGroupData.aConnectionData.totalPayloadBytes += packet.payload.count
                            
                        // inOut == true means an incoming connection
                        if packet.handshake
                        {
                            if packet.in_out
                            {
                                labData.connectionGroupData.aConnectionData.incomingPackets[packet.connection] = packet.payload
                                labData.connectionGroupData.aConnectionData.incomingDates[packet.connection] = Double(packet.timestamp)
                            }
                            else
                            {
                                labData.connectionGroupData.aConnectionData.outgoingPackets[packet.connection] = packet.payload
                                labData.connectionGroupData.aConnectionData.outgoingDates[packet.connection] = Double(packet.timestamp)
                            }
                                
                            // Add this connection ID to the list if it is not already there
                            if !labData.connectionGroupData.aConnectionData.connections.contains(packet.connection)
                            {
                                labData.connectionGroupData.aConnectionData.connections.append(packet.connection)
                            }
                        }
                        
                    case .transportB:
                        labData.connectionGroupData.bConnectionData.totalPayloadBytes += packet.payload.count
                        
                        if packet.handshake
                        {
                            // inOut == true means an incoming connection
                            if packet.in_out
                            {
                                labData.connectionGroupData.bConnectionData.incomingPackets[packet.connection] = packet.payload
                                labData.connectionGroupData.bConnectionData.incomingDates[packet.connection] = Double(packet.timestamp)
                                
                                print("Transport B incoming packet count: \(labData.connectionGroupData.bConnectionData.incomingPackets.count)")
                            }
                            else
                            {
                                labData.connectionGroupData.bConnectionData.outgoingPackets[packet.connection] = packet.payload
                                labData.connectionGroupData.bConnectionData.outgoingDates[packet.connection] = Double(packet.timestamp)
                                
                                print("Transport B outgoing packet count: \(labData.connectionGroupData.bConnectionData.outgoingPackets.count)")
                            }

                            // Add this connection ID to the list if it is not already there
                            if !labData.connectionGroupData.bConnectionData.connections.contains(packet.connection)
                            {
                                labData.connectionGroupData.bConnectionData.connections.append(packet.connection)
                            }
                        }
                        
                }
        }
        
        return true
    }


}
