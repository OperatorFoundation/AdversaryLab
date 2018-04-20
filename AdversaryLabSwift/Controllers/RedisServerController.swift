//
//  RedisServerController.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 4/5/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation

class RedisServerController: NSObject
{
    static let sharedInstance = RedisServerController()
    
    var redisProcess:Process!
    
    func launchRedisServer()
    {
        isRedisServerRunning
        {
            (serverIsRunning) in
            
            if serverIsRunning
            {
                return
            }
            else
            {
                let bundle = Bundle.main
                
                guard let redisConfigPath = bundle.path(forResource: "redis", ofType: "conf")
                    else
                {
                    print("Unable to launch Redis server: could not find terraform executable.")
                    return
                }
                
                guard let redisPath = bundle.path(forResource: "redis-server", ofType: nil)
                    else
                {
                    print("Unable to launch Redis server: could not find terraform executable.")
                    return
                }
                
                guard let redisModulePath = bundle.path(forResource: "subsequences", ofType: "so")
                    else
                {
                    print("Unable to launch Redis server: could not find the needed module.")
                    return
                }
                
                guard let path = bundle.path(forResource: "LaunchRedisServerScript", ofType: "sh")
                    else
                {
                    print("Unable to launch Redis server. Could not find the script.")
                    return
                }
                
                print("\n👇👇 Running Script 👇👇:\n")
                
                self.runRedisScript(path: path, arguments: [redisPath, redisConfigPath, redisModulePath])
                {
                    (hasCompleted) in
                    
                    print("🚀 Launch Redis Server Script Complete 🚀")
                }
            }
        }
        
    }
    
    func shutdownRedisServer()
    {
        if redisProcess != nil
        {
            if redisProcess.isRunning
            {
                redisProcess.terminate()
            }
        }
        
        guard let path = Bundle.main.path(forResource: "ShutdownRedisServerScript", ofType: "sh")
        else
        {
            print("Unable to shutdown Redis server. Could not find the script.")
            return
        }
        
        guard let redisPath = Bundle.main.path(forResource: "redis-cli", ofType: nil)
            else
        {
            print("Unable to launch Redis server. Could not find terraform executable.")
            return
        }
        
        print("\n👇👇 Running Script 👇👇:\n")
        
        runRedisScript(path: path, arguments: [redisPath])
        {
            (taskCompleted) in
            
            print("Server has been 🤖 TERMINATED 🤖")
        }
    }
    
    func isRedisServerRunning(completion:@escaping (_ completion:Bool) -> Void)
    {
        guard let redisCliPath = Bundle.main.path(forResource: "redis-cli", ofType: nil)
            else
        {
            print("Unable to ping Redis server. Could not find terraform executable.")
            completion(false)
            return
        }
        guard let path = Bundle.main.path(forResource: "CheckRedisServerScript", ofType: "sh")
            else
        {
            print("Unable to ping Redis server. Could not find the script.")
            completion(false)
            return
        }
        
        let process = Process()
        process.launchPath = path
        process.arguments = [redisCliPath]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.terminationHandler =
        {
            (task) in
            // Get the data
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            
            print(output ?? "no output")
            
            if output == "PONG\n"
            {
                print("\nWe received a pong, server is already running!!")
                completion(true)
            }
            else
            {
                print("\nNo Pong, launch the server!!")
                completion(false)
            }
        }
        process.waitUntilExit()
        process.launch()
    }
    
    func runRedisScript(path: String, arguments: [String]?, completion:@escaping (_ completion:Bool) -> Void)
    {
        let processQueue = DispatchQueue.global(qos: .background)
        processQueue.async
        {
            print("🚀🚀🚀🚀🚀🚀🚀")
            self.redisProcess = Process()
            self.redisProcess.launchPath = path
            
            if let arguments = arguments
            {
                self.redisProcess.arguments = arguments
            }
            
            self.redisProcess.terminationHandler =
            {
                (task) in
                
                //Main Thread Stuff Here If Needed
                DispatchQueue.main.async(execute:
                {
                    print("Redis Script Has Terminated.")
                    completion(true)
                })
            }
            self.redisProcess.launch()
        }
    }
}

