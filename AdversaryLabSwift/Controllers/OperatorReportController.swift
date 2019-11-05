//
//  OperatorReportController.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 6/17/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import Cocoa
import Quartz
import RedShot
import Auburn


/**
 This class is for Operator Foundation Reporting
 */
class OperatorReportController
{
    static let sharedInstance = OperatorReportController()
    let formatter = ISO8601DateFormatter()
    
    func createReportTextFile(forModel modelName: String)
    {
        let fileManager = FileManager.default
        guard let appDirectory = getAdversarySupportDirectory()
            else
        {
            print("Failed to bundle the model group, could not find the application document directory.")
            return
        }
        
        let folderURL = appDirectory.appendingPathComponent("OperatorReports")
        let fileURL = folderURL.appendingPathComponent(getReportTextFileName()).appendingPathExtension(".md")
        
        generateReportContent(forModel: modelName, completion:
        {
            (report) in
            //print(report)
            let fileData = report.data(using: .utf8)
            
            //If the file doesn't exist create it
            if !fileManager.fileExists(atPath: fileURL.path)
            {
                do
                {
                    try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
                    print("Created a Folder!!! - \(folderURL)")
                }
                catch
                {
                    print("Failed to create a folder \(folderURL)")
                    print(error.localizedDescription)
                }
            }
            else
            {
                print("Folder already exists: \(folderURL)")
            }
            
            fileManager.createFile(atPath: fileURL.path, contents: fileData, attributes: nil)
        })
    }
    
    func getReportTextFileName() -> String
    {
        
        formatter.timeZone = TimeZone.current
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate]
        let now = formatter.string(from: Date())
        
        return "AdversaryLab\(now)"
    }
    
    func generateReportContent(forModel modelName: String, completion: @escaping (_ completion: String) -> Void)
    {
        //Today's date as string
        formatter.timeZone = TimeZone.current
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withTimeZone,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime,
                                   .withSpaceBetweenDateAndTime,
                                   .withColonSeparatorInTimeZone]
        
        let now = formatter.string(from: Date())
        
        //Format with markdown because pretty.
        let reportHeader = "## Adversary Lab Report\n"
        let reportDate = "\(now)\n\n"
        generateResultsTable(forModel: modelName, completion:
        {
            (reportData) in
            
            completion(reportHeader + reportDate + reportData)
        })
    }
    
    ///This method generates a markdown table for a given country.
    ///If the country has no test results this method returns nil instead.
    func generateResultsTable(forModel modelName: String, completion: @escaping (_ completion: String) -> Void)
    {
        let tableHeader = "\n## \(modelName)\n"
        
        let timingTableHeader = "\n### Time Difference\n"
        let timingTableFields = "| Category | Timing | Accuracy |\n| :-------------: | :-------------: | :-------------: |\n"
        
        let tlsTableHeader = "\n### TLS Names\n"
        let tlsTableHeaderFields = "| Category | TLS | Accuracy |\n| :-------------: | :-------------: | :-------------: |\n"
        
        let lengthTableHeader = "\n### Packet Lengths\n"
        let lengthTableFields = "| Category | Incoming Length | Incoming Length Accuracy | Outgoing Length | Outgoing Length Accuracy |\n| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |\n"
        
        let entropyTableHeader = "\n### Entropy\n"
        let entropyTableHeaderFields = "| Category | Incoming Entropy | Incoming Entropy Accuracy | Outgoing Entropy | Outgoing Entropy Accuracy |\n| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |\n"
        
        let floatTableHeader = "\n### Floating Sequences\n"
        let floatTableFields = "| Category | Incoming Accuracy | Outgoing Accuracy |\n| :-------------: | :-------------: | :-------------: |\n"
        
        DispatchQueue.global(qos: .utility).async
        {
            let testResults: RMap<String,Double> = RMap(key: testResultsKey)
            let tlsTestValuesDictionary: RMap<String,String> = RMap(key: tlsTestResultsKey)
            let allFeatTLSDictionary: RMap<String,String> = RMap(key: allFeaturesTLSTestResultsKey)
            
            // Timing (milliseconds)
            let timeBlocked: String
            let timeBlockAccuracy: String
            let timeAllowed: String
            let timeAllowAccuracy: String
            
            if testResults[blockedTimingKey] != nil, testResults[blockedTimingAccuracyKey] != nil, testResults[allowedTimingKey] != nil, testResults[allowedTimingAccuracyKey] != nil
            {
                timeBlocked = String(format: "%.2f", testResults[blockedTimingKey]!)
                timeBlockAccuracy = String(format: "%.2f", testResults[blockedTimingAccuracyKey]!)
                timeAllowed = String(format: "%.2f", testResults[allowedTimingKey]!)
                timeAllowAccuracy = String(format: "%.2f", testResults[allowedTimingAccuracyKey]!)
            }
            else
            {
                timeBlocked = "--"
                timeBlockAccuracy = "--"
                timeAllowed = "--"
                timeAllowAccuracy = "--"
            }
            
            let timingAllowedRow = "| Allowed | \(timeAllowed) | \(timeAllowAccuracy) |\n"
            let timingBlockedRow = "| Blocked | \(timeBlocked) | \(timeBlockAccuracy) |\n"
            
            // TLS Common Names
            let tlsBlocked = tlsTestValuesDictionary[blockedTLSKey] ?? "--"
            let tlsAllowed = tlsTestValuesDictionary[allowedTLSKey] ?? "--"
            let tlsBlockAccuracy: String
            let tlsAllowAccuracy: String
            
            if testResults[blockedTLSAccuracyKey] != nil, testResults[allowedTLSAccuracyKey] != nil
            {
                tlsBlockAccuracy = String(format: "%.2f", testResults[blockedTLSAccuracyKey]!)
                tlsAllowAccuracy = String(format: "%.2f", testResults[allowedTLSAccuracyKey]!)
            }
            else
            {
                tlsBlockAccuracy = "--"
                tlsAllowAccuracy = "--"
            }
            
            let tlsAllowedRow = "| Allowed| \(tlsAllowed) | \(tlsAllowAccuracy) |\n"
            let tlsBlockedRow = "| Blocked| \(tlsBlocked) | \(tlsBlockAccuracy) |\n"
            
            // Lengths
            let lengthInAllowed: String
            let lengthInAllowAccuracy: String
            let lengthOutAllowed: String
            let lengthOutAllowAccuracy: String
            
            let lengthInBlocked: String
            let lengthInBlockAccuracy: String
            let lengthOutBlocked: String
            let lengthOutBlockAccuracy: String
            
            if testResults[allowedIncomingLengthKey] != nil, testResults[allowedIncomingLengthAccuracyKey] != nil, testResults[allowedOutgoingLengthKey] != nil, testResults[allowedOutgoingLengthAccuracyKey] != nil, testResults[blockedIncomingLengthKey] != nil, testResults[blockedIncomingLengthAccuracyKey] != nil, testResults[blockedOutgoingLengthKey] != nil,  testResults[blockedOutgoingLengthAccuracyKey] != nil
            {
                lengthInAllowed = String(format: "%.2f", testResults[allowedIncomingLengthKey]!)
                lengthInAllowAccuracy = String(format: "%.2f", testResults[allowedIncomingLengthAccuracyKey]!)
                lengthOutAllowed = String(format: "%.2f", testResults[allowedOutgoingLengthKey]!)
                lengthOutAllowAccuracy = String(format: "%.2f", testResults[allowedOutgoingLengthAccuracyKey]!)
                
                lengthInBlocked = String(format: "%.2f", testResults[blockedIncomingLengthKey]!)
                lengthInBlockAccuracy = String(format: "%.2f", testResults[blockedIncomingLengthAccuracyKey]!)
                lengthOutBlocked = String(format: "%.2f", testResults[blockedOutgoingLengthKey]!)
                lengthOutBlockAccuracy = String(format: "%.2f", testResults[blockedOutgoingLengthAccuracyKey]!)
            }
            else
            {
                lengthInAllowed = "--"
                lengthInAllowAccuracy = "--"
                lengthOutAllowed = "--"
                lengthOutAllowAccuracy = "--"
                
                lengthInBlocked = "--"
                lengthInBlockAccuracy = "--"
                lengthOutBlocked = "--"
                lengthOutBlockAccuracy = "--"
            }
            
            let lengthAllowedRow = "| Allowed | \(lengthInAllowed) | \(lengthInAllowAccuracy) | \(lengthOutAllowed) | \(lengthOutAllowAccuracy) |\n"
            let lengthBlockedRow = "| Blocked | \(lengthInBlocked) | \(lengthInBlockAccuracy) | \(lengthOutBlocked) | \(lengthOutBlockAccuracy) |\n"
            
            // Entropy
            let entInAllowed: String
            let entInAllowAccuracy: String
            let entOutAllowed: String
            let entoutAllowAccuracy: String
            let entInBlocked: String
            let entInBlockAccuracy: String
            let entOutBlocked: String
            let entOutBlockAccuracy: String
            
            if testResults[allowedIncomingEntropyKey] != nil, testResults[allowedIncomingEntropyAccuracyKey] != nil, testResults[allowedOutgoingEntropyKey] != nil, testResults[allowedOutgoingEntropyAccuracyKey] != nil, testResults[blockedIncomingEntropyKey] != nil, testResults[blockedIncomingEntropyAccuracyKey] != nil, testResults[blockedOutgoingEntropyKey] != nil, testResults[blockedOutgoingEntropyAccuracyKey] != nil
            {
                entInAllowed = String(format: "%.2f", testResults[allowedIncomingEntropyKey]!)
                entInAllowAccuracy = String(format: "%.2f", testResults[allowedIncomingEntropyAccuracyKey]!)
                entOutAllowed = String(format: "%.2f", testResults[allowedOutgoingEntropyKey]!)
                entoutAllowAccuracy = String(format: "%.2f", testResults[allowedOutgoingEntropyAccuracyKey]!)
                entInBlocked = String(format: "%.2f", testResults[blockedIncomingEntropyKey]!)
                entInBlockAccuracy = String(format: "%.2f", testResults[blockedIncomingEntropyAccuracyKey]!)
                entOutBlocked = String(format: "%.2f", testResults[blockedOutgoingEntropyKey]!)
                entOutBlockAccuracy = String(format: "%.2f", testResults[blockedOutgoingEntropyAccuracyKey]!)
            }
            else
            {
                entInAllowed = "--"
                entInAllowAccuracy = "--"
                entOutAllowed = "--"
                entoutAllowAccuracy = "--"
                entInBlocked = "--"
                entInBlockAccuracy = "--"
                entOutBlocked = "--"
                entOutBlockAccuracy = "--"
            }
            
            let entropyAllowedRow = "| Allowed | \(entInAllowed) | \(entInAllowAccuracy) | \(entOutAllowed) | \(entoutAllowAccuracy) |\n"
            let entropyBlockedRow = "| Blocked | \(entInBlocked) | \(entInBlockAccuracy) | \(entOutBlocked) | \(entOutBlockAccuracy) |\n"

            // Float Sequences
            let floatInAllowAccuracy: String
            let floatOutAllowAccuracy: String
            let floatInBlockAccuracy: String
            let floatOutBlockAccuracy: String
            
            if testResults[allowedIncomingFloatAccuracyKey] != nil, testResults[allowedOutgoingFloatAccuracyKey] != nil, testResults[blockedIncomingFloatAccuracyKey] != nil, testResults[blockedOutgoingFloatAccuracyKey] != nil
            {
                floatInAllowAccuracy = String(format: "%.2f", testResults[allowedIncomingFloatAccuracyKey]!)
                floatOutAllowAccuracy = String(format: "%.2f", testResults[allowedOutgoingFloatAccuracyKey]!)
                floatInBlockAccuracy = String(format: "%.2f", testResults[blockedIncomingFloatAccuracyKey]!)
                floatOutBlockAccuracy = String(format: "%.2f", testResults[blockedOutgoingFloatAccuracyKey]!)
            }
            else
            {
                floatInAllowAccuracy = "--"
                floatOutAllowAccuracy = "--"
                floatInBlockAccuracy = "--"
                floatOutBlockAccuracy = "--"
            }
            
            let floatAllowedRow = "| Allowed | \(floatInAllowAccuracy) | \(floatOutAllowAccuracy) |\n"
            let floatBlockedRow = "| Allowed | \(floatInBlockAccuracy) | \(floatOutBlockAccuracy) |\n"
            
            // All Features
            let allFeatAllowInLength: String
            let allFeatAllowOutLength: String
            let allFeatAllowInEntropy: String
            let allFeatAllowOutEntropy: String
            let allFeatAllowTiming: String
            let allAllowAccuracy: String
            
            let allFeatBlockInLength: String
            let allFeatBlockOutLength: String
            let allFeatBlockInEntropy: String
            let allFeatBlockOutEntropy: String
            let allFeatBlockTiming: String
            let allBlockAccuracy: String
            
            let allFeatAllowTLS = allFeatTLSDictionary[allowedAllFeaturesTLSKey] ?? "--"
            let allFeatBlockedTLS = allFeatTLSDictionary[blockedAllFeaturesTLSKey] ?? "--"
            
            if testResults[allowedAllFeaturesIncomingLengthKey] != nil, testResults[allowedAllFeaturesOutgoingLengthKey] != nil, testResults[allowedAllFeaturesIncomingEntropyKey] != nil, testResults[allowedAllFeaturesOutgoingEntropyKey] != nil, testResults[allowedAllFeaturesTimingKey] != nil, testResults[allowedAllFeaturesAccuracyKey] != nil, testResults[blockedAllFeaturesIncomingLengthKey] != nil, testResults[blockedAllFeaturesOutgoingLengthKey] != nil, testResults[blockedAllFeaturesIncomingEntropyKey] != nil, testResults[blockedAllFeaturesOutgoingEntropyKey] != nil, testResults[blockedAllFeaturesTimingKey] != nil, testResults[blockedAllFeaturesAccuracyKey] != nil
            {
                allFeatAllowInLength = String(format: "%.2f", testResults[allowedAllFeaturesIncomingLengthKey]!)
                allFeatAllowOutLength = String(format: "%.2f", testResults[allowedAllFeaturesOutgoingLengthKey]!)
                allFeatAllowInEntropy = String(format: "%.2f", testResults[allowedAllFeaturesIncomingEntropyKey]!)
                allFeatAllowOutEntropy = String(format: "%.2f", testResults[allowedAllFeaturesOutgoingEntropyKey]!)
                allFeatAllowTiming = String(format: "%.2f", testResults[allowedAllFeaturesTimingKey]!)
                allAllowAccuracy = String(format: "%.2f", testResults[allowedAllFeaturesAccuracyKey]!)
                
                allFeatBlockInLength = String(format: "%.2f", testResults[blockedAllFeaturesIncomingLengthKey]!)
                allFeatBlockOutLength = String(format: "%.2f", testResults[blockedAllFeaturesOutgoingLengthKey]!)
                allFeatBlockInEntropy = String(format: "%.2f", testResults[blockedAllFeaturesIncomingEntropyKey]!)
                allFeatBlockOutEntropy = String(format: "%.2f", testResults[blockedAllFeaturesOutgoingEntropyKey]!)
                allFeatBlockTiming = String(format: "%.2f", testResults[blockedAllFeaturesTimingKey]!)
                allBlockAccuracy = String(format: "%.2f", testResults[blockedAllFeaturesAccuracyKey]!)
            }
            else
            {
                allFeatAllowInLength = "--"
                allFeatAllowOutLength = "--"
                allFeatAllowInEntropy = "--"
                allFeatAllowOutEntropy = "--"
                allFeatAllowTiming = "--"
                allAllowAccuracy = "--"
                
                allFeatBlockInLength = "--"
                allFeatBlockOutLength = "--"
                allFeatBlockInEntropy = "--"
                allFeatBlockOutEntropy = "--"
                allFeatBlockTiming = "--"
                allBlockAccuracy = "--"
            }
            
            let allFeaturesTableHeader = "\n### All Fields\n"
            let allFeaturesTableFields = "| Category| Incoming Length | Outgoing Length | Incoming Entropy | Outgoing Entropy | Timing | TLS | Accuracy |\n| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |\n"
            let allFeatAllowedRow = "| Allowed | \(allFeatAllowInLength) | \(allFeatAllowOutLength) | \(allFeatAllowInEntropy) | \(allFeatAllowOutEntropy) | \(allFeatAllowTiming) | \(allFeatAllowTLS) | \(allAllowAccuracy) |\n"
            let allFeatBlockedRow = "| Blocked | \(allFeatBlockInLength) | \(allFeatBlockOutLength) | \(allFeatBlockInEntropy) | \(allFeatBlockOutEntropy) | \(allFeatBlockTiming) | \(allFeatBlockedTLS) | \(allBlockAccuracy) |"

            DispatchQueue.main.async
            {
                let timingTableValues = timingAllowedRow + timingBlockedRow
                let timingTable = timingTableHeader + timingTableFields + timingTableValues
                
                let tlsTableValues = tlsAllowedRow + tlsBlockedRow
                let tlsTable = tlsTableHeader + tlsTableHeaderFields + tlsTableValues
                
                let lengthTableValues = lengthAllowedRow + lengthBlockedRow
                let lengthTable = lengthTableHeader + lengthTableFields + lengthTableValues
                
                let entropyTableValues = entropyAllowedRow + entropyBlockedRow
                let entropyTable = entropyTableHeader + entropyTableHeaderFields + entropyTableValues
                
                let floatTableValues = floatAllowedRow + floatBlockedRow
                let floatTable = floatTableHeader + floatTableFields + floatTableValues
                
                let allFeaturesTableValues = allFeatAllowedRow + allFeatBlockedRow
                let allFeaturesTable = allFeaturesTableHeader + allFeaturesTableFields + allFeaturesTableValues
                
                //Put it all together and what do you get? m;)
                completion(tableHeader + lengthTable + entropyTable + timingTable + tlsTable + floatTable + allFeaturesTable)
            }

        }
    }
    
}
