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
        let panel = NSPanel(contentViewController: NSHostingController(rootView: LabView().frame(minWidth: 800, minHeight: 960)))
        panel.title = "Adversary Lab"
        panel.makeKeyAndOrderFront(nil)
    }
    
    
    func streamConnections()
    {
        analysisQueue.async
        {
            while self.streaming == true
            {
                let connectionGenerator = FakeConnectionGenerator()
                connectionGenerator.addConnections()
            }
        }
    }
}


