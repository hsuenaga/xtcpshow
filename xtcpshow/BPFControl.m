//
//  BPFControl.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/29.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ServiceManagement/ServiceManagement.h>
#import <Security/Security.h>

#import "BPFControl.h"
#import "../OpenBPF/OpenBPFXPC.h"

NSString *const BPFControlServiceID=@"com.mac.hiroki.suenaga.OpenBPF";

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

- (BOOL)installHelper
{
	NSError *error;

	if (![self blessHelperWithLabel:(NSString *)BPFControlServiceID
				  error:(NSError **)&error]) {
		NSLog(@"JobBless failed:%@", [error description]);
		return NO;
	}
	return YES;
}

- (BOOL)openXPC
{
	[self installHelper];
	xpc = [[NSXPCConnection alloc] initWithMachServiceName:BPFControlServiceID options:NSXPCConnectionPrivileged];
	if (!xpc) {
		[self installHelper];
		xpc = [[NSXPCConnection alloc] initWithMachServiceName:BPFControlServiceID options:NSXPCConnectionPrivileged];
	}
	if (!xpc) {
		NSLog(@"Cannot open XPC conncetion: %@",
		      BPFControlServiceID);
		return NO;
	}
	xpc.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(OpenBPFXPC)];
	xpc.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(NotifyOpenBPFXPC)];
	xpc.exportedObject = self;
	xpc.interruptionHandler = ^(void) {
		NSLog(@"connection interrupted.");
	};
	xpc.invalidationHandler = ^(void) {
		NSLog(@"connection invalidated.");
	};

	[xpc resume];
	proxy = [xpc remoteObjectProxyWithErrorHandler:^(NSError *e) {
		NSLog(@"proxy error:%@", [e description]);
	}];
	if (proxy == nil) {
		NSLog(@"cannot get proxy");
		return NO;
	}

	return YES;
}

- (void)closeXPC
{
	if (!xpc)
		return;

	[xpc invalidate];
}

- (void)secure
{
	if (![self openXPC])
		return;
	[proxy secure];

	[self closeXPC];
	return;
}

- (void)insecure
{
	NSLog(@"Insecure the BPF device");
	if (![self openXPC]) {
		NSLog(@"cannot open XPC");
		return;
	}
	[proxy insecure];
	NSLog(@"messaging done");
//	[self closeXPC];
	return;
}

- (void)XPCresult:(BOOL)result
{
	if (result == YES)
		NSLog(@"XPC success");
	else
		NSLog(@"XPC failure");
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
