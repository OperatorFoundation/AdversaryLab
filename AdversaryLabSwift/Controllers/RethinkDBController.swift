//
//  RethinkDBController.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 1/3/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation
import Rethink

class RethinkDBController
{
    static let sharedInstance = RethinkDBController()
    //let rethinkdb = "/usr/local/bin/rethinkdb"
    let rethinkdb = "rethinkdb"
    let python = "/usr/local/bin/python3"
    let tableName = "Packets"
    var rethinkConnection: ReConnection?

    func launchRethinkDB(fromFile fileURL: URL, completion: @escaping (Bool) -> Void)
    {
        // Launch Server First
        
        // Now connect with client
        R.connect(URL(string: "rethinkdb://localhost:28015")!) { (connectError, reConnection) in
            
            if let rethinkError = connectError
            {
                print("Error connecting to the rethink database: \(rethinkError)")
                completion(false)
            }
            
            self.rethinkConnection = reConnection
            
            self.deleteDatabase
            {
                (deleted) in
                
                if !deleted
                {
                    print("\nFailed to delete old rethink data.")
                }
                
                self.restoreDB(fromFile: fileURL)
                
                self.mergeIntoCurrentDatabase
                {
                    success in
                    
                    print("\nReturned from merging DB.\n")
                    completion(success)
                }
            }
        }
    }
    
    func restoreDB(fromFile fileURL: URL)
    {
       let restoreTask = Process()
       restoreTask.executableURL = URL(fileURLWithPath: python, isDirectory: false)
       restoreTask.arguments = ["-m", rethinkdb, "restore", fileURL.path]
       
       print("Current Directory: \(FileManager.default.currentDirectoryPath)")
       print("Launching restoreDB process.")
       print("Execuatable URL: \(rethinkdb)")
       print("Arguments: \(restoreTask.arguments!)")
       restoreTask.launch()
    }
    
    func dumpDB(filename: String?)
    {
        let dumpTask = Process()
        dumpTask.executableURL = URL(fileURLWithPath: rethinkdb, isDirectory: false)
        
        //Arguments will pass the arguments to the executable, as though typed directly into terminal.
        var arguments = ["dump"]
        if filename != nil
        {
            arguments.append("-f")
            arguments.append("\(filename!).tar.gz")
        }
        dumpTask.arguments = arguments
        
        //Go ahead and run the process/task
        dumpTask.launch()
    }
    
    func deleteDatabase(completion: @escaping (Bool) -> Void)
    {
        // Make sure that we have a connection to the database
        guard let connection = rethinkConnection
            else {
                print("Unable to merge rethink data into current database. There is no connection to rethink.")
                completion(false)
                return
        }
        
        
        ///Scan rethinkdb for transports with available data
        R.dbList().run(connection)
        {
            (response) in
            
            guard let dbNames = response.value as? [String]
                else {
                    print("Unexpected response from rethink query dbList: \(response)")
                    completion(false)
                    return
            }
            
            for dbName in dbNames
            {
                R.dbDrop(dbName).run(connection)
                { (dbDropResponse) in
                    
                    print("Rethink database drop response: \(dbDropResponse)")
                }
            }
            
            completion(true)
        }
    }
    
    func mergeIntoCurrentDatabase(completion: @escaping (Bool) -> Void)
    {
        // Make sure that we have a connection to the database
        guard let connection = rethinkConnection
            else {
                print("Unable to merge rethink data into current database. There is no connection to rethink.")
                completion(false)
                return
        }
        
        ///Scan rethinkdb for transports with available data
        R.dbList().run(connection)
        {
            (response) in
            
            guard let dbNames = response.value as? [String]
                else {
                    print("Unexpected response from rethink query dbList: \(response)")
                    completion(false)
                    return
            }
            ///Ask the user which transport is allowed and which is blocked
            DispatchQueue.main.async {
                guard let (allowedTransport, remainingTransports) = showChooseAllowedConnectionsAlert(transportNames: dbNames)
                    else {
                        completion(false)
                        return
                }
                guard let (blockedTransport, _) = showChooseBlockedConnectionsAlert(transportNames: remainingTransports)
                    else {
                    completion(false)
                    return
                }
                
                ///Load the data for those transports into Swift data structures
                var allowedRethinks = [RethinkPacket]()
                var blockedRethinks = [RethinkPacket]()
                
                self.getPacketsArray(from: allowedTransport, connection: connection)
                {
                    (maybeAllowedArray) in
                    
                    if let allowedArray = maybeAllowedArray
                    {
                        ///Write Swift data structures to Redis database
                        
                        for allowedDictionary in allowedArray
                        {
                            if let aRethink = RethinkPacket(reThinkData: allowedDictionary)
                            {
                                allowedRethinks.append(aRethink)
                            }
                        }
                        
                        print("Parsed \(allowedRethinks.count) allowed RethinkPackets.")
                    }
                    
                    self.getPacketsArray(from: blockedTransport, connection: connection)
                    {
                        (maybeBlockedArray) in
                        
                        if let blockedArray = maybeBlockedArray
                        {
                            for blockedDictionary in blockedArray
                            {
                                if let bRethink = RethinkPacket(reThinkData: blockedDictionary)
                                {
                                    blockedRethinks.append(bRethink)
                                }
                            }
                            ///Write Swift data structures to Redis database
                            print("Parsed \(blockedRethinks.count) blocked RethinkPackets")
                            
                            guard !allowedRethinks.isEmpty, !blockedRethinks.isEmpty
                                else
                            {
                                print("Failed to get both blocked and allowed packets from Rethink.")
                                completion(false)
                                return
                            }
                            
                            let redisConnectionData = ConnectionData(allowedRethinkPackets: allowedRethinks, blockedRethinkPackets: blockedRethinks)
                            redisConnectionData.saveToRedis
                            {
                                (saved) in
                                
                                print("\nSaved our Rethink data to Redis!\n")
                                completion(saved)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func getPacketsArray(from reThinkDBName: String, connection: ReConnection, completion: @escaping (Array<Dictionary<String, Any>>?) -> Void)
    {
        R.db(reThinkDBName).table(self.tableName).indexWait().run(connection)
        { (waitResponse) in
            
            guard !waitResponse.isError
                else {
                    print("Error waiting for table: \(waitResponse)")
                    completion(nil)
                    return
            }
            
            R.db(reThinkDBName).table(self.tableName).count().run(connection) { (countResponse) in
                guard let docCount = countResponse.value as? Int
                    else {
                        print("Count response was not an int: \(countResponse)")
                        completion(nil)
                        return
                }
                
                R.db(reThinkDBName).table(self.tableName).sample(docCount).run(connection) { (sampleResponse) in
                    
                    guard let rawValues = sampleResponse.value as? Array<Dictionary<String,Any>>
                        else {
                            print("Raw data from ReThink is nil.")
                            completion(nil)
                            return
                    }
                    
                    print("Sample 0: \(rawValues[0])")
                    completion(rawValues)
                }
            }
        }
    }
}
