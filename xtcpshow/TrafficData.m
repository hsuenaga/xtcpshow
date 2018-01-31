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
//  Created by SUENAGA Hiroki on 2017/12/22.
//  Copyright © 2017年 SUENAGA Hiroki. All rights reserved.
//

#import "TrafficData.h"

//
// base class of traffic data
//
@interface TrafficData ()
@property (assign, nonatomic, readwrite) int objectID;
@property (strong, nonatomic, readwrite) NSDate *dataFrom;
@property (strong, nonatomic, readwrite) NSDate *dataTo;
@property (assign, nonatomic) NSUInteger numberOfSamples;
@property (strong, nonatomic, readwrite) id parent;
@property (strong, nonatomic, readwrite) id next;
@property (strong, nonatomic, readwrite) id aux;
@property (weak, nonatomic) TrafficData *newerSample;
@property (weak, nonatomic) TrafficData *olderSample;
@property (assign, nonatomic) BOOL samplingData;
- (id)init;
- (id)initAtTimeval:(struct timeval *)tv withPacketLength:(uint64_t)lengh;
@end

@implementation TrafficData {
    BOOL sampling_data;
}
@synthesize objectID, dataFrom, dataTo, numberOfSamples;
@synthesize parent, next, aux;
@synthesize newerSample, olderSample;


//
// private initializer
//
- (id)initAtTimeval:(struct timeval *)tv withPacketLength:(uint64_t)length
{
    NSNumber *data = [NSNumber numberWithUnsignedInteger:length];
    NSDate *date = tv ? tv2date(tv) : nil;
    self = [super initWithMode:DATA_UINTEGER
                     numerator:data
                   denominator:nil
                      dataFrom:date
                        dataTo:nil
                   fromSamples:0];
    self.parent = nil;
    if (tv) {
        [self alignStartEnd];
    }
    if (length > 0) {
        self.numberOfSamples = 1;
    }
    self.samplingData = TRUE;
    
    return self;
}

- (id)init
{
    return [self initAtTimeval:NULL withPacketLength:0];
}

//
// public allocator
//  create new sampling data in contaier class 'parent'.
//  the container class doesn't have 'strong' reference to the allocated object.
//  the allocated object must be held by some other object.
//
+ (TrafficData *)sampleOf:(id)parent atTimeval:(struct timeval *)tv withPacketLength:(uint64_t)length auxData:(id)aux
{
    TrafficData *new;
    
    new = [[self.class alloc] initAtTimeval:tv withPacketLength:length];
    new.parent = parent;
    new.aux = aux;
    return new;
}

//
// basic acsessor
//
- (TrafficData *)addSampleAtTimeval:(struct timeval *)tv withBytes:(NSUInteger)bytes auxData:(id)aux
{
    if (!self.samplingData) {
        NSException *ex = [NSException exceptionWithName:@"Invalid Data"
                                                  reason:@"No sampling data held"
                                                userInfo:nil];
        @throw ex;
    }
    self.bytesReceived += bytes;
    self.numberOfSamples++;
    return self;
}

-(BOOL)dataAtDate:(NSDate *)date withBytes:(NSUInteger *)bytes withSamples:(NSUInteger *)samples
{
    if (!self.samplingData) {
        NSException *ex = [NSException exceptionWithName:@"Invalid Data"
                                                  reason:@"No sampling data held"
                                                userInfo:nil];
        @throw ex;
    }
    if (!date || !self.dataFrom) {
        *bytes = *samples = 0;
        return TRUE; // no date
    }
    if ([date isEqual:self.dataFrom] ||
        ([date laterDate:self.dataFrom] == date && [date earlierDate:self.dataTo] == date)) {
        *bytes = self.bytesReceived;
        *samples = self.numberOfSamples;
        return TRUE;
    }
        
    return FALSE;
}

- (NSUInteger)bytesReceived
{
    if (!self.samplingData) {
        NSException *ex = [NSException exceptionWithName:@"Invalid Data"
                                                  reason:@"No sampling data held"
                                                userInfo:nil];
        @throw ex;
    }
    return (NSUInteger)self.uint64Value;
}

- (void)setBytesReceived:(NSUInteger)bytesReceived
{
    self.samplingData = TRUE;
    self.uint64Value = (uint64_t)bytesReceived;
}

-(NSUInteger)bytesAtDate:(NSDate *)date
{
    if ([date isEqual:dataFrom] ||
        ([date laterDate:dataFrom] == date && [date earlierDate:dataTo] == date))
        return self.bytesReceived;
    return 0;
}

-(NSUInteger)bitsAtDate:(NSDate *)date
{
    return ([self bytesAtDate:date] * 8);
}


-(NSUInteger)samplesAtDate:(NSDate *)date
{
    if (!self.samplingData) {
        NSException *ex = [NSException exceptionWithName:@"Invalid Data"
                                                  reason:@"No sampling data held"
                                                userInfo:nil];
        @throw ex;
    }
    if ([date isEqual:dataFrom] ||
        ([date laterDate:dataFrom] == date && [date earlierDate:dataTo] == date))
        return self.numberOfSamples;
    return 0;
}

-(NSDate *)timestamp
{
    return self.dataFrom;
}

//
// smart string representations
//
- (NSString *)bytesString
{
    if (self.samplingData) {
        if (self.bytesReceived < 1000)
            return [NSString stringWithFormat:@"%3lu [bytes]",
                    self.bytesReceived];
        else if (self.bytesReceived < 1000000)
            return [NSString stringWithFormat:@"%4.1f [kbytes]",
                    (double)self.bytesReceived * 1.0E-3];
        else if (self.bytesReceived < 1000000000)
            return [NSString stringWithFormat:@"%4.1f [Mbytes]",
                    (double)self.bytesReceived * 1.0E-6];
        
        return [NSString stringWithFormat:@"%.1f [Gbytes]",
                (double)self.bytesReceived * 1.0E-9];
    }
    
    return @"(Not A Sampling Data)";
}

//
// Utility
//
+ (NSDate *)alignTimeval:(struct timeval *)tv withResolution:(NSTimeInterval)resolution
{
    NSUInteger msInterval = tv2msec(tv);
    NSUInteger msResolution = interval2msec(resolution);

    msInterval = msInterval - (msInterval % msResolution);

    return [NSDate dateWithTimeIntervalSince1970:msec2interval(msInterval)];
}

- (void)alignStartEnd
{
    self.dataTo = self.dataFrom;
}

- (NSUInteger)msStart
{
    if (!self.dataFrom)
        return 0;
    
    return date2msec(self.dataFrom);
}

- (NSUInteger)msEnd
{
    if (!self.dataTo)
        return 0;
    
    return date2msec(self.dataTo);
}

//
// NSCopying protocol
//
- (id)copyWithZone:(NSZone *)zone
{
    TrafficData *new = [super copyWithZone:zone];

    new.samplingData = self.samplingData;
    new.numberOfSamples = self.numberOfSamples;
    new.parent = nil;
    new.next = nil;
    new.aux = self.aux;
    new.newerSample = nil;
    new.olderSample = nil;
    
    return new;
}

//
// runtime support
//
- (NSString *)description
{
    if (self.samplingData) {
        return [NSString stringWithFormat:@"TrafficData(%lu samples, %@)",
                self.numberOfSamples, [self bytesString]];
    }
    return [super description];
}

- (NSString *)debugDescription
{
    if (self.samplingData) {
        return [NSString stringWithFormat:@"TrafficData: %lu samples, %@, From %@ To %@, parent=%@",
                self.numberOfSamples, [self bytesString],
                [self.dataFrom description],
                [self.dataTo description],
                [self.parent description]];
    }
    return [super debugDescription];
}

- (void)dumpTree:(BOOL)root
{
    [self writeDebug:@"obj%d [shape=point];\n", self.objectID];
}
@end
