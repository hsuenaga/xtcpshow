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

static NSString *const MachServiceName = @"com.mac.hiroki.suenaga.OpenBPF";
static const char *const BPF_DEV="/dev/bpf*";

@interface OpenBPFService : NSObject <OpenBPFXPC>
@property (strong) NSXPCConnection *xpcConnection;
@end

@implementation OpenBPFService
- (void)groupReadable:(int)uid reply:(void (^)(BOOL, NSString *))block
{
	glob_t gl;

	syslog(LOG_NOTICE, "groupReadble:reply:");
	
	memset(&gl, 0, sizeof(gl));
	glob(BPF_DEV, GLOB_NOCHECK, NULL, &gl);
	if (gl.gl_matchc <= 0) {
		block(NO, @"No bpf device found.");
		return;
	}

	syslog(LOG_NOTICE, "change permissions: uid%d, gid:%d", getuid(), getgid());
	for (int i = 0; i < gl.gl_pathc; i++) {
		struct stat st;
		const char *path = gl.gl_pathv[i];

		if (path == NULL)
			break;

		syslog(LOG_NOTICE, "device: %s", path);
		memset(&st, 0, sizeof(st));
		if (stat(path, &st) < 0)
			continue;
		if ((st.st_mode & S_IFCHR) == 0)
			continue;

		chown(path, uid, st.st_gid);
		chmod(path, st.st_mode | (S_IRUSR | S_IWUSR));
		syslog(LOG_NOTICE, "mode changed: %s", path);
	}
	syslog(LOG_NOTICE, "/dev/bpf owned by UID:%d", uid);
	block(YES, @"success");

	return;
}
- (void)alive:(void (^)(BOOL, NSString *))block
{
	syslog(LOG_NOTICE, "liveness check");
	block(YES, @"I'm alive");
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
	xpc = [[NSXPCListener alloc] initWithMachServiceName:MachServiceName];
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

