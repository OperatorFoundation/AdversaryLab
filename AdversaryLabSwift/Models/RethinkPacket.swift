//
//  RethinkPacket.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 1/13/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation

struct RethinkPacket: Codable
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
}

struct Payload: Codable
{
    let type: ReQLType
    let packetData: Data
    
    init(type: ReQLType, packetData: Data)
    {
        self.type = type
        self.packetData = packetData
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

enum ReQLType: String, Codable
{
    case binary = "BINARY"
}

extension Data {
    var hexDescription: String {
        return reduce("") {$0 + String(format: "%02x", $1)}
    }
}
