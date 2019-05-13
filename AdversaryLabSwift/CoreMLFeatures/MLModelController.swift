//
//  FeatureController.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 4/5/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import CreateML
import ZIPFoundation

class MLModelController
{
    func saveModel(classifier: MLClassifier,
                   classifierMetadata: MLModelMetadata,
                   regressor: MLRegressor,
                   regressorMetadata: MLModelMetadata,
                   fileName: String,
                   groupName: String)
    {
        save(classifier: classifier, classifierMetadata: classifierMetadata, fileName: fileName, groupName: groupName)
        save(regressor: regressor, regressorMetadata: regressorMetadata, fileName: fileName, groupName: groupName)
    }
    
    func save(classifier: MLClassifier,
              classifierMetadata: MLModelMetadata,
              fileName: String,
              groupName: String)
    {
        let fileManager = FileManager.default
        let modelGroupURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(groupName)
        
        if !fileManager.fileExists(atPath: modelGroupURL.path)
        {
            do
            {
                _ = try fileManager.createDirectory(at: modelGroupURL, withIntermediateDirectories: true, attributes: nil)
            }
            catch let directoryError
            {
                print("\nError creating model directory: \(directoryError)")
            }
        }

        let classificationFileURL = modelGroupURL.appendingPathComponent("AdversaryLab_\(fileName)_Classification.mlmodel")
        if fileManager.fileExists(atPath: classificationFileURL.path)
        {
            do
            {
                try fileManager.removeItem(at: classificationFileURL)
            }
            catch let removeClassyFileError
            {
                print("\nError removing file at \(classificationFileURL): \(removeClassyFileError)")
            }
        }
        do
        {
            try classifier.write(to: classificationFileURL, metadata: classifierMetadata)
        }
        catch let saveClassyError
        {
            print("Error saving Classification model: \(saveClassyError)")
        }
    }
    
    func save(regressor: MLRegressor,
              regressorMetadata: MLModelMetadata,
              fileName: String,
              groupName: String)
    {
        let fileManager = FileManager.default
        let modelGroupURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(groupName)
        
        if !fileManager.fileExists(atPath: modelGroupURL.path)
        {
            do
            {
                _ = try fileManager.createDirectory(at: modelGroupURL, withIntermediateDirectories: true, attributes: nil)
            }
            catch let directoryError
            {
                print("\nError creating model directory: \(directoryError)")
            }
        }
        
        let regressorFileURL = modelGroupURL.appendingPathComponent("AdversaryLab_\(fileName)_Regressor.mlmodel")
        
        if fileManager.fileExists(atPath: regressorFileURL.path)
        {
            do
            {
                try FileManager.default.removeItem(at: regressorFileURL)
            }
            catch let removeFileError
            {
                print("Error removing file at \(regressorFileURL.path): \(removeFileError)")
            }
        }
        
        do
        {
            try regressor.write(to: regressorFileURL, metadata: regressorMetadata)
        }
        catch let saveModelError
        {
            print("Error saving tls regressor model: \(saveModelError)")
        }
    }
    
    func bundle(modelGroup groupName: String)
    {
        let fileManager = FileManager.default
        let directoryURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(groupName)
        let bundleURL = directoryURL.appendingPathExtension("adversary")
        
        if fileManager.fileExists(atPath: bundleURL.path)
        {
            do
            {
                try fileManager.removeItem(at: bundleURL)
            }
            catch let removeError
            {
                print("Failed to remove pre existing file at \(bundleURL).\nError:\(removeError)")
                return
            }
        }

        do
        {
            try fileManager.zipItem(at: directoryURL, to: bundleURL)
            try fileManager.removeItem(at: directoryURL)
        }
        catch let zipError
        {
            print("\nUnable to zip model directory: \(zipError)")
        }
    }
    
    func unpack(adversaryURL: URL)
    {
        let fileManager = FileManager.default
        let temporaryDirURL = adversaryURL.deletingPathExtension()
        let modelGroupName = temporaryDirURL.lastPathComponent
        
        do
        {
            try fileManager.unzipItem(at: adversaryURL, to: temporaryDirURL, progress: nil, preferredEncoding: nil)
            
            let fileURLS = try fileManager.contentsOfDirectory(at: temporaryDirURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            for fileURL in fileURLS
            {
                do
                {
                    let dataTable = try MLDataTable(contentsOf: fileURL)
                    
                    let columnNames = dataTable.columnNames
                    if columnNames.count == 2
                    {
                        for columnName in columnNames
                        {
                            switch columnName
                            {
                            case ColumnLabel.entropy.rawValue:
                                print("\nFound Entropy Model File")
                            case ColumnLabel.timeDifference.rawValue:
                                print("\nFound Timing Model File")
                            case ColumnLabel.length.rawValue:
                                print("\nFound Packet Length Model File")
                            case ColumnLabel.classification.rawValue:
                                continue
                            default:
                                print("\nUnknown column: \(columnName)")
                            }
                        }
                        
                    }
                    
                }
                catch let dataTableError
                {
                    print("\nError creating MLDataTable: \(dataTableError)")
                    continue
                }
                
                //MLClassifier(trainingData: <#T##MLDataTable#>, targetColumn: <#T##String#>)
            }
        }
        catch let unzipError
        {
            print("\nError unzipping item at \(adversaryURL) to \(temporaryDirURL): \n\(unzipError)")
        }
        
        
    }
}
