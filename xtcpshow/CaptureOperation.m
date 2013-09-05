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

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>

#include <pcap/pcap.h>

#import "CaptureOperation.h"
#import "CaptureModel.h"
#import "DataQueue.h"
#import "DataQueueEntry.h"
#import "SamplingData.h"
#import "FlowData.h"

/*
 * Capture thread
 */
@implementation CaptureOperation
- (CaptureOperation *)init
{
	self = [super init];

	bpfControl = [[BPFControl alloc] init];
	bpfInsecure = NO;
	source_interface = NULL;
	filter_program = NULL;
	pcap = NULL;

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
	if (bpfInsecure && bpfControl) {
		[bpfControl secure];
		bpfInsecure = NO;
	}
	bpfControl = nil;
}

- (void) main
{
	struct pcap_stat ps;

	NSLog(@"caputer thread: interval %f [sec]", TIMESLOT);
	[_model setSamplingInterval:TIMESLOT];

	// initialize libpcap
	if (![self allocPcap]) {
		NSLog(@"cannot initialize lipcap. try bpfControl.");
		bpfInsecure = [bpfControl insecure];
		[self allocPcap];
	}
	if (pcap == NULL) {
		NSString *message;
		NSLog(@"cannot initialize libpcap");
		
		message =
		[NSString stringWithFormat:@"Caputer Error:%@",
		 last_error];
		[self sendError:@"Cannot Initialize libpcap"];
		return;
	}

	// set filter
	if (![self attachFilter]) {
		NSLog(@"libpcap filter error");
		[self sendError:@"Syntax erorr in filter statement"];
		return;
	}
	
	// reset BPF permission
	if (bpfInsecure && bpfControl) {
		[bpfControl secure];
		bpfInsecure = NO;
	}
	bpfControl = nil;

	// reset timer
	gettimeofday(&tv_next_tick, NULL);
	gettimeofday(&tv_last_tick, NULL);

	// init peak hold buffer for 1[sec]
	max_buffer = [[DataQueue alloc] init];
	[max_buffer zeroFill:(int)(ceil(1.0f/TIMESLOT))];

	// reset counter
	max_mbps = peak_mbps = 0.0;
	bytes = pkts = 0;

	terminate = FALSE;
	while (!terminate) {
		struct pcap_pkthdr *hdr;
		const u_char *data;
		int classID;
		float mbps;
		int code;

		if ([self isCancelled] == YES)
			break;

		if (_model == nil)
			break;

		code = pcap_next_ex(pcap, &hdr, &data);
		switch (code) {
			case 1:
				// got packet
				pkts++;
				bytes += hdr->len;
				classID = [_Flow clasifyPacket:data size:hdr->caplen linkType:pcap_datalink(pcap)];
				[self sendNotify:hdr->len
					withTime:&hdr->ts
				       withClass:classID];
				break;
			case 0:
				// timeout
				[self sendNotify:0 withTime:NULL withClass:0];
				break;

			if (_model == nil)
				break;

			code = pcap_next_ex(pcap, &hdr, &data);
			switch (code) {
				case 1:
					// got packet
					pkts++;
					bytes += hdr->len;
					[self sendNotify:hdr->len
						withTime:&hdr->ts];
					break;
				case 0:
					// timeout
					[self sendNotify:0 withTime:NULL];
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

			// update max
			mbps = (float)(bytes * 8) / last_interval; // [bps]
			mbps = mbps / (1000.0f * 1000.0f); // [mbps]
			if (max_mbps < mbps)
				max_mbps = mbps;
			[max_buffer shiftDataWithNewData:[SamplingData dataWithSingleFloat:mbps]];
			peak_mbps = [max_buffer maxFloatValue];

			// update model
			[_model setTotal_pkts:pkts];
			[_model setMbps:mbps];
			[_model setPeek_hold_mbps:peak_mbps];
			[_model setMax_mbps:max_mbps];
			[_model setSamplingIntervalLast:last_interval];
			bytes = 0;
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

- (float)elapsed:(struct timeval *)last
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

	expired = [self elapsed:&tv_next_tick];
	if (expired < TIMESLOT)
		return FALSE;
	
	elapsed = [self elapsed:&tv_last_tick];
	last_interval = elapsed;

	[self addSecond:TIMESLOT toTimeval:&tv_next_tick];
	gettimeofday(&tv_last_tick, NULL);
	return TRUE;
}

- (void)sendNotify:(int)size withTime:(struct timeval *)tv withClass:(int)classID
{
	SamplingData *sample;
	NSTimeInterval unix_time;
	NSDate *date;

	if (tv) {
		unix_time = tv->tv_sec;
		unix_time += ((double)tv->tv_usec / 1000000.0);
		date = [NSDate dateWithTimeIntervalSince1970:unix_time];
		sample = [SamplingData dataWithInt:size atDate:date fromSamples:1];
	}
	else {
		// psuedo clock frame
		sample = [SamplingData dataWithoutSample];
	}

	[_model
	 performSelectorOnMainThread:@selector(samplingNotify:)
	 withObject:sample
	 waitUntilDone:NO];
}

- (void)sendError:(NSString *)message
{
	[_model
	 performSelectorOnMainThread:@selector(samplingError:)
	 withObject:last_error
	 waitUntilDone:NO];
}

- (void)sendFinish
{
	[_model
	 performSelectorOnMainThread:@selector(samplingFinish:)
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
		last_error = @"pcap_create() failed";
		goto error;
	}

	if (pcap_set_snaplen(pcap, CAP_SNAPLEN) != 0) {
		last_error = @"pcap_set_snaplen() failed";
		goto error;
	}
	if (pcap_set_timeout(pcap, CAP_TICK) != 0) {
		last_error = @"pcap_set_timeout() failed";
		goto error;
	}

	if (pcap_set_buffer_size(pcap, CAP_BUFSIZ) != 0) {
		last_error = @"pcap_set_buffer_size() failed";
		goto error;
	}

	if (_model.promisc == YES) {
		NSLog(@"Enable promiscuous mode");
		pcap_set_promisc(pcap, 1);
	}
	else {
		NSLog(@"Disable promiscuous mode");
		pcap_set_promisc(pcap, 0);
	}

	r = pcap_activate(pcap);
	if (r == PCAP_WARNING) {
		NSLog(@"WARNING: %s", pcap_geterr(pcap));
	}
	else if (r != 0) {
		last_error = @"pcap_activate() failed";
		goto error;
	}
	NSLog(@"libpcap initialized.");

	return TRUE;

error:
	if (pcap) {
		NSLog(@"%@: %s", last_error, pcap_geterr(pcap));
		last_error =
		[NSString stringWithFormat:@"Device error: %s", pcap_geterr(pcap)];
		pcap_close(pcap);
		pcap = NULL;
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
		last_error = [NSString  stringWithFormat:@"Filter error: %s",
		      pcap_geterr(pcap)];
		NSLog(@"pcap_compile() failed");
		NSLog(@"program: %s", filter_program);
		return FALSE;
	}

	if (pcap_setfilter(pcap, &filter) < 0) {
		last_error = [NSString stringWithFormat:@"Filter error: %s",
		      pcap_geterr(pcap)];
		NSLog(@"pcap_setfilter() failed");
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