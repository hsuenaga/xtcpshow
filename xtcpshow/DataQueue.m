//
//  DataQueue.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>

#import "DataQueue.h"
#import "DataEntry.h"

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
	[self clearSumState];

	return self;
}

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
	DataEntry *entry;

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

- (void)addDataEntry:(DataEntry *)entry
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

-(DataEntry *)addDataEntry:(DataEntry *)entry withLimit:(size_t)limit
{
	if (_count < limit) {
		[self addDataEntry:entry];
		return nil;
	}

	return [self shiftDataWithNewData:entry];
}

- (void)addFloatValue:(float)value
{
	[self addDataEntry:[DataEntry dataWithFloat:value atTimeval:NULL]];
}

- (float)addFloatValue:(float)value withLimit:(size_t)limit
{
	DataEntry *old;

	old = [self addDataEntry:[DataEntry dataWithFloat:value atTimeval:NULL] withLimit:limit];
	if (old)
		return [old floatValue];

	return 0.0f;
}

- (BOOL)prependFloatValue:(float)value
{
	DataEntry *entry;

	entry = [DataEntry dataWithFloat:value atTimeval:NULL];
	if (_head) {
		entry.next = _head;
		_head = entry;
	}
	else {
		_head = _tail = entry;
	}
	[self addSumState:value];
	_count++;
	
	CHECK_COUNTER(self);
	return TRUE;
}

- (DataEntry *)dequeueDataEntry
{
	DataEntry *entry;

	if (!_head)
		return nil;

	entry = _head;
	_head = entry.next;
	entry.next = nil;
	if (!_head)
		_tail = nil;
	[self subSumState:[entry floatValue]];
	_count--;

	CHECK_COUNTER(self);
	return entry;
}

- (float)dequeueFloatValue
{
	return [[self dequeueDataEntry] floatValue];
}

- (DataEntry *)shiftDataWithNewData:(DataEntry *)entry
{
	[self addDataEntry:entry];
	return [self dequeueDataEntry];
}

- (float)shiftFloatValueWithNewValue:(float)newvalue
{
	return [[self shiftDataWithNewData:[DataEntry dataWithFloat:newvalue atTimeval:NULL]] floatValue];
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

- (void)enumerateFloatUsingBlock:(void(^)(float value, NSUInteger idx,  BOOL *stop))block
{
	DataEntry *entry;
	NSUInteger idx = 0;

	for (entry = _head; entry; entry = entry.next) {
		BOOL stop = FALSE;
		float value;

		value = [entry floatValue];
		block(value, idx, &stop);
		if (stop == TRUE)
			break;
		idx++;
	}
	CHECK_COUNTER(self);
}

- (void)enumerateFloatWithTimeUsingBlock:(void(^)(float value, NSDate *date, NSUInteger idx,  BOOL *stop))block
{
	DataEntry *entry;
	NSUInteger idx = 0;

	for (entry = _head; entry; entry = entry.next) {
		BOOL stop = FALSE;

		block([entry floatValue], [entry timestamp], idx, &stop);
		if (stop == TRUE)
			break;
		idx++;
	}
	CHECK_COUNTER(self);
}

- (void)enumerateDataUsingBlock:(void (^)(DataEntry *data, NSUInteger, BOOL *))block
{
	DataEntry *entry;
	NSUInteger idx = 0;

	for (entry = _head; entry; entry = entry.next) {
		BOOL stop = FALSE;

		block(entry, idx, &stop);
		if (stop == TRUE)
			break;
		idx++;
	}
	CHECK_COUNTER(self);
}

- (void)replaceValueUsingBlock:(void(^)(float *value, NSUInteger idx, BOOL *stop))block
{
	DataEntry *entry;
	NSUInteger idx = 0;

	_count = 0;
	for (entry = _head; entry; entry = entry.next) {
		BOOL stop = FALSE;
		float value;

		value = [entry floatValue];
		block(&value, idx, &stop);
		if (stop == TRUE)
			break;
		[entry setFloatValue:value];
		_count++;
		idx++;
	}
	entry.next = nil;
	[self refreshSumState];
	CHECK_COUNTER(self);
}

- (void)zeroFill:(size_t)size
{
	[self deleteAll];
	for (int i = 0; i < size; i++)
		[self addFloatValue:0.0];
	CHECK_COUNTER(self);
}

- (void)deleteAll
{
	_head = _tail = nil;
	[self clearSumState];
	_count = 0;
}

- (DataQueue *)copy
{
	DataEntry *entry;
	DataQueue *new = [[DataQueue alloc] init];

	for (entry = _head; entry; entry = entry.next)
		[new addDataEntry:[entry copy]];
	[new refreshSumState];

	CHECK_COUNTER(self);
	return new;
}

- (void)removeFromHead:(size_t)size
{
	while (size-- && _head)
		[self dequeueFloatValue];
	CHECK_COUNTER(self);
}

- (void)clipFromHead:(size_t)size
{
	DataEntry *entry;

	[self clearSumState];
	_count = 0;

	for (entry = _head; entry; entry = entry.next) {
		_count++;
		if (size-- == 0) {
			entry.next = nil;
			_tail = entry;
			break;
		}
	}
	CHECK_COUNTER(self);
}

- (BOOL)isEmpty
{
	if (!_head)
		return TRUE;

	return FALSE;
}

- (NSUInteger)maxSamples
{
	DataEntry *entry;
	NSUInteger max = 0;

	for (entry = _head; entry; entry = entry.next) {
		if (max < entry.numberOfSamples)
			max = entry.numberOfSamples;
	}
	return max;
}

- (float)maxFloatValue
{
	DataEntry *entry;
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

- (float)averageFloatValue
{
	if (_count == 0)
		return 0.0;

	return ([self sum] / (float)_count);
}

- (void)assertCounting
{
	DataEntry *entry;
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
