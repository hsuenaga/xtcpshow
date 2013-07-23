//
//  Track.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <pcap/pcap.h>

#define SNAPLEN 128
#define NPKT 1000
#define TICK 10 /* [ms] */
#define TIMESLOT 50 /* [ms] */
#define DEF_DEVICE "en0"

#import "Capture.h"

static int alloc_pcap(id, const char *);
static int set_filter(id, const char *);
static int dispatch(pcap_t *, id);
static void callback(u_char *, const struct pcap_pkthdr *, const u_char *);
static uint32_t tv2msec(struct timeval *);

/*
 * C utility
 */
static uint32_t tv2msec(struct timeval *tv)
{
	uint32_t ms;
	
	ms = (uint32_t)tv->tv_sec * 1000;
	ms += (uint32_t)tv->tv_usec / 1000;
	
	return ms;
}

/*
 * Capture thread
 */
@implementation CaptureOperation
- (void) main
{
	NSLog(@"caputer thread");
	for (;;) {
		dispatch([[self model] pcap], self);
		if ([self isCancelled] == YES)
			break;
	}
	NSLog(@"done thread");
}
@end

static int dispatch(pcap_t *pcap, id obj) {
	CaptureOperation *op = (CaptureOperation *)obj;
	u_char *user;
	int n;
	
	
	if (pcap == NULL) {
		NSLog(@"pcap not initialized.");
		return -1;
	}
	if (obj == nil) {
		NSLog(@"nil object passed.");
		return -1;
	}
	
	user = (u_char *)((__bridge_retained void*)op);
	op = nil;
	n = pcap_dispatch(pcap, -1, callback, user);
	if (n == 0)
		callback(user, NULL, NULL);
	op = (__bridge_transfer CaptureOperation *)((void *)user);

	return 0;
}

static void callback(u_char *user,
		     const struct pcap_pkthdr *hdr, const u_char *bytes)
{
	CaptureOperation *op;
	TCPShowModel *model;
	struct timeval now, delta;
	float delta_ms, mbps, bps;

	if (user == NULL)
		return;
	op = (__bridge CaptureOperation *)((void *)user);
	if (op == nil)
		return;
	model = [op model];
	if (model == nil)
		return;
	
	gettimeofday(&now, NULL);
	timersub(&now, model.last, &delta);
	delta_ms = (float)tv2msec(&delta);
	
	if (delta_ms < TIMESLOT) {
		if (bytes) {
			model.bytes += hdr->len;
			model.pkts++;
		}
		return;
	}
	NSLog(@"Resolusion %f [ms], %d [pkts]", delta_ms, model.pkts);
	
	/* timeslot expired */
	bps = ((float)model.bytes * 8.0 * 1000.0) / delta_ms;
	mbps = bps / (1000.0 * 1000.0);
//	NSLog(@"%8.3f [mbps]\n", mbps);
	
	model.mbps = mbps;
	*model.last = now;
	model.bytes = 0;
	model.pkts = 0;
	[[model controller] updateUserInterface];
}

/*
 * Model object
 */
@implementation TCPShowModel
- (TCPShowModel *) init
{
	/* thread */
	self->capture_cue = [[NSOperationQueue alloc] init];
	
	/* pcap binding */
	self.pcap = NULL;
	self.errbuf = self->errbuf_store;
	NSLog(@"initialize pcap");
	if (alloc_pcap(self, DEF_DEVICE) < 0) {
		NSLog(@"Cannot initialize pcap");
		return nil;
	}
	if (set_filter(self, "tcp") < 0) {
		NSLog(@"Cannot initialize filter");
		return nil;
	}
	
	/* raw traffic */
	memset(&self->timestamp_store, 0, sizeof(self->timestamp_store));
	self.last = &self->timestamp_store;
	self.bytes = 0;
	self.pkts = 0;
	
	/* cooked data */
	self.mbps = 0.0;
	
	return self;
}

- (void) startCapture
{
	CaptureOperation *op = [[CaptureOperation alloc] init];
	
	NSLog(@"Start capture thread");
	op.model = self;
	[self->capture_cue addOperation:op];
}

- (void) stopCapture
{
	NSLog(@"Stop capture thread");
	[self->capture_cue cancelAllOperations];
}


- (void) dealloc
{
	if (self.pcap) {
		pcap_close(self.pcap);
		self.pcap = NULL;
	}

}
@end

static int alloc_pcap(id obj, const char *source) {
	TCPShowModel *model = (TCPShowModel *)obj;
	pcap_t *pcap = NULL;
	int r;
	
	pcap = pcap_create(source, model.errbuf);
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
	model.pcap = pcap;
	NSLog(@"libpcap initialized.");
	
	return 0;
	
error:
	if (pcap) {
		NSLog(@"ERROR: %s", pcap_geterr(pcap));
		pcap_close(pcap);
	}
	return -1;
}

static int set_filter(id obj, const char *prog)
{
	TCPShowModel *model = (TCPShowModel *)obj;
	struct bpf_program filter;
	
	if (pcap_compile(model.pcap, &filter,
	    prog, 0, PCAP_NETMASK_UNKNOWN) != 0) {
		NSLog(@"pcap_compile() failed: %s",
		    pcap_geterr(model.pcap));
		return -1;
	}
	
	if (pcap_setfilter(model.pcap, &filter) < 0) {
		NSLog(@"pcap_setfilter() failed: %s",
		    pcap_geterr(model.pcap));
		pcap_freecode(&filter);
		return -1;
	}

	pcap_freecode(&filter);
	return 0;
}