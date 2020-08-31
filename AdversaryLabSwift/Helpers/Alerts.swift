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
    alert.messageText = "Not enough packets to process"
    alert.informativeText = "There is not enough valid data in the selected database file."
    alert.runModal()
}

func showNoBlockedConnectionsAlert()
{
    let alert = NSAlert()
    alert.messageText = "No blocked connections to test"
    alert.informativeText = "There are no observed blocked connections in the current database. Please run live capture for blocked connections before trying to test the data."
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

func showRethinkFileAlert() -> URL?
{
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedFileTypes = ["zip"]
    
    let result = panel.runModal()
    guard result == NSApplication.ModalResponse.OK
        else { return nil }
    
    return panel.urls[0]
}

func showChooseBConnectionsAlert(transportNames: [String]) -> (transportB: String, remainingTransports: [String])?
{
    let alert = NSAlert()
    alert.messageText = "Select the other transport you want to use for your analysis."
    
    let blockedPopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200 , height: 20))
    blockedPopup.addItems(withTitles: transportNames)
    alert.accessoryView = blockedPopup
    
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    
    let result = alert.runModal()
    if result == .alertFirstButtonReturn
    {
        let index = blockedPopup.indexOfSelectedItem
        if index >= 0, index < transportNames.count, let selectedTransport = blockedPopup.titleOfSelectedItem
        {
            
            var remainingTransports = transportNames
            _ = remainingTransports.remove(at: index)
            transportB = selectedTransport
            return (selectedTransport, remainingTransports)
        }
    }
    
    return nil
}

func showChooseAConnectionsAlert(transportNames: [String]) -> (transportA: String, remainingTransports: [String])?
{
    let alert = NSAlert()
    alert.messageText = "Select one of the transports you want to analyze."
    
    let allowedPopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200 , height: 20))
    allowedPopup.addItems(withTitles: transportNames)
    alert.accessoryView = allowedPopup
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    
    let result = alert.runModal()
    if result == .alertFirstButtonReturn
    {
        let index = allowedPopup.indexOfSelectedItem
        if index >= 0, index < transportNames.count, let selectedTransport = allowedPopup.titleOfSelectedItem
        {
            
            var remainingTransports = transportNames
            _ = remainingTransports.remove(at: index)
            transportA = selectedTransport
            return (selectedTransport, remainingTransports)
        }
    }
    
    return nil
}

func quitAdversaryLab()
{
    // TODO: Quit
    RedisServerController.sharedInstance.shutdownRedisServer()
    NSApplication.shared.terminate(nil)
}
