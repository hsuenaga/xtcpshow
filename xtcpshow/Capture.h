//
//  Capture.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <pcap/pcap.h>

#import <Foundation/Foundation.h>
#import "AppDelegate.h"

#define SNAPLEN 64
#define NPKT 1000
#define TICK 10 /* [ms] */
#define TIMESLOT (0.05) /* [sec] */
#define AGESLOT (1.0) /* [sec] */

@interface CaptureOperation : NSOperation
@property (strong) TCPShowModel *model;
- (void)main;
@end

@interface TCPShowModel : NSObject {
	NSOperationQueue *capture_cue;
	struct timeval timestamp_store;
	struct timeval agerate_store;
	char errbuf_store[PCAP_ERRBUF_SIZE];
}

/*
 * pcap binding
 */
@property (assign) pcap_t *pcap;
@property (assign) char *errbuf;
@property (assign) const char *device;
@property (assign) const char *filter;

/*
 * raw traffic data
 */
@property (assign) struct timeval *last;
@property (assign) struct timeval *age_last;
@property (assign) uint32_t bytes;
@property (assign) uint32_t pkts;
@property (assign) uint32_t total_pkts;
@property (assign) uint32_t drop_pkts;

/*
 * cooked traffic data
 */
@property (assign) float mbps;
@property (assign) float max_mbps;
@property (assign) float aged_db;
@property (assign) float aged_mbps;
@property (assign) float resolution;

/*
 * connection to controller
 */
@property (weak) AppDelegate *controller;

- (int)startCapture;
- (void)stopCapture;
@end