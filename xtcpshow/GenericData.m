// Copyright (c) 2018
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
//  GenericData.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/30.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//
#import <stdint.h>
#import "GenericData.h"

static NSUInteger newID = 0;
static NSFileHandle *debugHandle = nil;

@interface GenericData ()
@property (nonatomic) NSUInteger objectID;
@end

@implementation GenericData
@synthesize numberOfSamples;
@synthesize timestamp;
@synthesize dataFrom;
@synthesize dataTo;

+ (void)initialize
{
    newID = 0;
    debugHandle = nil;
}

+ (NSUInteger)newID
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
    [debugHandle truncateFileAtOffset:0];
}

+ (void)openDebugFile:(NSString *)fileName
{
    NSString *path = [NSString stringWithFormat:@"%@/%@", NSHomeDirectory(), fileName];
    
    NSFileManager *fmgr = [NSFileManager defaultManager];
    [fmgr createFileAtPath:path contents:nil attributes:nil];
    GenericData.debugHandle = [NSFileHandle fileHandleForWritingAtPath:path];
}

- (id)initWithMode:(enum enum_data_mode)mvalue numerator:(NSNumber *)nvalue denominator:(NSNumber *)dvalue dataFrom:(NSDate *)from dataTo:(NSDate *)to fromSamples:(NSUInteger)samples enableSaturation:(BOOL)saturation;
{
    self = [super initWithMode:mvalue
                    numerator:nvalue
                   denominator:dvalue
              enableSaturation:saturation];
    self.objectID = [self.class newID];
    self.numberOfSamples = samples;
    if (from) {
        self.timestamp = [GenericTime timeWithNSDate:from];
        self.dataFrom = self.timestamp;
    }
    else {
        self.timestamp = nil;
        self.dataFrom = nil;
    }

    if (to == from) {
        self.dataTo = self.timestamp;
    }
    else if (to){
        self.dataTo = [GenericTime timeWithNSDate:to];
    }
    else {
        self.dataTo = nil;
    }
    self.unitName = nil;
    return self;
}

- (id)init
{
    return [self initWithMode:DATA_NOVALUE
                    numerator:nil
                  denominator:nil
                     dataFrom:nil
                       dataTo:nil
                  fromSamples:0
             enableSaturation:TRUE];
}

+ (id)dataWithoutValue {
    GenericData *new = [self.class alloc];
    return [new initWithMode:DATA_NOVALUE
                   numerator:nil
                 denominator:nil
                    dataFrom:nil
                      dataTo:nil
                 fromSamples:0
            enableSaturation:TRUE];
}

+ (id)dataWithDouble:(double)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples
{
    GenericData *new = [self.class alloc];
    return [new initWithMode:DATA_DOUBLE
                   numerator:[NSNumber numberWithDouble:data]
                 denominator:nil
                    dataFrom:date
                      dataTo:nil
                 fromSamples:samples
            enableSaturation:TRUE];
}

+ (id)dataWithDouble:(double)data
{
    return [self.class dataWithDouble:data atDate:nil fromSamples:1];
}

+ (id)dataWithInteger:(NSInteger)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples
{
    GenericData *new = [self.class alloc];
    return [new initWithMode:DATA_INTEGER
                   numerator:[NSNumber numberWithInteger:data]
                 denominator:nil
                    dataFrom:date
                      dataTo:nil
                 fromSamples:samples
            enableSaturation:TRUE];
}

+ (id)dataWithInteger:(NSInteger)data
{
    return [self.class dataWithInteger:data atDate:nil fromSamples:1];
}

+ (id)dataWithUInteger:(NSUInteger)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples
{
    GenericData *new = [self.class alloc];
    return [new initWithMode:DATA_UINTEGER
                   numerator:[NSNumber numberWithInteger:data]
                 denominator:nil
                    dataFrom:date
                      dataTo:nil
                 fromSamples:samples
            enableSaturation:TRUE];
}

+ (id)dataWithUInteger:(NSUInteger)data
{
    return [self.class dataWithUInteger:data atDate:nil fromSamples:1];
}

- (NSDate *)timestamp
{
    return [self.timestamp date];
}

- (void)setTimestamp:(NSDate *)timestamp
{
    if (timestamp) {
        self->timestamp = [GenericTime timeWithNSDate:timestamp];
    }
    else {
        self->timestamp = nil;
    }
    return;
}

- (void)addData:(GenericData *)data withSign:(int)sign
{
    [super addNumber:data];
    self.dataFrom = [self.dataFrom earlierTime:data.dataFrom];
    self.dataTo = [self.dataTo laterTime:data.dataTo];
    if (sign > 0) {
        self.numberOfSamples += data.numberOfSamples;
    }
    else if (self.numberOfSamples >= data.numberOfSamples) {
        self.numberOfSamples -= data.numberOfSamples;
    }
    else {
        self.numberOfSamples = 0;
    }
}

- (void)addData:(GenericData *)data
{
    [self addData:data withSign:1];
    if (self.unitName == nil)
        self.unitName = data.unitName;
    else if (data.unitName && ![self.unitName isEqualToString:data.unitName])
        self.unitName = nil;
    return;
}

- (void)subData:(GenericData *)data
{
    [self addData:data withSign:-1];
    if (self.unitName == nil)
        self.unitName = data.unitName;
    else if (data.unitName && [self.unitName isEqualToString:data.unitName])
        self.unitName = nil;
    return;
}

- (void)mulData:(GenericData *)data
{
    [super mulNumber:data];
    if (self.unitName && data.unitName)
        self.unitName = [NSString stringWithFormat:@"%@*%@", self.unitName, data.unitName];
    else
        self.unitName = nil;
}

- (void)divData:(GenericData *)data
{
    [super divNumber:data];
    if (self.unitName && data.unitName)
        self.unitName = [NSString stringWithFormat:@"%@/%@", self.unitName, data.unitName];
    else
        self.unitName = nil;
}

//
// NSCopying protocol
//
- (id)copyWithZone:(NSZone *)zone
{
    GenericData *new = [super copyWithZone:zone];

    new->timestamp = self->timestamp;
    new->dataFrom = self->dataFrom;
    new->dataTo = self->dataTo;
    new->numberOfSamples = self->numberOfSamples;

    return new;
}

//
// runtime support
//
- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ [%@]",
            [super description], self.unitName];
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"%@, timestamp:%@, dataFrom:%@, dataTo:%@, unit:%@",
            [super description],
            [self.timestamp description],
            [self.dataFrom description],
            [self.dataTo description],
            self.unitName];
}

//
// debug
//
- (void)dumpTree:(BOOL)root
{
    [self writeDebug:@"obj%lu [shape=point];\n", self.objectID];
}

- (void)writeDebug:(NSString *)format, ...
{
    if (!debugHandle) {
        NSLog(@"%@ [obj%lu] No debug handle.", self.class, self.objectID);
        return;
    }

    NSString *contents;
    va_list args;
    va_start(args, format);
    contents = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [debugHandle writeData:[contents dataUsingEncoding:NSUTF8StringEncoding]];
}
@end
