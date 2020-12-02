//
//  FileController.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 10/6/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import CreateML
import Foundation

import Song
import ZIPFoundation

class FileController
{
    let trainingDataFilename = "TrainingResults.json"
    
    func saveModel(classifier: MLClassifier,
    classifierMetadata: MLModelMetadata,
    classifierFileName: String,
    recommender: LengthRecommender,
    recommenderFileName: String,
    groupName: String)
    {
        save(classifier: classifier, classifierMetadata: classifierMetadata, fileName: classifierFileName, groupName: groupName)
        save(recommender: recommender, fileName: recommenderFileName, groupName: groupName)
    }
    
    func saveModel(classifier: MLClassifier,
                   classifierMetadata: MLModelMetadata,
                   classifierFileName: String,
                   regressor: MLRegressor,
                   regressorMetadata: MLModelMetadata,
                   regressorFileName: String,
                   groupName: String)
    {
        guard let appDirectory = prepareDirectory(groupName: groupName)
            else
        {
            print("Failed to save the model, could not prepare the \(groupName) directory.")
            return
        }
        
        let modelGroupURL = appDirectory.appendingPathComponent(groupName)
        let classificationFileURL = modelGroupURL.appendingPathComponent(classifierFileName)
        
        if FileManager.default.fileExists(atPath: classificationFileURL.path)
        {
            do
            {
                try FileManager.default.removeItem(at: classificationFileURL)
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
        
        if FileManager.default.fileExists(atPath: regressorFileURL.path)
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
        guard let appDirectory = prepareDirectory(groupName: groupName)
        else
        {
            print("Failed to save the classifier, could not prepare the \(groupName) directory.")
            return
        }
        
        let modelGroupURL = appDirectory.appendingPathComponent(groupName)
        let classificationFileURL = modelGroupURL.appendingPathComponent("\(fileName).mlmodel")
        
        if FileManager.default.fileExists(atPath: classificationFileURL.path)
        {
            do
            {
                try FileManager.default.removeItem(at: classificationFileURL)
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
    
    func save(recommender: LengthRecommender,
              fileName: String,
              groupName: String)
    {
        guard let appDirectory = prepareDirectory(groupName: groupName)
        else { return }
        
        let groupURL = appDirectory.appendingPathComponent(groupName)
        let recommenderFileURL = groupURL.appendingPathComponent("\(fileName).\(songFileExtension)")
        
        if FileManager.default.fileExists(atPath: recommenderFileURL.path)
        {
            do
            {
                try FileManager.default.removeItem(at: recommenderFileURL)
            }
            catch let removeFileError
            {
                print("Error removing file at \(recommenderFileURL.path): \(removeFileError)")
            }
        }
        
        do
        {
            try recommender.write(to: recommenderFileURL)
        }
        catch let saveModelError
        {
            print("Error saving tls regressor model: \(saveModelError)")
        }
    }
    
    func saveTrainingData(groupName: String)
    {
        guard let appDirectory = prepareDirectory(groupName: groupName)
        else { return }
        
        let groupURL = appDirectory.appendingPathComponent(groupName)
        let trainingDataFileURL = groupURL.appendingPathComponent("\(trainingDataFilename).\(songFileExtension)")
        
        if FileManager.default.fileExists(atPath: trainingDataFileURL.path)
        {
            do
            {
                try FileManager.default.removeItem(at: trainingDataFileURL)
            }
            catch let removeFileError
            {
                print("Error removing file at \(trainingDataFileURL.path): \(removeFileError)")
            }
        }
        
        let encoder = SongEncoder()
        
        do {
            // Encode the struct
            let trainingBytes = try encoder.encode(trainingData)
            
            // Save it to a file
            try trainingBytes.write(to: trainingDataFileURL)
            
        } catch let encodeError {
            print("Failed to encode traingingData, error on encode: \(encodeError)")
            return
        }
        
        
    }
    
    func bundle(modelGroup groupName: String)
    {
        let fileManager = FileManager.default
        guard let appDirectory = prepareDirectory(groupName: groupName)
            else
        {
            print("Failed to bundle the model group, could not find the application document directory.")
            return
        }
        
        let directoryURL = appDirectory.appendingPathComponent(groupName)
        let bundleURL = directoryURL.appendingPathExtension("adversary")
        
        if fileManager.fileExists(atPath: bundleURL.path)
        {
            do{
                try fileManager.removeItem(at: bundleURL)
            }
            catch let removeFileError
            {
                print("Error trying to remove file at \(bundleURL.path): \(removeFileError)")
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
        guard let appDirectory = getAdversarySupportDirectory()
            else
        {
            print("Failed to save the file, could not find the application document directory.")
            return nil
        }
        
        let modelGroupName = "temp"
        let temporaryDirURL = appDirectory.appendingPathComponent(modelGroupName, isDirectory: true)
        
        if FileManager.default.fileExists(atPath: temporaryDirURL.path)
        {
            try? FileManager.default.removeItem(at: temporaryDirURL)
        }
        
        do
        {
            try FileManager.default.unzipItem(at: adversaryURL, to: temporaryDirURL, progress: nil, preferredEncoding: nil)
            
            let fileURLS = try FileManager.default.contentsOfDirectory(at: temporaryDirURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            print("\nUnzipped item at: \(adversaryURL.path)\nto: \(temporaryDirURL.path)")
            
            if fileURLS.count == 1, fileURLS[0].hasDirectoryPath
            {
                print("Unpacked model files to: \(fileURLS[0])")
                loadTrainingData(from: fileURLS[0])
                
                return fileURLS[0]
            }
            else
            {
                for fileURL in fileURLS
                {
                    print("\nFound file: \(fileURL.path)")
                    if fileURL.pathExtension == "mlmodel"
                    {
                        print("\nFound an mlm file in the chosen directory: \(fileURL)")
                    }
                }
                
                print("Unpacked model files to: \(temporaryDirURL)")
                loadTrainingData(from: temporaryDirURL)
                
                return temporaryDirURL
            }
        }
        catch let unzipError
        {
            print("\nError unzipping item at \(adversaryURL) to \(temporaryDirURL): \n\(unzipError)")
            
            return nil
        }
        
    }
    
    func prepareDirectory(groupName: String) -> URL?
    {
        let fileManager = FileManager.default
        guard let appDirectory = getAdversarySupportDirectory()
            else
        {
            print("Failed to save the file, could not find the application support directory.")
            return nil
        }
        
        let groupURL = appDirectory.appendingPathComponent(groupName)
        
        if !fileManager.fileExists(atPath: groupURL.path)
        {
            do {
                try fileManager.createDirectory(at: groupURL, withIntermediateDirectories: true, attributes: nil)
            } catch let createDirError {
                print("Failed to prepare the \(groupName) directory.")
                print("Received a directory creation error: \(createDirError)")
                return nil
            }
        }
        
        do
        {
            _ = try fileManager.createDirectory(at: groupURL, withIntermediateDirectories: true, attributes: nil)
        }
        catch let directoryError
        {
            print("\nError creating group directory: \(directoryError)")
            return nil
        }
        
        return appDirectory
    }
    
    func loadTrainingData(from directoryURL: URL)
    {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            for fileUrl in files
            {
                if fileUrl.lastPathComponent == trainingDataFilename
                {
                    let decoder = SongDecoder()
                    
                    do
                    {
                        let trainingBytes = try Data(contentsOf: fileUrl)
                        trainingData = try decoder.decode(TrainingData.self, from: trainingBytes)
                        return
                    }
                    catch let decodeError
                    {
                        print("Error decoding training data: \(decodeError)")
                        return
                    }
                }
            }
            
        } catch let error {
            print("Failed to load TrainingData. Error reading contents of directory: \(error)")
            return
        }
        
    }
    
    func loadSongFile(fileURL: URL, completion:@escaping (_ completion:Bool) -> Void)
    {
        SymphonyController().launchSymphony(fromFile: fileURL)
        {
            (success) in
            
            completion(success)
        }
    }
}
