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

- (void)insertChild:(TrafficSample *)child;
- (TrafficSample *)addToChildNode:(struct timeval *)tv withBytes:(NSUInteger)bytes;
@end

@implementation TrafficData {
    NSPointerArray *dataRef; // child nodes
};

//
// initializer
//
- (id)initWithResolution:(NSTimeInterval)resolution startAt:(NSDate *)start endAt:(NSDate *)end
{
    self = [super init];
    
    self.packetLength = 0;
    self.numberOfSamples = 0;
    self.Start = start;
    self.End = end;
    self.Resolution = resolution;
    dataRef = [NSPointerArray weakObjectsPointerArray];
    [self alignDate];
    self.uniq_id = global_id++;
    
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
- (void)insertChild:(TrafficSample *)child
{
    //
    // dataRef must be sorted.
    //
    if ([dataRef count] == 0) {
        [dataRef addPointer:(__bridge void * _Nullable)(child)];
        return;
    }
    
    int idx = (int)([dataRef count] - 1);
    TrafficSample *walk = [dataRef pointerAtIndex:idx];
    
    // try to insert to tail.
    if (walk && [child.Start laterDate:walk.End]) {
        [dataRef addPointer:(__bridge void * _Nullable)(child)];
        return;
    }
    
    // try to insert to inermediate position
    for (idx--;idx >= 0; idx--) {
        walk = [dataRef pointerAtIndex:idx];
        if (walk == nil)
            continue;
        if ([child.Start earlierDate:walk.Start])
            continue; // skip old entry.
        // newer entry is found. insert to previous position.
        [dataRef insertPointer:(__bridge void * _Nullable)(child) atIndex:(idx + 1)];
        return;
    }
    
    // insert to head
    [dataRef insertPointer:(__bridge void * _Nullable)(child) atIndex:0];
    return;
}

- (TrafficSample *)addToChildNode:(struct timeval *)tv withBytes:(NSUInteger)bytes
{
    if (!self.Resolution || [self msResolution] < NBRANCH) {
        // We have traffic sample directly.
        TrafficSample *child = [TrafficSample sampleOf:self atTimeval:tv withPacketLength:bytes];
        [self insertChild:child];
        return child;
    }

    //
    // indirect reference via another TrafficData.
    //
    TrafficData *child = nil;
    if ([dataRef count] > 0) {
        // check from tail to head
        for (int idx = (int)[dataRef count] - 1; idx >= 0; idx--) {
            child = [dataRef pointerAtIndex:idx];
            if (child == nil)
                continue;
            if ([child acceptableTimeval:tv])
                break; // use existing child node.
            child = nil;
        }
    }
     if (!child) {
         // no acceptable child node found.
        child = [TrafficData unixDataOf:self
                     withMsResolution:([self msResolution] / NBRANCH)
                              startAt:tv
                                endAt:tv];
         [self insertChild:child];
    }

    // request child to hold sampling data.
    return [child addSampleAtTimeval:tv withBytes:bytes];
}

- (TrafficSample *)addSampleAtTimeval:(struct timeval *)tv withBytes:(NSUInteger)bytes
{
    if (![self acceptableTimeval:tv])
        return nil;
    
    id new = [self addToChildNode:tv withBytes:bytes];
    if (!new)
        return nil;
    
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
- (void)dumpTree:(NSFileHandle *)file
{
    NSString *msg;
    if ([dataRef count] > 0) {
        for (int idx = 0; idx < [dataRef count]; idx++) {
            TrafficSample *obj = [dataRef pointerAtIndex:idx];
            if (obj == nil) {
                msg = [NSString stringWithFormat:@"obj%d -> null\n",
                       self.uniq_id];
                [file writeData:[msg dataUsingEncoding:NSUTF8StringEncoding]];
            }
            else {
                msg = [NSString stringWithFormat:@"obj%d -> obj%d\n",
                       self.uniq_id, obj.uniq_id];
                [file writeData:[msg dataUsingEncoding:NSUTF8StringEncoding]];
                [obj dumpTree:file];
            }
        }
    }
    else {
        msg = [NSString stringWithFormat:@"obj%d -> term\n", self.uniq_id];
        [file writeData:[msg dataUsingEncoding:NSUTF8StringEncoding]];
    }
}
@end
