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
    
    let logPath = NSHomeDirectory()+"/Documents/debug.log"
    let fixInternetPath = "Helpers/fixInternet.sh"
    
    fileprivate var listener:NSXPCListener
    fileprivate let kHelperToolMachServiceName = "org.operatorFoundation.AdversaryLabService"
    
    override init()
    {
        // Set up our XPC listener to handle requests on our Mach service.
        self.listener = NSXPCListener(machServiceName:kHelperToolMachServiceName)
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
    
    func startAdversaryLabClient(allowBlock: String, port: String, configFileName: String)
    {
        writeToLog(logDirectory: appDirectory, content: "\n******* START Adversary Lab Client *******")
        
        //Arguments
        let mode = "capture"
        let dataset = "testing"
        let adversaryLabeClientArgs: [String] = [mode, dataset, allowBlock, port]
        
        _ = runAdversaryLabClientScript(arguments: adversaryLabeClientArgs)
        
        writeToLog(logDirectory: appDirectory, content: "START Adversary Lab ClientEND OF FUNCTION")
    }
    
    func stopAdversaryLabClient()
    {
        writeToLog(logDirectory: appDirectory, content: "\n******* STOP Adversary Lab Client *******")
        
        if AdversaryLabService.connectTask != nil
        {
            AdversaryLabService.connectTask!.terminate()
        }
        
        //killAll(processToKill: "openvpn")
    }
    
    private func runAdversaryLabClientScript(arguments: [String]) -> Bool
    {
        writeToLog(logDirectory: appDirectory, content: "Helper func: runAdversaryLabClientScript")
        
        guard let adversaryLabClientPath = Bundle.main.path(forResource: "AdversaryLabClient", ofType: nil)
        else
        {
            print("\nCould not find AdversaryLabClient executable. This should be in the app bundle.")
            return false
        }

        //Creates a new Process and assigns it to the connectTask property.
        AdversaryLabService.connectTask = Process()
        //The launchPath is the path to the executable to run.
        AdversaryLabService.connectTask.launchPath = adversaryLabClientPath
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
        let logFilePath = logDirectory + "moonbounceLog.txt"
        
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


//#import "AdversaryLabService.h"
//
//@implementation AdversaryLabService
//
//// This implements the example protocol. Replace the body of this class with the implementation of this service's protocol.
//- (void)upperCaseString:(NSString *)aString withReply:(void (^)(NSString *))reply {
//    NSString *response = [aString uppercaseString];
//    reply(response);
//}
//
//@end
