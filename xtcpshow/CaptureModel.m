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
#import "DataEntry.h"

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
	_device = NULL;
	_filter = "tcp";

	// data size
	_history_size = DEF_HISTORY;
	_data = [[DataQueue alloc] init];

	// traffic data
	[self resetCounter];

	// outlets
	_controller = nil;

	return self;
}

- (void) startCapture
{
	CaptureOperation *op = [[CaptureOperation alloc] init];

	NSLog(@"Start capture thread");
	[self resetCounter];
	[op setModel:self];
	[op setSource:_device];
	[op setFilter:_filter];
	[op setQueuePriority:NSOperationQueuePriorityHigh];
	[capture_cue addOperation:op];
	running = TRUE;
}

- (void) stopCapture
{
	NSLog(@"Stop capture thread");
	[capture_cue cancelAllOperations];
}

- (BOOL) captureEnabled
{
	return running;
}

- (void) resetCounter
{
	_total_pkts = 0;
	_mbps = 0.0f;
	_max_mbps = 0.0f;
	_peek_hold_mbps = 0.0f;
	_samplingIntervalLast = 0.0f;
}

- (float) samplingIntervalMS
{
	return ([self samplingInterval] * 1000.0f);
}

- (float) samplingIntervalLastMS
{
	return (_samplingIntervalLast * 1000.0f);
}

- (void) animationTick
{
	// nothing to do
}

//
// notify from Capture operation thread
//
- (void) samplingNotify:(DataEntry *)entry
{
	if (entry.numberOfSamples > 0)
		[_data addDataEntry:entry withLimit:_history_size];
	_data.last_update = [entry timestamp];
}

- (void) samplingError:(NSString *)message
{
	[_controller samplingError:message];
	running = FALSE;
}

- (void) samplingFinish:(id)sender
{
	running = FALSE;
}
@end