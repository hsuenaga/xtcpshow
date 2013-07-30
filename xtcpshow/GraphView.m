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

@implementation GraphView
- (void)drawText: (NSString *)t atPoint:(NSPoint) p
{
	NSMutableDictionary *attr;
	
	attr = [[NSMutableDictionary alloc] init];
	[attr setValue:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	[attr setValue:[NSFont fontWithName:@"Menlo Regular" size:12] forKey:NSFontAttributeName];
	[t drawAtPoint:p withAttributes:attr];
}

- (void)plotBPS:(float)mbps maxBPS:(float)max_mbps atPos:(unsigned int)n maxPos:(int)max_n
{
	NSGradient *grad;
	NSRect bar, rect;
	float l, r, w, h;
	
	rect = [self bounds];

	/* width and height of bar */
	h = floor(rect.size.height * (mbps / max_mbps));
	if (h < 1.0)
		return; // less than 1 pixel
	w = floor(rect.size.width / (float)max_n);
	if (w < 1.0)
		w = 1.0;
	
	/* left and right of bar */
	l = floor(w * (float)n);
	r = floor(l + w);
	if (r > rect.size.width)
		return;
	
	bar.origin.x = l;
	bar.origin.y = 0;
	bar.size.width = w + 1.0;
	bar.size.height = h;
	
	grad = [[NSGradient alloc]
		initWithStartingColor:[NSColor blackColor]
		endingColor:[NSColor greenColor]];
	[grad drawInRect:bar angle:90.0];
}

- (void)plotTrend:(float)y_max withAvg:(float)y_avg withRange:(float)y_range
{
	NSRect rect;
	NSBezierPath *path;
	NSString *marker;
	float y;
	
	rect = [self bounds];

	[[NSColor redColor] set];
	path = [NSBezierPath bezierPath];
	y = rect.size.height * (y_avg / y_range);
	[path moveToPoint:NSMakePoint(0.0, y)];
	[path lineToPoint:NSMakePoint(rect.size.width, y)];
	[path stroke];
	
	[[NSColor blueColor] set];
	path = [NSBezierPath bezierPath];
	y = rect.size.height * (y_max / y_range);
	[path moveToPoint:NSMakePoint(0.0, y)];
	[path lineToPoint:NSMakePoint(rect.size.width, y)];
	[path stroke];
	
	/* max maker */
	if (y < (rect.size.height / 5))
		y = (rect.size.height / 5);
	else if (y > ((rect.size.height / 5) * 4))
		y = (rect.size.height / 5) * 4;
	
	marker = [NSString stringWithFormat:@" Max %6.3f", y_max];
	[self drawText:marker atPoint:NSMakePoint(0.0, y)];
}

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
	NSRect rect = [self bounds];
	NSString *title;
	float res, y_range, x_range, auto_range;
	__block float y_max, y_avg;
	__block int winsz, width;
	int smasz;

	NSDisableScreenUpdates();
	res = self->resolution * 1000.0; // [ms]

	/* clear screen */
	[[NSColor blackColor] set];
	NSRectFill(rect);

	/* caclulate size */
	winsz = self->window_size;
	smasz = self->sma_size;
	[self->data setSMASize:sma_size];
	
	/* auto ranging */
	y_max = [self->data maxWithRange:winsz];
	if (y_max < 1.0)
		auto_range = 1.0;
	else if (y_max < 5.0)
		auto_range = 2.5;
	else
		auto_range = 5.0;
	y_range = (auto_range * (floor(y_max / auto_range) + 1.0));
	x_range = res * winsz;
	
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
	y_avg = 0.0;
	width = rect.size.width;
	[[NSColor greenColor] set];
	[self->data forEach:^(float value, int w) {
		y_avg += value;
		[gc saveGraphicsState];
		[self plotBPS:value
		       maxBPS:y_range
			atPos:w
		       maxPos:width];
		[gc restoreGraphicsState];
		return 0;
	} withRange:winsz withWidth:width];
	
	/* caclulate total average */
	if ([self->data size] > 0)
		y_avg = y_avg / (float)[self->data size];
	else
		y_avg = 0.0;
	
	/* bar graph params */
	title =
	[NSString stringWithFormat:@" Y-Range %6.3f [Mbps] / X-Range %6.1f [ms] / SMA %6.1f [ms] / Avg %6.3f [Mbps] ",
	 y_range, x_range, (res * smasz), y_avg];
	[self drawText:title atPoint:NSMakePoint(0.0, 0.0)];
	
	/* plot trend line */
	[self plotTrend:y_max withAvg:y_avg withRange:y_range];
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
