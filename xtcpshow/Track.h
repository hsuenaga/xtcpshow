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

struct traffic {
	struct timeval last;
	uint32_t bytes;
	uint32_t pkts;
};

@interface Track : NSObject {
	pcap_t *pcap;
}

/*
 * raw traffic data
 */
@property (assign) struct timeval last;
@property (assign) uint32_t bytes;
@property (assign) uint32_t pkts;
/*
 * cocked traffic data
 */
@property (assign) float mbps;

/*
 * connection to controller
 */
@property (weak) AppDelegate *controller;

- (void)startCapture;
- (void)updateNotify;

@end