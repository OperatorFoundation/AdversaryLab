//
//  Globals.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 4/15/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Cocoa
import Foundation
import SwiftUI

import Abacus

var modelDirectoryURL: URL?

func getAdversarySupportDirectory() -> URL?
{
    if let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    {
        return appSupportDirectory.appendingPathComponent("AdversaryLab")
    }
    
    return nil
}

func getAdversaryTempDirectory() -> URL?
{
    guard let appDirectory = getAdversarySupportDirectory()
    else
    {
        print("\nFailed to test models. Unable to locate application document directory.")
        return nil
    }
    
    return appDirectory.appendingPathComponent("temp", isDirectory: true)
}
