//
//  ConnectionChartViewController.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 7/7/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import Cocoa
import Charts

class ConnectionChartViewController: NSViewController
{
    @IBOutlet weak var titleField: NSTextField!
    
    var titleString = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        titleField.stringValue = titleString
    }
    
}
