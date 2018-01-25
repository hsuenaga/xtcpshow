//
//  OpenBPFService.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/25.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//
#import <ServiceManagement/ServiceManagement.h>
#import <SecurityFoundation/SecurityFoundation.h>
#import <Security/Security.h>

#import "OpenBPFService.h"

enum {
    XPC_IDLE,
    XPC_RUNNING,
    XPC_COMPLETE
};

@interface OpenBPFService ()
@property (assign, atomic) int version;
@property (strong, atomic) NSString *message;
@property (assign, atomic) BOOL status;
@property (strong, atomic) NSString *deviceName;
@property (strong, atomic) NSFileHandle *deviceHandle;
@property (strong, atomic) NSConditionLock *lock;

- (id)newConnection:(void(^)(NSString *msg))eventHandler;
- (void)checkVersion;
- (void)getFileHandle;
@end

@implementation OpenBPFService
- (id)init
{
    self = [super init];
    self.version = 0;
    self.status = FALSE;
    self.deviceName = nil;
    self.deviceHandle = nil;
    self.lock = [[NSConditionLock alloc] initWithCondition:XPC_IDLE];
    [self checkVersion];
    return self;
}

+ (void)installHelper
{
    AuthorizationRef authref;
    OSStatus status;
    
    status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authref);
    if (status != errAuthorizationSuccess) {
        NSLog(@"AuthorizationCreate failed.");
        return;
    }
    
    //
    // Acquire Rights
    //
    AuthorizationItem authItem = {kSMRightBlessPrivilegedHelper, 0, NULL, 0};
    AuthorizationRights authRights = {1, &authItem};
    AuthorizationFlags flags = kAuthorizationFlagDefaults |
    kAuthorizationFlagInteractionAllowed |
    kAuthorizationFlagPreAuthorize |
    kAuthorizationFlagExtendRights;
    
    status = AuthorizationCopyRights(authref, &authRights, kAuthorizationEmptyEnvironment, flags, NULL);
    if (status != errAuthorizationSuccess) {
        NSLog(@"AuthorizationCopyRights() failed.");
        return;
    }
    
    //
    // Bless helper
    //
    CFErrorRef cfError;
    BOOL result;
    result = (BOOL)SMJobBless(kSMDomainUserLaunchd,(CFStringRef)CFBridgingRetain(BPFControlServiceID), authref, &cfError);
    if (!result) {
        NSError *error = CFBridgingRelease(cfError);
        NSLog(@"SMJobBless failed: %@", [error description]);
        return;
    }
    
    return;
}

- (BOOL)openDevice
{
    if (self.version != OpenBPF_VERSION) {
        NSLog(@"Invalid Helper version.");
        return FALSE;
    }
    [self getFileHandle];
    return self.status;
}

- (void)closeDevice
{
    if (self.deviceHandle) {
        [self.deviceHandle closeFile];
    }
    self.deviceHandle = nil;
    self.deviceName = nil;
    self.status = FALSE;
}

- (int)fileDescriptor
{
    if (self.deviceHandle)
        return [self.deviceHandle fileDescriptor];

    return -1;
}

- (id)newConnection:(void (^)(NSString *))eventHandler
{
    NSXPCConnection *xpc = [[NSXPCConnection alloc] initWithMachServiceName:BPFControlServiceID options:NSXPCConnectionPrivileged];
    xpc.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(OpenBPFXPC)];
    xpc.exportedInterface = nil;
    xpc.exportedObject = nil;
    xpc.interruptionHandler = ^(void) {
        eventHandler(@"XPC Interrupted.");
    };
    xpc.invalidationHandler = ^(void) {
        eventHandler(@"XPC Invalidated.");
    };
    return xpc;
}

- (void)checkVersion
{
    NSLog(@"checkVersion: XPC start.");
    [self.lock lockWhenCondition:XPC_IDLE];
    NSXPCConnection *connection = [self newConnection:^(NSString *msg) {
        NSLog(@"checkVersion: %@", msg);
        [self.lock unlockWithCondition:XPC_COMPLETE];
    }];
    [connection resume];
    id proxy = [connection remoteObjectProxyWithErrorHandler:^(NSError *e) {
        NSLog(@"checkVersion: %@", e);
        [self.lock unlockWithCondition:XPC_COMPLETE];
    }];
    [proxy alive:^(int v, NSString *m) {
        NSLog(@"checkVersion: XPC answer received: version:%d msg:%@",
              v, m);
        self.version = v;
        self.message = m;
        [connection invalidate];
    }];
    
    NSLog(@"checkVersion: Wait for XPC reply.");
    [self.lock lockWhenCondition:XPC_COMPLETE];
    NSLog(@"checkVersion: XPC Call completed");
    [self.lock unlockWithCondition:XPC_IDLE];
}

- (void)getFileHandle
{
    NSLog(@"getFileHandle: XPC start.");
    [self.lock lockWhenCondition:XPC_IDLE];
    NSXPCConnection *connection = [self newConnection:^(NSString *msg) {
        NSLog(@"getFileHandle: %@", msg);
        [self.lock unlockWithCondition:XPC_COMPLETE];
    }];
    [connection resume];
    id proxy = [connection remoteObjectProxyWithErrorHandler:^(NSError *e) {
        NSLog(@"getFileHandle: %@", e);
        [self.lock unlockWithCondition:XPC_COMPLETE];
    }];
    [proxy getFileHandle:^(BOOL s, NSString *n, NSFileHandle *h) {
        NSLog(@"getFileHandle: XPC answer received: status:%s deviceName:%@", s ? "TRUE":"FALSE", n);
        self.status = s;
        self.deviceName = n;
        self.deviceHandle = h;
        [connection invalidate];
    }];
    
    NSLog(@"getFileHandle: Wait for XPC reply.");
    [self.lock lockWhenCondition:XPC_COMPLETE];
    NSLog(@"getFileHandle: XPC Call completed.");
    [self.lock unlockWithCondition:XPC_IDLE];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"BPF Service (Version:%d Message:%@ STATUS:%s deviceName:%@ deviceHandle:%@)",
            self.version, self.message, self.status ? "TRUE":"FALSE", self.deviceName, self.deviceHandle.description];
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"BPF Service (Version:%d Message:%@ STATUS:%s deviceName:%@ deviceHandle:%@)",
            self.version, self.message, self.status ? "TRUE":"FALSE", self.deviceName, self.deviceHandle.debugDescription];
}
@end
