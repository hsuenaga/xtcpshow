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
//  CaptureOperation.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#import "BPFControl.h"
#import "CaptureOperation.h"
#import "CaptureModel.h"
#import "ComputeQueue.h"
#import "DerivedData.h"

/*
 * Capture thread
 */
@implementation CaptureOperation
@synthesize bpfControl;
@synthesize peak_hold_queue;
@synthesize index;

- (CaptureOperation *)init
{
	self = [super init];

	source_interface = NULL;
	filter_program = NULL;
	bpfControl = NULL;
    index = nil;

	return self;
}

- (void)dealloc
{
	if (source_interface)
		free(source_interface);
	if (filter_program)
		free(filter_program);
	source_interface = NULL;
	filter_program = NULL;
	bpfControl = nil;
    index = nil;
}

- (void) main
{
	NSLog(@"caputer thread: interval %f [sec]", TIMESLOT);
	[_model setSamplingInterval:TIMESLOT];

	// initialize libpcap
	if (!bpfControl) {
		NSLog(@"cannot initialize bpfControl module.");
		[self sendError:@"bpfControl is not found."];
		return;
	}

	// set filter
	if (![self attachFilter]) {
		NSLog(@"libpcap filter error");
		[self sendError:@"Syntax erorr in filter statement"];
		return;
	}
    
    if (!index) {
        NSLog(@"no packet index");
        return;
    }
	
	// reset timer
	gettimeofday(&tv_next_tick, NULL);
	gettimeofday(&tv_last_tick, NULL);
    struct timeval tick = {
        .tv_sec = 0,
        .tv_usec = CAP_TICK * 1000, // [msec]
    };
    [bpfControl timeout:&tick];

	// reset counter
	max_mbps = peak_mbps = 0.0;
	bytes = pkts = 0;

    if (![bpfControl promiscus:[_model promisc]]) {
        NSLog(@"Cannot initizlize BPF.");
        [self sendError:@"Cannot enable promiscus mode"];
        return;
    }
    if (![bpfControl start:source_interface]) {
        NSLog(@"Cannot Initiaize BPF.");
        [self sendError:@"Cannot attach interface"];
        return;
    }

    TrafficData *timeout = [TrafficData sampleOf:self
                                           atTimeval:NULL
                                    withPacketLength:0
                                             auxData:nil];
    terminate = FALSE;
    while (!terminate) {
		@autoreleasepool {
            struct timeval tv;
            uint32_t pktlen;
			float mbps;

			if ([self isCancelled] == YES)
				break;

			if (_model == nil)
				break;
            if (![bpfControl next:&tv withCaplen:NULL withPktlen:&pktlen]) {
                NSLog(@"bpfControl error.");
                [self sendError:@"Failed to read from BPF"];
                terminate = true;
            }
            else if (tv.tv_sec || tv.tv_usec) {
                TrafficData *sample;
                pkts++;
                bytes += pktlen;
                sample = [index addSampleAtTimevalExtend:&tv withBytes:pktlen auxData:nil];
                [self sendNotify:sample];
			}
            else {
                // timeout
                timeout.Start = timeout.End = [NSDate date];
                [self sendNotify:timeout];
            }

			// timer update
			if ([self tick_expired] == FALSE)
				continue;
            
			// update max
			mbps = (float)(bytes * 8) / last_interval; // [bps]
			mbps = mbps / (1000.0f * 1000.0f); // [mbps]
			if (max_mbps < mbps)
				max_mbps = mbps;

			// update model
			[_model setTotal_pkts:pkts];
			[_model setMbps:mbps];
			[_model setMax_mbps:max_mbps];
			[_model setSamplingIntervalLast:last_interval];
			bytes = 0;
		}
	}

	// finalize
    [bpfControl stop];
	NSLog(@"%d packets recieved by pcap", [bpfControl bs_recv]);
	NSLog(@"%d packets dropped by pcap", [bpfControl bs_drop]);
	NSLog(@"%d packets dropped by device", [bpfControl bs_ifdrop]);
	NSLog(@"%d packets proccessed.", pkts);
	NSLog(@"done thread");
	[self sendFinish];
    
    // debug
    [index openDebugFile:@"tree.dot"];
    [index dumpTree:true];
}

- (void)setSource:(const char *)source
{
	if (source_interface) {
		free(source_interface);
		source_interface = NULL;
	}
	if (source)
		source_interface = strdup(source);
}

- (void)setFilter:(const char *)filter
{
	if (filter_program) {
		free(filter_program);
		filter_program = NULL;
	}
	if (filter)
		filter_program = strdup(filter);
}

- (float)elapsedFrom:(struct timeval *)last
{
	struct timeval now, delta;
	float elapsed;

	gettimeofday(&now, NULL);
	timersub(&now, last, &delta);
	elapsed = (float)delta.tv_sec;
	elapsed += (float)delta.tv_usec / (1000.0f * 1000.0f);

	return elapsed;
}

- (void)addSecond:(float)second toTimeval:(struct timeval *)tv
{
	struct timeval delta;
	float usecond;
	int add = TRUE;

	if (isnan(second) || isinf(second))
		return;

	if (second < 0.0) {
		add = FALSE;
		second = fabsf(second);
	}

	delta.tv_sec = floor(second);
	usecond = second - (float)delta.tv_sec;
	usecond = usecond * (1000.0f * 1000.0f);
	delta.tv_usec = floor(usecond);

	if (add)
		timeradd(tv, &delta, tv);
	else
		timersub(tv, &delta, tv);
}

- (BOOL)tick_expired
{
	float expired, elapsed;

	expired = [self elapsedFrom:&tv_next_tick];
	if (expired < TIMESLOT)
		return FALSE;
	
	elapsed = [self elapsedFrom:&tv_last_tick];
	last_interval = elapsed;

	[self addSecond:TIMESLOT toTimeval:&tv_next_tick];
	gettimeofday(&tv_last_tick, NULL);
	return TRUE;
}

- (void)sendNotify:(TrafficData *)sample
{
    if (!sample)
        return;

	[_model
	 performSelectorOnMainThread:@selector(samplingNotify:)
	 withObject:sample
	 waitUntilDone:NO];
}

- (void)sendError:(NSString *)message
{
    if (message && last_error) {
        message = [message stringByAppendingString:@"\n"];
        message = [message stringByAppendingString:last_error];
    }
    else if (last_error) {
        message = last_error;
    }
	[_model
	 performSelectorOnMainThread:@selector(samplingError:)
	 withObject:message
	 waitUntilDone:NO];
}

- (void)sendFinish
{
	[_model
	 performSelectorOnMainThread:@selector(samplingFinish:)
	 withObject:self
	 waitUntilDone:NO];
}

- (BOOL)attachFilter
{
	if (filter_program == NULL) {
		NSLog(@"No filter program");
		return FALSE;
	}
    [bpfControl setFilter:[[NSString alloc] initWithUTF8String:filter_program]];

	return TRUE;
}
@end
