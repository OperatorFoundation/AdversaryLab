//
//  ProgressBot.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 4/25/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation

class ProgressBot
{
    static let sharedInstance = ProgressBot()
    
    var analysisComplete = true
    {
        didSet
        {
            NotificationCenter.default.post(name: .updateProgressIndicator, object: nil)
        }
    }
    
    var progressMessage = ""
    {
        didSet
        {
            //NotificationCenter.default.post(name: .updateProgressIndicator, object: nil)
        }
    }
    
    var totalToAnalyze = 0
    {
        didSet
        {
            //NotificationCenter.default.post(name: .updateProgressIndicator, object: nil)
        }
    }
    
    var currentProgress = 0
    {
        didSet
        {
            //NotificationCenter.default.post(name: .updateProgressIndicator, object: nil)
        }
    }
    
    func update(progressMessage: String, totalToAnalyze: Int, currentProgress: Int)
    {
        if Thread.isMainThread
        {
            self.progressMessage = progressMessage
            self.totalToAnalyze = totalToAnalyze
            self.currentProgress = currentProgress
        }
        else
        {
            DispatchQueue.main.async
            {
                self.progressMessage = progressMessage
                self.totalToAnalyze = totalToAnalyze
                self.currentProgress = currentProgress
            }
        }
    }
}
