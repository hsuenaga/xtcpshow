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
//  TrafficSample.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2017/12/22.
//  Copyright © 2017年 SUENAGA Hiroki. All rights reserved.
//

#import "TrafficSample.h"

static int newID = 0;
static NSFileHandle *debugHandle = nil;

//
// base class of traffic data
//
@interface TrafficSample ()
@property (weak,atomic) TrafficSample *newerSample;
@property (weak,atomic) TrafficSample *olderSample;
- (id)init;
- (id)initAtTimeval:(struct timeval *)tv withPacketLength:(uint64_t)lengh;
@end

@implementation TrafficSample
@synthesize objectID;
@synthesize parent;
@synthesize numberOfSamples;
@synthesize packetLength;
@synthesize Start;
@synthesize End;

//
// private initializer
//
- (id)initAtTimeval:(struct timeval *)tv withPacketLength:(uint64_t)length
{
    self = [super init];
    parent = nil;
    
    objectID = [[self class] newID];
    if (tv)
        self.Start = self.End = tv2date(tv);
    numberOfSamples = 1;
    packetLength = length;
    [self alignStartEnd];
    
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
+ (id)sampleOf:(id)parent atTimeval:(struct timeval *)tv withPacketLength:(uint64_t)length auxData:(id)aux
{
    TrafficSample *new;
    
    new = [[TrafficSample alloc] initAtTimeval:tv withPacketLength:length];
    new.parent = parent;
    new.aux = aux;
    return new;
}

+ (int)newID
{
    return newID++;
}

+ (NSFileHandle *)debugHandle
{
    return debugHandle;
}

+ (void)setDebugHandle:(NSFileHandle *)handle
{
    if (debugHandle) {
        [debugHandle synchronizeFile];
        [debugHandle closeFile];
        debugHandle = nil;
    }
    debugHandle = handle;
}

//
// basic acsessor
//
-(NSUInteger)bitsFromDate:(NSDate *)from toDate:(NSDate *)to
{
    
    return ([self bytesFromDate:from toDate:to] * 8);
}

-(NSUInteger)bytesFromDate:(NSDate *)from toDate:(NSDate *)to
{
    if ([from earlierDate:Start] && [to laterDate:End])
        return self.packetLength;
    return 0;
}

-(NSUInteger)samplesFromDate:(NSDate *)from toDate:(NSDate *)to
{
    if ((from && [from laterDate:End]) || (to && [to earlierDate:Start]))
        return 0; // out of range
    return self.numberOfSamples;
}

//
// simple scaled acsessor
//
- (NSUInteger)bytes
{
    return self.packetLength;
}

- (double)kbytes
{
    return ((double)[self bytes]) * 1.0E-3;
}

- (double)Mbytes
{
    return ((double)[self bytes]) * 1.0E-6;
}

- (double)Gbytes
{
    return ((double)[self bytes]) * 1.0E-9;
}

- (NSUInteger)bits
{
    return (self.packetLength * 8);
}

- (double)kbits
{
    return ((double)[self bits]) * 1.0E-3;
}

- (double)Mbits
{
    return ((double)[self bits]) * 1.0E-6;
}

- (double)Gbits
{
    return ((double)[self bits]) * 1.0E-9;
}

//
// smart string representations
//
- (NSString *)bytesString
{
    if (self.packetLength < 1000)
        return [NSString stringWithFormat:@"%3lu [bytes]", [self bytes]];
    else if (self.packetLength < 1000000)
        return [NSString stringWithFormat:@"%4.1f [kbytes]", [self kbytes]];
    else if (self.packetLength < 1000000000)
        return [NSString stringWithFormat:@"%4.1f [Mbytes]", [self Mbytes]];
    
    return [NSString stringWithFormat:@"%.1f [Gbytes]", [self Gbytes]];
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
    self.End = self.Start;
}

- (NSUInteger)msStart
{
    if (!self.Start)
        return 0;
    
    return date2msec(self.Start);
}

- (NSUInteger)msEnd
{
    if (!self.End)
        return 0;
    
    return date2msec(self.End);
}

//
// NSCopying protocol
//
- (id)copyWithZone:(NSZone *)zone
{
    TrafficSample *new = [[TrafficSample alloc] init];
    
    new->numberOfSamples = self.numberOfSamples;
    new->packetLength = self.packetLength;
    new->Start = self.Start;
    new->End = self.End;
    new->parent = nil;
    
    return new;
}

//
// runtime support
//
- (NSString *)description
{
    return [NSString stringWithFormat:@"TrafficData(%llu samples, %@)",
            self.numberOfSamples, [self bytesString]];
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"TrafficData: %llu samples, %@, From %@ To %@, parent=%@",
            self.numberOfSamples, [self bytesString],
            [self.Start description],
            [self.End description],
            [self.parent description]];
}

- (void)dumpTree:(BOOL)root
{
    [self writeDebug:@"obj%d [shape=point];\n", self.objectID];
}

- (void)openDebugFile:(NSString *)fileName
{
    NSString *path;
    path = [NSString stringWithFormat:@"%@/%@", NSHomeDirectory(), fileName];
    
    NSFileManager *fmgr = [NSFileManager defaultManager];
    [fmgr createFileAtPath:path contents:nil attributes:nil];
    if (debugHandle) {
        [debugHandle synchronizeFile];
        [debugHandle closeFile];
        debugHandle = nil;
    }
    debugHandle = [NSFileHandle fileHandleForWritingAtPath:path];
    [debugHandle truncateFileAtOffset:0];
}

- (void)writeDebug:(NSString *)format, ...
{
    if (!debugHandle) {
        NSLog(@"No debug handle.");
    }
    NSString *contents;
    va_list args;
    
    va_start(args, format);
    contents = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [debugHandle writeData:[contents dataUsingEncoding:NSUTF8StringEncoding]];
}
@end
