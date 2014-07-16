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
//  BPFControl.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/29.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ServiceManagement/ServiceManagement.h>
#import <Security/Security.h>

#import "BPFControl.h"
#import "OpenBPFXPC.h"

static BOOL xpcInvalid = NO;
static BOOL xpcRunning = NO;
static BOOL xpcResult = NO;

@implementation BPFControl
- (id)init
{
	OSStatus status;

	status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &self->_authRef);
	if (status != errAuthorizationSuccess) {
		/* AuthorizationCreate really shouldn't fail. */
		assert(NO);
		self->_authRef = NULL;
		NSLog(@"AuthorizationCreate failed.");
		return nil;
	}

	return self;
}

- (void)dealloc
{
	if (xpc) {
		[xpc invalidate];
		xpc = nil;
	}
}

- (BOOL)installHelper
{
	NSError *error;

	if (xpc) {
		[xpc invalidate];
		xpc = nil;
	}

	if (![self blessHelperWithLabel:(NSString *)BPFControlServiceID
				  error:(NSError **)&error]) {
		NSLog(@"JobBless failed:%@", [error description]);
		return NO;
	}
	xpc = [[NSXPCConnection alloc] initWithMachServiceName:BPFControlServiceID options:NSXPCConnectionPrivileged];

	return YES;
}

static void waitReply(void)
{
	// XXX: use NSLock and condition variable?
	while (xpcInvalid == NO && xpcRunning == YES) {
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
	}
}

- (BOOL)openXPC
{
	if (!xpc || xpcInvalid)
		xpc = [[NSXPCConnection alloc] initWithMachServiceName:BPFControlServiceID options:NSXPCConnectionPrivileged];
	if (!xpc)
		return NO;

	xpcResult = NO;
	xpcInvalid = NO;
	xpcRunning = NO;

	xpc.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(OpenBPFXPC)];
	xpc.exportedInterface = nil;
	xpc.exportedObject = nil;
	xpc.interruptionHandler = ^(void) {
		NSLog(@"connection interrupted.");
		xpcRunning = NO;
	};
	xpc.invalidationHandler = ^(void) {
		NSLog(@"connection invalidated.");
		xpcRunning = NO;
		xpcInvalid = YES;
	};
	proxy = [xpc remoteObjectProxyWithErrorHandler:^(NSError *e) {
		NSLog(@"proxy error:%@", [e description]);
		xpcRunning = NO;
	}];
	if (proxy == nil) {
		NSLog(@"cannot get proxy");
		[xpc invalidate];
		xpc = nil;
		return NO;
	}

	[xpc resume];
	xpcRunning = YES;
	[proxy alive:^(int version, NSString *m) {
		NSLog(@"Helper livness: version %d (%@)", version, m);
		if (version == OpenBPF_VERSION)
			xpcResult = YES;
		else
			xpcResult = NO;
		xpcRunning = NO;
	}];
	waitReply();
	if (!xpc || xpcInvalid)
		return NO;
	[xpc suspend];
	
	if (!xpcResult) {
		[xpc invalidate];
		xpc = nil;
	}
	return xpcResult;
}

- (BOOL)checkXPC
{
	if (![self openXPC]) {
		NSLog(@"No valid helper found. install.");
		if (![self installHelper]) {
			NSLog(@"Helper installation failed.");
			return NO;
		}
		if (![self openXPC]) {
			NSLog(@"Installed helper is not running.");
			return NO;
		}
	}

	return YES;
}

- (void)closeXPC
{
	if (!xpc)
		return;

	[xpc invalidate];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
	xpc = nil;
	xpcRunning = NO;
}

- (BOOL)secure
{
	NSLog(@"Secure the BPF device");
	if (![self checkXPC]) {
		NSLog(@"cannot open XPC");
		return NO;
	}
	[xpc resume];
	xpcRunning = YES;
	[proxy chown:0 reply:^(BOOL reply, NSString *m){
		xpcResult = reply;
		NSLog(@"secure BPF => %d (%@)", xpcResult, m);
		xpcRunning = NO;
	}];
	waitReply();
	if (xpc)
		[xpc suspend];
	NSLog(@"messaging done");

	return xpcResult;
}

- (BOOL)insecure
{
	NSLog(@"Insecure the BPF device");
	if (![self checkXPC]) {
		NSLog(@"cannot open XPC");
		return NO;
	}
	[xpc resume];
	xpcRunning = YES;
	[proxy chown:getuid() reply:^(BOOL reply, NSString *m) {
		xpcResult = reply;
		NSLog(@"insecure BPF => %d (%@)", xpcResult, m);
		xpcRunning = NO;
	}];
	waitReply();
	if (xpc)
		[xpc suspend];
	NSLog(@"messaging done");

	return xpcResult;
}

- (BOOL)blessHelperWithLabel:(NSString *)label error:(NSError **)errorPtr
{
	BOOL result = NO;
	NSError * error = nil;

	AuthorizationItem authItem		= { kSMRightBlessPrivilegedHelper, 0, NULL, 0 };
	AuthorizationRights authRights	= { 1, &authItem };
	AuthorizationFlags flags		=	kAuthorizationFlagDefaults				|
	kAuthorizationFlagInteractionAllowed	|
	kAuthorizationFlagPreAuthorize			|
	kAuthorizationFlagExtendRights;

	NSLog(@"open helper");

	/* Obtain the right to install our privileged helper tool (kSMRightBlessPrivilegedHelper). */
	OSStatus status = AuthorizationCopyRights(self->_authRef, &authRights, kAuthorizationEmptyEnvironment, flags, NULL);
	if (status != errAuthorizationSuccess) {
		error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
	} else {
		CFErrorRef  cfError;

		/* This does all the work of verifying the helper tool against the application
		 * and vice-versa. Once verification has passed, the embedded launchd.plist
		 * is extracted and placed in /Library/LaunchDaemons and then loaded. The
		 * executable is placed in /Library/PrivilegedHelperTools.
		 */
		result = (BOOL) SMJobBless(kSMDomainSystemLaunchd, (CFStringRef)CFBridgingRetain(label), self->_authRef, &cfError);
		if (!result) {
			NSLog(@"SMJobBless failed.");
			error = CFBridgingRelease(cfError);
		}
	}
	if ( ! result && (errorPtr != NULL) ) {
		assert(error != nil);
		*errorPtr = error;
	}

	return result;
}

@end
