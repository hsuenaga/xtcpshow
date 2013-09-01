//
//  main.m
//  OpenBPF
//
//  Created by SUENAGA Hiroki on 2013/08/28.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/types.h>
#include <sys/stat.h>

#include <glob.h>
#include <syslog.h>

#import <Foundation/Foundation.h>
#import "OpenBPFXPC.h"
#import "BPFService.h"

@interface OpenBPFDelete : NSObject <NSXPCListenerDelegate>
@end

@implementation OpenBPFDelete
- (BOOL)listener:(NSXPCListener *)listener
shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
	BPFService *serviceObj = [[BPFService alloc] init];

	syslog(LOG_NOTICE, "connection requested");
	newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(OpenBPFXPC)];
	newConnection.exportedObject = serviceObj;
	newConnection.remoteObjectInterface = nil;
	serviceObj.xpcConnection = newConnection;

	[newConnection resume];
	return YES;
}
@end

int main(int argc, const char * argv[])
{
	NSXPCListener *xpc;
	OpenBPFDelete *handler = [[OpenBPFDelete alloc] init];

	syslog(LOG_NOTICE, "OpenBPF launchd.");
	xpc = [[NSXPCListener alloc] initWithMachServiceName:BPFControlServiceID];
	if (xpc == nil) {
		syslog(LOG_NOTICE, "cannot setup XPC");
		return 0;
	}
	
	syslog(LOG_NOTICE, "resuming XPC");
	[xpc setDelegate:handler];
	[xpc resume];
	[[NSRunLoop currentRunLoop] run];
	syslog(LOG_NOTICE, "end XPC");

	// not reached
	return 0;
}
