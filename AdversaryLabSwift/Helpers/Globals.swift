//
//  Globals.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 4/15/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import Cocoa

var helperClient: AdversaryLabServiceProtocol?
var appDirectory = ""

func getAdversarySupportDirectory() -> URL?
{
    if let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    {
        return appSupportDirectory.appendingPathComponent("AdversaryLab")
    }
    
    return nil
}
