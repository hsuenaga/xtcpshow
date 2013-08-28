//
//  FlowData.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/26.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.H>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <pcap/pcap.h>

#import "FlowData.h"

struct flowRecord4 {
	struct sockaddr_in node1;
	struct sockaddr_in node2;
	uint8_t proto;
};

NSString const * flowStateEstablish = @"Established";
NSString const * flowStateClosed = @"Closed";

@implementation FlowData
- (id)init
{
	FlowIDToRec = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory];
	FlowRecToID = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory valueOptions:NSMapTableWeakMemory];
	FlowRecToState = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory];
	lastClassID = 0;

	return self;
}

- (int)makeFlow4:(const struct ip *)ip tcpHeader:(const struct tcphdr *)tcp removeFlow:(BOOL)remove
{
	NSValue *recObj;
	NSNumber *classID;
	struct flowRecord4 rec;
	struct sockaddr_in *src, *dst;

	// create flowrecord
	memset(&rec, 0, sizeof(rec));
	if (ntohs(tcp->th_sport) < ntohs(tcp->th_dport)) {
		src = &rec.node1;
		dst = &rec.node2;
	}
	else {
		src = &rec.node2;
		dst = &rec.node1;
	}
	src->sin_family = dst->sin_family = AF_INET;
	src->sin_len = dst->sin_len = sizeof(struct sockaddr_in);
	memcpy(&src->sin_addr, &ip->ip_src, sizeof(src->sin_addr));
	src->sin_port = tcp->th_sport;
	memcpy(&dst->sin_addr, &ip->ip_dst, sizeof(dst->sin_addr));
	dst->sin_port = tcp->th_dport;
	rec.proto = IPPROTO_TCP;
	recObj = [NSValue valueWithBytes:&rec
				objCType:@encode(typeof(rec))];

	// check existing flow and remove if reqested
	classID = [FlowRecToID objectForKey:recObj];
	if (remove) {
		if (classID) {
			[FlowIDToRec removeObjectForKey:classID];
			[FlowRecToID removeObjectForKey:recObj];
			[FlowRecToState setObject:flowStateClosed forKey:recObj];
			NSLog(@"flow %d closed", [classID intValue]);
		}
		return -1;
	}
	if (classID)
		return [classID intValue];

	// ignore closed flow
	if ([FlowRecToState objectForKey:recObj] == flowStateClosed)
		return -1;

	// new flow
	classID = [NSNumber numberWithInteger:lastClassID];
	lastClassID++;

	[FlowIDToRec setObject:recObj forKey:classID];
	[FlowRecToID setObject:classID forKey:recObj];
	[FlowRecToState setObject:flowStateEstablish forKey:recObj];
	NSLog(@"flow %d found: %@",
	      [classID intValue],
	      [self descriptionForClassID:[classID intValue]]);
	return [classID intValue];
}

- (int)clasifyPacket:(const void *)byte size:(size_t)size linkType:(int)dlt
{
	const uint8_t *octed = byte;
	const struct ip *ip;
	const struct tcphdr *tcp;
	int hlen;
	BOOL remove = NO;

	// ignore DLT header
	switch (dlt) {
		case DLT_NULL:
			hlen = 4;
			break;
		case DLT_EN10MB:
			hlen = 14;
			break;
		case DLT_PPP:
			hlen = 2;
			if (octed[0] == 0xff && octed[1] == 0x03)
				hlen += 2; // HDLC
			break;
		case DLT_RAW:
			hlen = 0;
			break;
		default:
			return -1;
	}
	if (size < hlen)
		return -1;
	size -= hlen; octed += hlen;

	// extract IP header
	if (size < sizeof(*ip))
		return -1;
	ip = (const struct ip *)octed;
	if (ip->ip_v != IPVERSION)
		return -1; // XXX: IPv6
	if (ip->ip_p != IPPROTO_TCP)
		return -1;
	hlen = ip->ip_hl << 2;
	if (size < hlen)
		return -1;
	size -= hlen; octed += hlen;

	// extract TCP header
	if (size < sizeof(*tcp))
		return -1;
	tcp = (const struct tcphdr *)octed;
	hlen = tcp->th_off;
	if (size < hlen)
		return -1;
	size -= hlen; octed += hlen;

	// extract TCP state
	if (tcp->th_flags & TH_FIN)
		remove = YES;
	else if (tcp->th_flags & TH_RST)
		remove = YES;

	return [self makeFlow4:ip tcpHeader:tcp removeFlow:remove];
}

- (BOOL)getFlowRecord4:(struct flowRecord4 *)rec4 fromClassID:(int)classID
{
	NSNumber *classIDObj;
	NSValue *val;

	if (rec4 == NULL)
		return NO;
	classIDObj = [NSNumber numberWithInt:classID];
	val = [FlowIDToRec objectForKey:classIDObj];
	if (val == nil)
		return NO;
	[val getValue:rec4];
	return YES;
}

- (NSUInteger)numberOfClassID
{
	return [FlowIDToRec count];
}

- (NSArray *)arrayOfClassID
{
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[self numberOfClassID]];
	NSEnumerator *enumID;
	NSNumber *classID;

	enumID = [FlowIDToRec keyEnumerator];

	while ( (classID = [enumID nextObject])) {
		[array addObject:classID];
	}

	return array;
}

- (NSString *)descriptionForClassID:(int)classID
{
	struct flowRecord4 rec4;
	char shost[NI_MAXHOST], dhost[NI_MAXHOST];
	char sserv[NI_MAXSERV], dserv[NI_MAXSERV];

	if (![self getFlowRecord4:&rec4 fromClassID:classID])
		return @"NoFlowRecord";

	getnameinfo((struct sockaddr *)&rec4.node1, sizeof(rec4.node1),
		    shost, sizeof(shost), sserv, sizeof(sserv),
		    NI_NUMERICHOST|NI_NUMERICSERV);
	getnameinfo((struct sockaddr *)&rec4.node2, sizeof(rec4.node2),
		    dhost, sizeof(dhost), dserv, sizeof(dserv),
		    NI_NUMERICHOST|NI_NUMERICSERV);
	return [NSString stringWithFormat:@"%s:%s <=> %s:%s",
		shost, sserv, dhost, dserv];
}
@end
