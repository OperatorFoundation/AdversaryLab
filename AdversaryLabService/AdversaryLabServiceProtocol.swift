//
//  AdversaryLabServiceProtocol.h
//  AdversaryLabService
//
//  Created by Mafalda on 4/15/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation

@objc public protocol AdversaryLabServiceProtocol
{
    func startAdversaryLabClient(allowBlock: String, port: String, configFileName: String)
    func stopAdversaryLabClient()
}

//#import <Foundation/Foundation.h>
//
//// The protocol that this service will vend as its API. This header file will also need to be visible to the process hosting the service.
//@protocol AdversaryLabServiceProtocol
//
//// Replace the API of this protocol with an API appropriate to the service you are vending.
//- (void)upperCaseString:(NSString *)aString withReply:(void (^)(NSString *))reply;
//
//@end
//
///*
// To use the service from an application or other process, use NSXPCConnection to establish a connection to the service by doing something like this:
//
//     _connectionToService = [[NSXPCConnection alloc] initWithServiceName:@"org.operatorFoundation.AdversaryLabService"];
//     _connectionToService.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(AdversaryLabServiceProtocol)];
//     [_connectionToService resume];
//
//Once you have a connection to the service, you can use it like this:
//
//     [[_connectionToService remoteObjectProxy] upperCaseString:@"hello" withReply:^(NSString *aString) {
//         // We have received a response. Update our text field, but do it on the main thread.
//         NSLog(@"Result string was: %@", aString);
//     }];
//
// And, when you are finished with the service, clean up the connection like this:
//
//     [_connectionToService invalidate];
//*/
