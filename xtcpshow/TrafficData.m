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

static int newID = 0;
static NSFileHandle *debugHandle = nil;

//
// base class of traffic data
//
@interface TrafficData ()
@property (weak,atomic) TrafficData *newerSample;
@property (weak,atomic) TrafficData *olderSample;
- (id)init;
- (id)initAtTimeval:(struct timeval *)tv withPacketLength:(uint64_t)lengh;
@end

@implementation TrafficData
@synthesize objectID;
@synthesize parent;
@synthesize numberOfSamples;
@synthesize bytesReceived;
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
    if (tv) {
        self.Start = self.End = tv2date(tv);
        numberOfSamples = 1;
        bytesReceived = length;
        [self alignStartEnd];
    }
    
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
    TrafficData *new;
    
    new = [[TrafficData alloc] initAtTimeval:tv withPacketLength:length];
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
-(BOOL)dataAtDate:(NSDate *)date withBytes:(NSUInteger *)bytes withSamples:(NSUInteger *)samples
{
    if (!date || !self.Start) {
        *bytes = *samples = 0;
        return TRUE; // no date
    }
    
    if ([date isEqual:date] ||
        ([date laterDate:self.Start] == date && [date earlierDate:self.End] == date)) {
        *bytes = self.bytes;
        *samples = self.numberOfSamples;
        return TRUE;
    }
        
    return FALSE;
}
-(NSUInteger)bitsAtDate:(NSDate *)date
{
    
    return ([self bytesAtDate:date] * 8);
}

-(NSUInteger)bytesAtDate:(NSDate *)date
{
    if ([date isEqual:Start] ||
        ([date laterDate:Start] == date && [date earlierDate:End] == date))
        return self.bytesReceived;
    return 0;
}

-(NSUInteger)samplesAtDate:(NSDate *)date
{
    if ([date isEqual:Start] ||
        ([date laterDate:Start] == date && [date earlierDate:End] == date))
        return self.numberOfSamples;
    return 0;
}

-(NSDate *)timestamp
{
    return self.Start;
}

//
// simple scaled acsessor
//
- (NSUInteger)bytes
{
    return self.bytesReceived;
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
    return (self.bytesReceived * 8);
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
    if (self.bytesReceived < 1000)
        return [NSString stringWithFormat:@"%3lu [bytes]", [self bytes]];
    else if (self.bytesReceived < 1000000)
        return [NSString stringWithFormat:@"%4.1f [kbytes]", [self kbytes]];
    else if (self.bytesReceived < 1000000000)
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
    TrafficData *new = [[TrafficData alloc] init];
    
    new->numberOfSamples = self.numberOfSamples;
    new->bytesReceived = self.bytesReceived;
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
