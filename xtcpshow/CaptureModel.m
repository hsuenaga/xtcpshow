//
//  CaptureModel.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include "math.h"

#import "CaptureModel.h"
#import "CaptureOperation.h"
#import "DataQueue.h"

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
	
	// data size
	self.history_size = DEF_HISTORY;
	self.data = [[DataQueue alloc] init];
	[self.data zeroFill:self.history_size];

	// traffic data
	self.total_pkts = 0;
	self.mbps = 0.0;
	self.max_mbps = 0.0;
	self.peek_hold_mbps = 0.0;
	
	// outlets
	self.controller = nil;
	
	return self;
}

- (int) startCapture
{
	CaptureOperation *op = [[CaptureOperation alloc] init];
	
	NSLog(@"Start capture thread");
	[self resetCounter];
	[op setModel:self];
	[op setSource:self.device];
	[op setFilter:self.filter];
	[op setQueuePriority:NSOperationQueuePriorityHigh];
	[capture_cue addOperation:op];
	running = TRUE;
	
	return 0;
}

- (void) stopCapture
{
	NSLog(@"Stop capture thread");
	[capture_cue cancelAllOperations];
	running = FALSE;
}

- (BOOL) captureEnabled
{
	return running;
}

- (void) resetCounter
{
	self.total_pkts = 0;
	self.mbps = 0.0;
	self.max_mbps = 0.0;
	self.peek_hold_mbps = 0.0;
	self.resolution = 0.0;
	self.target_resolution = 0.0;
}

- (void) samplingNotify:(NSNumber *)number
{
	[self.data shiftFloatValueWithNewValue:[number floatValue]];
}

- (void) samplingError
{
	[self.controller samplingError];
}
@end
