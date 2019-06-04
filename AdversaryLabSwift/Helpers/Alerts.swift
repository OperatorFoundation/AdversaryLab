//
//  Alerts.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 5/17/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Cocoa

    // TODO: Call this when there is no appropriate data to be processed in the rdb file
func showNoDataAlert()
{
    let alert = NSAlert()
    alert.messageText = "No packets to process"
    alert.informativeText = "There is no valid data in the selected database file to process."
    alert.runModal()
}

func showOtherProcessAlert(processName: String)
{
    let alert = NSAlert()
    alert.messageText = "Server port is busy"
    alert.informativeText = "\(processName) is using the Redis server port. Adversary Lab will quit"
    alert.runModal()
    quitAdversaryLab()
}

func showNameModelAlert() -> String?
{
    let alert = NSAlert()
    alert.messageText = "Please name the folder where we will save the model group."
    
    let textfield = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 21))
    textfield.placeholderString = "Model Name"
    alert.accessoryView = textfield
    
    let _ = alert.runModal()
    
    guard textfield.stringValue != ""
        else { return nil }
    
    return textfield.stringValue
}

func showSelectAdversaryFileAlert() -> URL?
{
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowedFileTypes = ["adversary"]
    
    let result = panel.runModal()
    
    guard result == NSApplication.ModalResponse.OK
        else { return nil }
    
    return panel.urls[0]    
}

func showCaptureAlert()
{
    guard let helper = helperClient
        else
    {
        print("\nUnable to start live capture, the helper app is not initialized.")
        return
    }
    
    guard let adversaryLabClientPath = Bundle.main.path(forResource: "AdversaryLabClient", ofType: nil)
        else
    {
        print("Could not find AdversaryLabClient executable. This should be in the app bundle.")
        return
    }
    
    let alert = NSAlert()
    alert.messageText = "Please enter your capture options"
    alert.informativeText = "Enter the desired port to listen on and choose whether this is an allowed or a blocked connection."
    
    let textfield = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 21))
    textfield.placeholderString = "Port Number"
    alert.accessoryView = textfield
    alert.addButton(withTitle: "Capture Allowed Traffic")
    alert.addButton(withTitle: "Capture Blocked Traffic")
    alert.addButton(withTitle: "Cancel")
    
    let response = alert.runModal()
    
    guard textfield.stringValue != ""
        else
    {
        return
    }
    
    switch response
    {
    case .alertFirstButtonReturn:
        // Allowed Traffic
        print("\nCapture requested for allowed connection on port:\(textfield.stringValue)")
        helper.startAdversaryLabClient(allowBlock: "allow", port: textfield.stringValue, pathToClient: adversaryLabClientPath)
        
    case .alertSecondButtonReturn:
        // Blocked traffic
        print("\nCapture requested for blocked connection on port:\(textfield.stringValue)")
        helper.startAdversaryLabClient(allowBlock: "block", port: textfield.stringValue, pathToClient: adversaryLabClientPath)
        
    default:
        // Cancel Button
        return
    }
}

func quitAdversaryLab()
{
    // TODO: Quit
    RedisServerController.sharedInstance.shutdownRedisServer()
    NSApplication.shared.terminate(nil)
}
