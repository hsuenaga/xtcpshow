//
//  Capture.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <pcap/pcap.h>

#import "Capture.h"

static int alloc_pcap(id, const char *);
static int set_filter(id, const char *);
static int dispatch(pcap_t *, id);
static void callback(u_char *, const struct pcap_pkthdr *, const u_char *);
static float tv2float(struct timeval *);

/*
 * C utility
 */
static float tv2float(struct timeval *tv)
{
	float sec;
	
	sec = (float)tv->tv_sec * 1000.0;
	sec += (float)tv->tv_usec / (1000.0 * 1000.0);
	
	return sec;
}

/*
 * Capture thread
 */
@implementation CaptureOperation
- (void) main
{
	struct timeval now;
	pcap_t *p;
	
	gettimeofday(&now, NULL);
	NSLog(@"caputer thread");
	p = [[self model] pcap];
	[[self model] setPcap:NULL];
	*self.model.last = now;
	while (p) {
		dispatch(p, self);
		if ([self isCancelled] == YES)
			break;
	}
	pcap_close(p);
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
	float fDelta, mbps, bps;

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
	fDelta = tv2float(&delta);
	
	if (hdr && fDelta < TIMESLOT) {
		if (bytes) {
			model.bytes += hdr->len;
			model.pkts++;
		}
		return;
	}

	/* timeslot expired */
	*model.last = now;
	bps = ((float)model.bytes * 8.0) / fDelta;
	mbps = bps / (1000.0 * 1000.0);
	model.mbps = mbps;
	model.resolution = fDelta;
	
	/* max data */
	if (mbps > model.max_mbps) {
		model.max_mbps = mbps;
	}
	
	/* aging data */
	model.aged_db = (model.aged_db * 0.9) + (mbps * 0.1);
	timersub(&now, model.age_last, &delta);
	fDelta = tv2float(&delta);
	if (fDelta > AGESLOT) {
		model.aged_mbps = model.aged_db;
		*model.age_last = now;
	}

	/* clear counter */
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
	self.pcap = NULL;
	
	/* raw traffic */
	memset(&self->timestamp_store, 0, sizeof(self->timestamp_store));
	self.last = &self->timestamp_store;
	self.age_last = &self->agerate_store;
	self.bytes = 0;
	self.pkts = 0;
	
	/* cooked data */
	self.mbps = 0.0;
	self.max_mbps = 0.0;
	self.aged_mbps = 0.0;

	return self;
}

- (void) startCapture
{
	CaptureOperation *op = [[CaptureOperation alloc] init];
	
	NSLog(@"initialize pcap");
	if (self.pcap) {
		pcap_close(self.pcap);
		self.pcap = NULL;
	}
	if (alloc_pcap(self, DEF_DEVICE) < 0) {
		NSLog(@"Cannot initialize pcap");
		return;
	}
	if (set_filter(self, DEF_FILTER) < 0) {
		NSLog(@"Cannot initialize filter");
		return;
	}
	
	NSLog(@"Start capture thread");
	op.model = self;
	op.model.mbps = 0.0;
	op.model.max_mbps = 0.0;
	op.model.aged_mbps = 0.0;
	op.model.bytes = 0;
	op.model.pkts = 0;
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