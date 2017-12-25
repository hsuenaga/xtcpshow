// Copyright (c) 2017
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
//  TrafficData.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2017/12/21.
//  Copyright © 2017年 SUENAGA Hiroki. All rights reserved.
//

#import "math.h"
#import "TimeConverter.h"
#import "TrafficSample.h"
#import "TrafficData.h"

//
// Traffic Data Container
//
@interface TrafficData ()
- (id)init;
- (id)initWithResolution:(NSTimeInterval)resolusion startAt:(NSDate *)start endAt:(NSDate *)end;
- (id)initWithResolutionUnix:(NSUInteger)msResolution startAt:(struct timeval *)tvStart endAt:(struct timeval *)tvEnd;
- (TrafficSample *)addToChildNode:(struct timeval *)tv withBytes:(NSUInteger)bytes;
@end

@implementation TrafficData {
    NSPointerArray *dataRef; // child nodes
};
@synthesize Resolution;
@synthesize nextResolution;

//
// initializer
//
- (id)initWithResolution:(NSTimeInterval)resolution startAt:(NSDate *)start endAt:(NSDate *)end
{
    self = [super init];
    
    self.Start = start;
    self.End = end;
    self.numberOfSamples = 0;
    self.packetLength = 0;
    
    if (resolution) {
        NSUInteger msResolution = (NSUInteger)floor(resolution * 1000.0);
        NSUInteger nextResolution = 0;
        if (msResolution > 1) {
            double pf = log(msResolution)/log(NBRANCH);
            NSUInteger ipf = (NSUInteger)round(pf);
            nextResolution = NBRANCH;
            for (int i = 1; i < ipf; i++)
                nextResolution = nextResolution * NBRANCH;
            if (nextResolution == msResolution)
                nextResolution = nextResolution / NBRANCH;
            if (nextResolution >= 1) {
                NSUInteger nslot = msResolution / nextResolution;
                if (msResolution % nextResolution)
                    nslot++;
                msResolution = nslot * nextResolution;
                self.Resolution = msec2interval(msResolution);
                self.nextResolution = msec2interval(nextResolution);
            }
            else {
                self.Resolution = msec2interval((msResolution));
                self.nextResolution = NAN;
            }
        }
        else {
            self.Resolution = msec2interval(1);
            self.nextResolution = NAN;
        }
    }
    else {
        self.Resolution = NAN;
        self.nextResolution = NAN;
    }
    dataRef = [NSPointerArray weakObjectsPointerArray];
    if (self.Resolution && interval2msec(self.Resolution) > 1) {
        for (int i = 0; i < NBRANCH; i++)
            [dataRef addPointer:nil];
    }
    [self alignDate];
    
    return self;
}

- (id)initWithResolutionUnix:(NSUInteger)msResolution
                     startAt:(struct timeval *)tvStart endAt:(struct timeval *)tvEnd
{
    NSTimeInterval resolution = NAN;
    NSDate *start = nil;
    NSDate *end = nil;
    
    if (msResolution)
        resolution = msec2interval(msResolution);
    if (tvStart)
        start = tv2date(tvStart);
    if (tvEnd)
        end = tv2date(tvEnd);

    return [self initWithResolution:resolution startAt:start endAt:end];
}

- (id)init
{
    return [self initWithResolution:NAN startAt:nil endAt:nil];
}

+(id)dataOf:(id)parent withResolution:(NSTimeInterval)Resolution startAt:(NSDate *)start endAt:(NSDate *)end
{
    TrafficData *new = [[TrafficData alloc]
                        initWithResolution:Resolution startAt:start endAt:end];
    new.parent = parent;

    return new;
}

+(id)unixDataOf:(id)parent withMsResolution:(NSUInteger)msResolution
        startAt:(struct timeval *)tvStart endAt:(struct timeval *)tvEnd
{
    TrafficData *new = [[TrafficData alloc]
                        initWithResolutionUnix:msResolution startAt:tvStart endAt:tvEnd];
    new.parent = parent;
    
    return new;
}

//
// basic acsessor
//
- (NSUInteger)bitsFromDate:(NSDate *)from toDate:(NSDate *)to
{
    NSUInteger bits = 0;
    NSArray *allData = [dataRef allObjects];
    BOOL overflow;
    
    if (from == nil || to == nil)
        return 0;
    if (self.packetLength == 0)
        return 0;
    if (self.Start && self.End) {
        // we have data window.
        if ([from laterDate:self.End])
            return 0; // out of range
        if ([to earlierDate:self.Start] || [to isEqual:self.Start])
            return 0; // out of range. merginal entry must specified by "from".
        if (([from isEqual:self.Start] || [from earlierDate:self.Start])
            && [to laterDate:self.End])
            return (self.packetLength * 8); // just report entire data.
    }

    //
    // correct individual samples.
    //
    for (int idx = 0; idx < [allData count]; idx++) {
        if (allData[idx] == nil) {
            // sampling data was lost due to buffer limitation.
            overflow = true;
            break;
        }

        TrafficSample *sample = (TrafficSample *)allData[idx];
        if ([sample.Start earlierDate:from])
            continue;
        if ([sample.Start isEqual:to] || [sample.Start laterDate:to])
            break;
        // valid sample.
        bits += (sample.packetLength * 8);
    }
    if ([allData count] > 0 && !overflow)
        return bits; // return accurate data.

    //
    // accurate data was lost.
    //
    if (!self.Resolution || !self.Start || !self.End)
        return (self.packetLength * 8);

    NSTimeInterval duration = [self durationOverwrapFromDate:from toDate:to];
    double ratio = duration / self.Resolution;
    return (NSUInteger)floor(((double)(self.packetLength * 8)) * ratio);
}

- (NSUInteger)bytesFromDate:(NSDate *)from toDate:(NSDate *)to
{
    return ([self bitsFromDate:from toDate:to] / 8);
}

- (double)bitsPerSecFromDate:(NSDate *)from toDate:(NSDate *)to
{
    NSUInteger bits = [self bitsFromDate:from toDate:to];
    NSTimeInterval duration = [self durationOverwrapFromDate:from toDate:to];
    return ((double)bits / (double)duration);
}

- (double)bytesPerSecFromDate:(NSDate *)from toDate:(NSDate *)to
{
    return [self bitsPerSecFromDate:from toDate:to] / 8.0;
}

- (NSArray *)samplesFromDate:(NSDate *)from toDate:(NSDate *)to
{
    NSArray *children = [dataRef allObjects];
    BOOL incomplete = false;
    
    if ((from && [from laterDate:self.End]) || (to && [to earlierDate:self.Start]))
        return nil; // out of range
    
    if ([children count] == 0)
        return [NSArray arrayWithObject:self]; // no detail.
    
    NSMutableArray *array = [[NSMutableArray alloc] init];
    for (int idx = 0; idx < [children count]; idx++) {
        TrafficSample *child = [children objectAtIndex:idx];
        
        if (child == nil) {
            // incomplete collection.
            incomplete = true;
            continue;
        }
        if (incomplete && from && to) {
            if ([to earlierDate:child.Start]) {
                // old data was lost, but we have ecnough new data.
                incomplete = false;
                continue;
            }
            if ([to laterDate:child.Start]) {
                // lost data. giveup.
                return [NSArray arrayWithObject:self];
            }
        }
        NSArray *particle = [child samplesFromDate:from toDate:to];
        if (particle)
            [array addObjectsFromArray:particle];
    }

    return array;
}

- (double)bps
{
    if (self.Start == nil || self.End == nil)
        return NAN;
    
    double delta = (double)[self.End timeIntervalSinceDate:self.Start];
    double dbits = (double)[self bits];
    
    return (dbits / delta);
}

- (double)kbps
{
    return [self bps] * 1.0E-3;
}

- (double)Mbps
{
    return [self bps] * 1.0E-6;
}

- (double)Gbps
{
    return [self bps] * 1.0E-9;
}

//
// smart string representations
//
- (NSString *)bpsString
{
    double bps = [self bps];
    
    if (isnan(bps))
        return @"NaN";
    else if (bps < 1.0E3)
        return [NSString stringWithFormat:@"%4.1f [bps]", [self bps]];
    else if (bps < 1.0E6)
        return [NSString stringWithFormat:@"%4.1f [kbps]", [self kbps]];
    else if (bps < 1.0E9)
        return [NSString stringWithFormat:@"%4.1f [Mbps]", [self Mbps]];
    
    return [NSString stringWithFormat:@"%.1f [Gbps]", [self Gbps]];
}

//
// operator
//
- (BOOL)acceptableTimeval:(struct timeval *)tv
{
    if (self.Start == nil || self.End == nil || tv == NULL)
        return false;
    
    NSUInteger msTimestamp = tv2msec(tv);
    if ([self msStart] <= msTimestamp && msTimestamp < [self msEnd])
        return true;

    return false;
}

//
// insert child container(TrraficData) or sigle data(TrafficSample).
// we use TrafficSample as abstructed base class.
//
- (TrafficSample *)addToChildNode:(struct timeval *)tv withBytes:(NSUInteger)bytes
{
    //
    // leaf
    //
    if (isnan(self.Resolution) ||
        isnan(self.nextResolution) ||
        [self msResolution] <= 1) {
        // We have traffic sample directly.
        TrafficSample *child = [TrafficSample sampleOf:self atTimeval:tv withPacketLength:bytes];
        [dataRef addPointer:(__bridge void * _Nullable)child];
        return child;
    }

    //
    // indirect reference via another TrafficData.
    //
    //  Start                                End
    //  |<---------resolution[msec]--------->|
    //  |<-slot 1->|<-slot 2->|...|<-slot n->| ... n => NBRNACH
    //                ^
    //                offset(timestamp - start) [ms]
    //  slot = offset / (resolution / nbranch) = offset * nbrach / resolution
    //
    NSUInteger slot = (tv2msec(tv) - [self msStart]) * NBRANCH / [self msResolution];
    if (slot >= [dataRef count]) {
        NSLog(@"slot %lu is out of range", slot);
        slot = [dataRef count] - 1;
    }
    
    TrafficData *child = [dataRef pointerAtIndex:slot];
    if (!child) {
        // create new node.
        child = [TrafficData unixDataOf:self
                       withMsResolution:interval2msec(self.nextResolution)
                                startAt:tv
                                  endAt:tv];
        [dataRef replacePointerAtIndex:slot
                           withPointer:(__bridge void * _Nullable)child];
    }

    return [child addSampleAtTimeval:tv withBytes:bytes];
}

- (TrafficSample *)addSampleAtTimeval:(struct timeval *)tv withBytes:(NSUInteger)bytes
{
    if (![self acceptableTimeval:tv]) {
        NSLog(@"obj%d request is not acceptable", self.objectID);
        return nil;
    }
    
    id new = [self addToChildNode:tv withBytes:bytes];
    if (!new) {
        NSLog(@"obj%d child node rejected the timestamp", self.objectID);
        return nil;
    }
    
    self.numberOfSamples++;
    self.packetLength += bytes;
    return new;
}

- (TrafficSample *)addSampleAtTimevalExtend:(struct timeval *)tv
                       withBytes:(NSUInteger)bytes
{
    if (tv == NULL)
        return nil;
    
    NSUInteger msTimestamp = tv2msec(tv);
    BOOL extend = false;

    if (![self msStart] || msTimestamp < [self msStart]) {
        self.Start = msec2date(msTimestamp);
        extend = true;
    }
    
    if (![self msEnd] || [self msEnd] < msTimestamp) {
        self.End = msec2date(msTimestamp);
        extend = true;
    }
    if (extend)
        [self alignDate];
    
    return [self addSampleAtTimeval:tv withBytes:bytes];
}

//
// NSCopying protocol
//
- (id)copyWithZone:(NSZone *)zone
{
    TrafficData *new = [[TrafficData alloc] init];
    
    new.numberOfSamples = self.numberOfSamples;
    new.packetLength = self.packetLength;
    new.Start = self.Start;
    new.End = self.End;
    new.Resolution = self.Resolution;
    new.parent = nil;

    return new;
}

//
// Utility
//
- (void)alignDate
{
    if (!self.Resolution)
        return;
    
    NSUInteger msResolution = interval2msec(self.Resolution);
    if (self.Start) {
        NSUInteger msStart = date2msec(self.Start);
        msStart = msStart - (msStart % msResolution);
        self.Start = msec2date(msStart);
    }
    if (self.End) {
        NSUInteger msEnd = date2msec(self.End);
        msEnd = msEnd - (msEnd % msResolution) + msResolution;
        self.End = msec2date(msEnd);
    }
}

- (NSUInteger)msResolution
{
    if (isnan(self.Resolution))
        return 0;
    
    return interval2msec(self.Resolution);
}

- (NSTimeInterval)durationOverwrapFromDate:(NSDate *)from toDate:(NSDate *)to
{
    if ([from laterDate:self.End])
        return NAN;
    if ([to earlierDate:self.Start] || [to isEqual:self.Start])
        return NAN;
    NSDate *start = [self.Start laterDate:from] ? self.Start : from;
    NSDate *end = [self.End earlierDate:to] ? self.End : to;
    
    return [end timeIntervalSinceDate:start];
}

//
// debug
//
- (void)dumpTree:(BOOL)root
{
    // header
    if (root) {
        [self writeDebug:@"digraph xtcpdump {\n"];
        [self writeDebug:@"node [shape=record];\n"];
        [self writeDebug:@"graph [rankdir=TB];\n"];
    }
    
    NSArray *node = [dataRef allObjects];
    if ([node count] == 0) {
        [self writeDebug:@"node%d [shape=doublecircle label=\"%llu [bytes]\"];\n",
         self.objectID, self.packetLength];
        return;
    }

    // create record def
    [self writeDebug:@"node%d [shape=record label=\"{<obj%d> obj%d\\n%lu[msec]\\n%llu [bytes]|{",
     self.objectID, self.objectID, self.objectID, [self msResolution], self.packetLength];
    __block BOOL delim = false;
    [node
     enumerateObjectsUsingBlock:^(TrafficSample *ptr, NSUInteger idx, BOOL *stop) {
         if ([ptr isMemberOfClass:[self class]]) {
             if (delim)
                 [self writeDebug:@"|"];
             [self writeDebug:@"<obj%d> slot%lu", ptr.objectID, idx];
             delim = true;
         }
         else {
             [self writeDebug:@"<leaf%d> no child", self.objectID];
             *stop = true;
         }
     }];
    [self writeDebug:@"}}\"];\n"];

    // create record link
    [node
     enumerateObjectsUsingBlock:^(TrafficSample *ptr, NSUInteger idx, BOOL *stop) {
         if ([ptr isMemberOfClass:[self class]]) {
             [self writeDebug:@"node%d:obj%d -> node%d:obj%d;\n",
              self.objectID, ptr.objectID, ptr.objectID, ptr.objectID];
         }
         else {
             [self writeDebug:@"node%d:leaf%d -> obj%d;\n",
              self.objectID, self.objectID, ptr.objectID];
         }
         [ptr dumpTree:false];
     }];
    
    // footer
    if (root) {
        [self writeDebug:@"}\n"];
    }
}
@end
