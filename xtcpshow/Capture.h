//
//  Track.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <pcap/pcap.h>

#import <Foundation/Foundation.h>
#import "AppDelegate.h"

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

/*
 * raw traffic data
 */
@property (assign) struct timeval *last;
@property (assign) struct timeval *age_last;
@property (assign) uint32_t bytes;
@property (assign) uint32_t pkts;
/*
 * cooked traffic data
 */
@property (assign) float mbps;
@property (assign) float max_mbps;
@property (assign) float aged_db;
@property (assign) float aged_mbps;

/*
 * connection to controller
 */
@property (weak) AppDelegate *controller;

- (void)startCapture;
- (void)stopCapture;
@end