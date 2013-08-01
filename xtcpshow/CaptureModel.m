//
//  CaptureModel.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#import "CaptureModel.h"
#import "CaptureOperation.h"
/*
 * Model object: almost values are updated by operation thread.
 */
@implementation CaptureModel
- (CaptureModel *) init
{
	/* thread */
	capture_cue = [[NSOperationQueue alloc] init];
	running = FALSE;
	
	/* pcap */
	self.device = NULL;
	self.filter = NULL;
	
	/* raw traffic */
	self.total_pkts = 0;
	
	/* cooked data */
	self.mbps = 0.0;
	self.max_mbps = 0.0;
	self.peek_hold_mbps = 0.0;
	
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
@end
