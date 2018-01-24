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
#import "CaptureOperation.h"

/*
 * Capture thread
 */
@interface CaptureOperation ()
- (void)dealloc;
- (BOOL)attachFilter;
- (double)elapsedFrom:(struct timeval *)last;
- (BOOL)tick_expired;
- (void)sendError:(NSString *)message;
- (void)sendFinish;
@end

@implementation CaptureOperation {
    NSString *last_error;
    
    char *source_interface;
    char *filter_program;
    
    struct timeval tv_start;
    struct timeval tv_next_tick;
    struct timeval tv_last_tick;
    double last_interval; // [sec]
    double total_elapsed; // [sec]
    BOOL terminate;
    
    // counter
    uint64_t totalBytes;
    uint64_t totalPkts;
    int bytes;
    double max_mbps;
}
@synthesize model;
@synthesize bpfControl;
@synthesize dataBase;

- (CaptureOperation *)init
{
	self = [super init];

	source_interface = NULL;
	filter_program = NULL;
	bpfControl = NULL;
    self.dataBase = nil;

	return self;
}

- (void)dealloc
{
    if (source_interface) {
		free(source_interface);
        source_interface = NULL;
    }
    if (filter_program) {
		free(filter_program);
        filter_program = NULL;
    }
}

- (void) main
{
    if (dataBase == nil) {
        NSLog(@"no packet data base");
        return;
    }

	NSLog(@"caputer thread: interval %f [sec]", TIMESLOT);
    model.samplingInterval = TIMESLOT;
    
	// initialize bpf
	if (!bpfControl) {
		NSLog(@"cannot initialize bpfControl module.");
		[self sendError:@"bpfControl is not found."];
		return;
	}

	// reset timer
    gettimeofday(&tv_start, NULL);
    tv_next_tick = tv_last_tick = tv_start;
    
    // set timeout
    struct timeval tick = {
        .tv_sec = 0,
        .tv_usec = BPF_TIMEOUT * 1000, // [msec]
    };
    if (![bpfControl timeout:&tick]) {
        NSLog(@"Cannot set timeout to BPF.");
        [self sendError:@"Cannot set timeout"];
        return;
    }
    
    // set filter
    if (![self attachFilter]) {
        NSLog(@"libpcap filter error");
        [self sendError:@"Syntax erorr in filter statement"];
        return;
    }
    
    // Promiscus mode
    if (![bpfControl promiscus:[model promisc]]) {
        NSLog(@"Cannot initizlize BPF.");
        [self sendError:@"Cannot enable promiscus mode"];
        return;
    }
    
    // Enable caputuring
    if (![bpfControl start:source_interface]) {
        NSLog(@"Cannot Initiaize BPF.");
        [self sendError:@"Cannot attach interface"];
        return;
    }
    
    // receive packets.
    max_mbps = 0.0;
    totalBytes = bytes = totalPkts = 0;
    terminate = FALSE;
    while (!terminate) {
		@autoreleasepool {
			if ([self isCancelled] == YES || self.model == nil)
				break;
            
            struct timeval tv;
            uint32_t pktlen;
            if (![bpfControl next:&tv withCaplen:NULL withPktlen:&pktlen]) {
                NSLog(@"bpfControl error.");
                [self sendError:@"Failed to read from BPF"];
                terminate = true;
            }
            else if (tv.tv_sec || tv.tv_usec) {
                TrafficData *sample;
                totalPkts++;
                totalBytes += pktlen;
                bytes += pktlen;
                sample = [dataBase addSampleAtTimevalExtend:&tv withBytes:pktlen auxData:nil];
			}
            else {
                // BPF timeout.
                // there is no samples received. this means
                // we confirmed there is no traffic until now.
                [dataBase updateLastDate:[NSDate date]];
            }

			// timer update for measure
			if ([self tick_expired] == FALSE)
				continue;
            
			// update max
			double bps = (double)(bytes * 8) / last_interval; // [bps]
			double mbps = bps * 1.0E-6; // [mbps]
			if (max_mbps < mbps)
				max_mbps = mbps;

            // update average
            double avgbps = (double)(totalBytes * 8) / total_elapsed;
            double avgmbps = avgbps * 1.0E-6;
            
			// update model
            model.totalPkts = totalPkts;
            model.average_mbps = avgmbps;
            model.mbps = mbps;
            model.max_mbps = max_mbps;
            model.samplingIntervalLast = last_interval;
			bytes = 0;
		}
	}

	// finalize
    [bpfControl stop];
	NSLog(@"%d packets recieved by pcap", [bpfControl bs_recv]);
	NSLog(@"%d packets dropped by pcap", [bpfControl bs_drop]);
	NSLog(@"%d packets dropped by device", [bpfControl bs_ifdrop]);
	NSLog(@"%llu packets proccessed.", totalPkts);
	NSLog(@"done thread");
	[self sendFinish];
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

- (BOOL)attachFilter
{
    if (filter_program == NULL) {
        NSLog(@"No filter program");
        return FALSE;
    }
    [bpfControl setFilter:[[NSString alloc] initWithUTF8String:filter_program]];
    
    return TRUE;
}

- (double)elapsedFrom:(struct timeval *)last
{
	struct timeval now, delta;
	float elapsed;

	gettimeofday(&now, NULL);
	timersub(&now, last, &delta);
	elapsed = (double)delta.tv_sec;
    elapsed += (double)delta.tv_usec * 1.0E-6;

	return elapsed;
}

- (void)addSecond:(double)second toTimeval:(struct timeval *)tv
{
	struct timeval delta;
	double usecond;
	int add = TRUE;

	if (isnan(second) || isinf(second))
		return;

	if (second < 0.0) {
		add = FALSE;
		second = fabs(second);
	}

	delta.tv_sec = floor(second);
	usecond = (second - (double)delta.tv_sec) * 1.0E6;
	delta.tv_usec = floor(usecond);

	if (add)
		timeradd(tv, &delta, tv);
	else
		timersub(tv, &delta, tv);
}

- (BOOL)tick_expired
{
	if ([self elapsedFrom:&tv_next_tick] < TIMESLOT)
		return FALSE;
    
	last_interval = [self elapsedFrom:&tv_last_tick];
    total_elapsed = [self elapsedFrom:&tv_start];
	[self addSecond:TIMESLOT toTimeval:&tv_next_tick];

    gettimeofday(&tv_last_tick, NULL);
	return TRUE;
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
	[model
	 performSelectorOnMainThread:@selector(recvError:)
	 withObject:message
	 waitUntilDone:NO];
}

- (void)sendFinish
{
	[model
	 performSelectorOnMainThread:@selector(recvFinish:)
	 withObject:self
	 waitUntilDone:NO];
}

@end
