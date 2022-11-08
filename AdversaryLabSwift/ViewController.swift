//
//  ViewController.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 1/11/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Cocoa
import CoreML
import SwiftUI

class ViewController: NSViewController
{
    var streaming: Bool = false
            
    override func viewDidLoad()
    {
        super.viewDidLoad()
    }

    // MARK: - IBActions
    @IBAction func newLabClicked(_ sender: NSButton)
    {
        let panel = NSPanel(contentViewController: NSHostingController(rootView: LabView().frame(minWidth: 700, minHeight: 625)))
        panel.center()
        panel.title = "Adversary Lab"
        panel.makeKeyAndOrderFront(nil)
    }

}
