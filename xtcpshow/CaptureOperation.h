//
//  CaptureOperation.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <pcap/pcap.h>

#import <Foundation/Foundation.h>

#import "AppDelegate.h"

#define TIMESLOT (0.10f) // [sec] (= 100[ms])
#define HOLDSLOT (1.0f)  // [sec]

#define CAP_TICK 100      // 50 [ms]
#define CAP_SNAPLEN 64
#define CAP_BUFSIZ (CAP_SNAPLEN * 128)

@class CaptureModel;
@class DataQueue;

@interface CaptureOperation : NSOperation {
	NSString *last_error;
	DataQueue *max_buffer;

	char errbuf[PCAP_ERRBUF_SIZE];
	char *source_interface;
	char *filter_program;
	pcap_t *pcap;

	struct timeval tv_next_tick;
	struct timeval tv_last_tick;
	float last_interval; // [ms]
	BOOL terminate;

	// counter
	float max_mbps;
	float peak_mbps;
	int pkts;
	int bytes;
}
@property (weak) CaptureModel *model;

- (CaptureOperation *)init;
- (void)dealloc;
- (void)main;
- (void)setSource:(const char *)source;
- (void)setFilter:(const char *)filter;

- (float)elapsed:(struct timeval *)last;
- (BOOL)tick_expired;
- (void)sendNotify:(int)size withTime:(struct timeval *)tv;
- (void)sendError:(NSString *)message;
- (void)sendFinish;

- (BOOL)allocPcap;
- (BOOL)attachFilter;
@end