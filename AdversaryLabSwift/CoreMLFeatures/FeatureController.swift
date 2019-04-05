//
//  FeatureController.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 4/5/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import CreateML

class FeatureController
{
    func saveModel(classifier: MLClassifier, classifierMetadata: MLModelMetadata, regressor: MLRegressor, regressorMetadata: MLModelMetadata, name: String)
    {
        // Save Regressor
        let fileManager = FileManager.default
        let regressorFileURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Canary\(name)Regressor.mlmodel")
        
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
        
        // Save classifier
        let tlsClassificationFileURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Canary\(name)Classificationl.mlmodel")
        if fileManager.fileExists(atPath: tlsClassificationFileURL.path)
        {
            do
            {
                try fileManager.removeItem(at: tlsClassificationFileURL)
            }
            catch let removeClassyFileError
            {
                print("\nError removing file at \(tlsClassificationFileURL): \(removeClassyFileError)")
            }
        }
        do
        {
            try classifier.write(to: tlsClassificationFileURL, metadata: classifierMetadata)
        }
        catch let saveClassyError
        {
            print("Error saving TLS Classification model: \(saveClassyError)")
        }
    }
}
