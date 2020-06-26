//
//  RethinkPacket.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 1/13/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation

struct RethinkPacket
{
    // FIXME: inOut bool value meaning is?
    let inOut: Bool
    let handshake: Bool
    let allowBlock: Bool
    let id: String
    let connectionID: String
    let timestamp: Double
    let tcpPacket: Payload
    let ipPacket: Payload
    let payload: Payload

    init?(reThinkData: Dictionary<String, Any>)
    {
        guard let inOutValue = reThinkData[ReThinkKey.inOut.rawValue] as? Bool,
            let handshakeValue = reThinkData[ReThinkKey.handshake.rawValue] as? Bool,
            let allowBlockValue = reThinkData[ReThinkKey.allowBlock.rawValue] as? Bool,
            let idValue = reThinkData[ReThinkKey.id.rawValue] as? String,
            let connectionIDValue = reThinkData[ReThinkKey.connectionID.rawValue] as? String,
            let timestampValue = reThinkData[ReThinkKey.timestamp.rawValue] as? Int
            else { return nil }
        
//        guard let tcpDict = reThinkData[ReThinkKey.tcpPacket.rawValue] as? Dictionary<String, Any>,
//            let ipDict = reThinkData[ReThinkKey.ipPacket.rawValue] as? Dictionary<String, Any>,
//            let payloadDict = reThinkData[ReThinkKey.payload.rawValue] as? Dictionary<String, Any>
//            else { return nil }
//
//        guard let tcpValue = Payload(packetDictionary: tcpDict),
//            let ipValue = Payload(packetDictionary: ipDict),
//            let payloadValue = Payload(packetDictionary: payloadDict)
//            else { return nil }
        
        guard let tcpValueString = reThinkData[ReThinkKey.tcpPacket.rawValue] as? String,
            let ipValueString = reThinkData[ReThinkKey.ipPacket.rawValue] as? String,
            let payloadValueString = reThinkData[ReThinkKey.payload.rawValue] as? String
            else { return nil }
        
        let tcpValue = Payload(type: ReQLType.binary, packetData: Data(tcpValueString.utf8))
        let ipValue = Payload(type: ReQLType.binary, packetData: Data(ipValueString.utf8))
        let payloadValue = Payload(type: ReQLType.binary, packetData: Data(payloadValueString.utf8))
        
        self.inOut = inOutValue
        self.handshake = handshakeValue
        self.allowBlock = allowBlockValue
        self.id = idValue
        self.connectionID = connectionIDValue
        self.timestamp = Double(timestampValue)
        self.tcpPacket = tcpValue
        self.ipPacket = ipValue
        self.payload = payloadValue
    }
    
}

struct Payload
{
    let type: ReQLType
    let packetData: Data
    
    init(type: ReQLType, packetData: Data)
    {
        self.type = type
        self.packetData = packetData
    }
    
    init?(packetDictionary: Dictionary<String, Any>)
    {
        guard let typeString = packetDictionary[ReThinkKey.reQLType.rawValue] as? String,
            let packetValue = packetDictionary[ReThinkKey.packetData.rawValue] as? String
        else { return nil }
        
        guard let decodedData = Data(base64Encoded: packetValue)
        else { return nil }
        
        // TODO: Account for more than one type
        guard typeString == ReQLType.binary.rawValue
            else
        {
            print("Error saving ReThink Payload data: unknown ReQL Type \(typeString)")
            return nil
        }
        
        if packetValue.isEmpty
        {
            print("\nRethink packet payload packet data is an empty string.\n")
        }
        
        self.type = ReQLType.binary
    
        self.packetData = decodedData
        //self.packetData = Data(packetValue.utf8)
    }
}

enum ReThinkKey: String
{
    case inOut = "in_out"
    case id = "id"
    case tcpPacket = "tcp_packet"
    case ipPacket = "ip_packet"
    case reQLType = "$reql_type$"
    case packetData = "data"
    case handshake = "handshake"
    case connectionID = "connection"
    case timestamp = "timestamp"
    case payload = "payload"
    case allowBlock = "allow_block"
}

enum ReQLType: String
{
    case binary = "BINARY"
}
