//
//  HelperAppController.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 4/19/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation

class HelperAppController
{
    static var xpcServiceConnection: NSXPCConnection?
    
    static func connectToXPCService() -> AdversaryLabServiceProtocol
    {
        // Create a connection to the service
        assert(Thread.isMainThread)
        if (self.xpcServiceConnection == nil)
        {
            self.xpcServiceConnection = NSXPCConnection(machServiceName: helperToolName, options: NSXPCConnection.Options.privileged)
            self.xpcServiceConnection!.remoteObjectInterface = NSXPCInterface(with:AdversaryLabServiceProtocol.self)
            self.xpcServiceConnection!.invalidationHandler =
            {
                // If the connection gets invalidated then, on the main thread, nil out our
                // reference to it.  This ensures that we attempt to rebuild it the next time around.
                self.xpcServiceConnection!.invalidationHandler = nil
                OperationQueue.main.addOperation()
                    {
                        self.xpcServiceConnection = nil
                        NSLog("connection invalidated\n")
                    }
            }
        }
        
        self.xpcServiceConnection?.resume()
        return (self.xpcServiceConnection!.remoteObjectProxy as! AdversaryLabServiceProtocol)
    }
    
}
