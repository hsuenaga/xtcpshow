//
//  DataQueue.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>

#import "DataQueue.h"

#define ERR_FILTER 0.00001f

@implementation DataQueue
- (DataQueue *)init
{
	self = [super init];

	STAILQ_INIT(&head);
	_interval = 0.0f;
	sum_remain = 0.0f;

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

- (BOOL)addFloatValue:(float)value
{
	struct DataQueueEntry *entry;
	float new_sum;

	entry = (struct DataQueueEntry *)malloc(sizeof(*entry));
	if (entry == NULL)
		return FALSE;
	entry->data = value;
	new_sum = _sum + (value + sum_remain);
	sum_remain = (value + sum_remain) - (new_sum - _sum);
	_sum = new_sum;
	_count++;

	STAILQ_INSERT_TAIL(&head, entry, chain);
	return TRUE;
}

- (float)addFloatValue:(float)value withLimit:(size_t)limit
{
	float oldvalue = NAN;

	if (_count < limit)
		[self addFloatValue:value];
	else
		oldvalue = [self shiftFloatValueWithNewValue:value];

	return oldvalue;
}

- (BOOL)prependFloatValue:(float)value
{
	struct DataQueueEntry *entry;
	float new_sum;

	entry = (struct DataQueueEntry *)malloc(sizeof(*entry));
	if (entry == NULL)
		return FALSE;
	entry->data = value;
	new_sum = _sum + (value + sum_remain);
	sum_remain = (value + sum_remain) - (new_sum - _sum);
	_sum = new_sum;
	_count++;

	STAILQ_INSERT_HEAD(&head, entry, chain);
	return TRUE;
}

- (float)dequeueFloatValue
{
	struct DataQueueEntry *entry;
	float oldvalue, new_sum;

	if (STAILQ_EMPTY(&head)) {
		return NAN;
	}

	entry = STAILQ_FIRST(&head);
	STAILQ_REMOVE_HEAD(&head, chain);
	oldvalue = entry->data;
	free(entry);
	_count--;
	if (_count == 0) {
		_sum = 0.0;
		return oldvalue;
	}
	if (oldvalue == 0.0f || isnan(oldvalue))
		return oldvalue;

	new_sum = (_sum + sum_remain) - oldvalue;
	if (isnan(oldvalue) || isinf(oldvalue) || (new_sum / oldvalue) < ERR_FILTER) {
		float tmp_sum;

		new_sum = 0.0f;
		sum_remain = 0.0f;
		STAILQ_FOREACH(entry, &head, chain) {
			tmp_sum = new_sum + entry->data + sum_remain;
			sum_remain = (entry->data + sum_remain) - (tmp_sum - new_sum);
			new_sum = tmp_sum;
		}
	}
	_sum  = new_sum;

	return oldvalue;
}

- (float)shiftFloatValueWithNewValue:(float)newvalue
{
	float oldvalue;

	if (STAILQ_EMPTY(&head))
		return newvalue;

	oldvalue = [self dequeueFloatValue];
	[self addFloatValue:newvalue];

	return oldvalue;
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
	__block BOOL stop = FALSE;

	_sum = 0.0;
	sum_remain = 0.0;
	STAILQ_FOREACH(entry, &head, chain) {
		float new_sum;

		if (stop == TRUE)
			continue;
		block(&entry->data, idx, &stop);
		new_sum = _sum + entry->data + sum_remain;
		sum_remain = (entry->data + sum_remain) - (new_sum - _sum);
		_sum = new_sum;
		idx++;
	}
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
	_count = 0;
	_sum = 0.0;
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
	_count = 0;
	_sum = 0.0;
	sum_remain = 0.0;

	while(size-- && !STAILQ_EMPTY(&head)) {
		float new_sum;

		entry = STAILQ_FIRST(&head);
		STAILQ_REMOVE_HEAD(&head, chain);
		STAILQ_INSERT_TAIL(&temp, entry, chain);
		new_sum = _sum + (entry->data + sum_remain);
		sum_remain = (entry->data + sum_remain) - (new_sum - _sum);
		_sum = new_sum;
		_count++;
	}

	while(!STAILQ_EMPTY(&head)) {
		entry = STAILQ_FIRST(&head);
		STAILQ_REMOVE_HEAD(&head, chain);
		free(entry);
	}

	if (_count == 0)
		_sum = 0.0;

	memcpy(&head, &temp, sizeof(head));
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
		if (entry->data == NAN)
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

	return (_sum / (float)_count);
}
@end
