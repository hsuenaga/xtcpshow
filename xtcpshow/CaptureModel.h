//
//  CaptureModel.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#import <Foundation/Foundation.h>
@class AppDelegate;
@class DataQueue;
@class FlowData;

#define DEF_HISTORY 50000 // packets

@interface CaptureModel : NSObject {
	NSOperationQueue *capture_cue;
	BOOL running;
}

// pcap binding
@property (assign) const char *device;
@property (assign) const char *filter;
@property (assign) BOOL promisc;

// data size
@property (assign) size_t history_size;

// traffic data reported by capture thread
@property (atomic, assign) uint32_t total_pkts;
@property (atomic, assign) float mbps;
@property (atomic, assign) float max_mbps;
@property (atomic, assign) float peek_hold_mbps;
@property (atomic, assign) float samplingIntervalLast; // [sec]
@property (atomic, assign) float samplingInterval; // [sec]
@property (atomic, strong) FlowData *flow;

// data processing (don't acccess from other thread)
@property (strong) DataQueue *data;
@property (weak) AppDelegate *controller;

- (CaptureModel *)init;
- (void)startCapture;
- (void)stopCapture;
- (BOOL)captureEnabled;

- (void)resetCounter;

- (void)setSamplingInterval:(float)interval;
- (float)samplingInterval;
- (float)samplingIntervalMS;
- (float)samplingIntervalLastMS;

- (void)animationTick;

- (void)samplingNotify:(NSNumber *)number;
- (void)samplingError:(NSString *)message;
- (void)samplingFinish:(id)sender;
@end