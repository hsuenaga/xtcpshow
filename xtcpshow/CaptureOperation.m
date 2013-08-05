//
//  CaptureOperation.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <pcap/pcap.h>

#import "CaptureOperation.h"
#import "CaptureModel.h"

/*
 * Capture thread
 */
@implementation CaptureOperation
- (CaptureOperation *)init
{
	self = [super init];
	source_interface = NULL;
	filter_program = NULL;

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
}

- (void) main
{
	struct pcap_stat ps;
	float max_mbps, ph_max_mbps;
	int bytes, pkts;

	NSLog(@"caputer thread");
	[[self model] setSamplingInterval:TIMESLOT];

	// initialize libpcap
	if (![self allocPcap]) {
		NSLog(@"cannot initialize libpcap");
		[self sendError];
		return;
	}
	if (![self attachFilter]) {
		NSLog(@"libpcap filter error");
		[self sendError];
		return;
	}

	// reset timer
	gettimeofday(&tv_next_tick, NULL);
	tv_peek_hold = tv_next_tick;

	// reset counter
	max_mbps = ph_max_mbps = 0.0;
	bytes = pkts = 0;

	terminate = FALSE;
	while (!terminate) {
		struct pcap_pkthdr *hdr;
		const u_char *data;
		float mbps;
		int code;

		if ([self isCancelled] == YES)
			break;

		if ([self model] == nil)
			break;

		code = pcap_next_ex(pcap, &hdr, &data);
		switch (code) {
			case 1:
				// got packet
				bytes += hdr->len;
				pkts += 1;
				break;
			case 0:
				// timeout
				break;
			default:
				NSLog(@"pcap error: %s",
				      pcap_geterr(pcap));
				terminate = TRUE;
				break;
		}

		// timer update
		if ([self tick_expired] == FALSE)
			continue;

		// update and reset snapshot
		mbps = (float)(bytes * 8) / last_interval; // [bps]
		mbps = mbps / (1000.0 * 1000.0); // [mbps]

		// update max
		if (mbps > max_mbps)
			max_mbps = mbps;
		if (mbps > ph_max_mbps)
			ph_max_mbps = mbps;

		// reset peek_hold data
		if ([self peek_hold_expired])
			ph_max_mbps = 0.0;

		// update model
		[[self model] setTotal_pkts:pkts];
		[[self model] setMbps:mbps];
		[[self model] setPeek_hold_mbps:ph_max_mbps];
		[[self model] setMax_mbps:max_mbps];
		[[self model] setSnapSamplingInterval:last_interval];
		[self sendNotify:bytes];
		bytes = 0;
	}
	// finalize
	if (pcap_stats(pcap, &ps) == 0) {
		NSLog(@"%d packets recieved by pcap", ps.ps_recv);
		NSLog(@"%d packets dropped by pcap", ps.ps_drop);
		NSLog(@"%d packets dropped by device", ps.ps_ifdrop);
	}
	pcap_close(pcap);
	NSLog(@"%d packets proccessed.", pkts);
	NSLog(@"done thread");
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

- (float)elapsed:(struct timeval *)last
{
	struct timeval now, delta;
	float elapsed;

	gettimeofday(&now, NULL);
	timersub(&now, last, &delta);
	elapsed = (float)delta.tv_sec;
	elapsed += (float)delta.tv_usec / (1000.0 * 1000.0);

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

	usecond = second - (floor(second));
	usecond = usecond * (1000.0 * 1000.0);
	delta.tv_sec = floor(second);
	delta.tv_usec = floor(usecond);

	if (add)
		timeradd(tv, &delta, tv);
	else
		timersub(tv, &delta, tv);
}

- (BOOL)tick_expired
{
	float elapsed;

	elapsed = [self elapsed:&tv_next_tick];
	if (elapsed < TIMESLOT)
		return FALSE;

	last_interval = elapsed;
	[self addSecond:TIMESLOT toTimeval:&tv_next_tick];
	return TRUE;
}

- (BOOL)peek_hold_expired
{
	float elapsed;

	elapsed = [self elapsed:&tv_peek_hold];
	if (elapsed < HOLDSLOT)
		return FALSE;

	gettimeofday(&tv_peek_hold, NULL);
	return TRUE;
}

- (void)sendNotify:(float)mbps
{
	[[self model]
	 performSelectorOnMainThread:@selector(samplingNotify:)
	 withObject:[NSNumber numberWithFloat:mbps]
	 waitUntilDone:NO];
}

- (void)sendError
{
	NSObject *model;

	model = (NSObject *)[self model];

	[model
	 performSelectorOnMainThread:@selector(samplingError)
	 withObject:self
	 waitUntilDone:NO];
}

- (BOOL) allocPcap
{
	int r;

	if (source_interface == NULL) {
		NSLog(@"No source interface");
		return FALSE;
	}

	NSLog(@"initializing libpcap...");
	pcap = pcap_create(source_interface, errbuf);
	if (pcap == NULL) {
		NSLog(@"pcap_create() failed.");
		goto error;
	}

	if (pcap_set_snaplen(pcap, CAP_SNAPLEN) != 0) {
		NSLog(@"pcap_set_snaplen() failed.");
		goto error;
	}
	if (pcap_set_timeout(pcap, CAP_TICK) != 0) {
		NSLog(@"pcap_set_timeout() failed.");
		goto error;
	}

	if (pcap_set_buffer_size(pcap, CAP_BUFSIZ) != 0) {
		NSLog(@"pcap_set_buffer_size() failed.");
		goto error;
	}

	r = pcap_activate(pcap);
	if (r == PCAP_WARNING) {
		NSLog(@"pcap_activate() has warning.");
		NSLog(@"WARNING: %s", pcap_geterr(pcap));
	}
	else if (r != 0) {
		NSLog(@"pcap_activate() failed.");
		goto error;
	}
	NSLog(@"libpcap initialized.");

	return TRUE;

error:
	if (pcap) {
		NSLog(@"ERROR: %s", pcap_geterr(pcap));
		pcap_close(pcap);
	}
	return FALSE;
}

- (BOOL)attachFilter
{
	struct bpf_program filter;

	if (filter_program == NULL) {
		NSLog(@"No filter program");
		return FALSE;
	}
	if (pcap_compile(pcap, &filter, filter_program,
			 0, PCAP_NETMASK_UNKNOWN) != 0) {
		NSLog(@"pcap_compile() failed: %s",
		      pcap_geterr(pcap));
		NSLog(@"program: %s", filter_program);
		return FALSE;
	}

	if (pcap_setfilter(pcap, &filter) < 0) {
		NSLog(@"pcap_setfilter() failed: %s",
		      pcap_geterr(pcap));
		pcap_freecode(&filter);
		return FALSE;
	}

	if (pcap_setdirection(pcap, PCAP_D_IN) != 0) {
		NSLog(@"pcap_setdirection() is not supported.");
	}

	pcap_freecode(&filter);
	return TRUE;
}
@end