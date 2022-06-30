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
import Auburn

/**
 This class is for Operator Foundation Reporting
 */
class OperatorReportController
{
    let formatter = ISO8601DateFormatter()
    
    func createReportTextFile(labData: LabData, forModel modelName: String)
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
        
        generateReportContent(labData: labData, forModel: modelName, completion:
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
    
    func generateReportContent(labData: LabData, forModel modelName: String, completion: @escaping (_ completion: String) -> Void)
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
        generateResultsTable(labData: labData, forModel: modelName, completion:
        {
            (reportData) in
            
            completion(reportHeader + reportDate + reportData)
        })
    }
    
    ///This method generates a markdown table for a given country.
    ///If the country has no test results this method returns nil instead.
    func generateResultsTable(labData: LabData, forModel modelName: String, completion: @escaping (_ completion: String) -> Void)
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
            var transportATiming = "--"
            var transportATimingAccuracy = "--"
            var transportBTiming = "--"
            var transportBTimingAccuracy = "--"
            
            if let transportATimingTestResults = labData.packetTimings.transportATestResults
            {
                transportATiming = String(format: "%.2f", transportATimingTestResults.prediction)
                
                if let accuracy = transportATimingTestResults.accuracy
                {
                    transportATimingAccuracy = String(format: "%.2f", accuracy)
                }
            }
            
            if let transportBTimingTestResults = labData.packetTimings.transportBTestResults
            {
                transportBTiming = String(format: "%.2f", transportBTimingTestResults.prediction)
                
                if let accuracy = transportBTimingTestResults.accuracy
                {
                    transportBTimingAccuracy = String(format: "%.2f", accuracy)
                }
            }
            
            let timingAllowedRow = "| Allowed | \(transportATiming) | \(transportATimingAccuracy) |\n"
            let timingBlockedRow = "| Blocked | \(transportBTiming) | \(transportBTimingAccuracy) |\n"
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
            var lengthInA = "--"
            var lengthInAAccuracy = "--"
            var lengthOutA = "--"
            var lengthOutAAccuracy = "--"
            
            var lengthInB = "--"
            var lengthInBAccuracy = "--"
            var lengthOutB = "--"
            var lengthOutBAccuracy = "--"
            
            if let aIncomingLengthTestResults = labData.packetLengths.incomingATestResults
            {
                lengthInA = String(format: "%.2f", aIncomingLengthTestResults.prediction)
                
                if let accuracy = aIncomingLengthTestResults.accuracy
                {
                    lengthInAAccuracy = String(format: "%.2f", accuracy)
                }
            }
            
            if let aOutgoingLengthTestResults = labData.packetLengths.outgoingATestResults
            {
                lengthOutA = String(format: "%.2f", aOutgoingLengthTestResults.prediction)
                if let accuracy = aOutgoingLengthTestResults.accuracy
                {
                    lengthOutAAccuracy = String(format: "%.2f", accuracy)
                }
            }
            
            if let bIncomingLengthTestResults = labData.packetLengths.incomingBTestResults
            {
                lengthInB = String(format: "%.2f", bIncomingLengthTestResults.prediction)
                
                if let accuracy = bIncomingLengthTestResults.accuracy
                {
                    lengthInBAccuracy = String(format: "%.2f", accuracy)
                }
            }
            
            if let bOutgoingLengthTestResults = labData.packetLengths.outgoingBTestResults
            {
                lengthOutB = String(format: "%.2f", bOutgoingLengthTestResults.prediction)
                
                if let accuracy = bOutgoingLengthTestResults.accuracy
                {
                    lengthOutBAccuracy = String(format: "%.2f", accuracy)
                } else { lengthOutBAccuracy = "--" }
                
            } else { lengthOutB = "--" }
            
            let lengthAllowedRow = "| Allowed | \(lengthInA) | \(lengthInAAccuracy) | \(lengthOutA) | \(lengthOutAAccuracy) |\n"
            let lengthBlockedRow = "| Blocked | \(lengthInB) | \(lengthInBAccuracy) | \(lengthOutB) | \(lengthOutBAccuracy) |\n"
            
            // Entropy
            var entInA = "--"
            var entInAAccuracy = "--"
            var entOutA = "--"
            var entoutAAccuracy = "--"
            var entInB = "--"
            var entInBAccuracy = "--"
            var entOutB = "--"
            var entOutBAccuracy = "--"
            
            if let entInATestResults = labData.packetEntropies.incomingATestResults
            {
                entInA = String(format: "%.2f", entInATestResults.prediction)
                
                if let accuracy = entInATestResults.accuracy
                {
                    entInAAccuracy = String(format: "%.2f", accuracy)
                }
            }
            
            if let entOutATestResults = labData.packetEntropies.outgoingATestResults
            {
                entOutA = String(format: "%.2f", entOutATestResults.prediction)
                
                if let accuracy = entOutATestResults.accuracy
                {
                    entoutAAccuracy = String(format: "%.2f", accuracy)
                }
            }
            
            if let entInBTestResults = labData.packetEntropies.incomingBTestResults
            {
                entInB = String(format: "%.2f", entInBTestResults.prediction)
                
                if let accuracy = entInBTestResults.accuracy
                {
                    entInBAccuracy = String(format: "%.2f", accuracy)
                }
            }
            
            if let entOutBTestResults = labData.packetEntropies.outgoingBTestResults
            {
                entOutB = String(format: "%.2f", entOutBTestResults.prediction)
                
                if let accuracy = entOutBTestResults.accuracy
                {
                    entOutBAccuracy = String(format: "%.2f", accuracy)
                }
            }
            
            let entropyAllowedRow = "| Allowed | \(entInA) | \(entInAAccuracy) | \(entOutA) | \(entoutAAccuracy) |\n"
            let entropyBlockedRow = "| Blocked | \(entInB) | \(entInBAccuracy) | \(entOutB) | \(entOutBAccuracy) |\n"

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
