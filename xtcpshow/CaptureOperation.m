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
- (void) main
{
	struct pcap_stat ps;
	float max_mbps, ph_max_mbps;
	int bytes, pkts;
	
	NSLog(@"caputer thread");
	[[self model] setTarget_resolution:(TIMESLOT * 1000.0)];
	
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
	gettimeofday(&tv_last_tick, NULL);
	tv_peek_hold = tv_last_tick;
	last_tick = 0.0;
	last_peek_hold = 0.0;
	
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
		mbps = (float)(bytes * 8) / last_tick; // [bps]
		mbps = mbps / (1000.0 * 1000.0); // [mbps]
		bytes = 0;
		
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
		[[self model] setResolution:(last_tick * 1000.0)];

		// send notify
		[self sendNotify];
		last_tick -= TIMESLOT;

		// send padding
		while (last_tick > TIMESLOT) {
			[self sendNotify];
			last_tick -= TIMESLOT;
		}
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

- (BOOL)tick_expired
{
	float elapsed;
	
	elapsed = [self elapsed:&tv_last_tick];
	if (elapsed < TIMESLOT)
		return FALSE;
	
	last_tick = elapsed;
	gettimeofday(&tv_last_tick, NULL);
	return TRUE;
}

- (BOOL)peek_hold_expired
{
	float elapsed;
	
	elapsed = [self elapsed:&tv_peek_hold];
	if (elapsed < HOLDSLOT)
		return FALSE;
	
	last_peek_hold = elapsed;
	gettimeofday(&tv_peek_hold, NULL);
	return TRUE;
}

- (void)sendNotify
{
	NSObject *controller;
	
	controller = (NSObject *)[[self model] controller];
	
	[controller
	 performSelectorOnMainThread:@selector(samplingNotify)
	 withObject:self
	 waitUntilDone:NO];
}

- (void)sendError
{
	NSObject *controller;
	
	controller = (NSObject *)[[self model] controller];
	
	[controller
	 performSelectorOnMainThread:@selector(samplingError)
	 withObject:self
	 waitUntilDone:NO];
}

- (BOOL) allocPcap
{
	int r;
	
	NSLog(@"initializing libpcap...");
	pcap = pcap_create(self.source, errbuf);
	if (pcap == NULL) {
		NSLog(@"pcap_create() failed.");
		goto error;
	}
	
	if (pcap_set_snaplen(pcap, SNAPLEN) != 0) {
		NSLog(@"pcap_set_snaplen() failed.");
		goto error;
	}
	if (pcap_set_timeout(pcap, TICK) != 0) {
		NSLog(@"pcap_set_timeout() failed.");
		goto error;
	}
	
	if (pcap_set_buffer_size(pcap, SNAPLEN * NPKT) != 0) {
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
	const char *prog = [self filter];
	
	if (pcap_compile(pcap, &filter,
			 prog, 0, PCAP_NETMASK_UNKNOWN) != 0) {
		NSLog(@"pcap_compile() failed: %s",
		      pcap_geterr(pcap));
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