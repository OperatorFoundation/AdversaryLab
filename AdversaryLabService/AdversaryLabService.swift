//
//  AdversaryLabService.m
//  AdversaryLabService
//
//  Created by Mafalda on 4/15/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation

class AdversaryLabService: NSObject, AdversaryLabServiceProtocol, NSXPCListenerDelegate
{
    static var connectTask:Process!
    var verbosity = 3
    
    let logPath: String
    //let fixInternetPath = "Helpers/fixInternet.sh"
    
    fileprivate var listener:NSXPCListener
    fileprivate let kHelperToolMachServiceName = "org.operatorFoundation.AdversaryLabService"
    
    override init()
    {
        // Set up our XPC listener to handle requests on our Mach service.
        self.listener = NSXPCListener(machServiceName:kHelperToolMachServiceName)
        
        if let appDirectory = getAdversarySupportDirectory()
        {
            logPath = appDirectory.appendingPathComponent("Documents/debug.log").path
        }
        else
        {
            logPath = NSHomeDirectory()+"/Documents/debug.log"
        }
        
        super.init()
        self.listener.delegate = self
    }
    
    func run()
    {
        // Tell the XPC listener to start processing requests.
        writeToLog(logDirectory: appDirectory, content: "*****Run Was Called******")
        
        // Resume the listener. At this point, NSXPCListener will take over the execution of this service, managing its lifetime as needed.
        self.listener.resume()
        
        // Run the run loop forever.
        writeToLog(logDirectory: appDirectory, content: "^^^^^^We are about to RunLoop this thing up in here^^^^^^")
        RunLoop.current.run()
        writeToLog(logDirectory: appDirectory, content: "<<<<<<<Our RunLoop is over, it was good while it lasted.>>>>>>>>")
    }
    
    // Called by our XPC listener when a new connection comes in.  We configure the connection
    // with our protocol and ourselves as the main object.
    func listener(_ listener:NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool
    {
        writeToLog(logDirectory: appDirectory, content: "****New Incoming Connection****")
        
        print("new incoming connection")
        
        // Configure the new connection and resume it. Because this is a singleton object, we set 'self' as the exported object and configure the connection to export the 'SMJobBlessHelperProtocol' protocol that we implement on this object.
        newConnection.exportedInterface = NSXPCInterface(with:AdversaryLabServiceProtocol.self)
        newConnection.exportedObject = self;
        newConnection.resume()
        return true
    }
    
    func startAdversaryLabClient(allowBlock: String, port: String, pathToClient: String)
    {
//        writeToLog(logDirectory: appDirectory, content: "\n******* START Adversary Lab Client Called *******")
//
//        //Arguments
//        let adversaryLabeClientArgs: [String] = [port, allowBlock]
//
//        _ = runAdversaryLabClientScript(arguments: adversaryLabeClientArgs, pathToExecutable: pathToClient)
//
//        writeToLog(logDirectory: appDirectory, content: "START Adversary Lab Client END OF FUNCTION")
        let executableURL = URL(fileURLWithPath: pathToClient)
        launchAdversaryLab(forPort: port, executableURL: executableURL)
    }
    
    private var pipe = Pipe()
    
    func launchAdversaryLab(forPort port: String, executableURL: URL)
    {
        print("🔬  Launching Adversary Lab.")
        
        let arguments = [port]
        
        if AdversaryLabService.connectTask != nil
        {
            print("🔬  AdversaryLab process isn't nil.")
            AdversaryLabService.connectTask!.terminate()
        }

        AdversaryLabService.connectTask = Process()
        AdversaryLabService.connectTask!.executableURL = executableURL
        AdversaryLabService.connectTask!.arguments = arguments
        
        // Refresh our pipe just in case we've already used it.
        pipe = Pipe()
        AdversaryLabService.connectTask!.standardInput = pipe
        print("🔬  Assigned standard input to pipe.")
        
        AdversaryLabService.connectTask!.launch()
    }
    
    func stopAdversaryLabClient()
    {
        writeToLog(logDirectory: appDirectory, content: "\n******* STOP Adversary Lab Client *******")
        
        if AdversaryLabService.connectTask != nil
        {
            AdversaryLabService.connectTask!.terminate()
        }
        
        //killAll(processToKill: "")
    }
    
    private func runAdversaryLabClientScript(arguments: [String], pathToExecutable: String) -> Bool
    {
        writeToLog(logDirectory: appDirectory, content: "Helper func: runAdversaryLabClientScript")

        //Creates a new Process and assigns it to the connectTask property.
        AdversaryLabService.connectTask = Process()
        //The launchPath is the path to the executable to run.
        AdversaryLabService.connectTask.launchPath = pathToExecutable
        //Arguments will pass the arguments to the executable, as though typed directly into terminal.
        AdversaryLabService.connectTask.arguments = arguments
        
        //Go ahead and launch the process/task
        AdversaryLabService.connectTask.launch()
        
        //This may be a lie :(
        return true
    }
    
    func writeToLog(logDirectory: String, content: String)
    {
        let timeStamp = Date()
        let contentString = "\n\(timeStamp):\n\(content)\n"
        let logFilePath = logDirectory + "AdversaryLabLog.txt"
        
        if let fileHandle = FileHandle(forWritingAtPath: logFilePath)
        {
            //append to file
            fileHandle.seekToEndOfFile()
            fileHandle.write(contentString.data(using: String.Encoding.utf8)!)
        }
        else
        {
            //create new file
            do
            {
                try contentString.write(toFile: logFilePath, atomically: true, encoding: String.Encoding.utf8)
            }
            catch
            {
                print("Error writing to file \(logFilePath)")
            }
        }
    }
}
