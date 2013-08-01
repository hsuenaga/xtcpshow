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

#define TIMESLOT (0.01) /* [sec] (= 10[ms])*/
#define HOLDSLOT (1.0) /* [sec] */

@class CaptureModel;

@interface CaptureOperation : NSOperation {
	char errbuf[PCAP_ERRBUF_SIZE];
	pcap_t *pcap;
	struct timeval tv_last_tick;
	struct timeval tv_peek_hold;
	float last_tick;
	float last_peek_hold;
	BOOL terminate;
}
@property (weak) CaptureModel *model;
@property (assign) const char *source;
@property (assign) const char *filter;

- (void)main;
- (float)elapsed:(struct timeval *)last;
- (BOOL)tick_expired;
- (BOOL)peek_hold_expired;
- (void)sendNotify;
- (void)sendError;

- (BOOL)allocPcap;
- (BOOL)attachFilter;
@end