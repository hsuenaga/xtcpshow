//
//  DataQueue.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>

#import "DataQueue.h"
#import "SamplingData.h"

#undef DEBUG_COUNTER

#define REFRESH_THR 1000 // [samples]

#ifdef DEBUG_COUNTER
#define CHECK_COUNTER(x) [(x) assertCounting]
#else
#define CHECK_COUNTER(x) // nothing
#endif

@implementation DataQueue
- (DataQueue *)init
{
	self = [super init];

	_head = nil;
	_tail = nil;
	_count = 0;
	refresh_count = REFRESH_THR;
	last_read = nil;
	[self clearSumState];

	return self;
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
	SamplingData *entry;

	[self clearSumState];
	for (entry = _head; entry; entry = entry.next) {
		float value, new_value;

		value = [entry floatValue];
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
		[self addDataEntry:[SamplingData dataWithFloat:0.0f]];
	[self refreshSumState];
	CHECK_COUNTER(self);
}

- (void)addDataEntry:(SamplingData *)entry
{
	if (!entry)
		return;

	if (_tail) {
		_tail.next = entry;
		_tail = entry;
	}
	else {
		_head = _tail = entry;
	}
	[self addSumState:[entry floatValue]];
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
	SamplingData *entry;

	if (!_head)
		return nil;

	entry = _head;
	_head = entry.next;
	entry.next = nil;
	if (!_head)
		_tail = nil;
	if (last_read == entry)
		last_read = nil;
	[self subSumState:[entry floatValue]];
	_count--;

	CHECK_COUNTER(self);
	return entry;
}

- (SamplingData *)shiftDataWithNewData:(SamplingData *)entry
{
	[self addDataEntry:entry];
	return [self dequeueDataEntry];
}

- (SamplingData *)readNextData
{
	SamplingData *entry;

	if (!_head)
		return nil;

	if (last_read && last_read.next == nil)
		return nil; // no new data arrived.

	if (!last_read) {
		entry = [_head copy];
		entry.next = nil;
		last_read = _head;
	}
	else {
		entry = [last_read.next copy];
		entry.next = nil;
		last_read = last_read.next;
	}

	return entry;
}

- (void)rewind
{
	last_read = nil;
}

- (void)enumerateDataUsingBlock:(void (^)(SamplingData *data, NSUInteger, BOOL *))block
{
	BOOL stop = FALSE;
	SamplingData *entry;
	NSUInteger idx = 0;

	add = sub = add_remain = sub_remain = 0.0f;
	for (entry = _head; entry; entry = entry.next) {
		float v, new_add;

		if (!stop)
			block(entry, idx, &stop);
		
		v = [entry floatValue] + add_remain;
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
	SamplingData *entry;
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
	SamplingData *entry;
	NSUInteger max = 0;

	for (entry = _head; entry; entry = entry.next) {
		if (max < entry.numberOfSamples)
			max = entry.numberOfSamples;
	}
	return max;
}

- (float)maxFloatValue
{
	SamplingData *entry;
	float max = 0.0;

	for (entry = _head; entry; entry = entry.next) {
		float value = [entry floatValue];

		if (isnan(value))
			[self invalidValueException];

		if (max < value)
			max = value;
	}
	return max;
}

- (NSDate *)lastDate
{
	if (!_tail)
		return nil;
	return _tail.timestamp;
}

- (NSDate *)firstDate
{
	if (!_head)
		return nil;
	return _head.timestamp;
}

- (NSDate *)nextDate
{
	if (!_head)
		return nil;

	if (!last_read)
		return _head.timestamp;

	if (!last_read.next)
		return nil;

	return last_read.next.timestamp;
}

- (float)averageFloatValue
{
	if (_count == 0)
		return 0.0;

	return ([self sum] / (float)_count);
}

- (void)assertCounting
{
	SamplingData *entry;
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
