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

class MLModelController
{
    
    func createAandBTables(fromTable dataTable: MLDataTable) -> (transportATable: MLDataTable, transportBTable: MLDataTable)?
    {
        var transportATable: MLDataTable?
        var transportBTable: MLDataTable?
        var currentTable: MLDataTable = dataTable
        var currentRow: MLDataTable?
        
        while (transportATable == nil || transportBTable == nil) && currentTable.rows.count > 0
        {
            currentRow = currentTable.prefix(1)
            currentTable = currentTable.suffix(currentTable.rows.count - 1)
            
            // This is a transport A Row
            if currentRow?[ColumnLabel.classification.rawValue][0] == ClassificationLabel.transportA.rawValue
            {
                transportATable = currentRow
            }
            else if currentRow?[ColumnLabel.classification.rawValue][0] == ClassificationLabel.transportB.rawValue
            {
                transportBTable = currentRow
            }
        }
        
        guard let aTable = transportATable, let bTable = transportBTable
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
