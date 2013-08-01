//
//  CaptureModel.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "AppDelegate.h"

#define SNAPLEN 64
#define NPKT 1000
#define TICK 1 /* [ms] */

@interface CaptureModel : NSObject {
	NSOperationQueue *capture_cue;
	BOOL running;
}

/*
 * pcap binding
 */
@property (assign) const char *device;
@property (assign) const char *filter;

/*
 * traffic data reported by capture thread
 */
@property (atomic, assign) uint32_t total_pkts;
@property (atomic, assign) float mbps;
@property (atomic, assign) float max_mbps;
@property (atomic, assign) float peek_hold_mbps;
@property (atomic, assign) float resolution;
@property (atomic, assign) float target_resolution;

/*
 * connection to controller
 */
@property (weak) AppDelegate *controller;

- (int)startCapture;
- (void)stopCapture;
- (BOOL)captureEnabled;
- (void)resetCounter;

@end