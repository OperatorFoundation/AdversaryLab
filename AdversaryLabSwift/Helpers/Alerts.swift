//
//  Alerts.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 5/17/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers


/// Call this when there is no appropriate data to be processed
func showNoDataAlert(labData: LabData)
{
    let alert = NSAlert()
    alert.messageText = "Not enough packets to process"
    alert.informativeText = "There is not enough valid data in the selected database file."
    _ = alert.runModal()
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
    panel.allowedContentTypes = [UTType("org.operatorFoundation.AdversaryLabSwift")!]
    
    let result = panel.runModal()
    
    guard result == NSApplication.ModalResponse.OK
        else { return nil }
    
    return panel.urls[0]    
}

func showSelectAdversaryLabDataAlert() -> URL?
{
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [UTType.zip]
    
    let result = panel.runModal()
    guard result == NSApplication.ModalResponse.OK
        else { return nil }
    
    return panel.urls[0]
}

func showChooseBConnectionsAlert(labData: LabData, transportNames: [String])
{
    // Do not show Transport A as an option if it has already been selected
    var remainingTransports = transportNames
    if let index = remainingTransports.firstIndex(of: labData.transportA)
    {
        remainingTransports.remove(at: index)
    }
    
    let alert = NSAlert()
    alert.messageText = "Select the other transport you want to use for your analysis."
    
    let transportBPopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200 , height: 20))
    transportBPopup.addItems(withTitles: remainingTransports)
    alert.accessoryView = transportBPopup
    
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    
    let result = alert.runModal()
    if result == .alertFirstButtonReturn
    {
        let index = transportBPopup.indexOfSelectedItem
        if index >= 0, index < remainingTransports.count, let selectedTransport = transportBPopup.titleOfSelectedItem
        {
            labData.transportB = selectedTransport
        }
    }
}

func showChooseAConnectionsAlert(labData: LabData, transportNames: [String])
{
    // Do not show Transport A as an option if it has already been selected
    var remainingTransports = transportNames
    if let index = remainingTransports.firstIndex(of: labData.transportB)
    {
        remainingTransports.remove(at: index)
    }
    
    let alert = NSAlert()
    alert.messageText = "Select one of the transports you want to analyze."
    
    let transportAPopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200 , height: 20))
    transportAPopup.addItems(withTitles: remainingTransports)
    alert.accessoryView = transportAPopup
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    
    let result = alert.runModal()
    if result == .alertFirstButtonReturn
    {
        let index = transportAPopup.indexOfSelectedItem
        if index >= 0, index < remainingTransports.count, let selectedTransport = transportAPopup.titleOfSelectedItem
        {
            labData.transportA = selectedTransport
        }
    }
}

func quitAdversaryLab()
{
    // TODO: Quit
    NSApplication.shared.terminate(nil)
}
