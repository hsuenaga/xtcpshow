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
#import "DerivedData.h"

#define ROUND (0.001)

@implementation ComputeQueueEntry
@synthesize data;

- (ComputeQueueEntry *)initWithData:(id)data withTimestamp:(NSDate *)ts
{
    self = [super initWithData:data withTimestamp:ts];
    if ([data isMemberOfClass:[DerivedData class]]) {
        self.data = data;
    }
    else if ([data isMemberOfClass:[TrafficData class]]){
        TrafficData *tdata = (TrafficData *)data;
        DerivedData *sdata = [DerivedData dataWithInt:(int)[tdata bytesReceived]
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

+ (ComputeQueueEntry *)entryWithData:(id)data withTimestamp:(NSDate *)ts
{
    return [[ComputeQueueEntry alloc] initWithData:data withTimestamp:ts];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[ComputeQueueEntry alloc]
            initWithData:[self.data copy]
            withTimestamp:self.timestamp];
}
@end

@interface ComputeQueue ()
- (double)roundDouble:(double)value;
@end

@implementation ComputeQueue
@synthesize count;

- (double)roundDouble:(double)value
{
    double rvalue = floor(value / prec) * prec;
    if (rvalue == -0.0)
        rvalue = fabs(rvalue);
    return rvalue;
}

- (ComputeQueue *)initWithZeroFill:(size_t)size
{
    if (size == 0)
        return nil;
    
    self = [super initWithSize:size];
    [self zeroFill];
    prec = ROUND;
    
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
// protected
//
- (void)addSumState:(double)value
{
	double new_value;
	double delta;
	
    if (isnan(value) || isinf(value)) {
		[self invalidValueException];
        return;
    }
	
	if (value == 0.0)
		return;

	value = value + add_remain;
	new_value = sumState + value;
    if (isinf(new_value) || isnan(new_value)) {
        [self invalidValueException];
        return;
    }
    delta = new_value - sumState;
	add_remain = value - delta;
	sumState = new_value;
}

- (void)subSumState:(double)value
{
    return [self addSumState:(-value)];
}

- (void)clearSumState
{
	sumState = 0.0;
	add_remain = 0.0;
}

- (double)sum
{
	double sum;
	sum = sumState + add_remain;
    return sum;
}

//
// public
//
- (void)zeroFill
{
	self.head = self.tail = nil;
	self.count = 0;
    DerivedData *zero = [DerivedData dataWithSingleDouble:0.0];
    NSDate *now = [NSDate date];
    for (int i = 0; i < self.size; i++) {
        [self enqueue:zero withTimestamp:now];
    }
    [self clearSumState];
}

- (DerivedData *)enqueue:(DerivedData *)data withTimestamp:(NSDate *)ts
{
    if (data) {
        [self addSumState:[data doubleValue]];
    }
    
    ComputeQueueEntry *add = [ComputeQueueEntry entryWithData:data withTimestamp:ts];
    ComputeQueueEntry *sub = (ComputeQueueEntry *)[self enqueueEntry:add];
    if (sub == nil)
        return nil;
    if (![sub isMemberOfClass:[ComputeQueueEntry class]]) {
        NSException *ex = [NSException
                           exceptionWithName:@"inconsitent queue"
                           reason:@"not a DataQueueEntry"
                           userInfo:nil];
        @throw ex;
    }
    [self subSumState:[sub.data doubleValue]];
    
    return sub.data;
}

- (DerivedData *)dequeue
{
    ComputeQueueEntry *entry;

    entry = (ComputeQueueEntry *)[self dequeueEntry];
	[self subSumState:[entry.data doubleValue]];
	return entry.data;
}

- (ComputeQueue *)copy
{
    ComputeQueue *new = [ComputeQueue queueWithSize:self.size];

    for (QueueEntry *entry = self.head; entry; entry = entry.next) {
        [new enqueue:[entry copy] withTimestamp:[entry timestamp]];
    }

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
        DerivedData *walk = entry.content;
		if (max < walk.numberOfSamples)
			max = walk.numberOfSamples;
	}
	return max;
}

- (double)maxDoubleValue
{
	QueueEntry *entry;
	double max = 0.0;

	for (entry = self.head; entry; entry = entry.next) {
        DerivedData *walk = entry.content;
		double value = [walk doubleValue];

		if (isnan(value))
			[self invalidValueException];

		if (max < value)
			max = value;
	}
    return max;
}

- (double)averageDoubleValue
{
    if (self.count == 0) {
        NSLog(@"queue is empty");
        NSLog(@"queue size is %zu", self.size);
		return 0.0;

    }
    double avg = [self sum] / (double)self.count;
    return [self roundDouble:avg];
}

- (double)standardDeviation
{
	double avg = [self averageDoubleValue];
	double variance = 0.0;

    if (self.count < 1)
        return 0.0;
    
    for (QueueEntry *entry = self.head; entry;
         entry = entry.next) {
        DerivedData *walk = entry.content;
		variance += pow((avg - walk.doubleValue), 2.0);
    }
	variance /= (self.count - 1);

    double deviation = sqrt(variance);
    return [self roundDouble:deviation];
}

- (void)invalidValueException
{
	NSException *ex = [NSException exceptionWithName:@"Invalid Value" reason:@"Value in DataQueue is not a number." userInfo:nil];

	@throw ex;
}
@end
