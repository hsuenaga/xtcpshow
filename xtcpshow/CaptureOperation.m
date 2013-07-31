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

static int dispatch(pcap_t *, id);
static void callback(u_char *, const struct pcap_pkthdr *, const u_char *);
static float tv2floatSec(struct timeval *);

/*
 * Capture thread
 */
@implementation CaptureOperation
- (void) main
{
	struct timeval now;
	struct pcap_stat ps;
	pcap_t *p;
	
	gettimeofday(&now, NULL);
	NSLog(@"caputer thread");
	p = [[self model] pcap];
	[[self model] setPcap:NULL];
	[[self model] setTarget_resolution:(TIMESLOT * 1000.0)]; // [ms]
	*self.model.last = now;
	*self.model.age_last = now;
	while (p) {
		dispatch(p, self);
		if ([self isCancelled] == YES)
			break;
		if ([self model] == nil)
			break;
	}
	if (pcap_stats(p, &ps) == 0) {
		NSLog(@"%d packets recieved by pcap", ps.ps_recv);
		NSLog(@"%d packets dropped by pcap", ps.ps_drop);
		NSLog(@"%d packets dropped by device", ps.ps_ifdrop);
		self.model.drop_pkts += ps.ps_drop;
		self.model.drop_pkts += ps.ps_ifdrop;
	}
	pcap_close(p);
	NSLog(@"%d packets proccessed.", self.model.total_pkts);
	NSLog(@"done thread");
}
@end

/*
 * C API bridge
 */
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
	n = pcap_dispatch(pcap, 1, callback, user);
	if (n == 0)
		callback(user, NULL, NULL);
	op = (__bridge_transfer CaptureOperation *)((void *)user);

	return 0;
}

static void callback(u_char *user,
		     const struct pcap_pkthdr *hdr, const u_char *bytes)
{
	CaptureOperation *op;
	CaptureModel *model;
	struct timeval now, delta;
	float fDelta, fDeltaAge, mbps, bps;

	if (user == NULL) {
		NSLog(@"empty context");
		return;
	}
	op = (__bridge CaptureOperation *)((void *)user);
	if (op == nil) {
		NSLog(@"empty operation");
		return;
	}
	model = [op model];
	if (model == nil) {
		NSLog(@"No model attached");
		return;
	}
	
	gettimeofday(&now, NULL);
	timersub(&now, model.last, &delta);
	fDelta = tv2floatSec(&delta);
	if (hdr && bytes) {
		model.bytes += hdr->len;
		model.pkts++;
		model.total_pkts++;
	}
	if (fDelta < TIMESLOT)
		return;

	/* timeslot expired */
	*model.last = now;
	bps = ((float)model.bytes * 8.0) / fDelta;
	mbps = bps / (1000.0 * 1000.0);
	model.mbps = mbps;
	model.resolution = fDelta * 1000.0; // [ms]
	
	/* max data */
	if (mbps > model.max_mbps) {
		model.max_mbps = mbps;
	}
	
	/* aging data */
	model.aged_db = (model.aged_db * 0.5) + (mbps * 0.5);
	timersub(&now, model.age_last, &delta);
	fDeltaAge = tv2floatSec(&delta);
	if (fDeltaAge > AGESLOT) {
		model.aged_mbps = model.aged_db;
		*model.age_last = now;
	}
	
	/* clear counter */
	model.bytes = 0;
	model.pkts = 0;
	
	/* notify to controller */
	while (fDelta > TIMESLOT) {
		[[model controller] samplingNotify];
		fDelta -= TIMESLOT;
		/* send padding */
		model.mbps = 0.0;
	}
}

static float tv2floatSec(struct timeval *tv)
{
	float sec;
	
	sec = (float)tv->tv_sec;
	sec += (float)tv->tv_usec / (1000.0 * 1000.0); // [sec]
	
	return sec;
}