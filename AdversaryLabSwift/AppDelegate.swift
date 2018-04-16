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
    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        
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

