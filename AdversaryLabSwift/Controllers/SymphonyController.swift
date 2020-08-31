//
//  SymphonyController.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 7/7/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Foundation
import ZIPFoundation
import Symphony
import RawPacket

class SymphonyController
{
    static let sharedInstance = SymphonyController()
    
    let tableName = "Packets"
    var transportNames: [String] = []
    var symphony: Symphony?
    var tablesURL: URL?

    func launchSymphony(fromFile fileURL: URL, completion: @escaping (Bool) -> Void)
    {
        // Unzip the directory
        guard let songDirectory = unzipSong(sourceURL: fileURL)
            else
        {
                completion(false)
                return
        }
        
        symphony = Symphony(root: songDirectory)
        
        // FIXME: We need to actually get the list of transport names from Symphony, this functionality does not exist yet
        // Get the list of transports in the Symphony DB
        
        do
        {
            let tables = try FileManager().contentsOfDirectory(at: songDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            tablesURL = songDirectory
            for tableURL in tables
            {
                transportNames.append(tableURL.lastPathComponent)
            }
            
            saveSymphonyDataAsConnectionGroup()
        }
        catch let error
        {
            print("Error looking for transport directories: \(error)")
            completion(false)
            return
        }
    }
    
    func saveSymphonyDataAsConnectionGroup()
    {
        let processor = DataProcessing()
        // Make sure that we have a connection to the database
        guard symphony != nil
            else
        {
            print("Unable to save Symphony data into Redis database. Failed to find Symphony instance.")
            return
        }

        guard transportNames.count > 1 else
        {
            print("Unable to add Symphony data to Redis, we need at least two transports.")
            return
        }
        
        print("Found transports in database: \(transportNames)")
        
        ///Ask the user which transport is allowed and which is blocked
        guard let (transportA, remainingTransports) = showChooseAConnectionsAlert(transportNames: self.transportNames)
            else
        {
                return
        }
            
        guard let (transportB, _) = showChooseBConnectionsAlert(transportNames: remainingTransports)
            else
        {
            return
        }
        
        guard let (aPackets, bPackets) = self.packetArraysFromSymphony(for: transportA, transportB: transportB)
        else
        {
           print("Failed to get both blocked and allowed packets from Symphony.")
           return
        }
            
        ///Write Swift data structures
        processor.updateConnectionGroupData(forTransportA: transportA,
                                            aRawPackets: aPackets,
                                            transportB: transportB,
                                            bRawPackets: bPackets)
    }
    
    /// File management
    func unzipSong(sourceURL: URL) -> URL?
    {
        let fileManager = FileManager()
        let currentWorkingURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let destinationURL = currentWorkingURL.appendingPathComponent("adversary_data")
        do
        {
            // Overwrite any old data at this directory
            if fileManager.fileExists(atPath: destinationURL.path)
            {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.unzipItem(at: sourceURL, to: currentWorkingURL)
            return destinationURL
        }
        catch
        {
            print("Extraction of ZIP archive failed with error:\(error)")
            return nil
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
        
        let tableURL = URL(fileURLWithPath: reThinkDBName)
        let table = symphonyDB.readSequence(elementType: RawPacket.self, at: tableURL)
        
        return table
    }
}
