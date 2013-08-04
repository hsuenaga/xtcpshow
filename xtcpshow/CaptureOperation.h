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

#define TIMESLOT (0.1) /* [sec] (= 100[ms])*/
#define HOLDSLOT (1.0) /* [sec] */

#define CAP_TICK 1
#define CAP_SNAPLEN 64
#define CAP_BUFSIZ (CAP_SNAPLEN * 128)

@class CaptureModel;

@interface CaptureOperation : NSOperation {
	char errbuf[PCAP_ERRBUF_SIZE];
	char *source_interface;
	char *filter_program;
	pcap_t *pcap;
	struct timeval tv_next_tick;
	struct timeval tv_peek_hold;
    float last_interval; // [ms]
	BOOL terminate;
}
@property (weak) CaptureModel *model;

- (CaptureOperation *)init;
- (void)dealloc;
- (void)main;
- (void)setSource:(const char *)source;
- (void)setFilter:(const char *)filter;

- (float)elapsed:(struct timeval *)last;
- (BOOL)tick_expired;
- (BOOL)peek_hold_expired;
- (void)sendNotify:(float)mbps;
- (void)sendError;

- (BOOL)allocPcap;
- (BOOL)attachFilter;
@end