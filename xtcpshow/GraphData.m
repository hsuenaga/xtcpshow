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

static float sma_init_sum(struct hist_head *, int);
static float sma_update_sum(struct hist_head *, float, float);
static void sma_free_sum(struct hist_head *);

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

- (void)setSMASize:(int)size
{
	sma_size = size;
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

- (void)forEach:(int(^)(float, int))callback withRange:(int)n withWidth:(int)w
{
	struct hist_head sma_db;
	struct history_entry *h;
	float sma_sum, unit;
	int i, last_block, off;

	sma_sum = sma_init_sum(&sma_db, sma_size);
	if (sma_sum == NAN)
		return;
	
	off = self.size - n;
	unit = (float)n / (float)w;
	i = 0;
	last_block = -1;
	TAILQ_FOREACH(h, &self->history, tq_link) {
		float sma;
		int next_block;
		
		/* update SMA  */
		sma_sum = sma_update_sum(&sma_db, h->value, sma_sum);
		sma = sma_sum / (float)sma_size;
		if (off > 0) {
			/* skip */
			off--;
			continue;
		}
		next_block = (int)(floor((float)i / unit));
		if (next_block != last_block) {
			if (callback(sma, next_block) < 0) {
				break;
			}
			last_block = next_block;
		}
		i++;
	}
	
	sma_free_sum(&sma_db);
}

- (float)maxWithRange:(int)n
{
	__block float max = 0.0;
	
	[self forEach:^(float value, int idx) {
		if (max < value)
			max = value;
		return 0;
	} withRange:n withWidth:n];
			    
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

static float sma_init_sum(struct hist_head *hd, int size)
{
	if (size < 1)
		size = 1;
	
	TAILQ_INIT(hd);
	for (int i = 0; i < size; i++) {
		struct history_entry *ent =
		    (struct history_entry *)malloc(sizeof(*ent));
		if (ent == NULL)
			return NAN;
		ent->value = 0.0;
		TAILQ_INSERT_HEAD(hd, ent, tq_link);
	}

	return 0.0;
}

static float sma_update_sum(struct hist_head *hd,
			    float value, float sum)
{
	struct history_entry *ent;
	
	/* sub old value */
	ent = TAILQ_FIRST(hd);
	TAILQ_REMOVE(hd, ent, tq_link);
	sum = sum - ent->value;
	if (sum < MIN_FILTER)
		sum = 0.0;
	
	/* add new value */
	ent->value = value;
	TAILQ_INSERT_TAIL(hd, ent, tq_link);
	sum = sum + ent->value;
	
	if (sum < MIN_FILTER)
		return 0.0;
	return sum;
}

static void sma_free_sum(struct hist_head *hd)
{
	struct history_entry *ent;
	
	while ( (ent = TAILQ_FIRST(hd))) {
		TAILQ_REMOVE(hd, ent, tq_link);
		free(ent);
	}
}