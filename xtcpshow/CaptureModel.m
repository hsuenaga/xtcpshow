//
//  CaptureModel.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <pcap/pcap.h>

#import "CaptureModel.h"
#import "CaptureOperation.h"

static int alloc_pcap(id, const char *);
static int set_filter(id, const char *);

/*
 * Model object
 */
@implementation CaptureModel
- (CaptureModel *) init
{
	/* thread */
	self->capture_cue = [[NSOperationQueue alloc] init];
	self->running = FALSE;
	
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
	self.total_pkts = 0;
	self.drop_pkts = 0;
	
	/* cooked data */
	self.mbps = 0.0;
	self.max_mbps = 0.0;
	self.aged_mbps = 0.0;
	
	return self;
}

- (int) startCapture
{
	CaptureOperation *op = [[CaptureOperation alloc] init];
	
	NSLog(@"initialize pcap");
	if (self.pcap) {
		pcap_close(self.pcap);
		self.pcap = NULL;
	}
	if (alloc_pcap(self, self.device) < 0) {
		NSLog(@"Cannot initialize pcap");
		return -1;
	}
	if (set_filter(self, self.filter) < 0) {
		NSLog(@"Cannot initialize filter");
		pcap_close(self.pcap);
		self.pcap = NULL;
		return -1;
	}
	
	NSLog(@"Start capture thread");
	op.model = self;
	op.model.mbps = 0.0;
	op.model.max_mbps = 0.0;
	op.model.aged_mbps = 0.0;
	op.model.bytes = 0;
	op.model.pkts = 0;
	[op setQueuePriority:NSOperationQueuePriorityHigh];
	[self->capture_cue addOperation:op];
	self->running = TRUE;
	
	return 0;
}

- (void) stopCapture
{
	NSLog(@"Stop capture thread");
	[self->capture_cue cancelAllOperations];
	self->running = FALSE;
}

- (BOOL) captureEnabled
{
	return self->running;
}

- (void) resetCounter
{
	self.total_pkts = 0;
	self.drop_pkts = 0;
	self.bytes = 0;
	self.pkts = 0;
	self.mbps = 0.0;
	self.max_mbps = 0.0;
	self.aged_db = 0.0;
	self.aged_mbps = 0.0;
	self.resolution = 0.0;
	self.target_resolution = 0.0;
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
	CaptureModel *model = (CaptureModel *)obj;
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
	CaptureModel *model = (CaptureModel *)obj;
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
	
	if (pcap_setdirection(model.pcap, PCAP_D_IN) != 0) {
		NSLog(@"pcap_setdirection() is not supported.");
	}


	pcap_freecode(&filter);
	return 0;
}