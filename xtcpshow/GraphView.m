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

NSString *const RANGE_AUTO = @"Auto";
NSString *const RANGE_PEEKHOLD = @"PeekHold";
NSString *const RANGE_MANUAL = @"Manual";

@implementation GraphView
- (void)initData
{
	self.data = nil;
	self.TargetTimeOffset = 0;
	self.TargetTimeLength = 0;
	self.viewOffset = 0;
	self.scalingMode = DISCRETE_SCALING;
	graph_gradient = [[NSGradient alloc]
			  initWithStartingColor:[NSColor clearColor]
			  endingColor:[NSColor greenColor]];
}

- (void)updateRange
{
	float max;
	float new_range;
	float unit;

	max = [[self data] maxFloatValue];

	/* auto ranging */
	if (range_mode == RANGE_MANUAL) {
		max = manual_range;
	} else if (range_mode == RANGE_PEEKHOLD) {
		if (peak_range < max)
			peak_range = max;
		max = peak_range;
	}

	/* scaling */
	if (max < 0.5) {
		unit = 0.5;
	}
	else if (max < 1.0) {
		unit = 1.0;
	}
	else if (max < 5.0) {
		unit = 2.5;
	}
	else {
		unit = 5.0;
	}
	new_range = (unit * (floor(max / unit) + 1.0));

	if (new_range != y_range)
		needRedrawImage = TRUE;

	y_range = new_range; // [Mbps]
	x_range = _samplingInterval * _TargetTimeLength * 1000.0f; // [ms]
	sma_range = _samplingInterval * _SMASize * 1000.0f; // [ms]
}

- (float)setRange:(NSString *)mode withRange:(float)range
{

	range_mode = mode;
	peak_range = 0.0f;
	if (mode == RANGE_MANUAL)
		manual_range = range;

	[self updateRange];

	return y_range;
}

- (float)setRange:(NSString *)mode withStep:(int)step
{
	float range;

	if (step < 0) {
		step = 0;
		range = 0.0; // suprress compiler
	}

	else if (step == 0) {
		range = 0.5;
	}
	else if (step == 1) {
		range = 1.0;
	}
	else if (step == 2) {
		range = 2.5;
	}
	else {
		range = 5.0f * (float)(step - 1);
	}
	return [self setRange:mode withRange:range];
}

- (void)drawGraph
{
	DataQueue *data;
	NSRect rect;

	[NSGraphicsContext saveGraphicsState];
	rect = [self bounds];
	data = [self data];
	[data enumerateFloatUsingBlock:^(float value, NSUInteger idx, BOOL *stop) {
		NSRect bar;

		if (idx > rect.size.width) {
			*stop = YES;
			return;
		}
		bar.origin.x = (float)idx;
		bar.origin.y = 0;
		bar.size.width = 1.0;
		bar.size.height = value * _bounds.size.height / y_range;
		if (bar.size.height < 1.0)
			return;
		[graph_gradient drawInRect:bar angle:90.0];
	}];
	[NSGraphicsContext restoreGraphicsState];
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

- (void)drawGuide
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

- (void)drawGrid
{
	NSRect rect = [self bounds];

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
	[self drawGrid];

	/* plot bar graph */
	[self drawGraph];

	/* bar graph params */
	title =
	[NSString stringWithFormat:@" Y-Range %6.3f [Mbps] / X-Range %6.1f [ms] / MA %6.1f [ms] / Avg %6.3f [Mbps] ",
	 y_range, x_range, sma_range,
	 [[self data] averageFloatValue]];
	[self drawText:title atPoint:NSMakePoint(0.0, 0.0)];

	/* plot trend line */
	[self drawGuide];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)importData:(DataQueue *)data
{
	DataResampler *sampler = [[DataResampler alloc] init];
	NSUInteger viewSMA;
	float unit_conv;

	// remember sampling interval of original data
	_samplingInterval = [data interval];

	[sampler importData:data];
	[sampler clipQueueTail:[self dataRangeTail]];
	if (_scalingMode == DISCRETE_SCALING)
		[sampler discreteScaleQueue:[self dataScale]];
	else
		[sampler linearScaleQueue:[self dataScale]];

	if (_SMASize > 1) {
		viewSMA = ceil((float)_SMASize * [self dataScale]);
		if (viewSMA > 1)
			[sampler triangleMovingAverage:viewSMA];
	}
	[sampler clipQueueTail:[self viewRange]];

	// convert [bytes] => [Mbps]
	unit_conv = 8.0f / [[sampler data] interval]; // [bps]
	unit_conv = unit_conv / 1000.0f / 1000.0f; // [Mbps]

	[sampler scaleAllValue:unit_conv];

	_data = [sampler data];
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

- (NSRange)dataRangeTail
{
	NSRange range;

	// range from 'tail'
	range.location = _TargetTimeOffset;
	range.length = _TargetTimeLength + _SMASize;
	return range;
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
