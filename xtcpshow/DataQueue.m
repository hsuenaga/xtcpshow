//
//  DataQueue.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>

#import "DataQueue.h"

#define REFRESH_THR 1000 // [samples]

@implementation DataQueue
- (DataQueue *)init
{
	self = [super init];

	STAILQ_INIT(&head);
	_interval = 0.0f;
	_count = 0;
	refresh_count = REFRESH_THR;
	[self clearSumState];

	return self;
}

- (void)dealloc
{
	struct DataQueueEntry *entry;

	while (!STAILQ_EMPTY(&head)) {
		entry = STAILQ_FIRST(&head);
		STAILQ_REMOVE_HEAD(&head, chain);
		free(entry);
	}
}

- (void)addSumState:(float)value
{
	float new_value;
	float delta;
	
	if (isnan(value) || isinf(value))
		return; // XXX: exception
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
		return; // XXX: exception
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
	struct DataQueueEntry *entry;

	[self clearSumState];
	STAILQ_FOREACH(entry, &head, chain) {
		float value, new_value;

		if (isnan(entry->data) || isinf(entry->data))
			continue;

		value = entry->data + add_remain;
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

- (BOOL)addFloatValue:(float)value
{
	struct DataQueueEntry *entry;

	entry = (struct DataQueueEntry *)malloc(sizeof(*entry));
	if (entry == NULL)
		return FALSE;
	entry->data = value;

	STAILQ_INSERT_TAIL(&head, entry, chain);
	[self addSumState:value];
	_count++;

	return TRUE;
}

- (float)addFloatValue:(float)value withLimit:(size_t)limit
{
	if (_count < limit) {
		[self addFloatValue:value];
		return 0.0f;
	}

	return [self shiftFloatValueWithNewValue:value];
}

- (BOOL)prependFloatValue:(float)value
{
	struct DataQueueEntry *entry;

	entry = (struct DataQueueEntry *)malloc(sizeof(*entry));
	if (entry == NULL)
		return FALSE;
	entry->data = value;

	STAILQ_INSERT_HEAD(&head, entry, chain);
	[self addSumState:value];
	_count++;

	return TRUE;
}

- (float)dequeueFloatValue
{
	struct DataQueueEntry *entry;
	float oldvalue;

	if (STAILQ_EMPTY(&head)) {
		return nanf(__func__);
	}

	entry = STAILQ_FIRST(&head);
	STAILQ_REMOVE_HEAD(&head, chain);
	oldvalue = entry->data;
	free(entry);
	_count--;

	if (_count == 0)
		[self clearSumState];
	else
		[self subSumState:oldvalue];

	return oldvalue;
}

- (float)shiftFloatValueWithNewValue:(float)newvalue
{
	[self addFloatValue:newvalue];
	return [self dequeueFloatValue];
}

- (void)enumerateFloatUsingBlock:(void(^)(float value, NSUInteger idx,  BOOL *stop))block
{
	struct DataQueueEntry *entry;
	NSUInteger idx = 0;

	STAILQ_FOREACH(entry, &head, chain) {
		BOOL stop = FALSE;

		block(entry->data, idx, &stop);
		if (stop == TRUE)
			break;
		idx++;
	}
}

- (void)replaceValueUsingBlock:(void(^)(float *value, NSUInteger idx, BOOL *stop))block
{
	struct DataQueueEntry *entry;
	NSUInteger idx = 0;

	_count = 0;
	STAILQ_FOREACH(entry, &head, chain) {
		BOOL stop = FALSE;

		block(&entry->data, idx, &stop);
		if (stop == TRUE)
			break;
		_count++;
		idx++;
	}
	[self refreshSumState];
}

- (void)zeroFill:(size_t)size
{
	[self deleteAll];
	for (int i = 0; i < size; i++)
		[self addFloatValue:0.0];
}

- (void)deleteAll
{
	struct DataQueueEntry *entry;

	while (!STAILQ_EMPTY(&head)) {
		entry = STAILQ_FIRST(&head);
		STAILQ_REMOVE_HEAD(&head, chain);
		free(entry);
	}
	
	[self clearSumState];
	_count = 0;
}

- (DataQueue *)duplicate
{
	struct DataQueueEntry *entry;
	DataQueue *new = [[DataQueue alloc] init];

	new.interval = _interval;
	STAILQ_FOREACH(entry, &head, chain) {
		[new addFloatValue:entry->data];
	}
	
	return new;
}

- (void)removeFromHead:(size_t)size
{
	while (size-- && !STAILQ_EMPTY(&head))
		[self dequeueFloatValue];
}

- (void)clipFromHead:(size_t)size
{
	struct DataQueueEntry *entry;
	struct DataQueueHead temp;

	STAILQ_INIT(&temp);
	[self clearSumState];
	_count = 0;

	while(size-- && !STAILQ_EMPTY(&head)) {
		entry = STAILQ_FIRST(&head);
		STAILQ_REMOVE_HEAD(&head, chain);
		STAILQ_INSERT_TAIL(&temp, entry, chain);
		[self addSumState:entry->data];
		_count++;
	}

	while(!STAILQ_EMPTY(&head)) {
		entry = STAILQ_FIRST(&head);
		STAILQ_REMOVE_HEAD(&head, chain);
		free(entry);
	}

	head = temp;
}

- (BOOL)isEmpty
{
	if (STAILQ_EMPTY(&head))
		return TRUE;
	return FALSE;
}

- (float)maxFloatValue
{
	struct DataQueueEntry *entry;
	float max = 0.0;

	STAILQ_FOREACH(entry, &head, chain) {
		if (isnan(entry->data))
			continue;
		if (max < entry->data)
			max = entry->data;
	}
	return max;
}

- (float)averageFloatValue
{
	if (_count == 0)
		return 0.0;

	return ([self sum] / (float)_count);
}
@end
