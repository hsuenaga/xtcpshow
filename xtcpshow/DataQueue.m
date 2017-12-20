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
#import "DataQueueEntry.h"
#import "SamplingData.h"

#undef DEBUG_COUNTER

#define REFRESH_THR 1000 // [samples]

#ifdef DEBUG_COUNTER
#define CHECK_COUNTER(x) [(x) assertCounting]
#else
#define CHECK_COUNTER(x) // nothing
#endif

@implementation DataQueue
- (DataQueue *)initWithZeroFill:(int)size
{
    self = [super init];
    if (size)
        [self zeroFill:size];
    refresh_count = REFRESH_THR;
    
    return self;
}

- (DataQueue *)init
{
    return [self initWithZeroFill:0];
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
	for (entry = _head; entry; entry = entry.next) {
		float value, new_value;

		value = [entry.content floatValue];
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
- (void)zeroFill:(size_t)size
{
	_head = _tail = nil;
	_count = 0;
	for (int i = 0; i < size; i++)
		[self addDataEntry:[SamplingData dataWithSingleFloat:0.0f]];
	[self refreshSumState];
	CHECK_COUNTER(self);
}

- (void)addDataEntry:(SamplingData *)data
{
	DataQueueEntry *entry;

	if (!data)
		return;
	entry = [DataQueueEntry entryWithData:data];

	if (_tail) {
		_tail.next = entry;
		_tail = entry;
	}
	else {
		_head = _tail = entry;
	}
	[self addSumState:[data floatValue]];
	_count++;
	CHECK_COUNTER(self);
}

-(SamplingData *)addDataEntry:(SamplingData *)entry withLimit:(size_t)limit
{
	if (_count < limit) {
		[self addDataEntry:entry];
		return nil;
	}

	return [self shiftDataWithNewData:entry];
}

- (SamplingData *)dequeueDataEntry
{
	DataQueueEntry *entry;

	if (!_head)
		return nil;

	entry = _head;
	_head = entry.next;
	entry.next = nil;
	if (!_head)
		_tail = nil;
	if (_last_read == entry)
		_last_read = nil;
	[self subSumState:[entry.content floatValue]];
	_count--;

	CHECK_COUNTER(self);
	return entry.content;
}

- (SamplingData *)shiftDataWithNewData:(SamplingData *)entry
{
	[self addDataEntry:entry];
	return [self dequeueDataEntry];
}

- (SamplingData *)readNextData
{
	DataQueueEntry *entry;

	if (!_head)
		return nil;

	if (_last_read && _last_read.next == nil)
		return nil; // no new data arrived.

	if (!_last_read) {
		entry = [_head copy];
		entry.next = nil;
		_last_read = _head;
	}
	else {
		entry = [_last_read.next copy];
		entry.next = nil;
		_last_read = _last_read.next;
	}

	return entry.content;
}

- (void)seekToDate:(NSDate *)date
{
	if (!_head)
		return;
	_last_read = nil;

	for (DataQueueEntry *entry = _head; entry;
	     entry = entry.next)
	{
		NSDate *seek = entry.content.timestamp;

		if ([date laterDate:seek] == date) {
			_last_read = entry;
			continue;
		}
		break;
	}
}


- (void)rewind
{
	_last_read = nil;
}

- (void)enumerateDataUsingBlock:(void (^)(SamplingData *data, NSUInteger, BOOL *))block
{
	DataQueueEntry *entry;
	BOOL stop = FALSE;
	NSUInteger idx = 0;

	add = sub = add_remain = sub_remain = 0.0f;
	for (entry = _head; entry; entry = entry.next) {
		float v, new_add;

		if (!stop)
			block(entry.content, idx, &stop);
		
		v = [entry.content floatValue] + add_remain;
		new_add = add + v;
		add_remain = (new_add - add) - v;
		add = new_add;
		idx++;
	}
	refresh_count = REFRESH_THR;
	CHECK_COUNTER(self);
}

- (DataQueue *)copy
{
	DataQueueEntry *entry;
	DataQueue *new = [[DataQueue alloc] init];

	for (entry = _head; entry; entry = entry.next)
		[new addDataEntry:[entry copy]];
	[new refreshSumState];

	CHECK_COUNTER(self);
	return new;
}

- (BOOL)isEmpty
{
	if (!_head)
		return TRUE;

	return FALSE;
}

- (NSUInteger)maxSamples
{
	DataQueueEntry *entry;
	NSUInteger max = 0;

	for (entry = _head; entry; entry = entry.next) {
		if (max < entry.content.numberOfSamples)
			max = entry.content.numberOfSamples;
	}
	return max;
}

- (float)maxFloatValue
{
	DataQueueEntry *entry;
	float max = 0.0;

	for (entry = _head; entry; entry = entry.next) {
		float value = [entry.content floatValue];

		if (isnan(value))
			[self invalidValueException];

		if (max < value)
			max = value;
	}
	return max;
}

- (float)averageFloatValue
{
	if (_count == 0)
		return 0.0;
    float avg = [self sum] / (float)_count;
    if (avg < 0.001f) {
        avg = 0.0f;
    }
    return avg;
}

- (float)standardDeviation
{
	float avg = [self averageFloatValue];
	float variance = 0.0;

    for (DataQueueEntry *entry = _head; entry;
	     entry = entry.next)
		variance += pow((avg - entry.content.floatValue), 2.0);
	variance /= (_count - 1);

    float deviation = sqrtf(variance);
    if (deviation < 0.001f) {
        deviation = 0.0f;
    }
	return sqrtf(variance);
}

- (NSDate *)lastDate
{
	if (!_tail)
		return nil;
	return _tail.content.timestamp;
}

- (NSDate *)firstDate
{
	if (!_head)
		return nil;
	return _head.content.timestamp;
}

- (NSDate *)nextDate
{
	if (!_head)
		return nil;

	if (!_last_read)
		return _head.content.timestamp;

	if (!_last_read.next)
		return nil;

	return _last_read.next.content.timestamp;
}

- (void)assertCounting
{
	DataQueueEntry *entry;
	NSUInteger idx = 0;

	for (entry = _head; entry; entry = entry.next)
		idx++;

	NSAssert(idx == _count, @"counter(%lu) and entries(%lu) are mismatched", _count, idx);
}

- (void)invalidValueException
{
	NSException *ex = [NSException exceptionWithName:@"Invalid Value" reason:@"Value in DataQueue is not a number." userInfo:nil];

	@throw ex;
}

- (void)invalidChainException:(NSUInteger)idx
{
	NSString *message;

	message = [NSString stringWithFormat:@"counter(%lu) and entry(%lu) are mismatched", _count, idx];
	NSException *ex = [NSException exceptionWithName:@"Invalid Chain" reason:message userInfo:nil];

	@throw ex;
}
@end
