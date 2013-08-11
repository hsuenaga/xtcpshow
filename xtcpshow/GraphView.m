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
#import "DataEntry.h"

NSString *const RANGE_AUTO = @"Auto";
NSString *const RANGE_PEEKHOLD = @"PeekHold";
NSString *const RANGE_MANUAL = @"Manual";

@implementation GraphView
- (void)initData
{
	_data = nil;
	_showPacketMarker = TRUE;
	time_offset = 0;
	time_length = 0;
	
	graph_gradient = [[NSGradient alloc]
			  initWithStartingColor:[NSColor clearColor]
			  endingColor:[NSColor greenColor]];
}

- (void)updateRange
{
	float max;
	float new_range;

	max = [[self data] maxFloatValue];

	/* auto ranging */
	if (range_mode == RANGE_MANUAL) {
		if (manual_range <= 0.5f)
			new_range = 0.5f;
		else if (manual_range <= 1.0f)
			new_range = 1.0f;
		else if (manual_range <= 2.5f)
			new_range = 2.5f;
		else
			new_range =
			5.0f * (ceil(manual_range/5.0f));
	} else {
		if (range_mode == RANGE_PEEKHOLD) {
			if (peak_range < max)
				peak_range = max;
			max = peak_range;
		}

		/* automatic scaling */
		if (max < 0.5f)
			new_range = 0.5f;
		else if (max < 1.0f)
			new_range = 1.0f;
		else if (max < 2.5f)
			new_range = 2.5f;
		else
			new_range = 5.0f * (ceil(max / 5.0f));
	}
	y_range = new_range; // [Mbps]
	x_range = time_length * 1000.0f; // [ms]
	ma_range = sma_length * 1000.0f; // [ms]
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

	if (step < 1)
		range = 0.5;
	else if (step == 1)
		range = 1.0;
	else if (step == 2)
		range = 2.5;
	else
		range = (float)(5 * (step - 2));
	NSLog(@"step:%d range:%f", step, range);

	return [self setRange:mode withRange:range];
}

- (int)stepValueWithRange:(float)range
{
	int step;

	if (range < 1.0f)
		step = 0;
	else if (range < 2.5f)
		step = 1;
	else if (range < 5.0f)
		step = 2;
	else
		step = ((int)floor(range / 5.0f)) + 2;
	NSLog(@"range:%f step:%d", range, step);

	return step;
}

- (void)setTargetTimeLength:(int)value
{
	// UI resolution is 1/20 [sec]
	time_length = (NSTimeInterval)value / 20.0;
}

- (void)setMATimeLength:(int)value
{
	// UI resolution is 1/20 [sec]
	sma_length = (NSTimeInterval)value / 20.0;
}

- (void)drawGraph
{
	[NSGraphicsContext saveGraphicsState];
	[_data enumerateFloatUsingBlock:^(float value, NSUInteger idx, BOOL *stop) {
		NSRect bar;

		if (idx < GraphOffset)
			return;
		idx -= GraphOffset;

		if (idx > _bounds.size.width) {
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

- (void)drawXMark;
{
	[NSGraphicsContext saveGraphicsState];
	[[NSColor cyanColor] set];
	[_data enumerateDataUsingBlock:^(DataEntry *data, NSUInteger idx, BOOL *stop) {
		NSBezierPath *path;
		NSUInteger samples;
		float h;

		if (idx < XmarkOffset)
			return;
		idx -= XmarkOffset;

		if (idx > _bounds.size.width) {
			*stop = YES;
			return;
		}
		if ( (samples = [data numberOfSamples]) == 0)
			return;
		h = _bounds.size.height / (float)_maxSamples;
		h = h * (float)samples;
		path = [NSBezierPath bezierPath];
		[path moveToPoint:NSMakePoint((float)idx, 0.0f)];
		[path lineToPoint:NSMakePoint((float)idx, h)];
		[path setLineCapStyle:NSRoundLineCapStyle];
		[path stroke];
	}];

	[self drawText:[NSString stringWithFormat:@" Max %lu [packets/sample]", _maxSamples] atPoint:NSMakePoint(0.0f, _bounds.size.height - 14.0f)];

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
	float y;

	[NSGraphicsContext saveGraphicsState];

	rect = [self bounds];

	[[NSColor redColor] set];
	path = [NSBezierPath bezierPath];
	y =
	rect.size.height * (_averageValue / y_range);
	[path moveToPoint:NSMakePoint(0.0, y)];
	[path lineToPoint:NSMakePoint(rect.size.width, y)];
	[path stroke];

	[[NSColor blueColor] set];
	path = [NSBezierPath bezierPath];
	y = rect.size.height * (_maxValue / y_range);
	[path moveToPoint:NSMakePoint(0.0, y)];
	[path lineToPoint:NSMakePoint(rect.size.width, y)];
	[path stroke];

	/* max maker */
	if (y < (rect.size.height / 5))
		y = (rect.size.height / 5);
	else if (y > ((rect.size.height / 5) * 4))
		y = (rect.size.height / 5) * 4;

	marker = [NSString stringWithFormat:@" Max %6.3f [mbps]", _maxValue];
	[self drawText:marker atPoint:NSMakePoint(0.0, y)];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawGrid
{
	[NSGraphicsContext saveGraphicsState];
	[[NSColor whiteColor] set];
	for (int i = 1; i < 5; i++) {
		CGFloat pattern[2] = {5.0, 5.0};
		NSBezierPath *path;
		float y = (_bounds.size.height / 5.0) * (float)i;
		float x = (_bounds.size.width / 5.0) * (float)i;

		// vertical line
		path = [NSBezierPath bezierPath];
		[path setLineDash:pattern count:2 phase:0.0];
		[path moveToPoint:NSMakePoint(0, y)];
		[path lineToPoint:NSMakePoint(_bounds.size.width, y)];
		[path stroke];

		// horizontal line
		path = [NSBezierPath bezierPath];
		[path setLineDash:pattern count:2 phase:0.0];
		[path moveToPoint:NSMakePoint(x, 0)];
		[path lineToPoint:NSMakePoint(x, _bounds.size.height)];
		[path stroke];
	}
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

	/* update x/y axis */
	[self updateRange];

	/* show matrix */
	[self drawGrid];

	/* plot x mark */
	if (_showPacketMarker == TRUE)
		[self drawXMark];

	/* plot bar graph */
	[self drawGraph];

	/* bar graph params */
	title =
	[NSString stringWithFormat:@" Y-Range %6.3f [Mbps] / X-Range %6.1f [ms] / MA %6.1f [ms] / Avg %6.3f [Mbps] ",
	 y_range, x_range, ma_range,
	 [[self data] averageFloatValue]];
	[self drawText:title atPoint:NSMakePoint(0.0, 0.0)];

	/* plot trend line */
	[self drawGuide];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)importData:(DataQueue *)data
{
	DataResampler *sampler = [[DataResampler alloc] init];
	NSDate *start, *end;
	NSTimeInterval dataLength;
	NSUInteger viewSMA;
	float viewWidth;
	float unit_conv, tick;

	// calculate tick
	end = [data last_update];
	viewWidth = _bounds.size.width;
	dataLength = 0 - time_length - sma_length;
	start = [end dateByAddingTimeInterval:dataLength];
	tick = time_length / viewWidth; // [sec]

	// make bar graph
	[sampler importData:data];
	[sampler clipQueueFromDate:start];
	[sampler alignWithTick:tick fromDate:start toDate:end];

	viewSMA = ceil(sma_length / tick);
	if (viewSMA > 1)
		[sampler triangleMovingAverage:viewSMA];
	GraphOffset = [[sampler data] count] - viewWidth;
	XmarkOffset = GraphOffset / 2;

	// convert [bytes] => [Mbps]
	unit_conv = 8.0f / tick; // [bps]
	unit_conv = unit_conv / 1000.0f / 1000.0f; // [Mbps]
	[sampler scaleAllValue:unit_conv];

	_data = [sampler data];

	// update statistics
	_maxSamples = [_data maxSamples];
	_maxValue = [_data maxFloatValue];
	_averageValue = [_data averageFloatValue];
}

- (void)drawRect:(NSRect)dirty_rect
{
	NSDisableScreenUpdates();
	[self drawAll];
	NSEnableScreenUpdates();
}

@end
