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
    //static let sharedInstance = SymphonyController()    
    let dataQueue = DispatchQueue(label: "DataQueue")
    let tableName = "Packets"
    
    var transportNames: [String] = []
    var symphony: Symphony?
    var tablesURL: URL?

    func launchSymphony(fromFile fileURL: URL, labData: LabData) -> [String]?
    {
        // Unzip the directory
        guard let songDirectory = unzipSong(sourceURL: fileURL) else
        { return nil }
        
        symphony = Symphony(root: songDirectory)
        
        // Get the list of transports in the Symphony DB
        do
        {
            let tables = try FileManager().contentsOfDirectory(at: songDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            tablesURL = songDirectory
            for tableURL in tables
            {
                transportNames.append(tableURL.lastPathComponent)
            }
            
            // Make sure that we have a connection to the database
            guard symphony != nil
                else
            {
                print("Failed to find Symphony instance.")
                return nil
            }

            return transportNames
        }
        catch let error
        {
            print("Error looking for transport directories: \(error)")
            return nil
        }
    }
    
    func processConnectionData(labData: LabData) async -> Bool
    {
        guard let (aPackets, bPackets) = self.packetArraysFromSymphony(for: labData.transportA, transportB: labData.transportB)
        else
        {
           print("Failed to get both blocked and allowed packets from Symphony.")
           return false
        }
        let handler = Task
        {
            await DataProcessing().updateConnectionGroupData(labData: labData, aRawPackets: aPackets, bRawPackets: bPackets)
        }
        print("1) Called updateConnectionGroupData")
        let finished = await handler.value
        print("5) Finished updateConnectionGroupData")
        
        return finished
    }
    
    /// File management
    func unzipSong(sourceURL: URL) -> URL?
    {
        guard let applicationSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else {
            print("Unable to unzip the Song data because we could not find the application support directory.")
            return nil
        }
        
        let destinationURL = applicationSupportDir.appendingPathComponent("adversary_data")
        let otherZIPURL = applicationSupportDir.appendingPathComponent("__MACOSX")
        do
        {
            // Overwrite any old data at this directory
            if FileManager.default.fileExists(atPath: otherZIPURL.path)
            {
                try FileManager.default.removeItem(at: otherZIPURL)
            }
            
            if FileManager.default.fileExists(atPath: destinationURL.path)
            {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.unzipItem(at: sourceURL, to: applicationSupportDir)
            
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
