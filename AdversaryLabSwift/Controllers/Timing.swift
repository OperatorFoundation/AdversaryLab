//
//  Timing.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn

func processTiming(forConnection connection: ObservedConnection) -> (processed: Bool, error: Error?)
{
    let outPacketDateHash: RMap<String, Double> = RMap(key: connection.outgoingDateKey)
    let inPacketDateHash: RMap<String, Double> = RMap(key: connection.incomingDateKey)
    let timeDifferenceList: RList<Double> = RList(key: connection.timeDifferenceKey)
    
    // Get the out packet time stamp
    guard let outTimeInterval = outPacketDateHash[connection.connectionID]
        else
    {
        return (false, PacketTimingError.noOutPacketDateForConnection(connection.connectionID))
    }
    
    // Get the in packet time stamp
    guard let inTimeInterval = inPacketDateHash[connection.connectionID]
        else
    {
        return (false, PacketTimingError.noInPacketDateForConnection(connection.connectionID))
    }
    
    // Add the time difference for this connection to the database
    let timeDifference = outTimeInterval - inTimeInterval
    timeDifferenceList.append(timeDifference)
    
    return (true, nil)
}
