//
//  GraphView.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include "math.h"

#import "GraphView.h"
#import "DataQueue.h"
#import "DataResampler.h"

@implementation GraphView
- (void)initData
{
	self.data = nil;
	self.TargetTimeOffset = 0;
	self.TargetTimeLength = 0;
	self.viewOffset = 0;
}

- (void)redrawGraphImage
{
	DataQueue *data;
	NSRect rect;
	
	[NSGraphicsContext saveGraphicsState];
	rect = [self bounds];
	data = [self data];
	[data enumerateFloatUsingBlock:^(float value, NSUInteger idx, BOOL *stop) {
		if (idx > rect.size.width) {
			*stop = YES;
			return;
		}
		[self plotBPS:value
		       maxBPS:y_range
			atPos:(int)idx
		       maxPos:rect.size.width];
	}];
	
	[NSGraphicsContext restoreGraphicsState];
}

- (void)updateRange
{
	float max;
	float new_range;
	float unit;

	max = [[self data] maxFloatValue];

	/* auto ranging */
	if (range_mode == RANGE_MANUAL) {
		new_range = manual_range;
	} else if (range_mode == RANGE_PEEKHOLD) {
		if (peek_range < max)
			peek_range = max;
		max = peek_range;
	}

	/* scaling */
	if (range_mode != RANGE_MANUAL) {
		if (max < 1.0) {
			unit = 1.0;
		}
		else if (max < 5.0) {
			unit = 2.5;
		}
		else {
			unit = 5.0;
		}
		new_range = (unit * (floor(max / unit) + 1.0));
	}
	
	if (new_range != y_range)
		needRedrawImage = TRUE;
	
	y_range = new_range; // [mBPS]
	x_range = self.resolution * self.TargetTimeLength; // [ms]
	sma_range = self.resolution * self.SMASize; // [ms]
}

- (void)setRange:(NSString *)mode withRange:(float)range
{
	if ([mode isEqualToString:@"Auto"]) {
		NSLog(@"Auto Range mode");
		range_mode = RANGE_AUTO;
		peek_range = 0.0;
		manual_range = 0.0;
	}
	else if ([mode isEqualToString:@"PeakHold"]) {
		NSLog(@"Peak Hold Range mode");
		range_mode = RANGE_PEEKHOLD;
		peek_range = 0.0;
		manual_range = 0.0;
	}
	else if ([mode isEqualToString:@"Manual"]) {
		NSLog(@"Manual Range mode");
		range_mode = RANGE_MANUAL;
		peek_range = 0.0;
		manual_range = range;
	}
	return;
}

- (void)drawText: (NSString *)t atPoint:(NSPoint) p
{
	NSMutableDictionary *attr;
	
	attr = [[NSMutableDictionary alloc] init];
	[attr setValue:[NSColor whiteColor]
		forKey:NSForegroundColorAttributeName];
	[attr setValue:[NSFont fontWithName:@"Menlo Regular" size:12]
		forKey:NSFontAttributeName];
	[t drawAtPoint:p withAttributes:attr];
}

- (void)plotBPS:(float)mbps
	 maxBPS:(float)max_mbps
	  atPos:(unsigned int)n
	 maxPos:(int)max_n
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
	bar.size.width = w;
	bar.size.height = h;
	
	grad = [[NSGradient alloc]
		initWithStartingColor:[NSColor clearColor]
		endingColor:[NSColor greenColor]];
	[grad drawInRect:bar angle:90.0];
}

- (void)plotTrend
{
	NSRect rect;
	NSBezierPath *path;
	NSString *marker;
	float y, y_max, y_avg;
	
	[NSGraphicsContext saveGraphicsState];
	
	rect = [self bounds];
	y_max = [[self data] maxFloatValue];
	y_avg = [[self data] averageFloatValue];

	[[NSColor redColor] set];
	path = [NSBezierPath bezierPath];
	y =
	rect.size.height * (y_avg / y_range);
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
	
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawAll
{
	NSRect rect = [self bounds];
	NSString *title;

	[NSGraphicsContext saveGraphicsState];

	/* clear screen */
	[[NSColor clearColor] set];
	NSRectFill(rect);
	
	/* caclulate size */
	[self updateRange];
	
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
	[self redrawGraphImage];
	
	/* bar graph params */
	title =
	[NSString stringWithFormat:@" Y-Range %6.3f [Mbps] / X-Range %6.1f [ms] / SMA %6.1f [ms] / Avg %6.3f [Mbps] ",
	 y_range, x_range, sma_range,
	 [[self data] averageFloatValue]];
	[self drawText:title atPoint:NSMakePoint(0.0, 0.0)];
	
	/* plot trend line */
	[self plotTrend];
	
	[NSGraphicsContext restoreGraphicsState];
}

- (float)dataScale
{
	float scale;
	float target_length;
	
	target_length = (float)_TargetTimeLength;
	if (target_length < 2.0)
		target_length = 2.0; // at least 2 sample
	
	scale = (float)[self bounds].size.width;
	scale = scale / target_length;
	
	return scale;
}

- (NSRange)viewRange
{
	NSRange range;
	
	range.location = [self viewOffset];
	range.length = (int)[self bounds].size.width;
	return range;
}

- (void)drawRect:(NSRect)dirty_rect
{
	NSDisableScreenUpdates();
	[self drawAll];
	NSEnableScreenUpdates();
}

@end
