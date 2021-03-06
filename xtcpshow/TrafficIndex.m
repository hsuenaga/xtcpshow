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
//  TrafficIndex.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2017/12/21.
//  Copyright © 2017年 SUENAGA Hiroki. All rights reserved.
//

#import "math.h"
#import "TimeConverter.h"
#import "TrafficData.h"
#import "TrafficIndex.h"

//
// Traffic Data Container
//
@interface TrafficIndex ()
@property (assign, nonatomic, readwrite) uint64_t numberOfSamples;
@property (assign, nonatomic, readwrite) uint64_t bytesReceived;
@property (strong, nonatomic, readwrite) id parent;

@property (strong, atomic, readwrite) NSDate *lastDate;
@property (assign, nonatomic, readwrite) uint64_t bytesBefore;
@property (assign, nonatomic, readwrite) uint64_t samplesBefore;
@property (assign, nonatomic, readwrite) NSTimeInterval Resolution;
@property (assign, nonatomic, readwrite) NSTimeInterval nextResolution;

- (id)init;
- (TrafficData *)addToChildNode:(struct timeval *)tv withBytes:(NSUInteger)bytes auxData:(id)aux;
- (BOOL)acceptableTimeval:(struct timeval *)tv;
- (NSUInteger)msResolution;
- (NSUInteger)slotFromTimeval:(struct timeval *)tv;
- (void)updateResolution:(NSTimeInterval)resolution;
@end

@implementation TrafficIndex {
    NSPointerArray *dataRef; // child nodes
};
@synthesize numberOfSamples;
@synthesize bytesReceived;
@synthesize parent;
@synthesize Resolution;
@synthesize nextResolution;
@synthesize lastDate;

//
// initializer
//
- (id)initWithResolution:(NSTimeInterval)resolution startAt:(NSDate *)start endAt:(NSDate *)end
{
    self = [super init];

    self.numberOfSamples = 0;
    self.bytesReceived = 0;
    self.lastDate = [NSDate date];
    self.dataFrom = start;
    self.dataTo = end;
    [self updateResolution:resolution];
    dataRef = [NSPointerArray weakObjectsPointerArray];
    if (!isnan(self.nextResolution)) {
        for (int i = 0; i < NBRANCH; i++)
            [dataRef addPointer:nil];
    }
    
    return self;
}

- (id)init
{
    return [self initWithResolution:NAN startAt:nil endAt:nil];
}

+(id)dataOf:(id)parent withResolution:(NSTimeInterval)Resolution startAt:(NSDate *)start endAt:(NSDate *)end
{
    TrafficIndex *new = [[TrafficIndex alloc]
                        initWithResolution:Resolution startAt:start endAt:end];
    new.parent = parent;
    return new;
}

+(id)unixDataOf:(id)parent withMsResolution:(NSUInteger)msResolution
        startAt:(struct timeval *)tvStart endAt:(struct timeval *)tvEnd
{
    return [TrafficIndex dataOf:parent
                withResolution:msec2interval(msResolution)
                       startAt:tvStart ? tv2date(tvStart) : nil
                         endAt:tvEnd ? tv2date(tvEnd): nil];
}

//
// basic acsessor
//
- (BOOL)dataAtDate:(NSDate *)date withBytes:(NSUInteger *)bytes withSamples:(NSUInteger *)samples
{
    if (self.bytesReceived == 0 && self.numberOfSamples == 0) {
        if (bytes)
            *bytes = 0;
        if (samples)
            *samples = 0;
        return TRUE; // no data
    }
    if (!date || !self.dataFrom || !self.dataTo) {
        if (bytes)
            *bytes = self.bytesReceived;
        if (samples)
            *samples = self.numberOfSamples;
        return TRUE; // no date
    }
    
    // we have data window.
    struct timeval tv;
    date2tv(date, &tv);
    if ([date earlierDate:self.dataFrom] == date) {
        if (bytes)
            *bytes = self.bytesBefore;
        if (samples)
            *samples = self.samplesBefore;
        return FALSE; // out of range
    }
    if ([date isEqual:self.dataTo] ||
        [date laterDate:self.dataTo] == date) {
        if (bytes)
            *bytes = self.bytesReceived;
        if (samples)
            *samples = self.numberOfSamples;
        return FALSE; // out of range
    }
    
    // leaf
    if (isnan(self.Resolution) ||
        isnan(self.nextResolution) ||
        [self msResolution] <= 1 ||
        NBRANCH < 2) {
        if (bytes)
            *bytes = self.bytesReceived;
        if (samples)
            *samples = self.numberOfSamples;
        return TRUE;
    }
    
    // search tree
    NSUInteger slot = [self slotFromTimeval:&tv];
    TrafficIndex *child = [dataRef pointerAtIndex:slot];
    if (!child) {
        while (slot > 0) {
            slot--;
            child = [dataRef pointerAtIndex:slot];
            if (child) {
                if (bytes)
                    *bytes = child.bytesReceived;
                if (samples)
                    *samples = child.numberOfSamples;
                return TRUE;
            }
        }
        if (bytes)
            *bytes = self.bytesBefore;
        if (samples)
            *samples = self.samplesBefore;
        return TRUE;
    }
    return [child dataAtDate:date withBytes:bytes withSamples:samples];
}

- (NSUInteger)bitsAtDate:(NSDate *)date
{
    return [self bytesAtDate:date] * 8;
}

- (NSUInteger)bytesAtDate:(NSDate *)date
{
    NSUInteger bytes = 0;
    
    [self dataAtDate:date withBytes:&bytes withSamples:NULL];
    return bytes;
}

- (NSUInteger)samplesAtDate:(NSDate *)date
{
    NSUInteger samples = 0;

    [self dataAtDate:date withBytes:NULL withSamples:&samples];
    return samples;
}

//
// operator
//
- (BOOL)acceptableTimeval:(struct timeval *)tv
{
    if (self.dataFrom == nil || self.dataTo == nil || tv == NULL) {
        NSLog(@"obj%lu time slot is not defined", self.objectID);
        return false;
    }
    
    NSUInteger msTimestamp = tv2msec(tv);
    if ([self msStart] <= msTimestamp && msTimestamp < [self msEnd])
        return true;

    NSLog(@"obj%lu timestamp %lu is out of range: %lu - %lu", [self objectID],
          msTimestamp, [self msStart], [self msEnd]);
    return false;
}

//
// insert child container(TrraficData) or sigle data(TrafficData).
// we use TrafficData as abstructed base class.
//
- (TrafficData *)addToChildNode:(struct timeval *)tv withBytes:(NSUInteger)bytes auxData:(id)aux
{
    //
    // leaf
    //
    if (isnan(self.Resolution) ||
        isnan(self.nextResolution) ||
        [self msResolution] <= 1 ||
        NBRANCH < 2) {
        // We have traffic sample directly.

        TrafficData *child;
        if ([dataRef count] > 0) {
            child = [dataRef pointerAtIndex:0];
            if (child) {
                [child addSampleAtTimeval:tv withBytes:bytes auxData:aux];
                return nil;
            }
        }
        child = [TrafficData sampleOf:self atTimeval:tv withPacketLength:bytes auxData:aux];
        [dataRef addPointer:(__bridge void * _Nullable)child];
        return child;
    }

    //
    // aggregate
    //
    NSUInteger slot = [self slotFromTimeval:tv];
    TrafficIndex *child = [dataRef pointerAtIndex:slot];
    if (!child) {
        // create new node.
        NSDate *start = nil, *end = nil;
        
        // copy parent's time marker
        if (slot == 0 && self.dataFrom) {
            start = self.dataFrom;
        }
        if (slot == (NBRANCH - 1) && self.dataTo) {
            end = self.dataTo;
        }
        
        // copy sibling's time marker
        if (!start && slot > 0) {
            TrafficIndex *prev = [dataRef pointerAtIndex:(slot - 1)];
            if (prev)
                start = prev.dataTo;
        }
        if (!end && slot < (NBRANCH - 1)) {
            TrafficIndex *next = [dataRef pointerAtIndex:(slot + 1)];
            if (next)
                end = next.dataFrom;
        }
        
        // allocatre new marker
        if (!start) {
            start = [TrafficData alignTimeval:tv withResolution:self.nextResolution];
        }
        if (!end) {
            NSUInteger msEnd = date2msec(start) + interval2msec(self.nextResolution);
            end = msec2date(msEnd);
        }
        
        if ([start isEqual:end]) {
            NSLog(@"invalid object setup");
        }
        child = [TrafficIndex dataOf:self
                       withResolution:self.nextResolution
                                startAt:start
                                  endAt:end];
        child.bytesBefore = self.bytesReceived - bytes;
        child.samplesBefore = self.numberOfSamples - 1;
        [dataRef replacePointerAtIndex:slot
                           withPointer:(__bridge void * _Nullable)child];
    }
    child.numberOfSamples = self.numberOfSamples;
    child.bytesReceived = self.bytesReceived;
    child.lastDate = self.lastDate;
    return [child addToChildNode:tv withBytes:bytes auxData:aux];

}

- (TrafficData *)addSampleAtTimeval:(struct timeval *)tv withBytes:(NSUInteger)bytes auxData:(id)aux
{
    if (![self acceptableTimeval:tv]) {
        NSLog(@"obj%lu request is not acceptable", self.objectID);
        return nil;
    }
    [super addSampleAtTimeval:tv withBytes:bytes auxData:aux];
    self.lastDate = tv2date(tv);
    return [self addToChildNode:tv withBytes:bytes auxData:aux];
}

- (TrafficData *)addSampleAtTimevalExtend:(struct timeval *)tv
                                  withBytes:(NSUInteger)bytes auxData:(id)aux
{
    if (tv == NULL)
        return nil;
    
    NSUInteger msTimestamp = tv2msec(tv);
    BOOL extend = false;

    if (![self msStart] || msTimestamp < [self msStart]) {
        self.dataFrom = msec2date(msTimestamp);
        extend = true;
    }
    
    if (![self msEnd] || [self msEnd] < msTimestamp) {
        self.dataTo = msec2date(msTimestamp);
        extend = true;
    }
    if (extend)
        [self alignStartEnd];
    
    return [self addSampleAtTimeval:tv withBytes:bytes auxData:aux];
}

//
// NSCopying protocol
//
- (id)copyWithZone:(NSZone *)zone
{
    TrafficIndex *new = [[TrafficIndex alloc] init];
    
    new.numberOfSamples = self.numberOfSamples;
    new.bytesReceived = self.bytesReceived;
    new.dataFrom = self.dataFrom;
    new.dataTo = self.dataTo;
    new.Resolution = self.Resolution;
    new.parent = nil;

    return new;
}

//
// Utility
//
- (void)alignStartEnd
{
    NSUInteger msResolution = [self msResolution];

    if (!msResolution)
        return;
    if (self.dataFrom) {
        NSUInteger msStart = date2msec(self.dataFrom);
        msStart = msStart - (msStart % msResolution);
        self.dataFrom = msec2date(msStart);
    }
    if (self.dataTo) {
        NSUInteger msEnd = date2msec(self.dataTo);
        msEnd = msEnd - (msEnd % msResolution) + msResolution;
        self.dataTo = msec2date(msEnd);
    }
    while ([dataRef count] > 0 &&
           [self.dataTo timeIntervalSinceDate:self.dataFrom] > (self.nextResolution * NBRANCH)) {
        TrafficIndex *firstChild;
        [dataRef removePointerAtIndex:0];
        if ([dataRef count] > 0) {
            firstChild = [dataRef pointerAtIndex:0];
            if (firstChild)
                self.dataFrom = firstChild.dataFrom;
        }
    }
}

- (NSUInteger)msResolution
{
    if (isnan(self.Resolution))
        return 0;
    
    return interval2msec(self.Resolution);
}

- (NSUInteger)slotFromTimeval:(struct timeval *)tv
{
    //
    // indirect reference via another TrafficIndex.
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
    
    return slot;
}

- (void)updateResolution:(NSTimeInterval)resolusion
{
    if (isnan(resolusion)) {
        self.Resolution = NAN;
        self.nextResolution = NAN;
        return;
    }
    
    NSUInteger msResolution = interval2msec(resolusion);
    if (msResolution <= 1) {
        // minimum resolusion.
        self.Resolution = msec2interval(1);
        self.nextResolution= NAN;
        return;
    }

    // ensure nextResolution to power of NBRANCH.
    NSUInteger pf = (NSUInteger)round(log(msResolution)/log(NBRANCH));
    NSUInteger msNext = NBRANCH;
    msNext = NBRANCH;
    for (int i = 1; i < pf; i++) {
        msNext *= NBRANCH;
    }
    if (msNext == msResolution) {
        // for example)
        // log(9999)/log(10) = 4 = log(10000)/log(10)
        // we need power of 3 for 9999.
        msNext /= NBRANCH;
    }
    if (msNext < 1) {
        self.Resolution = resolusion;
        self.nextResolution = NAN;
        return;
    }

    // adjust msResolution to multiple of nextResolution
    NSUInteger nslot = msResolution / msNext;
    if (msResolution % msNext) {
        nslot += 1;
    }
    msResolution = nslot * msNext;
    
    self.Resolution = msec2interval(msResolution);
    self.nextResolution = msec2interval(msNext);
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
        [self writeDebug:@"node%lu [shape=doublecircle label=\"%llu [bytes]\"];\n",
         self.objectID, self.bytesReceived];
        return;
    }

    // create record def
    [self writeDebug:@"node%lu [shape=record label=\"{<obj%lu> obj%lu\\n%lu[msec]\\n%llu [pkts]\\n%llu [bytes]\\n%llu [bytes]|{",
     self.objectID, self.objectID, self.objectID, [self msResolution], self.numberOfSamples, self.bytesBefore, self.bytesReceived];
    __block BOOL delim = false;
    [node
     enumerateObjectsUsingBlock:^(TrafficData *ptr, NSUInteger idx, BOOL *stop) {
         if ([ptr isKindOfClass:[self class]]) {
             if (delim)
                 [self writeDebug:@"|"];
             [self writeDebug:@"<obj%lu> slot%lu", ptr.objectID, idx];
             delim = true;
         }
         else {
             [self writeDebug:@"<leaf%lu> no child", self.objectID];
             *stop = true;
         }
     }];
    [self writeDebug:@"}}\"];\n"];

    // create record link
    [node
     enumerateObjectsUsingBlock:^(TrafficData *ptr, NSUInteger idx, BOOL *stop) {
         if ([ptr isKindOfClass:[self class]]) {
             [self writeDebug:@"node%lu:obj%lu -> node%lu:obj%lu;\n",
              self.objectID, ptr.objectID, ptr.objectID, ptr.objectID];
         }
         else {
             [self writeDebug:@"node%lu:leaf%lu -> obj%lu;\n",
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
