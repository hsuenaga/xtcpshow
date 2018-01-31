// Copyright (c) 2013
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
//  PID.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//
#import "math.h"

#import "PID.h"
#import "TrafficIndex.h"
#import "TrafficData.h"
#import "TrafficDB.h"
#import "ComputeQueue.h"
#import "FIR.h"

#undef DEBUG_SAMPLE

@interface PID ()
- (void)doPIDat:(NSDate *)date prev:(NSDate *)prev next:(NSDate *)next onDataBase:(TrafficDB *)dataBase;
- (NSDate *)roundDate:(NSDate *)date toTick:(NSTimeInterval)tick;
- (void)dumpParams;
- (void)invalidValueException;
@end

@implementation PID {
    FIR *filterFIR;
    BOOL write_protect;
    BOOL running;
    double tick;
    GenericData *tickDataUsec;
    NSTimeInterval dataLength;
}
@synthesize output;
@synthesize outputSamples;
@synthesize outputTimeLength;
@synthesize outputTimeOffset;
@synthesize FIRTimeLength;
@synthesize overSample;

- (PID *)init
{
    self = [super init];
    self->_outputLock = [NSRecursiveLock new];
    self->_kzStage = 3;
    self->tickDataUsec = [GenericData dataWithoutValue];
    return self;
}

- (void)updateParams
{
    // convert units
    tick = outputTimeLength / outputSamples; // [sec/sample]
    dataLength = outputTimeLength + FIRTimeLength;
    
    // Ts: fraction tick [usec]
    NSInteger outputUsec = (NSUInteger)round(outputTimeLength * 1.0E6);
    tickDataUsec = [GenericData dataWithInteger:outputUsec];
    [tickDataUsec divInteger:outputSamples];
    [tickDataUsec mulInteger:2]; // 2 * Ts
    
    // allocate FIR
    filterFIR = [FIR FIRwithTap:ceil(FIRTimeLength/tick) withStage:self.kzStage];
    
    NSUInteger maxSamples = outputSamples + [filterFIR tap];
    output = [ComputeQueue queueWithZero:maxSamples];
    output.last_used = nil;

#ifdef DEBUG
    [self dumpParams];
#endif
    running = TRUE;
}

- (void)purgeData
{
    running = FALSE;
    output.last_used = nil;
}

- (void)doPIDat:(NSDate *)cur prev:(NSDate *)prev next:(NSDate *)next onDataBase:(TrafficDB *)dataBase
{
    // Step1: get differential value
    NSUInteger bitsPrev = [dataBase bitsAtDate:prev];
    NSUInteger bitsNext = [dataBase bitsAtDate:next];
    if (bitsPrev > bitsNext) {
#ifdef DEBUG
        [dataBase.class openDebugFile:@"inconsistent_tree.dot"];
        [dataBase dumpTree:TRUE];
#endif
        NSException *ex = [NSException exceptionWithName:@"Inconsistent Data" reason:@"Data is decreadsed." userInfo:NULL];
        [self.outputLock unlock];
        @throw ex;
    }
    NSUInteger bits = bitsNext - bitsPrev;
    NSUInteger pkts = [dataBase samplesAtDate:cur] - [dataBase samplesAtDate:prev];
    GenericData *sample = [GenericData dataWithInteger:bits atDate:cur  fromSamples:pkts];
    [sample divData:tickDataUsec]; // u[k+1] - u[k-1] / (2*Ts)

    // Step2: FIR
    sample = [filterFIR filter:sample];
#ifdef DEBUG_SAMPLE
    NSLog(@"New sample: %@", sample);
#endif

    // Step3: finalize and output sample
    sample.timestamp = cur;
    [output enqueue:sample withTimestamp:cur];
    output.last_used = cur;
}

- (void)resampleDataBase:(TrafficDB *)dataBase atDate:(NSDate *)date;
{
    NSDate *start, *end;
    
    [self.outputLock lock];
    
    if (!running)
        [self updateParams];
    
    // get range of time
    end = [self roundDate:[date dateByAddingTimeInterval:outputTimeOffset] toTick:tick];
    end = [end dateByAddingTimeInterval:(-tick)];
    start = [self roundDate:[end dateByAddingTimeInterval:(-dataLength)] toTick:tick];
    if (output.last_used) {
        if ([start laterDate:output.last_used] == output.last_used) {
            start = [output.last_used dateByAddingTimeInterval:tick];
        }
    }
    if ([start laterDate:end] == start) {
        [self.outputLock unlock];
        return;
    }
    
    // PID block
    @autoreleasepool {
        NSDate *prev = nil;
        NSDate *cur = nil;
        NSDate *next = nil;
        for (cur = start; [cur laterDate:end] == end; cur = next) {
            if (!prev) {
                prev = [cur dateByAddingTimeInterval:-tick];
            }
            next = [cur dateByAddingTimeInterval:tick];
            [self doPIDat:cur prev:prev next:next onDataBase:dataBase];
            prev = cur;
        }
    }
    
    // get additional data(noise) generated by filter
    overSample = [output count] - outputSamples;
    [self.outputLock unlock];
}

- (BOOL)FIRenabled
{
    return [filterFIR tap] ? TRUE : FALSE;
}

- (NSDate *)roundDate:(NSDate *)date toTick:(NSTimeInterval)tick
{
    NSTimeInterval unixTime;
    
    unixTime = [date timeIntervalSince1970];
    unixTime = floor(unixTime / tick) * tick;
    return [NSDate dateWithTimeIntervalSince1970:unixTime];
}

- (void)dumpParams
{
    NSLog(@"===== Resampler =====");
    NSLog(@"Duration: %f [sec]", outputTimeLength);
    NSLog(@"Plot: %lu [point]", (unsigned long)outputSamples);
    NSLog(@"Tick: %f [sec/point]", tick);
    NSLog(@"TickUsec: %@ [sec/usec]", tickDataUsec);
    NSLog(@"FIR Duration: %f [sec]", FIRTimeLength);
    NSLog(@"FIR Taps: %lu [point]", [filterFIR tap]);
    NSLog(@"Output samples: %lu [point]", outputSamples + [filterFIR tap]);
}

- (void)invalidValueException
{
    NSException *ex;
    
    ex = [NSException exceptionWithName:@"Invalid value"
                                 reason:@"Invalid value in DataResampler"
                               userInfo:nil];
    @throw ex;
}
@end
