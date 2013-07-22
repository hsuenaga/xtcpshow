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

#import "Track.h"

static pcap_t *init_pcap(const char *);
static int dispatcher(pcap_t *pcap, id obj);
static void pc_handler(u_char *user, const struct pcap_pkthdr *, const u_char *);
static uint32_t tv2msec(struct timeval *);

/*
 * Objective-C
 */
@implementation Track
- (void) startCapture {
	pcap_t *new_pcap;
	
	[self setMbps:99.9];
	
	NSLog(@"initialize pcap");
	new_pcap = init_pcap(DEF_DEVICE);
	if (new_pcap == NULL) {
		NSLog(@"Cannot initialize pcap");
		return;
	}
	self->pcap = new_pcap;
	NSLog(@"disaptch packet");
//	dispatcher(new_pcap, (id)self);
	NSLog(@"done dispatch");
	[self updateNotify];
}

- (void) updateNotify {
	[[self controller] updateUserInterface];
}
@end

/*
 * libpcap bridge
 */
static pcap_t *init_pcap(const char *source) {
	struct bpf_program filter;
	char errbuf[PCAP_ERRBUF_SIZE];
	pcap_t *pcap = NULL;
	int r;
	
	memset(errbuf, 0, sizeof(errbuf));
	memset(&filter, 0, sizeof(filter));
	
	pcap = pcap_create(source, errbuf);
	if (pcap == NULL) {
		fprintf(stderr, "pcap_create() failed.\n");
		goto error;
	}
	
	if (pcap_set_snaplen(pcap, SNAPLEN) != 0) {
		fprintf(stderr, "pcap_set_snaplen() failed.\n");
		goto error;
	}
	
	if (pcap_set_timeout(pcap, TICK) != 0) {
		fprintf(stderr, "pcap_set_timeout() failed.\n");
		goto error;
	}
	
	if (pcap_set_buffer_size(pcap, SNAPLEN * NPKT) != 0) {
		fprintf(stderr, "pcap_set_buffer_size() failed.\n");
		goto error;
	}
	
	r = pcap_activate(pcap);
	if (r == PCAP_WARNING) {
		fprintf(stderr, "pcap_activate() has warning.\n");
		pcap_perror(pcap, "warning");
	}
	else if (r != 0) {
		fprintf(stderr, "pcap_activate() failed.\n");
		goto error;
	}
	
	if (pcap_compile(pcap,
			 &filter, "ip", 0, PCAP_NETMASK_UNKNOWN) != 0) {
		fprintf(stderr, "pcap_compile() failed.\n");
		goto error;
	}
	
	if (pcap_setfilter(pcap, &filter) < 0) {
		fprintf(stderr, "pcap_setfilter() failed.\n");
		pcap_freecode(&filter);
		goto error;
	}
	return pcap;
	
error:
	if (pcap) {
		pcap_perror(pcap, "init_pcap");
		pcap_close(pcap);
	}
	return NULL;
}

static int dispatcher(pcap_t *pcap, id obj) {
	int n;
	u_char *user;
	
	user = (u_char *)((__bridge void*)obj);
	NSLog(@"dispatcher called: pcap=%p, user=%p, handler=%p", pcap, user, pc_handler);

	for (;;) {
		n = pcap_dispatch(pcap, -1, pc_handler, user);
		if (n == 0)
			pc_handler(user, NULL, NULL);
	}
	
	return 0;
}

static uint32_t tv2msec(struct timeval *tv)
{
	uint32_t ms;
	
	ms = (uint32_t)tv->tv_sec * 1000;
	ms += (uint32_t)tv->tv_usec / 1000;
	
	return ms;
}

static void pc_handler(u_char *user, const struct pcap_pkthdr *hdr, const u_char *bytes)
{
	Track *obj;
	struct timeval last, now, delta;
	uint32_t delta_ms;
	float mbps, kbps, bps;
	
	obj = (__bridge Track *)((void *)user);
	gettimeofday(&now, NULL);
	last = obj.last;
	timersub(&now, &last, &delta);
	delta_ms = tv2msec(&delta);
	if (delta_ms < TIMESLOT) {
		if (bytes) {
			obj.bytes += hdr->len;
			obj.pkts++;
		}
		return;
	}
	
	/* timeslot expired */
	bps = (float)(obj.bytes * 8 * 1000) / (float)delta_ms;
	kbps = bps / 1000.0;
	mbps = kbps / 1000.0;
	
	NSLog(@"%8.3f [mbps]\n", mbps);
	
	obj.mbps = mbps;
	obj.last = now;
	obj.bytes = 0;
	obj.pkts = 0;
	
	[obj updateNotify];
}