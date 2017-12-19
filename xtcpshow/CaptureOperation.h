// Copyright (c) 2013
// SUENAGA Hiroki <hiroki_suenaga@mac.com>. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.

// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

//
//  CaptureOperation.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
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
@class BPFControl;

@interface CaptureOperation : NSOperation {
	NSString *last_error;
	DataQueue *max_buffer;

	BPFControl *bpfControl;
	char *source_interface;
	char *filter_program;

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
- (void)setBPFControl:(BPFControl *)bpfc;
- (void)setSource:(const char *)source;
- (void)setFilter:(const char *)filter;

- (float)elapsed:(struct timeval *)last;
- (BOOL)tick_expired;
- (void)sendNotify:(int)size withTime:(const struct timeval *)tv;
- (void)sendError:(NSString *)message;
- (void)sendFinish;
- (BOOL)attachFilter;
@end
