//
//  Sequences.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn

func processOffsetSequences(forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
{
    // Get the out packet that corresponds with this connection ID
    let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
    guard let outPacket: Data = outPacketHash[connection.connectionID]
        else
    {
        return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID))
    }
    
    for (index, _) in outPacket.enumerated()
    {
        let outOffsetSequenceSetKey = "\(connection.outgoingOffsetSequencesKey)\(index)"
        let outOffsetSequenceSet: RSortedSet<Data> = RSortedSet(key: outOffsetSequenceSetKey)
        for x in index..<outPacket.count
        {
            
            let sequence = outPacket[index...x]
            let newOutScore = outOffsetSequenceSet.incrementScore(ofField:sequence, byIncrement: 1)
            if newOutScore == nil
            {
                print("\nError incrementing score for out sequence \([UInt8](sequence)) for connection ID \(connection.connectionID)")
                print("Packet: \([UInt8](outPacket))")
            }
        }
        //print("Done creating out packet offset subsequence...")
    }
    
    // Get the in packet that corresponds with this connection ID
    let inPacketHash: RMap<String, Data> = RMap(key: connection.incomingKey)
    guard let inPacket = inPacketHash[connection.connectionID]
        else
    {
        return(false, PacketLengthError.noInPacketForConnection(connection.connectionID))
    }
    
    for (index, _) in inPacket.enumerated()
    {
        let inOffsetSequenceKey = "\(connection.incomingOffsetSequencesKey)\(index)"
        let inOffsetSequenceSet: RSortedSet<Data> = RSortedSet(key: inOffsetSequenceKey)
        for x in index ..< inPacket.count
        {
            let sequence = inPacket[index...x]
            let newInScore = inOffsetSequenceSet.incrementScore(ofField: sequence, byIncrement: 1)
            if newInScore == nil
            {
                print("Error incrementing score for in sequence \(sequence) for connection ID \(connection.connectionID)")
            }
        }
        //print("Done creating in packet offset subsequence...")
    }
    
    return (true, nil)
}
