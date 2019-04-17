//
//  AdversaryLabService.h
//  AdversaryLabService
//
//  Created by Mafalda on 4/15/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation

class AdversaryLabServiceDelegate: NSObject, NSXPCListenerDelegate
{
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool
    {
        let exportedObject = AdversaryLabService()
        newConnection.exportedInterface = NSXPCInterface(with: AdversaryLabServiceProtocol.self)
        newConnection.exportedObject = exportedObject
        newConnection.resume()
        return true
    }
}

//#import <Foundation/Foundation.h>
//#import "AdversaryLabServiceProtocol.h"
//
//// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
//@interface AdversaryLabService : NSObject <AdversaryLabServiceProtocol>
//@end
