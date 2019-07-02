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
    
//    var testResults7Days: [TestResult]?
//    var testResults30Days: [TestResult]?
//    var testResultsToday: [TestResult]?
    
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
                    print("\nFailed to create a folder \(folderURL)")
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
        let reportHeader = "## Adversary Lab Report\n\n"
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
        let tableHeader = "\n### \(modelName)\n"
        let tableFields = "| Allowed/Blocked  | Timing   | TLS  | Incoming Length  | Outgoing Length  | Incoming Entropy  | Outgoing Entropy  | All Features  |\n| :------------- | :------------- | :------------- | :------------- | :------------- | :------------- | :------------- | :------------- |\n"
        
        DispatchQueue.global(qos: .utility).async
        {
            let testResults: RMap<String,Double> = RMap(key: testResultsKey)
            
            // Timing (milliseconds)
            let timeBlockAccuracy = String(format: "%.2f", testResults[blockedTimingAccuracyKey] ?? "--")
            let timeAllowAccuracy = String(format: "%.2f", testResults[allowedTimingAccuracyKey] ?? "--")
            
            // TLS Common Names
            let tlsBlockAccuracy = String(format: "%.2f", testResults[blockedTLSAccuracyKey] ?? "--")
            let tlsAllowAccuracy = String(format: "%.2f", testResults[allowedTLSAccuracyKey] ?? "--")
            
            // Lengths
            let lengthInAllowAccuracy = String(format: "%.2f", testResults[allowedIncomingLengthAccuracyKey] ?? "--")
            let lengthInBlockAccuracy = String(format: "%.2f", testResults[blockedIncomingLengthAccuracyKey] ?? "--")
            let lengthOutAllowAccuracy = String(format: "%.2f", testResults[allowedOutgoingLengthAccuracyKey] ?? "--")
            let lengthOutBlockAccuracy = String(format: "%.2f", testResults[blockedOutgoingLengthAccuracyKey] ?? "--")
            
            // Entropy
            let entInAllowAccuracy = String(format: "%.2f", testResults[allowedIncomingEntropyAccuracyKey] ?? "--")
            let entoutAllowAccuracy = String(format: "%.2f", testResults[allowedOutgoingEntropyAccuracyKey] ?? "--")
            let entInBlockAccuracy = String(format: "%.2f", testResults[blockedIncomingEntropyAccuracyKey] ?? "--")
            let entOutBlockAccuracy = String(format: "%.2f", testResults[blockedOutgoingEntropyAccuracyKey] ?? "--")
            
            // All Features
            let allAllowAccuracy = String(format: "%.2f", testResults[allowedAllFeaturesAccuracyKey] ?? "--")
            let allBlockAccuracy = String(format: "%.2f", testResults[blockedAllFeaturesAccuracyKey] ?? "--")
            let row1 = "| Allowed| \(timeAllowAccuracy) | \(tlsAllowAccuracy) | \(lengthInAllowAccuracy) | \(lengthOutAllowAccuracy) | \(entInAllowAccuracy) | \(entoutAllowAccuracy) | \(allAllowAccuracy) |\n"
            let row2 = "| Blocked| \(timeBlockAccuracy) | \(tlsBlockAccuracy) | \(lengthInBlockAccuracy) | \(lengthOutBlockAccuracy) | \(entInBlockAccuracy) | \(entOutBlockAccuracy) | \(allBlockAccuracy) |\n"
            DispatchQueue.main.async
            {
                let tableValues = row1 + row2
                //Put it all together and what do you get? m;)
                completion(tableHeader + tableFields + tableValues)
            }

        }
    }
    
}
