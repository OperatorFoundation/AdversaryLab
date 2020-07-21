//
//  RedisServerController.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 4/5/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import Dispatch
import Auburn
import RedShot
import Datable

let redisQueue = DispatchQueue(label: "RedisQueue")

class RedisServerController: NSObject
{
    static let sharedInstance = RedisServerController()
    var redisProcess:Process!
    
    func launchRedisServer(completion:@escaping (_ completion: ServerCheckResult) -> Void)
    {
        if Auburn.redisIsRunning()
        {
            completion(.okay(nil))
            return
        }
        else
        {
            self.checkServerPortIsAvailable(completion:
            {
                (result) in
                
                switch result
                {
                case .okay( _):
                    print("\nServer port is available")
                    print("👇👇 Running Script 👇👇:\n")
                    self.runLaunchRedisScript
                    { (redisLaunched) in
                        
                        print("\n🚀 Launch Redis Server Script Complete 🚀")
                        
                        if redisLaunched
                        {
                            completion(.okay(nil))
                        }
                        else
                        {
                            completion(.failure("Failure running launch script."))
                        }
                    }
                case .otherProcessOnPort(let name):
                    print("\nAnother process is using our port. Process name: \(name)")
                    completion(result)
                case .corruptRedisOnPort(let pid):
                    print("\nBroken redis is already using our port. PID: \(pid)")
                    completion(result)
                case .failure(let failureString):
                    print("\nFailed to check server port: \(failureString ?? "")")
                    completion(result)
                }
            })
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
    
    func killProcess(pid: String, completion:@escaping (_ completion:Bool) -> Void)
    {
        guard let path = Bundle.main.path(forResource: "KillRedisServerScript", ofType: "sh")
            else
        {
            print("Unable to kill Redis server. Could not find the script.")
            completion(false)
            return
        }
        
        let process = Process()
        process.launchPath = path
        process.arguments = [pid]
        process.terminationHandler =
        {
            (task) in
            
            completion(true)
        }
        
        process.launch()
        process.waitUntilExit()
    }
    
    func checkServerPortIsAvailable(completion:@escaping (_ completion: ServerCheckResult) -> Void)
    {
        guard let path = Bundle.main.path(forResource: "CheckRedisServerPortScript", ofType: "sh")
            else
        {
            print("Unable to check the Redis server port. Could not find the script.")
            completion(.failure("Unable to check the Redis server port. Could not find the script."))
            return
        }
        
        let process = Process()
        process.launchPath = path
        let pipe = Pipe()
        process.standardOutput = pipe
        process.terminationHandler =
        {
            (task) in
            
            // Get the data
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: String.Encoding.utf8)

            if output == ""
            {
                print("\nOur port is empty")
                completion(.okay(nil))
            }
            else
            {
                print("\nReceived a response for our port with lsof: \(output ?? "no output")")
                guard let responseString = output
                else
                {
                    print("\nlsof response could not be interpreted as a string.")
                    completion(.failure("lsof response could not be interpreted as a string."))
                    return
                }
                
                let responseArray = responseString.split(separator: " ")
                guard responseArray.count > 1
                else
                {
                    completion(.failure(nil))
                    return
                }
                
                let processName = String(responseArray[0])
                let pid = String(responseArray[1])
                
                if processName == "redis-ser"
                {
                    completion(.corruptRedisOnPort(pid: pid))
                }
                else
                {
                    completion(.otherProcessOnPort(name: processName))
                }
            }
        }
        
        process.launch()
        process.waitUntilExit()
    }
    
    // Redis considers switching databases to be switching between numbered partitions within the same db file.
    // We will be switching instead to a database represented by a completely different file.
    func switchDatabaseFile(withFile fileURL: URL, completion:@escaping (_ completion:Bool) -> Void)
    {
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath
        let newDBName = fileURL.lastPathComponent
        let destinationURL = URL(fileURLWithPath: currentDirectory).appendingPathComponent(newDBName)

        // Rewrite redis.conf to use the dbfilename for the name of the new .rdb file
        // Setting the dbFilename calls config rewrite with the new name in Redis
        print("\nSetting new dbFilename to \(newDBName)")
        Auburn.dbfilename = newDBName
        sleep(1)
        self.unsubscribeFromNewConnectionsChannel()
        Auburn.shutdownRedis()
        sleep(1)
        shutdownRedisServer()
        sleep(2)
        
        redisQueue.async
        {
            // Copy the .rdb file into the Redis working directory, as specified in redis.conf (defaults to ./, which is the directory the Redis server was run from)
            do
            {
                if fileManager.fileExists(atPath: destinationURL.path)
                {
                    try fileManager.removeItem(at: destinationURL)
                }
                
                print("\nCopying new redis DB file.")
                try fileManager.copyItem(at: fileURL, to: destinationURL)
                
                print("\n📂  Copied file from: \n\(fileURL)\nto:\n\(destinationURL)\n")
            }
            catch let copyError
            {
                print("\nError copying redis DB file from \(fileURL) to \(currentDirectory):\n\(copyError)")
                completion(false)
                return
            }

            self.launchRedisServer(completion:
            {
                (launchResult) in
                
                switch launchResult
                {
                case .okay(_):
                    DispatchQueue.main.async
                    {
                        Auburn.restartRedis()
                        self.subscribeToNewConnectionsChannel()
                        //NotificationCenter.default.post(name: .updateDBFilename, object: nil)
                        completion(true)
                    }
                default:
                    DispatchQueue.main.async
                    {
                        print("\nFailed to relaunch redis after switching .rdb file.")
                        completion(false)
                        return
                    }
                }
            })
        }
    }
    
    func mergeIntoCurrentDatabase(mergeFile: URL, completion: @escaping (ConnectionGroupData?) -> Void)
    {
        let processor = DataProcessing()
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath
        let mergeGroup = DispatchGroup.init()
        let mergeQueue = DispatchQueue(label: "MergeQueue")
        
        guard let currentDBName = Auburn.dbfilename
            else
        {
            print("Unable to merge into current DB, database filename not found.")
            completion(nil)
            return
        }
        
        let newDBName = currentDBName.replacingOccurrences(of: ".rdb", with: "_merged.rdb")
        let destinationURL = URL(fileURLWithPath: currentDirectory).appendingPathComponent(newDBName)
        if !fileManager.fileExists(atPath: destinationURL.path)
        {
            fileManager.createFile(atPath: destinationURL.path, contents: nil, attributes: nil)
        }
        
        mergeQueue.async
        {
            
            let connectionGroupData = ConnectionGroupData()
            
            print("\nEnter 1")
            mergeGroup.enter()
            self.switchDatabaseFile(withFile: mergeFile)
            {
                (_) in
                
                print("\nLeave 1")
                mergeGroup.leave()
            }
            mergeGroup.wait()
            
            let newConnectionGroupData = ConnectionGroupData()
            let mergedConnectionData = processor.merge(connectionGroupData: connectionGroupData, with: newConnectionGroupData)
            
            mergeGroup.enter()
            print("\nEnter 2")
            self.switchDatabaseFile(withFile: destinationURL)
            {
                (_) in
                
                print("\nLeave 2")
                mergeGroup.leave()
            }
            mergeGroup.wait()
            
            
            print("\nEnter 3")
            mergeGroup.enter()
            processor.saveToRedis(connectionData: mergedConnectionData)
            {
                _ in
                
                print("\nLeave 3")
                mergeGroup.leave()
                completion(mergedConnectionData)
            }
            mergeGroup.wait()
        }
    }
    
    func runLaunchRedisScript(completion:@escaping (_ completion:Bool) -> Void)
    {
        let bundle = Bundle.main
        
        guard let path = bundle.path(forResource: "LaunchRedisServerScript", ofType: "sh")
            else
        {
            print("Unable to launch Redis server. Could not find the script.")
            completion(false)
            return
        }
        
        guard let redisConfigPath = bundle.path(forResource: "redis", ofType: "conf")
            else
        {
            print("Unable to launch Redis server: could not find terraform executable.")
            completion(false)
            return
        }
        
        guard let redisPath = bundle.path(forResource: "redis-server", ofType: nil)
            else
        {
            print("Unable to launch Redis server: could not find terraform executable.")
            completion(false)
            return
        }
        
        guard let redisModulePath = bundle.path(forResource: "subsequences", ofType: "so")
            else
        {
            print("Unable to launch Redis server: could not find the needed module.")
            completion(false)
            return
        }
        
        let processQueue = DispatchQueue.global(qos: .background)
        processQueue.async
        {
            print("🚀🚀🚀🚀🚀🚀🚀")
            print("Redis config path: \(redisConfigPath)")
            self.redisProcess = Process()
            self.redisProcess.launchPath = path
            self.redisProcess.arguments = [redisPath, redisConfigPath, redisModulePath]
            self.redisProcess.launch()
            
            sleep(1)
            
            if Auburn.redisIsRunning()
            {
                completion(true)
                return
            }
            else
            {
                completion(false)
                return
            }
        }
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
                
                print("Redis Script Has Terminated.")
                completion(true)
            }
            
            self.redisProcess.launch()
        }
    }
    
    func unsubscribeFromNewConnectionsChannel()
    {
        DispatchQueue.global(qos: .utility).async
        {
            guard let redis = try? Redis(hostname: "localhost", port: 6380)
                else
            {
                print("Unable to connect to Redis")
                return
            }
            
            redis.unsubscribe(channel: newConnectionsChannel)
        }
    }
    
    func subscribeToNewConnectionsChannel()
    {
        DispatchQueue.global(qos: .utility).async
        {
            guard let redis = try? Redis(hostname: "localhost", port: 6380)
                else
            {
                print("Unable to connect to Redis")
                return
            }
            
            do
            {
                print("Subscribing to redis channel.")
                
                try redis.subscribe(channel:newConnectionsChannel)
                {
                    (maybeRedisType, maybeError) in
                    
                    print("Received redis subscribe callback.")
                    guard let redisList = maybeRedisType as? [Datable]
                        else
                    {
                        return
                    }
                    
                    for each in redisList
                    {
                        guard let thisElement = each as? Data
                            else
                        { continue }
                        
                        guard thisElement.string == newConnectionMessage
                            else
                        {
                            print("Received a message: \(thisElement.string)")
                            continue
                        }
                        
                        DispatchQueue.main.async
                        {
                            //NotificationCenter.default.post(name: .updateStats , object: nil)
                        }
                    }
                }
            }
            catch
            { print("Error subscribing to Redis channel: \(error)") }
        }
    }
}
