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
//  CaptureModel.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//
#import <sys/types.h>
#import <sys/ioctl.h>
#import <sys/socket.h>

#import <net/if.h>
#import <net/if_dl.h>
#import <net/if_types.h>
#import <net/if_media.h>
#import <ifaddrs.h>

#import "CaptureModel.h"
#import "CaptureOperation.h"

NSString *const DEF_DEVICE=@"en0";
NSString *const PREFER_DEVICE=@"en";

/*
 * Model object: almost values are updated by operation thread.
 */
@implementation CaptureModel {
    NSOperationQueue *capture_cue;
    BOOL running;
}
@synthesize device;
@synthesize filter;
@synthesize promisc;
@synthesize bpfc;
@synthesize dataBase;
@synthesize totalPkts;
@synthesize mbps;
@synthesize max_mbps;
@synthesize average_mbps;
@synthesize samplingInterval;
@synthesize samplingIntervalLast;
@synthesize controller;

- (CaptureModel *) init
{
	self = [super init];

	// thread
	capture_cue = [[NSOperationQueue alloc] init];
	running = FALSE;

	// pcap
	device = NULL;
	filter = "tcp";
    bpfc = nil;

	// data size
    dataBase = [TrafficDB TrafficDBWithHistorySize:DEF_HISTORY withResolution:(1000 * 1000) startAt:NULL endAt:NULL];

	// traffic data
	[self resetCounter];

	// outlets
	controller = nil;

	return self;
}

- (BOOL) openDevice
{
    NSLog(@"OpenBPF device");
    if (bpfc) {
        [bpfc closeDevice];
        bpfc = nil;
    }
    bpfc = [[CaptureBPF alloc] init];
    if (bpfc == nil)
        return FALSE;
    return [bpfc openDevice];
}

- (BOOL) startCapture
{
    if (bpfc == nil)
        [self openDevice];
    
    [self resetCounter];
    
    NSLog(@"Start capture thread");
	CaptureOperation *op = [[CaptureOperation alloc] init];
	[op setModel:self];
    [op setDataBase:self.dataBase];
    [op setBpfControl:self.bpfc];
	[op setSource:self.device];
	[op setFilter:self.filter];
	[op setQueuePriority:NSOperationQueuePriorityHigh];
	[capture_cue addOperation:op];
	running = TRUE;
    return TRUE;
}

- (void) stopCapture
{
	NSLog(@"Stop capture thread");
	[capture_cue cancelAllOperations];
	[capture_cue waitUntilAllOperationsAreFinished];
#ifdef DEBUG
    [dataBase openDebugFile:@"debug_tree.dot"];
    [dataBase dumpTree:TRUE];
#endif
}

- (BOOL) captureEnabled
{
	return running;
}

- (void) resetCounter
{
	totalPkts = 0;
	mbps = 0.0;
	max_mbps = 0.0;
	average_mbps = 0.0;
    samplingInterval = 0.0;
	samplingIntervalLast = 0.0;
}

- (void) updateCounter:(id)sender
{
    [self.controller updateUserInterface];
}

- (double) samplingIntervalMS
{
	return (samplingInterval * 1.0E3);
}

- (double) samplingIntervalLastMS
{
	return (samplingIntervalLast * 1.0E3);
}

//
// notify from Capture operation thread
//
- (void) recvError:(NSString *)message
{
	[controller samplingError:message];
	running = FALSE;
}

- (void) recvFinish:(id)sender
{
	running = FALSE;
}

//
// create device list
//

- (BOOL)mediatActive:(const char *)ifname
{
    struct ifmediareq ifmr;
    memset(&ifmr, 0, sizeof(ifmr));
    strlcpy(ifmr.ifm_name, ifname, sizeof(ifmr.ifm_name));
    
    int s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s < 0) {
        NSLog(@"%s: socket() failed: %s", ifname, strerror(errno));
        return FALSE;
    }
    if (ioctl(s, SIOCGIFMEDIA, &ifmr) < 0) {
        close(s);
        if (errno ==  EOPNOTSUPP) {
            NSLog(@"%s: status unknown.", ifname);
            return TRUE;
        }
        NSLog(@"%s: ioctl(SIOCGIFMADIA) failed: %s", ifname, strerror(errno));
        return FALSE;
    }
    close(s);
    
    if (!(ifmr.ifm_status & IFM_AVALID))
        return FALSE;
    
    return ((ifmr.ifm_status & IFM_ACTIVE) != 0);
}

- (void)createInterfaceButton:(NSPopUpButton *)btn
{
    struct ifaddrs *ifap0, *ifap;
    
    if (getifaddrs(&ifap0) < 0)
        return;
    
    NSMutableArray *if_list = [NSMutableArray new];
    for (ifap = ifap0; ifap; ifap = ifap->ifa_next) {
        NSString *if_name, *exist_name;
        NSEnumerator *enumerator;
        
        if (ifap->ifa_flags & IFF_LOOPBACK)
            continue;
        if (!(ifap->ifa_flags & IFF_UP))
            continue;
        if (!(ifap->ifa_flags & IFF_RUNNING))
            continue;
        
        if_name = [NSString
                   stringWithCString:ifap->ifa_name
                   encoding:NSASCIIStringEncoding];
        enumerator = [if_list objectEnumerator];
        while (exist_name = [enumerator nextObject]) {
            if ([if_name isEqualToString:exist_name]) {
                if_name = nil;
                break;
            }
        }
        if (if_name == nil)
            continue;

        if (![self mediatActive:ifap->ifa_name])
            continue;

        [if_list addObject:if_name];
    }
    
    [if_list sortUsingSelector:@selector(compare:)];
    NSEnumerator *e = [if_list objectEnumerator];
    NSString *if_name;
    BOOL def_iface = FALSE;
    BOOL preferred_iface = FALSE;

    [btn removeAllItems];
    while (if_name = [e nextObject]) {
        [btn addItemWithTitle:if_name];
        if (!def_iface && [if_name isEqualToString:DEF_DEVICE]) {
            [btn selectItemWithTitle:if_name];
            def_iface = TRUE;
        }
        if (!def_iface && !preferred_iface) {
            NSRange range;
            range = [if_name rangeOfString:PREFER_DEVICE];
            if (range.location != NSNotFound) {
                [btn selectItemWithTitle:if_name];
                preferred_iface = TRUE;
            }
        }
    }
    freeifaddrs(ifap0);
}
@end
