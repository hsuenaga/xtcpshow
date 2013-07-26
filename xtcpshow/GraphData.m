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
	     WithSMA:(int)sma
{
	struct hist_head sma_hd;
	struct history_entry *h, *sma_h;
	float sma_sum;
	int i = 0, off;
	
	if (sma < 1)
		sma = 1;
	TAILQ_INIT(&sma_hd);
	for (i = 0; i < sma; i++) {
		sma_h = (struct history_entry *)malloc(sizeof *sma_h);
		sma_h->value = 0.0;
		TAILQ_INSERT_HEAD(&sma_hd, sma_h, tq_link);
	}

	off = self.size - n;
	sma_sum = 0.0;
	TAILQ_FOREACH(h, &self->history, tq_link) {
		float value;
		
		/* delete last SMA value */
		sma_h = TAILQ_FIRST(&sma_hd);
		TAILQ_REMOVE(&sma_hd, sma_h, tq_link);
		sma_sum -= sma_h->value;

		if (sma_sum < MIN_FILTER)
			sma_sum = 0.0;

		/* setup new SMA value */
		if (h->value < MIN_FILTER)
			sma_h->value = 0.0;
		else
			sma_h->value = h->value;

		/* update SMA */
		TAILQ_INSERT_TAIL(&sma_hd, sma_h, tq_link);
		sma_sum += sma_h->value;
		value = sma_sum / (float)sma;
		
		if (i < off) {
			i++;
			continue;
		}
		if (callback(value, (i - off)) < 0) {
			break;
		}
		i++;
	}
	
	while ( (sma_h = TAILQ_FIRST(&sma_hd))) {
		TAILQ_REMOVE(&sma_hd, sma_h, tq_link);
		free(sma_h);
	}
}

- (float)maxWithItems:(int)n withSMA:(int)sma
{
	__block float max = 0.0;
	
	[self blockForEach:^(float value, int idx) {
		if (max < value)
			max = value;
		return 0;
	} WithItems:n WithSMA:sma];
			    
	return max;
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