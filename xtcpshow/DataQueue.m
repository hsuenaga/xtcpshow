//
//  DataQueue.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>

#import "DataQueue.h"

@implementation DataQueue
- (DataQueue *)init
{
	self = [super init];
	
	STAILQ_INIT(&head);
	return self;
}

- (BOOL)addFloatValue:(float)value
{
	struct DataQueueEntry *entry;
	
	entry = (struct DataQueueEntry *)malloc(sizeof(*entry));
	if (entry == NULL)
		return FALSE;
	entry->data = value;
	_sum += value;
	_count++;
	
	STAILQ_INSERT_TAIL(&head, entry, chain);
	return TRUE;
}

- (float)dequeueFloatValue
{
	struct DataQueueEntry *entry;
	float oldvalue;
	
	if (STAILQ_EMPTY(&head)) {
		return NAN;
	}

	entry = STAILQ_FIRST(&head);
	STAILQ_REMOVE_HEAD(&head, chain);
	oldvalue = entry->data;
	free(entry);
	
	_sum -= oldvalue;
	_count--;
	if (_count == 0)
		_sum = 0.0;
	
	return oldvalue;
}

- (float)shiftFloatValueWithNewValue:(float)newvalue
{
	struct DataQueueEntry *entry;
	float oldvalue;
	
	entry = STAILQ_FIRST(&head);
	STAILQ_REMOVE_HEAD(&head, chain);
	oldvalue = entry->data;
	_sum -= oldvalue;
	
	entry->data = newvalue;
	STAILQ_INSERT_TAIL(&head, entry, chain);
	_sum += newvalue;

	return oldvalue;
}

- (void)enumerateFloatUsingBlock:(void(^)(float value, NSUInteger idx,  BOOL *stop))block
{
	struct DataQueueEntry *entry;
	NSUInteger idx = 0;
	
	STAILQ_FOREACH(entry, &head, chain) {
		BOOL stop = FALSE;
		
		block(entry->data, idx, &stop);
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
