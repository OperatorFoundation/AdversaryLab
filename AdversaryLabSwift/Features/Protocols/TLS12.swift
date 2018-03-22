//
//  Sequences.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 2/8/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Auburn
import Datable

let tlsRequestStart=Data(bytes: [0x16, 0x03])
let tlsResponseStart=Data(bytes: [0x16, 0x03])
let commonNameStart=Data(bytes: [0x55, 0x04, 0x03])
let commonNameEnd=Data(bytes: [0x30])

func isTls12(forConnection connection: ObservedConnection) -> Bool
{
    // Get the in packet that corresponds with this connection ID
    let inPacketHash: RMap<String, Data> = RMap(key: connection.incomingKey)
    guard let inPacket: Data = inPacketHash[connection.connectionID] else {
        NSLog("Error, connection has no incoming packet")
        return false
    }

    let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
    guard let outPacket: Data = outPacketHash[connection.connectionID] else {
        NSLog("Error, connection has no outgoing packet")
        return false
    }

    let maybeRequestRange = inPacket.range(of: tlsRequestStart, options: .anchored, in: nil)
    let maybeResponseRange = outPacket.range(of: tlsResponseStart, options: .anchored, in: nil)

    guard let requestRange = maybeRequestRange else {
        NSLog("TLS request not found \(inPacket as! NSData)")
        return false
    }
    
    guard let responseRange = maybeResponseRange else {
        NSLog("TLS response not found \(outPacket as! NSData)")
        return false
    }
    
    NSLog("Found TLS: \(requestRange) \(responseRange) \(outPacket.count)")
    
    return true
}

func processTls12(_ connection: ObservedConnection) {
    NSLog("Processing TLS")
    let outPacketHash: RMap<String, Data> = RMap(key: connection.outgoingKey)
    
    // Get the out packet that corresponds with this connection ID
    guard let outPacket: Data = outPacketHash[connection.connectionID]
        else
    {
        NSLog("No TLS outgoing packet found")
        return
    }
    
    let maybeBegin = findCommonNameStart(outPacket)
    guard let begin = maybeBegin else {
        NSLog("No common name beginning found \(outPacket as! NSData)")
        NSLog("\(connection.outgoingKey) \(connection.connectionID) \(outPacket.count)")
        return
    }
    
    let maybeEnd = findCommonNameEnd(outPacket, begin+commonNameStart.count)
    guard let end = maybeEnd else {
        NSLog("No common name beginning end")
        return
    }
    
    let commonData = extract(outPacket, begin+commonNameStart.count, end)
    let commonName = commonData.string
    NSLog("Found TLS 1.2 common name: \(commonName)")
}

private func findCommonNameStart(_ outPacket: Data) -> Int? {
    let maybeRange = outPacket.range(of: commonNameStart)
    guard let range = maybeRange else {
        return nil
    }
    
    return range.lowerBound
}

private func findCommonNameEnd(_ outPacket: Data, _ begin: Int) -> Int? {
    let maybeRange = outPacket.range(of: commonNameEnd, options: [], in: begin..<outPacket.count)
    guard let range = maybeRange else {
        return nil
    }
    
    return range.lowerBound
}

private func extract(_ outPacket: Data, _ begin: Int, _ end: Int) -> Data {
    return outPacket[begin+2...end]
}
