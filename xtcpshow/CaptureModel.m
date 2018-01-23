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
#include "math.h"

#import "BPFControl.h"
#import "CaptureModel.h"
#import "CaptureOperation.h"
#import "ComputeQueue.h"
#import "DerivedData.h"

/*
 * Model object: almost values are updated by operation thread.
 */
@implementation CaptureModel
- (CaptureModel *) init
{
	self = [super init];

	// thread
	capture_cue = [[NSOperationQueue alloc] init];
	running = FALSE;

	// pcap
	self.device = NULL;
	self.filter = "tcp";
    self.bpfc = nil;

	// data size
    self.dataBase = [TrafficDB TrafficDBWithHistorySize:DEF_HISTORY withResolution:(1000 * 1000) startAt:NULL endAt:NULL];

	// traffic data
	[self resetCounter];

	// outlets
	_controller = nil;

	return self;
}

- (BOOL) startCapture
{
    NSLog(@"OpenBPF device");
    self.bpfc = [[BPFControl alloc] init];
    if (self.bpfc == nil)
        return FALSE;
    
	CaptureOperation *op = [[CaptureOperation alloc] init];

	NSLog(@"Start capture thread");
	[self resetCounter];
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
    [self.dataBase openDebugFile:@"debug_tree.dot"];
    [self.dataBase dumpTree:TRUE];
#endif

}

- (BOOL) captureEnabled
{
	return running;
}

- (void) resetCounter
{
	self.total_pkts = 0;
	self.mbps = 0.0f;
	self.max_mbps = 0.0f;
	self.peek_hold_mbps = 0.0f;
	self.samplingIntervalLast = 0.0f;
}

- (float) samplingIntervalMS
{
	return (self.samplingInterval * 1000.0f);
}

- (float) samplingIntervalLastMS
{
	return (self.samplingIntervalLast * 1000.0f);
}

//
// notify from Capture operation thread
//
- (void) recvError:(NSString *)message
{
	[self.controller samplingError:message];
	running = FALSE;
}

- (void) recvFinish:(id)sender
{
	running = FALSE;
}
@end
