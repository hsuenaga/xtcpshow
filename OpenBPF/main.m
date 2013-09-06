// Copyright (c) 2013
// SUENAGA Hiroki <hiroki_suenaga@mac.com>. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.

// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

//
//  main.m
//  OpenBPF
//
//  Created by SUENAGA Hiroki on 2013/08/28.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
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

	syslog(LOG_NOTICE, "connection requested: %d", [newConnection processIdentifier]);
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
