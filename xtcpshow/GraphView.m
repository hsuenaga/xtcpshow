//
//  GraphView.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include "math.h"

#import "AppDelegate.h"
#import "GraphView.h"
#import "DataQueue.h"
#import "DataResampler.h"
#import "DataEntry.h"

//
// string resources
//
NSString *const RANGE_AUTO = @"Auto";
NSString *const RANGE_PEEKHOLD = @"PeekHold";
NSString *const RANGE_MANUAL = @"Manual";

NSString *const CAP_MAX_SMPL = @" Max %lu [packets/sample]";
NSString *const CAP_MAX_MBPS = @" Max %6.3f [mbps]";
NSString *const FMT_RANGE = @" Y-Range %6.3f [Mbps] / X-Range %6.1f [ms] / MA %6.1f [ms] / Avg %6.3f [Mbps] ";
NSString *const FMT_DATE = @"yyyy-MM-dd HH:mm:ss.SSS zzz ";
NSString *const FMT_NODATA = @"NO DATA RECORD ";

//
// gesture sensitivities
//
float const magnify_sensitivity = 2.0f;
float const scroll_sensitivity = 10.0f;

//
// class
//
@implementation GraphView
- (GraphView *)initWithFrame:(CGRect)aRect
{
	self = [super initWithFrame:aRect];
	if (!self)
		return nil;

	_data = nil;
	_showPacketMarker = TRUE;
	_magnifySense = magnify_sensitivity;
	_scrollSense = scroll_sensitivity;

	graph_gradient = [[NSGradient alloc]
			  initWithStartingColor:[NSColor clearColor]
			  endingColor:[NSColor greenColor]];
	resampler = [[DataResampler alloc] init];

	text_attr = [[NSMutableDictionary alloc] init];
	[text_attr setValue:[NSColor whiteColor]
		forKey:NSForegroundColorAttributeName];
	[text_attr setValue:[NSFont fontWithName:@"Menlo Regular" size:12]
		forKey:NSFontAttributeName];

	return self;
}

- (void)updateRange
{
	const double round = 0.05; // 50 [ms]
	float max;
	float new_range;
	BOOL resample = NO;

	// Y-axis
	max = [[self data] maxFloatValue];
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

	// Y-axis MA
	_MATimeLength = floor(_MATimeLength / round) * round;
	if (_MATimeLength < _minMATimeLength)
		_MATimeLength = _minMATimeLength;
	else if (_MATimeLength > _maxMATimeLength)
		_MATimeLength = _maxMATimeLength;
	new_range = _MATimeLength * 1000.0f; // [ms]
	if (ma_range < (new_range - round)
	    || ma_range > (new_range + round)) {
		resample = YES;
		ma_range = new_range;
	}

	// X-axis
	_viewTimeLength = floor(_viewTimeLength / round) * round;
	if (_viewTimeLength < _minViewTimeLength)
		_viewTimeLength = _minViewTimeLength;
	else if (_viewTimeLength > _maxViewTimeLength)
		_viewTimeLength = _maxViewTimeLength;
	new_range = _viewTimeLength * 1000.0f; // [ms]
	if (x_range < (new_range - round)
	    || x_range > (new_range + round)) {
		resample = YES;
		x_range = new_range;
	}

	if (resample)
		[resampler purgeData];
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

- (void)magnifyWithEvent:(NSEvent *)event
{
	_viewTimeLength *= 1.0/(1.0 + (event.magnification/_magnifySense));
	[self updateRange];
	[resampler purgeData];

	[_controller zoomGesture:self];
}

- (void)scrollWheel:(NSEvent *)event
{
	_MATimeLength -= (event.deltaY/_scrollSense);
	_viewTimeOffset += ((event.deltaX/_scrollSense) / 20.0f);
	[self updateRange];
	[resampler purgeData];

	[_controller scrollGesture:self];
}

- (void)drawGraph
{
	[NSGraphicsContext saveGraphicsState];
	[_data enumerateDataUsingBlock:^(DataEntry *data, NSUInteger idx, BOOL *stop) {
		NSRect bar;
		float value = [data floatValue];

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

	[self drawText:[NSString stringWithFormat:CAP_MAX_SMPL, _maxSamples]
	       atPoint:NSMakePoint(0.0f, _bounds.size.height - 14.0f)];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawText: (NSString *)text atPoint:(NSPoint)point
{
	NSAttributedString *atext = [NSAttributedString alloc];
	NSSize size;

	atext = [atext initWithString:text attributes:text_attr];
	size = [atext size];
	if ((point.x + size.width) > _bounds.size.width)
		point.x = _bounds.size.width - size.width;
	if ((point.y + size.height) > _bounds.size.height)
		point.y = _bounds.size.height - size.height;

	[atext drawAtPoint:point];
}

- (void)drawText:(NSString *)text alignRight:(CGFloat)y
{
	NSAttributedString *atext = [NSAttributedString alloc];
	NSSize size;
	NSPoint point;

	atext = [atext initWithString:text attributes:text_attr];
	size = [atext size];
	point.x = _bounds.size.width - size.width;
	point.y = y;
	if ((point.y + size.height) > _bounds.size.height)
		point.y = _bounds.size.height - size.height;
	[atext drawAtPoint:point];
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

	/* max text */
	if (y < (rect.size.height / 5))
		y = (rect.size.height / 5);
	else if (y > ((rect.size.height / 5) * 4))
		y = (rect.size.height / 5) * 4;

	marker = [NSString stringWithFormat:CAP_MAX_MBPS, _maxValue];
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

- (void)drawRange
{
	NSString *text;
	[NSGraphicsContext saveGraphicsState];
	text =
	[NSString stringWithFormat:FMT_RANGE,
	 y_range, x_range, ma_range,
	 [[self data] averageFloatValue]];
	[self drawText:text atPoint:NSMakePoint(0.0, 0.0)];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawDate
{
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	NSString *text;

	[NSGraphicsContext saveGraphicsState];
	[dateFormatter setDateFormat:FMT_DATE];
	if (_data && ![_data isEmpty])
		text = [dateFormatter stringFromDate:[_data lastDate]];
	else
		text = FMT_NODATA;

	[self drawText:text alignRight:_bounds.size.height];
	
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawAll
{
	[NSGraphicsContext saveGraphicsState];

	/* clear screen */
	[[NSColor clearColor] set];
	NSRectFill(_bounds);

	/* update x/y axis */
	[self updateRange];

	/* show matrix */
	[self drawGrid];

	/* plot packet marker */
	if (_showPacketMarker == TRUE)
		[self drawXMark];

	/* plot bar graph */
	[self drawGraph];

	/* plot guide line (max, average, ...) */
	[self drawGuide];

	/* graph params */
	[self drawRange];

	// date
	[self drawDate];
	[NSGraphicsContext restoreGraphicsState];
}

- (void)importData:(DataQueue *)data
{
	resampler.outputTimeLength = _viewTimeLength;
	resampler.outputSamples = _bounds.size.width;
	resampler.MATimeLength = _MATimeLength;

	[resampler resampleData:data];

	_data = [resampler data];
	_maxSamples = [_data maxSamples];
	_maxValue = [_data maxFloatValue];
	_averageValue = [_data averageFloatValue];

	GraphOffset = [resampler overSample];
	XmarkOffset = [resampler overSample] / 2;
}

- (void)purgeData
{
	[resampler purgeData];
}

- (void)drawRect:(NSRect)dirty_rect
{
	if (_bounds.size.width != resampler.outputSamples) {
		[resampler purgeData];
		resampler.outputSamples = _bounds.size.width;
	}

	NSDisableScreenUpdates();
	[self drawAll];
	NSEnableScreenUpdates();
}
@end
