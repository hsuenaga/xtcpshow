//
//  GraphView.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include "math.h"

#import "GraphView.h"
#import "GraphData.h"

static void plot_mbps(NSRect, float, float,
		      unsigned int, unsigned int);
static void plot_trend(NSRect, float, float, float);

/*
 * plot bar graph
 */
static void plot_mbps(NSRect rect, float mbps, float max_mbps,
		      unsigned int n, unsigned int max_n)
{
//	NSBezierPath *path = [NSBezierPath bezierPath];
	NSGradient *grad;
	NSRect bar;
	float l, r, w, h;

	/* width and height of bar */
	w = rect.size.width / (float)max_n;
	h = rect.size.height * (mbps / max_mbps);
	if (h < 1.0)
		return; /* less than 1 pixel */

	/* left and right of bar */
	l = w * (float)n;
	r = l + w;
	if (r > rect.size.width)
		return;

	bar.origin.x = l;
	bar.origin.y = 0;
	bar.size.width = w;
	bar.size.height = h;

	grad = [[NSGradient alloc]
		initWithStartingColor:[NSColor blackColor]
		endingColor:[NSColor greenColor]];
	[grad drawInRect:bar angle:90.0];
}

static void plot_trend(NSRect rect, float y_max, float y_avg, float y_scale)
{
	NSBezierPath *path;
	float y;
	
	[[NSColor redColor] set];
	path = [NSBezierPath bezierPath];
	y = rect.size.height * (y_avg / y_scale);
	[path moveToPoint:NSMakePoint(0.0, y)];
	[path lineToPoint:NSMakePoint(rect.size.width, y)];
	[path stroke];
	
	[[NSColor blueColor] set];
	path = [NSBezierPath bezierPath];
	y = rect.size.height * (y_max / y_scale);
	[path moveToPoint:NSMakePoint(0.0, y)];
	[path lineToPoint:NSMakePoint(rect.size.width, y)];
	[path stroke];
}

@implementation GraphView
- (void)allocHist
{
	self->data = [[GraphData alloc] init];
	if (self->data == nil)
		NSLog(@"cannot alloc history");
	[self->data setBufferSize:DEF_BUFSIZ];
}

- (void)setWindowSize:(int)size
{
	window_size = size;
	
	if (window_size < 10)
		window_size = 10;
	else if (window_size > [self->data size])
		window_size = [self->data size];
}

- (void)setSMASize:(int)size
{
	sma_size = size;
	if (sma_size < 1)
		sma_size = 1;
	else if (sma_size > [self->data size])
		sma_size = [self->data size];
}

- (void)drawRect:(NSRect)dirty_rect
{
	NSGraphicsContext* gc = [NSGraphicsContext currentContext];
	NSString *title;
	NSMutableDictionary *attr;
	NSRect rect = [self bounds];
	float res, y_scale, auto_range;
	__block float y_max, y_avg;
	__block int winsz;
	int smasz;

	NSDisableScreenUpdates();
	res = self->resolution * 1000.0; // [ms]

	/* clear screen */
	[[NSColor blackColor] set];
	NSRectFill(rect); // rect may smaller than widget size.

	/* caclulate size */
	winsz = self->window_size;
	smasz = self->sma_size;
	y_scale = [self->data maxWithItems:winsz withSMA:smasz];
	if (y_scale < 5.0)
		auto_range = 2.5;
	else
		auto_range = 5;
	y_scale = (auto_range * floor(y_scale / auto_range)) + auto_range;
	
	/* show matrix */
	[[NSColor whiteColor] set];
	for (int i = 1; i < 5; i++) {
		CGFloat pattern[2] = {5.0, 5.0};
		NSBezierPath *path;
		float y = (rect.size.height / 5.0) * (float)i;
		
		path = [NSBezierPath bezierPath];
		[path setLineDash:pattern count:2 phase:0.0];
		[path moveToPoint:NSMakePoint(0, y)];
		[path lineToPoint:NSMakePoint(rect.size.width, y)];
		[path stroke];
	}
	for (int i = 1; i < 5; i++) {
		CGFloat pattern[2] = {5.0, 5.0};
		NSBezierPath *path;
		float x = (rect.size.width / 5.0) * (float)i;
		
		path = [NSBezierPath bezierPath];
		[path setLineDash:pattern count:2 phase:0.0];
		[path moveToPoint:NSMakePoint(x, 0)];
		[path lineToPoint:NSMakePoint(x, rect.size.height)];
		[path stroke];
	}
	
	/* plot bar graph */
	y_max = 0.0;
	y_avg = 0.0;
	[[NSColor greenColor] set];
	[self->data blockForEach:^(float value, int i) {
		if (y_max < value)
			y_max = value;
		y_avg += value;
		[gc saveGraphicsState];
		plot_mbps(rect, value, y_scale, i, winsz);
		[gc restoreGraphicsState];
		return 0;
	} WithItems:winsz WithSMA:smasz];
	if ([self->data size] > 0)
		y_avg = y_avg / (float)[self->data size];
	else
		y_avg = 0.0;
	
	/* bar graph params */
	title =
	[NSString stringWithFormat:@" Y-Scale %6.3f [Mbps] / X-Scale %6.1f [ms] / SMA %6.1f [ms] / Avg %6.3f [Mbps] ",
	 y_scale, (res * winsz), (res * smasz), y_avg];
	attr = [[NSMutableDictionary alloc] init];
	[attr setValue:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	[attr setValue:[NSFont fontWithName:@"Menlo Regular" size:12] forKey:NSFontAttributeName];
	[title drawAtPoint:NSMakePoint(0.0, 0.0) withAttributes:attr];

	/* plot trend line */
	plot_trend(rect, y_max, y_avg, y_scale);
	
	NSEnableScreenUpdates();
}

- (void)addSnap:(float)snap trendData:(float)trend resolusion:(float)res
{
	self->snap_mbps = snap;
	self->trend_mbps = trend;
	self->resolution = res;
	
	/* delegate to history store */
	[self->data addFloat:snap];
}
@end
