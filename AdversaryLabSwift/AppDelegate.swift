//
//  AppDelegate.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 1/11/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Cocoa
import ZIPFoundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{    
    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        createAppSupportDirectory()
    }
    
    func application(_ application: NSApplication, open urls: [URL])
    {
        print("\nAdversary file opened. File URL(s): \(urls)")
        
        guard let fileURL = urls.first
            else { return }
        
        guard let adversaryDirectory = getAdversarySupportDirectory()
            else { return }
        
        let temporaryDirectory = adversaryDirectory.appendingPathComponent("temp", isDirectory: true)
        
        do
        {
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        catch
        {
            print("\nError creating temporary directory: \(error)")
        }

        do
        {
            try FileManager.default.unzipItem(at: fileURL, to: temporaryDirectory)
            
            
        }
        catch
        {
            print("\nError unzipping adversary file: \(error)")
        }
    }
    
    func createAppSupportDirectory()
    {
        if let adversaryDirectoryURL = getAdversarySupportDirectory()
        {
            do
            {
                try FileManager.default.createDirectory(at: adversaryDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            }
            catch
            {
                print("\nError creating adversary support directory: \(error)")
            }
        }
        else
        {
            print("\nUnable to find the application support directory. This is needed in order to save and unpack model files.")
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply
    {
        // Quit Redis Server
        print("TERMINATE Redis Server. 🤖")
        RedisServerController.sharedInstance.shutdownRedisServer()
        sleep(1)
        return NSApplication.TerminateReply.terminateNow
    }
    
    func applicationWillTerminate(_ aNotification: Notification)
    {
        
    }


}
