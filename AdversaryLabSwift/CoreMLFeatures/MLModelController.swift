//
//  FeatureController.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 4/5/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import CreateML
import CoreML
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
    
    func saveModel(classifier: MLClassifier,
                   classifierMetadata: MLModelMetadata,
                   classifierFileName: String,
                   regressor: MLRegressor,
                   regressorMetadata: MLModelMetadata,
                   regressorFileName: String,
                   groupName: String)
    {
        let fileManager = FileManager.default
        guard let appDirectory = getAdversarySupportDirectory()
            else
        {
            print("Failed to save the classifier, could not find the application document directory.")
            return
        }
        
        let modelGroupURL = appDirectory.appendingPathComponent(groupName)
        
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
        
        let classificationFileURL = modelGroupURL.appendingPathComponent(classifierFileName)
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
        
        let regressorFileURL = modelGroupURL.appendingPathComponent(regressorFileName)
        
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
            print("Error saving regressor model: \(saveModelError)")
        }
    }
    
    func save(classifier: MLClassifier,
              classifierMetadata: MLModelMetadata,
              fileName: String,
              groupName: String)
    {
        let fileManager = FileManager.default
        guard let appDirectory = getAdversarySupportDirectory()
        else
        {
            print("Failed to save the classifier, could not find the application document directory.")
            return
        }
        
        let modelGroupURL = appDirectory.appendingPathComponent(groupName)
        
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

        let classificationFileURL = modelGroupURL.appendingPathComponent("\(fileName).mlmodel")
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
            print("\nError saving Classification model: \(saveClassyError)")
        }
    }
    
    func save(regressor: MLRegressor,
              regressorMetadata: MLModelMetadata,
              fileName: String,
              groupName: String)
    {
        let fileManager = FileManager.default
        guard let appDirectory = getAdversarySupportDirectory()
            else
        {
            print("Failed to save the regressor, could not find the application document directory.")
            return
        }
        let modelGroupURL = appDirectory.appendingPathComponent(groupName)
        
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
        
        let regressorFileURL = modelGroupURL.appendingPathComponent("\(fileName).mlmodel")
        
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
        guard let appDirectory = getAdversarySupportDirectory()
            else
        {
            print("Failed to bundle the model group, could not find the application document directory.")
            return
        }
        let directoryURL = appDirectory.appendingPathComponent(groupName)
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
    
    func unpack(adversaryURL: URL) -> URL?
    {
        let fileManager = FileManager.default
        let modelGroupName = adversaryURL.deletingPathExtension().lastPathComponent
        
        guard let appDirectory = getAdversarySupportDirectory()
            else
        {
            print("Failed to unpack the adversary files, could not find the application document directory.")
            return nil
        }
        
        let temporaryDirURL = appDirectory.appendingPathComponent("\(modelGroupName)/temp", isDirectory: true)
        
        do
        {
            if fileManager.fileExists(atPath: temporaryDirURL.path)
            {
                try fileManager.removeItem(at: temporaryDirURL)
            }
            
            try fileManager.unzipItem(at: adversaryURL, to: temporaryDirURL, progress: nil, preferredEncoding: nil)
            
            let fileURLS = try fileManager.contentsOfDirectory(at: temporaryDirURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            for fileURL in fileURLS
            {
                if fileURL.pathExtension == "mlmodel"
                {
                    print("\nFound an mlm file in the chosen directory: \(fileURL)")
                }
            }
            
            return temporaryDirURL
        }
        catch let unzipError
        {
            print("\nError unzipping item at \(adversaryURL) to \(temporaryDirURL): \n\(unzipError)")
            
            return nil
        }
    }
    
    func createAllowedBlockedTables(fromTable dataTable: MLDataTable) -> (allowedTable: MLDataTable, blockedTable: MLDataTable)?
    {
        var allowedTable: MLDataTable?
        var blockedTable: MLDataTable?
        var currentTable: MLDataTable = dataTable
        var currentRow: MLDataTable?
        
        while (allowedTable == nil || blockedTable == nil) && currentTable.rows.count > 0
        {
            currentRow = currentTable.prefix(1)
            currentTable = currentTable.suffix(currentTable.rows.count - 1)
            
            // This is an allowed Row
            if currentRow?[ColumnLabel.classification.rawValue][0] == ClassificationLabel.allowed.rawValue
            {
                allowedTable = currentRow
            }
            else if currentRow?[ColumnLabel.classification.rawValue][0] == ClassificationLabel.blocked.rawValue
            {
                blockedTable = currentRow
            }
        }
        
        guard let aTable = allowedTable, let bTable = blockedTable
            else
        {
            print("\nFailed to create allowed or blocked lengths table.")
            return nil
        }
        
        return (aTable, bTable)
    }

    func prediction(fileURL: URL, batchFeatureProvider: MLBatchProvider) -> MLBatchProvider?
    {
        do
        {
            let compiledModelURL = try MLModel.compileModel(at: fileURL)
            let model = try MLModel(contentsOf: compiledModelURL)
            print("\nCreated a model from a file.\nInput: \(model.modelDescription.inputDescriptionsByName)\nPredicted Feature: \(model.modelDescription.predictedFeatureName ?? "unknown")\n")
            
            do
            {
                print("\nAttempting to make a prediction with \(model) using \(batchFeatureProvider.count) features")
                
                for index in 0 ..< batchFeatureProvider.count
                {
                    let features = batchFeatureProvider.features(at: index)
                    let featureNames = features.featureNames
                    let featureValue = features.featureValue(for: featureNames.first!)
                    print("\nFeature \(featureNames) = \(featureValue!)")
                }
                
                let prediction = try model.predictions(from: batchFeatureProvider, options: MLPredictionOptions())
                print("\n🔮  Made a prediction: \(prediction)  🔮")
                return prediction
            }
            catch let predictionError
            {
                print("\nError making prediction: \(predictionError)")
            }
        }
        catch let modelInitError
        {
            print("Error creating model from file at \(fileURL): \(modelInitError)")
        }
        
        return nil
    }
}
