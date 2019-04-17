//
//  AppDelegate.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 1/11/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{
    let fileManager = FileManager.default
    
    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        createAppSupportDirectory()
        
//        //Install God-Mode Helper
//        if !HelperAppInstaller.blessHelper(label: "org.OperatorFoundation.MoonbounceHelperTool")
//        {
//            print("Could not install MoonbounceHelperTool")
//        }
//        else
//        {
//            helperClient = HelperAppController.connectToXPCService()
//        }
    }
    
    func createAppSupportDirectory()
    {
        let appSupportDirectory = fileManager.urls(for: FileManager.SearchPathDirectory.applicationSupportDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)
        if appSupportDirectory.count > 0
        {
            if let bundleID: String = Bundle.main.bundleIdentifier
            {
                // Append the bundle ID to the URL for the
                // Application Support directory
                let directoryPath = appSupportDirectory[0].appendingPathComponent(bundleID)
                appDirectory = directoryPath.path
            }
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
