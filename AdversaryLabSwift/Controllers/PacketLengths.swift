//
//  PacketLengths.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn

func processPacketLengths(forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
{
    let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
    let outgoingLengthSet: RSortedSet<Int> = RSortedSet(key: connection.outgoingLengthsKey)
    let inPacketHash: RMap<String, Data> = RMap(key: connection.incomingKey)
    let incomingLengthSet: RSortedSet<Int> = RSortedSet(key: connection.incomingLengthsKey)
    
    // Get the out packet that corresponds with this connection ID
    guard let outPacket: Data = outPacketHash[connection.connectionID]
        else
    {
        return (false, PacketLengthError.noOutPacketForConnection(connection.connectionID))
    }
    
    /// DEBUG
    if outPacket.count < 10
    {
        print("\n### Outpacket count = \(String(outPacket.count))")
        print("\n⁉️  We got a weird out packet size... \(String(describing: String(data: outPacket, encoding: .utf8)))<----")
    }
    ///
    
    // Increment the score of this particular outgoing packet length
    let _ = outgoingLengthSet.incrementScore(ofField: outPacket.count, byIncrement: 1)
    
    // Get the in packet that corresponds with this connection ID
    guard let inPacket = inPacketHash[connection.connectionID]
        else
    {
        return(false, PacketLengthError.noInPacketForConnection(connection.connectionID))
    }
    
    /// DEBUG
    if inPacket.count < 10
    {
        print("\n### Inpacket count = \(String(inPacket.count))\n")
        print("\n⁉️  We got a weird in packet size... \(String(describing: String(data: outPacket, encoding: .utf8))) <---\n")
    }
    ///
    
    // Increment the score of this particular incoming packet length
    let newInScore = incomingLengthSet.incrementScore(ofField: inPacket.count, byIncrement: 1)
    if newInScore == nil
    {
        return(false, PacketLengthError.unableToIncremementScore(packetSize: inPacket.count, connectionID: connection.connectionID))
    }
    
    return(true, nil)
}
