//
//  GraphData.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>
#import "GraphData.h"

/*
 * History of graph view
 */
struct history_entry {
	float value;
	TAILQ_ENTRY(history_entry) tq_link;
};

@implementation GraphData
- (GraphData *)init
{
	TAILQ_INIT(&self->history);
	self->max_hist = 0;
	self->cur_hist = 0;
	return self;
}

- (void)setBufferSize:(int)size
{
	max_hist = size;
	cur_hist = 0;

	while (cur_hist < max_hist) {
		[self addFloat:0.0];
	}
}

- (int)size
{
	return self->cur_hist;
}

- (float)max
{
	struct history_entry *h;
	float max = 0.0;
	
	TAILQ_FOREACH(h, &self->history, tq_link) {
		if (max < h->value)
			max = h->value;
	}

	return max;
}

- (float)maxWithItems:(int)n
{
	struct history_entry *h;
	float max = 0.0;
	int i = 0, off;
	
	off = self.size - n;
	TAILQ_FOREACH(h, &self->history, tq_link)  {
		if (i < off) {
			i++;
			continue;
		}
		if (max < h->value)
			max = h->value;
	}
	return max;
}

- (void)addFloat:(float)value
{
	struct history_entry *h;
	
	if (self->cur_hist >= self->max_hist) {
		h = TAILQ_FIRST(&self->history);
		TAILQ_REMOVE(&self->history, h, tq_link);
	}
	else {
		h = malloc(sizeof(*h));
		if (h == NULL)
			return;
		self->cur_hist++;
	}
	h->value = value;

	TAILQ_INSERT_TAIL(&self->history, h, tq_link);
}

- (float)floatAtIndex:(int)index
{
	struct history_entry *h;
	
	TAILQ_FOREACH(h, &self->history, tq_link) {
		if (index == 0)
			return h->value;
		index--;
	}

	return 0.0;
}

- (void)blockForEach:(int(^)(float, int))callback WithItems:(int)n
{
	struct history_entry *h;
	int i = 0, off;

	off = self.size - n;
	TAILQ_FOREACH(h, &self->history, tq_link) {
		if (i < off) {
			i++;
			continue;
		}
		if (callback(h->value, (i - off)) < 0) {
			break;
		}
		i++;
	}
}

- (void)dealloc
{
	struct history_entry *h;
	
	while ( (h = TAILQ_FIRST(&self->history))) {
		TAILQ_REMOVE(&self->history, h, tq_link);
		free(h);
	}
}
@end