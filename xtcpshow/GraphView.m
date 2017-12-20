// Copyright (c) 2013
// SUENAGA Hiroki <hiroki_suenaga@mac.com>. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.

// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

//
//  GraphView.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//
#include "math.h"

#import "AppDelegate.h"
#import "GraphView.h"
#import "DataQueue.h"
#import "DataResampler.h"
#import "SamplingData.h"

//
// string resources
//
NSString *const RANGE_AUTO = @"Auto";
NSString *const RANGE_PEAKHOLD = @"PeakHold";
NSString *const RANGE_MANUAL = @"Manual";

NSString *const CAP_MAX_SMPL = @" Max %lu [packets/sample]";
NSString *const CAP_MAX_MBPS = @" Max %6.3f [Mbps]";
NSString *const CAP_AVG_MBPS = @" Avg %6.3f [Mbps], StdDev %6.3f [Mbps]";

NSString *const FMT_RANGE = @" VERT %6.3f [Mbps/div] / HORIZ %6.1f [ms/div] / FIR %6.1f [ms]";
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
		if (range_mode == RANGE_PEAKHOLD) {
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

	// Y-axis Packets per Sample
	if (range_mode == RANGE_AUTO) {
		// auto
		pps_range = _maxSamples;
	}
	else if (pps_range < _maxSamples) {
		// peak hold (no manual settting)
		pps_range = _maxSamples;
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

	_viewTimeOffset = floor(_viewTimeOffset / round) * round;
	if (_viewTimeOffset > 0.0)
		_viewTimeOffset = 0.0;

	if (resample)
		[resampler purgeData];
}

- (float)setRange:(NSString *)mode withRange:(float)range
{
	range_mode = mode;
	peak_range = 0.0f;
	pps_range = 0;
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

- (int)stepValueFromRange:(float)range
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
	_viewTimeOffset -= event.deltaX/_scrollSense;
	[self updateRange];
	[resampler purgeData];

	[_controller scrollGesture:self];
}

- (void)drawGraph:(NSRect)rect
{
	[NSGraphicsContext saveGraphicsState];
	[_data enumerateDataUsingBlock:^(SamplingData *data, NSUInteger idx, BOOL *stop) {
		NSRect bar;
		float value = [data floatValue];

		if (idx < GraphOffset)
			return;
		idx -= GraphOffset;

		if (idx > rect.size.width) {
			*stop = YES;
			return;
		}
		bar.origin.x = (float)idx;
		bar.origin.y = 0;
		bar.size.width = 1.0;
		bar.size.height = value * rect.size.height / y_range;
		if (bar.size.height < 1.0)
			return;
		[graph_gradient drawInRect:bar angle:90.0];
	}];
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawPPS:(NSRect)rect;
{
	[NSGraphicsContext saveGraphicsState];
	[[NSColor cyanColor] set];
	[_data enumerateDataUsingBlock:^(SamplingData *data, NSUInteger idx, BOOL *stop) {
		NSBezierPath *path;
		NSUInteger samples;
		float h;

		if (idx < XmarkOffset)
			return;
		idx -= XmarkOffset;

		if (idx > rect.size.width) {
			*stop = YES;
			return;
		}
		if ( (samples = [data numberOfSamples]) == 0)
			return;
		h = rect.size.height / (float)pps_range;
		h = h * (float)samples;
		path = [NSBezierPath bezierPath];
		[path moveToPoint:NSMakePoint((float)idx, 0.0f)];
		[path lineToPoint:NSMakePoint((float)idx, h)];
		[path setLineCapStyle:NSRoundLineCapStyle];
		[path stroke];
	}];

	[self drawText:[NSString stringWithFormat:CAP_MAX_SMPL, pps_range]
		inRect:rect
	       atPoint:NSMakePoint(0.0f, rect.size.height)];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawText:(NSString *)text inRect:(NSRect)rect atPoint:(NSPoint)point
{
	NSAttributedString *atext = [NSAttributedString alloc];
	NSSize size;

	atext = [atext initWithString:text attributes:text_attr];
	size = [atext size];
	if ((point.x + size.width) > rect.size.width)
		point.x = rect.size.width - size.width;
	if ((point.y + size.height) > rect.size.height)
		point.y = rect.size.height - size.height;

	[atext drawAtPoint:point];
}

- (void)drawText:(NSString *)text inRect:(NSRect)rect alignRight:(CGFloat)y
{
	NSAttributedString *atext = [NSAttributedString alloc];
	NSSize size;
	NSPoint point;

	atext = [atext initWithString:text attributes:text_attr];
	size = [atext size];
	point.x = rect.size.width - size.width;
	point.y = y;
	if ((point.y + size.height) > rect.size.height)
		point.y = rect.size.height - size.height;
	[atext drawAtPoint:point];
}

- (void)drawMaxGuide:(NSRect)rect
{
	NSBezierPath *path;
	NSString *marker;
	float y;

	[NSGraphicsContext saveGraphicsState];

	[[NSColor redColor] set];
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
	[self drawText:marker inRect:rect atPoint:NSMakePoint(0.0, y)];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawAvgGuide:(NSRect)rect
{
	NSBezierPath *path;
	NSString *marker;
	float w, y, deviation;

	w = rect.size.width;
	deviation = [_data standardDeviation];

	[NSGraphicsContext saveGraphicsState];

	[[NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:1.0] set];
	path = [NSBezierPath bezierPath];
	y =	rect.size.height * (_averageValue / y_range);
	[path moveToPoint:NSMakePoint(0.0, y)];
	[path lineToPoint:NSMakePoint(w, y)];
	[path stroke];

	if (_showDeviationBand == TRUE) {
		float dy, upper, lower;
		[[NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:0.4] set];
		path = [NSBezierPath bezierPath];
		y = rect.size.height * (_averageValue / y_range);
		dy = rect.size.height * (deviation / y_range);
		upper = y + dy;
		if (upper > rect.size.height)
			upper = rect.size.height;
		lower = y - dy;
		if (lower < 0.0)
			lower = 0.0;

		[path moveToPoint:NSMakePoint(0.0, upper)];
		[path lineToPoint:NSMakePoint(0.0, lower)];
		[path lineToPoint:NSMakePoint(w, lower)];
		[path lineToPoint:NSMakePoint(w, upper)];
		[path closePath];
		[path fill];
	}

	/* max text */
	if (y < (rect.size.height / 5))
		y = (rect.size.height / 5);
	else if (y > ((rect.size.height / 5) * 4))
		y = (rect.size.height / 5) * 4;

	marker = [NSString stringWithFormat:CAP_AVG_MBPS, _averageValue, deviation];
	[self drawText:marker inRect:rect alignRight:y];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawGrid:(NSRect)rect
{
	[NSGraphicsContext saveGraphicsState];
	[[NSColor whiteColor] set];
	for (int i = 1; i < 5; i++) {
		CGFloat pattern[2] = {5.0, 5.0};
		NSBezierPath *path;
		float y = (rect.size.height / 5.0) * (float)i;
		float x = (rect.size.width / 5.0) * (float)i;

		// vertical line
		path = [NSBezierPath bezierPath];
		[path setLineDash:pattern count:2 phase:0.0];
		[path moveToPoint:NSMakePoint(0, y)];
		[path lineToPoint:NSMakePoint(rect.size.width, y)];
		[path stroke];

		// horizontal line
		path = [NSBezierPath bezierPath];
		[path setLineDash:pattern count:2 phase:0.0];
		[path moveToPoint:NSMakePoint(x, 0)];
		[path lineToPoint:NSMakePoint(x, rect.size.height)];
		[path stroke];
	}
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawRange:(NSRect)rect
{
	NSString *text;
	[NSGraphicsContext saveGraphicsState];
	text =
	[NSString stringWithFormat:FMT_RANGE,
	 y_range / 5, x_range / 5, ma_range];
	[self drawText:text inRect:rect atPoint:NSMakePoint(0.0, 0.0)];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawDate:(NSRect)rect;
{
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	NSString *text;

	[NSGraphicsContext saveGraphicsState];
	[dateFormatter setDateFormat:FMT_DATE];
	if (_data && ![_data isEmpty])
		text = [dateFormatter stringFromDate:[_data lastDate]];
	else
		text = FMT_NODATA;

	[self drawText:text inRect:rect alignRight:rect.size.height];
	
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawAllWithSize:(NSRect)rect OffScreen:(BOOL)off
{
	[NSGraphicsContext saveGraphicsState];

	/* clear screen */
	if (off)
		[[NSColor blackColor] set];
	else
		[[NSColor clearColor] set];

	NSRectFill(rect);

	/* update x/y axis */
	[self updateRange];

	/* show matrix */
	[self drawGrid:rect];

	/* plot packet marker */
	if (_showPacketMarker == TRUE)
		[self drawPPS:rect];

	/* plot bar graph */
	[self drawGraph:rect];

	/* plot guide line (max, average, ...) */
	[self drawMaxGuide:rect];
	[self drawAvgGuide:rect];

	/* graph params */
	[self drawRange:rect];

	// date
	[self drawDate:rect];
	[NSGraphicsContext restoreGraphicsState];
}

- (void)resampleData:(DataQueue *)data inRect:(NSRect)rect
{
	NSDate *end;

	// fix up _viewTimeOffset
	end = [data last_update];
	end = [end dateByAddingTimeInterval:_viewTimeOffset];
	if ([end laterDate:[data firstDate]] != end) {
		_viewTimeOffset = [[data firstDate] timeIntervalSinceDate:[data last_update]];
	}

	resampler.outputTimeLength = _viewTimeLength;
	resampler.outputTimeOffset = _viewTimeOffset;
	resampler.outputSamples = rect.size.width;
	resampler.MATimeLength = _MATimeLength;

	[resampler resampleData:data];

	_data = [resampler data];
	_maxSamples = [_data maxSamples];
	_maxValue = [_data maxFloatValue];
	_averageValue = [_data averageFloatValue];

	GraphOffset = [resampler overSample];
	XmarkOffset = [resampler overSample] / 2;
}

- (void)importData:(DataQueue *)data
{
	[self resampleData:data inRect:_bounds];
}

- (void)purgeData
{
	[resampler purgeData];
}

- (void)saveFile:(DataQueue *)data;
{
	NSSize image_size = NSMakeSize(640, 480);
	NSRect image_rect;
	NSBitmapImageRep *buffer = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:image_size.width pixelsHigh:image_size.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bitmapFormat:0 bytesPerRow:(image_size.width * 4) bitsPerPixel:32];
	NSData *png;
	NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithBitmapImageRep:buffer];
	NSSavePanel *panel;

	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:gc];
	image_rect.size = image_size;
	image_rect.origin.x = 0;
	image_rect.origin.y = 0;
	NSLog(@"create PNG image");
	[self purgeData];
	[self resampleData:data inRect:image_rect];
	[self drawAllWithSize:image_rect OffScreen:YES];
	[NSGraphicsContext restoreGraphicsState];

	// get filename
	panel = [NSSavePanel savePanel];
	[panel setAllowedFileTypes:@[@"png"]];
	[panel setNameFieldStringValue:@"xtcpshow.png"];
	[panel runModal];
	NSLog(@"save to %@%@",
	      [panel directoryURL],
	      [panel nameFieldStringValue]);
    NSDictionary *prop = [[NSDictionary alloc] init];
    
	png = [buffer representationUsingType:NSPNGFileType properties:prop];
	[png writeToURL:[[panel directoryURL] URLByAppendingPathComponent:[panel nameFieldStringValue]]
	      atomically:NO];

	// restore data for display
	[self purgeData];
	[self resampleData:data inRect:_bounds];
}

- (void)drawRect:(NSRect)dirty_rect
{
	if (_bounds.size.width != resampler.outputSamples) {
		[resampler purgeData];
		resampler.outputSamples = _bounds.size.width;
	}

	if ([NSGraphicsContext currentContextDrawingToScreen]) {
		NSDisableScreenUpdates();
		// need to resample...
		[self drawAllWithSize:_bounds OffScreen:NO];
		NSEnableScreenUpdates();
	}
	else {
		// off screen rendering
		[self drawAllWithSize:dirty_rect OffScreen:YES];
	}
}
@end
