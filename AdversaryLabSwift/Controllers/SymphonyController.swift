//
//  SymphonyController.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 7/7/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation
import Rethink
import Symphony
import RawPacket

class SymphonyController
{
    static let sharedInstance = SymphonyController()
    let rethinkdb = "rethinkdb"
    let python = "/usr/local/bin/python3"
    let tableName = "Packets"
    var symphony: Symphony?

    func launchSymphony(fromFile fileURL: URL, completion: @escaping (Bool) -> Void)
    {
        symphony = Symphony(root: fileURL)
        saveSymphonyDataToRedis
        {
            (success) in
            
            print("\nReturned from saving Symphony Data to Redis DB.\n")
            completion(success)
        }
    }
    
    func saveSymphonyDataToRedis(completion: @escaping (Bool) -> Void)
    {
        let processor = DataProcessing()
        // Make sure that we have a connection to the database
        guard symphony != nil
            else
        {
            print("Unable to save Symphony data into Redis database. Failed to find Symphony instance.")
            completion(false)
            return
        }
        
        // FIXME: We need to actually get the list of transport names from Symphony, this functionality does not exist yet
        // Get the list of transports in the Symphony DB
        let transportNames: [String] = []
        
        guard transportNames.count > 1 else
        {
            print("Unable to add Symphony data to Redis, we need at least two transports.")
            completion(false)
            return
        }
        
        print("Found transports in database: \(transportNames)")
        
        ///Ask the user which transport is allowed and which is blocked
        DispatchQueue.main.async
        {
            guard let (transportA, remainingTransports) = showChooseAConnectionsAlert(transportNames: transportNames)
                else
            {
                    completion(false)
                    return
            }
                
            guard let (transportB, _) = showChooseBConnectionsAlert(transportNames: remainingTransports)
                else
            {
                completion(false)
                return
            }
            
            guard let (aPackets, bPackets) = self.packetArraysFromSymphony(for: transportA, transportB: transportB)
            else
            {
               print("Failed to get both blocked and allowed packets from Symphony.")
               completion(false)
               return
            }
                
            ///Write Swift data structures to Redis database
            let redisConnectionData = processor.connectionData(forTransportA: transportA, aRawPackets: aPackets, transportB: transportB, bRawPackets: bPackets)
            
            processor.saveToRedis(connectionData: redisConnectionData)
            {
                (saved) in
                
                print("\nSaved our Symphony data to Redis!\n")
                completion(saved)
            }
        }
    }
    
    /// ValueSequence is our own custom Array type
    func packetArraysFromSymphony(for transportA: String, transportB: String) -> (ValueSequence<RawPacket>, ValueSequence<RawPacket>)?
    {
        guard let aArray = self.getPacketsArray(from: transportA)
            else { return nil }
                
        guard let bArray = self.getPacketsArray(from: transportB)
            else { return nil }
        
        return (aArray, bArray)
    }
    
    func getPacketsArray(from reThinkDBName: String) -> ValueSequence<RawPacket>?
    {
        guard let symphonyDB = symphony
            else { return nil }
        
        let tableURL = URL(fileURLWithPath: self.tableName)
        let table = symphonyDB.readSequence(elementType: RawPacket.self, at: tableURL)
        
        return table
    }
}
