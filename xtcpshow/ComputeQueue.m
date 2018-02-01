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
//  DataQueue.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>

#import "ComputeQueue.h"
#import "TrafficData.h"

@implementation ComputeQueue
@synthesize count;

- (ComputeQueue *)initWithZeroFill:(size_t)size
{
    if (size == 0)
        return nil;
    
    self = [super initWithSize:size];
    [self zeroFill];
    sumData = [GenericData dataWithoutValue];
    return self;
}

- (ComputeQueue *)init
{
    return [self initWithZeroFill:0];
}

//
// allocator
//
+ (ComputeQueue *)queueWithSize:(size_t)size
{
    return [[ComputeQueue alloc] initWithSize:size];
}

+ (ComputeQueue *)queueWithZero:(size_t)size
{
    return [[ComputeQueue alloc] initWithZeroFill:size];
}

//
// public
//
- (void)clearSumState {
    self->sumData = [GenericData dataWithoutValue];
}

- (void)zeroFill
{
	self.head = self.tail = nil;
	self.count = 0;
    GenericData *zero = [GenericData dataWithInteger:0 atDate:[NSDate date] fromSamples:0];
    for (int i = 0; i < self.size; i++) {
        [self enqueue:zero withTimestamp:[zero timestamp]];
    }
    [self clearSumState];
}

- (id)enqueue:(id)data withTimestamp:(NSDate *)ts
{
    if (data && [data isKindOfClass:[GenericData class]]) {
        [data castToFractionWithDenominator:FRAC_RES];
        [self->sumData addData:data];
    }
    
    QueueEntry *add = [QueueEntry entryWithData:data withTimestamp:ts];
    QueueEntry *sub = [self enqueueEntry:add];
    if (sub == nil)
        return nil;
    if (![sub isKindOfClass:[add class]]) {
        NSException *ex = [NSException
                           exceptionWithName:@"inconsitent queue"
                           reason:@"unknown entry in queue"
                           userInfo:nil];
        @throw ex;
    }
    if ([sub.content isKindOfClass:[GenericData class]]) {
        [self->sumData subData:sub.content];
    }
    
    return sub.content;
}

- (id)dequeue
{
    QueueEntry *entry;

    entry = (QueueEntry *)[self dequeueEntry];
    if (entry.content && [entry.content isKindOfClass:[GenericData class]]) {
        [self->sumData subData:entry.content];
    }
	return entry.content;
}

- (id)copyWithZone:(NSZone *)zone
{
    ComputeQueue *new = [super copyWithZone:zone];

    new->sumData = [self->sumData copy];
    
	return new;
}

- (BOOL)isEmpty
{
	if (!self.head)
		return TRUE;

	return FALSE;
}

- (NSUInteger)maxSamples
{
	QueueEntry *entry;
	NSUInteger max = 0;

	for (entry = self.head; entry; entry = entry.next) {
        if ([entry.content isKindOfClass:[GenericData class]]) {
            if (max < [entry.content numberOfSamples])
                max = [entry.content numberOfSamples];
        }
	}
	return max;
}

- (double)maxDoubleValue
{
	QueueEntry *entry;
	double max = 0.0;

	for (entry = self.head; entry; entry = entry.next) {
        if ([entry.content isKindOfClass:[GenericData class]]) {
            double value = [entry.content doubleValue];

            if (isnan(value))
                [self invalidValueException];

            if (max < value)
                max = value;
        }
	}
    return max;
}

- (GenericData *)averageData
{
    GenericData *data = [self->sumData copy];
    [data divInteger:self.count];
    return data;
}

- (double)standardDeviation
{
	double avg = [[self averageData] doubleValue];
	double variance = 0.0;

    if (self.count < 1)
        return 0.0;
    
    for (QueueEntry *entry = self.head; entry; entry = entry.next) {
        if ([entry.content isKindOfClass:[GenericData class]]) {
            variance += pow((avg - [entry.content doubleValue]), 2.0);
        }
    }
	variance /= (double)(self.count - 1);

    return sqrt(variance);
}

- (void)invalidValueException
{
	NSException *ex = [NSException exceptionWithName:@"Invalid Value" reason:@"Value in DataQueue is not a number." userInfo:nil];

	@throw ex;
}
@end
