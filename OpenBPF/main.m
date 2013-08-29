//
//  main.m
//  OpenBPF
//
//  Created by SUENAGA Hiroki on 2013/08/28.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <syslog.h>

#import <Foundation/Foundation.h>
#import "OpenBPFXPC.h"

@interface OpenBPFService : NSObject <OpenBPFXPC>
@property (strong) NSXPCConnection *xpcConnection;
@end

@implementation OpenBPFService
- (void)secure
{
	syslog(LOG_INFO, "secure the permission");
	[[_xpcConnection remoteObjectProxy] XPCresult:YES];
	return;
}

- (void)insecure
{
	syslog(LOG_INFO, "insecure the permission");
	[[_xpcConnection remoteObjectProxy] XPCresult:YES];
	return;
}
@end

@interface OpenBPFDelete : NSObject <NSXPCListenerDelegate>
@end

@implementation OpenBPFDelete
- (BOOL)listener:(NSXPCListener *)listener
shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
	OpenBPFService *serviceObj = [[OpenBPFService alloc] init];

	syslog(LOG_INFO, "connection requested");
	newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(OpenBPFXPC)];
	newConnection.exportedObject = serviceObj;
	newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(NotifyOpenBPFXPC)];
	serviceObj.xpcConnection = newConnection;

	[newConnection resume];
	return YES;
}
@end

int main(int argc, const char * argv[])
{
	NSXPCListener *xpc;

	openlog("OpenBPF", LOG_NDELAY, LOG_DAEMON);
	syslog(LOG_INFO, "launched");

	@autoreleasepool {
		OpenBPFDelete *handler;
		
		xpc = [NSXPCListener serviceListener];
		if (xpc == nil) {
			syslog(LOG_ERR, "cannot setup XPC");
			return 0;
		}
		[xpc setDelegate:handler];
	}

	[xpc resume];
	// not reached
	return 0;
}

