//
//  TestModeViewController.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 4/26/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Cocoa
import CoreML

class TestModeViewController: NSViewController
{
    @IBOutlet weak var modelNameLabel: NSTextField!
    
    var modelDirectoryURL: URL?
    var modelName = ""
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        guard let modelDirURL = modelDirectoryURL
        else
        {
            // TODO: Show alert
            print("\nUnable to run model test, model directory is invalid.")
            
            self.view.window?.close()
            return
        }
        
        modelName = modelDirURL.lastPathComponent
        modelNameLabel.stringValue = modelName
        
        do
        {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: modelDirURL, includingPropertiesForKeys: [kCFURLLocalizedNameKey as URLResourceKey, kCFURLTypeIdentifierKey as URLResourceKey], options: .skipsHiddenFiles)
            
            for fileURL in fileURLs
            {
                if fileURL.pathExtension == "mlmodel"
                {
                    print("\nFound an mlm file in the chosen directory: \(fileURL)")
                    do
                    {
                        let compiledModelURL = try MLModel.compileModel(at: fileURL)
                        let model = try MLModel(contentsOf: compiledModelURL)
                        
                        print("\nCreated a model from a file.\nInput: \(model.modelDescription.inputDescriptionsByName)\nPredicted Feature: \(model.modelDescription.predictedFeatureName)\n")
                        
                        
                    }
                    catch let modelInitError
                    {
                        print("Error creating model from file at \(fileURL): \(modelInitError)")
                    }
                    
                }
            }
        }
        catch let directoryContentsError
        {
            print("\nError checking contents of selected model directory: \(directoryContentsError)")
        }
    }
    
}
