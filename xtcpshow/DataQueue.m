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

#import "DataQueue.h"
#import "TrafficSample.h"
#import "SamplingData.h"

#define REFRESH_THR 1000 // [samples]

@implementation DataQueueEntry
@synthesize data;

- (DataQueueEntry *)initWithData:(id)data withTimestamp:(NSDate *)ts
{
    self = [super initWithData:data withTimestamp:ts];
    if ([data isMemberOfClass:[SamplingData class]]) {
        self.data = data;
    }
    else if ([data isMemberOfClass:[TrafficSample class]]){
        TrafficSample *tdata = (TrafficSample *)data;
        SamplingData *sdata = [SamplingData dataWithInt:(int)[tdata packetLength]
                                                 atDate:[tdata timestamp]
                                            fromSamples:[tdata numberOfSamples]];
        self.data = sdata;
    }
    else {
        NSException *ex = [NSException exceptionWithName:@"Invalid Data"
                                                  reason:@"class of data is unknown"
                                                userInfo:nil];
        @throw ex;
    }
    return self;
}

+ (DataQueueEntry *)entryWithData:(id)data withTimestamp:(NSDate *)ts
{
    return [[DataQueueEntry alloc] initWithData:data withTimestamp:ts];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[DataQueueEntry alloc]
            initWithData:[self.data copy]
            withTimestamp:self.timestamp];
}
@end

@implementation DataQueue
@synthesize count;

- (DataQueue *)initWithZeroFill:(size_t)size
{
    if (size == 0)
        return nil;
    
    self = [super initWithSize:size];
    [self zeroFill];
    refresh_count = REFRESH_THR;
    
    return self;
}

- (DataQueue *)init
{
    return [self initWithZeroFill:0];
}

//
// allocator
//
+ (DataQueue *)queueWithSize:(size_t)size
{
    return [[DataQueue alloc] initWithSize:size];
}

+ (DataQueue *)queueWithZero:(size_t)size
{
    return [[DataQueue alloc] initWithZeroFill:size];
}

//
// protected
//
- (void)addSumState:(float)value
{
	float new_value;
	float delta;
	
	if (isnan(value) || isinf(value))
		[self invalidValueException];
	
	if (value == 0.0f)
		return;
	if (refresh_count-- == 0) {
		[self refreshSumState];
		return;
	}

	value = value + add_remain;
	new_value = add + value;
	if (isinf(new_value) || isnan(new_value)) {
		[self refreshSumState];
		return;
	}
	delta = new_value - add;
	add_remain = value - delta;
	add = new_value;
}

- (void)subSumState:(float)value
{
	float new_value;
	float delta;

	if (isnan(value) || isinf(value))
		[self invalidValueException];
	
	if (value == 0.0f)
		return;
	if (refresh_count-- == 0) {
		[self refreshSumState];
		return;
	}
	
	value = value + sub_remain;
	new_value = sub + value;
	if (isinf(new_value) || isnan(new_value)) {
		[self refreshSumState];
		return;
	}
	
	delta = new_value - sub;
	sub_remain = value - delta;
	sub = new_value;
}

- (void)clearSumState
{
	add = 0.0f;
	sub = 0.0f;
	add_remain = 0.0f;
	sub_remain = 0.0f;
}

- (void)refreshSumState
{
	DataQueueEntry *entry;

	[self clearSumState];
	for (entry = (DataQueueEntry *)self.head; entry; entry = (DataQueueEntry *)entry.next) {
		float value, new_value;

		value = [entry.data floatValue];
		if (isnan(value) || isinf(value))
			[self invalidValueException];

		value = value + add_remain;
		new_value = add + value;
		add_remain = (new_value - add) - value;
		add = new_value;
	}
	refresh_count = REFRESH_THR;
}

- (float)sum
{
	float sum;
	// XXX: cancellation of significant digits

	sum = add_remain - sub_remain;
	sum += add - sub;
	return sum;
}

//
// public
//
- (void)zeroFill
{
	self.head = self.tail = nil;
	self.count = 0;
    SamplingData *zero = [SamplingData dataWithSingleFloat:0.0];
    NSDate *now = [NSDate date];
    for (int i = 0; i < self.size; i++) {
        [self enqueue:zero withTimestamp:now];
    }
	[self refreshSumState];
}

- (SamplingData *)enqueue:(SamplingData *)data withTimestamp:(NSDate *)ts
{
    if (data) {
        [self addSumState:[data floatValue]];
    }
    
    DataQueueEntry *add = [DataQueueEntry entryWithData:data withTimestamp:ts];
    DataQueueEntry *sub = (DataQueueEntry *)[self enqueueEntry:add];
    if (sub == nil)
        return nil;
    
    if (![sub isMemberOfClass:[DataQueueEntry class]]) {
        NSException *ex = [NSException
                           exceptionWithName:@"inconsitent queue"
                           reason:@"not a DataQueueEntry"
                           userInfo:nil];
        @throw ex;
    }
    [self subSumState:[sub.data floatValue]];
    
    return sub.data;
}

- (SamplingData *)dequeue
{
    DataQueueEntry *entry;

    entry = (DataQueueEntry *)[self dequeueEntry];
	[self subSumState:[entry.data floatValue]];
	return entry.data;
}

- (DataQueue *)copy
{
    DataQueue *new = [DataQueue queueWithSize:self.size];

    for (QueueEntry *entry = self.head; entry; entry = entry.next) {
        [new enqueue:[entry copy] withTimestamp:[entry timestamp]];
    }
    [new refreshSumState];

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
        SamplingData *walk = entry.content;
		if (max < walk.numberOfSamples)
			max = walk.numberOfSamples;
	}
	return max;
}

- (float)maxFloatValue
{
	QueueEntry *entry;
	float max = 0.0;

	for (entry = self.head; entry; entry = entry.next) {
        SamplingData *walk = entry.content;
		float value = [walk floatValue];

		if (isnan(value))
			[self invalidValueException];

		if (max < value)
			max = value;
	}
	return max;
}

- (float)averageFloatValue
{
	if (self.count == 0)
		return 0.0;
    float avg = [self sum] / (float)self.count;
    if (avg < 0.001f) {
        avg = 0.0f;
    }
    return avg;
}

- (float)standardDeviation
{
	float avg = [self averageFloatValue];
	float variance = 0.0;

    if (self.count < 1)
        return 0.0f;
    
    for (QueueEntry *entry = self.head; entry;
         entry = entry.next) {
        SamplingData *walk = entry.content;
		variance += pow((avg - walk.floatValue), 2.0);
    }
	variance /= (self.count - 1);

    float deviation = sqrtf(variance);
    if (deviation < 0.001f) {
        deviation = 0.0f;
    }
	return sqrtf(variance);
}


- (void)invalidValueException
{
	NSException *ex = [NSException exceptionWithName:@"Invalid Value" reason:@"Value in DataQueue is not a number." userInfo:nil];

	@throw ex;
}
@end
