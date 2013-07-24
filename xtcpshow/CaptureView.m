//
//  CaptureView.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import "CaptureView.h"
#import "Capture.h"

static void plot_mbps(NSRect, float, float,
		      unsigned int, unsigned int);
static void plot_trend(NSRect, float, float);

/*
 * History of graph view
 */
struct history_entry {
	float value;
	TAILQ_ENTRY(history_entry) tq_link;
};

@implementation CaptureHistory
- (CaptureHistory *)init
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

- (void)blockForEach:(void(^)(float, int, int))callback
{
	struct history_entry *h;
	int i = 0;

	TAILQ_FOREACH(h, &self->history, tq_link) {
		callback(h->value, i++, self->cur_hist);
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

/*
 * plot bar graph
 */
static void plot_mbps(NSRect rect, float mbps, float max_mbps,
	       unsigned int n, unsigned int max_n)
{
	NSBezierPath *path;
	float l, r, w, h;

	/* width and height of bar */
	w = rect.size.width / (float)max_n;
	h = rect.size.height * (mbps / max_mbps);
	if (h < MIN_FILTER)
		return;

	/* left and right of bar */
	l = w * (float)n;
	r = l + w;
	if (r > rect.size.width)
		return;

	[[NSColor greenColor] set];
	path = [NSBezierPath bezierPath];

	[path moveToPoint:NSMakePoint(l, 0.0)];
	[path lineToPoint:NSMakePoint(l, h)];
	[path lineToPoint:NSMakePoint(r, h)];
	[path lineToPoint:NSMakePoint(r, 0.0)];
	[path closePath];
	[path fill];
}

static void plot_trend(NSRect rect, float mbps, float max_mbps)
{
	NSBezierPath *path = [NSBezierPath bezierPath];
	float y;
	
	[[NSColor redColor] set];
	y = rect.size.height * (mbps / max_mbps);
	[path moveToPoint:NSMakePoint(0.0, y)];
	[path lineToPoint:NSMakePoint(rect.size.width, y)];
	[path stroke];
}

@implementation CaptureView
- (void)allocHist
{
	self->hist = [[CaptureHistory alloc] init];
	if (self->hist == nil)
		NSLog(@"cannot alloc history");
	[self->hist setBufferSize:NHIST];
}

- (void)drawRect:(NSRect)rect
{
	NSGraphicsContext* gc = [NSGraphicsContext currentContext];
	NSString *title;
	NSMutableDictionary *attr;
	float mbps, trend, res, max_mbps;
	__block float avg_mbps;

	mbps = [[self model] mbps];
	trend = [[self model] aged_mbps];
	res = [[self model] resolution] * 1000; // [ms]
	max_mbps = [self->hist max];
	
	/* clear screen */
	[[NSColor blackColor] set];
	NSRectFill(rect);
	
	/* plot bar graph */
	avg_mbps = 0.0;
	[self->hist blockForEach:^(float value, int i, int max) {
		[gc saveGraphicsState];
		plot_mbps(rect, value, max_mbps, i, max);
		avg_mbps += value;
		[gc restoreGraphicsState];
	}];
	if ([self->hist size] > 0)
		avg_mbps = avg_mbps / (float)[self->hist size];
	else
		avg_mbps = 0.0;

	/* bar graph params */
	title =
	[NSString stringWithFormat:@" MAX %3.3f [Mbps] / AVG %3.3f [Mbps] / Res %2.1f [ms] ", max_mbps, avg_mbps, res];
	attr = [[NSMutableDictionary alloc] init];
	[attr setValue:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	[attr setValue:[NSFont fontWithName:@"Menlo Regular" size:16] forKey:NSFontAttributeName];
	[title drawAtPoint:NSMakePoint(0.0, 0.0) withAttributes:attr];

	/* plot trend line */
	plot_trend(rect, avg_mbps, max_mbps);
	
	/* update history */
	[self->hist addFloat:mbps];
}
@end
