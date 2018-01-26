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
#import "ComputeQueue.h"
#import "DataResampler.h"
#import "DerivedData.h"
#import "TrafficIndex.h"
#import "TrafficDB.h"

//
// string constants
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
// float constants
//
float const magnify_sensitivity = 2.0;
float const scroll_sensitivity = 10.0;

//
// Private Properties
//
@interface GraphView ()
// Graphic Components
@property (nonatomic) CGContextRef CGContext;
@property (nonatomic) CGLayerRef Backbuffer;
@property (nonatomic) NSGraphicsContext *layerBackbufferContext;
@property (nonatomic) NSMutableDictionary *textAttributes;
@property (nonatomic) NSGradient *gradGraph;
@property (nonatomic) NSBezierPath *pathSolid;
@property (nonatomic) NSBezierPath *pathDash;
@property (nonatomic) NSColor *colorBG;
@property (nonatomic) NSColor *colorFG;
@property (nonatomic) NSColor *colorAVG;
@property (nonatomic) NSColor *colorDEV;
@property (nonatomic) NSColor *colorBPS;
@property (nonatomic) NSColor *colorPPS;
@property (nonatomic) NSColor *colorMAX;
@property (nonatomic) NSColor *colorGRID;
@property (nonatomic) NSColor *colorGradStart;
@property (nonatomic) NSColor *colorGradEnd;
@property (nonatomic) NSDateFormatter *dateFormatter;

// Internal Configuration.
@property (nonatomic) NSString *range_mode;
@property (nonatomic) double manual_range;
@property (nonatomic) double peak_range;
@property (nonatomic) float magnifySense;
@property (nonatomic) float scrollSense;

// Offset of viewport. changed by scroll controll.
@property (nonatomic) NSTimeInterval viewTimeOffset;

// X-axis adjustment
@property (nonatomic) NSUInteger GraphOffset;
@property (nonatomic) NSUInteger XmarkOffset;

// X, Y Range settings.
@property (nonatomic) double y_range;
@property (nonatomic) double x_range;
@property (nonatomic) double FirRange;
@property (nonatomic) NSUInteger pps_range;

// Data-Bidings
@property (nonatomic) DataResampler *resampler;
@property (nonatomic) NSDate *lastResample;
@property (weak, nonatomic) ComputeQueue *viewData;
@property (weak, nonatomic) TrafficDB *inputData;
@property (nonatomic) NSUInteger maxSamples;
@property (nonatomic) double maxValue;
@property (nonatomic) double averageValue;

// Status Update
- (void)updateRange;

// Drawing
- (void)drawGraphHistgram:(NSRect)rect;
- (void)drawGraphBezier:(NSRect)rect;
- (void)drawPPS:(NSRect)rect;
- (void)drawText:(NSString *)text inRect:(NSRect)rect atPoint:(NSPoint)point;
- (void)drawText:(NSString *)text inRect:(NSRect)rect alignRight:(CGFloat)y;
- (void)drawMaxGuide:(NSRect)rect;
- (void)drawAvgGuide:(NSRect)rect;
- (void)drawGrid:(NSRect)rect;
- (void)drawRange:(NSRect)rect;
- (void)drawDate:(NSRect)rect;
- (void)drawAllWithSize:(NSRect)rect OffScreen:(BOOL)off;
- (void)setLayerContextWithRect:(NSRect)rect;
- (void)drawLayer;

// Computing
- (void)resampleDataInRect:(NSRect)rect;
@end

//
// class
//
@implementation GraphView
- (void)defineGraphicComponentsWithFrame:(CGRect)rect
{
    // Colors
    self.colorFG = [NSColor whiteColor];
    self.colorBG = [NSColor blackColor];
    self.colorAVG = [NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:1.0];
    self.colorDEV = [NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:0.4];
    self.colorGradStart = [NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:0.0];
    self.colorGradEnd = [NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:1.0];
    self.colorBPS = self.colorGradEnd;
    self.colorPPS = [NSColor cyanColor];
    self.colorMAX = [NSColor redColor];
    self.colorGRID = self.colorFG;
    
    // Gradiations
    self.gradGraph = [[NSGradient alloc] initWithStartingColor:self.colorGradStart endingColor:self.colorGradEnd];
    
    // Path
    self.pathSolid = [NSBezierPath bezierPath];
    self.pathDash = [NSBezierPath bezierPath];
    const CGFloat dash[2] = {5.0, 5.0};
    const NSUInteger count = sizeof(dash)/sizeof(dash[0]);
    [self.pathDash setLineDash:dash count:count phase:0.0];

    // Texts
    self.textAttributes = [NSMutableDictionary new];
    [self.textAttributes setValue:self.colorFG forKey:NSForegroundColorAttributeName];
    [self.textAttributes setValue:[NSFont fontWithName:@"Menlo Regular" size:12] forKey:NSFontAttributeName];
    self.dateFormatter = [NSDateFormatter new];
    [self.dateFormatter setDateFormat:FMT_DATE];
}

- (GraphView *)initWithFrame:(CGRect)aRect
{
	self = [super initWithFrame:aRect];
	if (!self)
		return nil;

    [self defineGraphicComponentsWithFrame:aRect];
	self.viewData = nil;
	self.showPacketMarker = TRUE;
	self.magnifySense = magnify_sensitivity;
	self.scrollSense = scroll_sensitivity;
    self.useHistgram = FALSE;
	self.resampler = [[DataResampler alloc] init];

	return self;
}

- (void)updateRange
{
	const double round = 0.05; // 50 [ms]
	float max;
	float new_range;
	BOOL resample = NO;

	// Y-axis
	max = [self.viewData maxDoubleValue];
	if (self.range_mode == RANGE_MANUAL) {
		if (self.manual_range <= 0.5f)
			new_range = 0.5f;
		else if (self.manual_range <= 1.0f)
			new_range = 1.0f;
		else if (self.manual_range <= 2.5f)
			new_range = 2.5f;
		else
			new_range =
			5.0f * (ceil(self.manual_range/5.0f));
	} else {
		if (self.range_mode == RANGE_PEAKHOLD) {
			if (self.peak_range < max)
				self.peak_range = max;
			max = self.peak_range;
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
	self.y_range = new_range; // [Mbps]

	// Y-axis MA
	_FIRTimeLength = floor(_FIRTimeLength / round) * round;
	if (_FIRTimeLength < _minFIRTimeLength)
		_FIRTimeLength = _minFIRTimeLength;
	else if (_FIRTimeLength > _maxFIRTimeLength)
		_FIRTimeLength = _maxFIRTimeLength;
	new_range = _FIRTimeLength * 1000.0f; // [ms]
	if (self.FirRange < (new_range - round)
	    || self.FirRange > (new_range + round)) {
		resample = YES;
		self.FirRange = new_range;
	}

	// Y-axis Packets per Sample
	if (self.range_mode == RANGE_AUTO) {
		// auto
		self.pps_range = _maxSamples;
	}
	else if (self.pps_range < _maxSamples) {
		// peak hold (no manual settting)
		self.pps_range = _maxSamples;
	}
	
	// X-axis
	_viewTimeLength = floor(_viewTimeLength / round) * round;
	if (_viewTimeLength < _minViewTimeLength)
		_viewTimeLength = _minViewTimeLength;
	else if (_viewTimeLength > _maxViewTimeLength)
		_viewTimeLength = _maxViewTimeLength;
	new_range = _viewTimeLength * 1000.0f; // [ms]
	if (self.x_range < (new_range - round)
	    || self.x_range > (new_range + round)) {
		resample = YES;
		self.x_range = new_range;
	}

	_viewTimeOffset = floor(_viewTimeOffset / round) * round;
	if (_viewTimeOffset > 0.0)
		_viewTimeOffset = 0.0;

    if (resample) {
		[self purgeData];
    }
}

- (float)setRange:(NSString *)mode withRange:(float)range
{
	self.range_mode = mode;
	self.peak_range = 0.0f;
	self.pps_range = 0;
	if (mode == RANGE_MANUAL)
		self.manual_range = range;

	[self updateRange];

	return self.y_range;
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

	[_controller zoomGesture:self];
}

- (void)scrollWheel:(NSEvent *)event
{
	_FIRTimeLength -= (event.deltaY/_scrollSense);
	_viewTimeOffset -= event.deltaX/_scrollSense;
	[self updateRange];

	[self.controller scrollGesture:self];
}

- (void)drawGraphHistgram:(NSRect)rect
{
	[NSGraphicsContext saveGraphicsState];
    
	[self.viewData enumerateDataUsingBlock:^(DerivedData *data, NSUInteger idx, BOOL *stop) {
		NSRect bar;
		CGFloat value = (CGFloat)[data doubleValue];

		if (idx < self.GraphOffset)
			return;
		idx -= self.GraphOffset;

		if (idx > rect.size.width) {
			*stop = YES;
			return;
		}
		bar.origin.x = (CGFloat)idx;
		bar.origin.y = 0;
		bar.size.width = 1.0;
		bar.size.height = value * rect.size.height / self.y_range;
		if (bar.size.height < 1.0)
			return;
		[self.gradGraph drawInRect:bar angle:90.0];
	}];
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawGraphBezier:(NSRect)rect
{
    [NSGraphicsContext saveGraphicsState];
    [self.colorBPS set];

    // start from (0.0)
    NSPoint pointStart = {
        .x = 0.0, .y=0.0
    };
    [self.pathSolid removeAllPoints];
    [self.pathSolid moveToPoint:pointStart];
    
    // make path
    double scaler = (double)rect.size.height / (double)self.y_range;
    BOOL __block pathOpen = false;
    [self.viewData enumerateDataUsingBlock:^(DerivedData *data, NSUInteger idx, BOOL *stop) {
        if (idx < self.GraphOffset)
            return;
        idx -= self.GraphOffset;
        
        if (idx > rect.size.width) {
            *stop = YES;
            return;
        }
        
        CGFloat value = [data doubleValue] * scaler;
        if ((int)(round(value)) == 0) {
            value = 0.0;
        }
        else if (value > rect.size.height) {
            value = rect.size.height;
        }
        NSPoint plot = {
            .x = (CGFloat)idx,
            .y = (CGFloat)value
        };
        if (!pathOpen) {
            if (plot.y > 0.0) {
                // create new shape
                [self.pathSolid lineToPoint:plot];
                pathOpen = true;
                return;
            }
            [self.pathSolid moveToPoint:plot];
            return;
        }
        else {
            if (plot.y == 0.0) {
                // close the shape
                [self.pathSolid lineToPoint:plot];
                [self.gradGraph drawInBezierPath:self.pathSolid angle:90.0];
                [self.pathSolid stroke];
                
                // restart from currnet plot
                [self.pathSolid removeAllPoints];
                [self.pathSolid moveToPoint:plot];
                pathOpen = false;
                return;
            }
            [self.pathSolid lineToPoint:plot];
            return;
        }
    }];
    
    // end at (width, 0)
    if (pathOpen) {
        NSPoint pointEnd = {
            .x = rect.size.width,
            .y = 0.0
        };
        [self.pathSolid lineToPoint:pointEnd];
        [self.gradGraph drawInBezierPath:self.pathSolid angle:90.0];
        [self.pathSolid stroke];
    }
    
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawPPS:(NSRect)rect;
{
	[NSGraphicsContext saveGraphicsState];
    [self.colorPPS set];

    double scaler = (double)rect.size.height / (double)self.pps_range;
	[self.viewData enumerateDataUsingBlock:^(DerivedData *data, NSUInteger idx, BOOL *stop) {
		if (idx < self.XmarkOffset)
			return;
		idx -= self.XmarkOffset;

		if (idx > rect.size.width) {
			*stop = YES;
			return;
		}
        NSUInteger samples = [data numberOfSamples];
		if (samples == 0)
			return;
		CGFloat value = (CGFloat)samples * scaler;
        [self.pathSolid removeAllPoints];
		[self.pathSolid moveToPoint:NSMakePoint((CGFloat)idx, (CGFloat)0.0)];
		[self.pathSolid lineToPoint:NSMakePoint((CGFloat)idx, value)];
		[self.pathSolid stroke];
	}];

	[self drawText:[NSString stringWithFormat:CAP_MAX_SMPL, self.pps_range]
		inRect:rect
	       atPoint:NSMakePoint(0.0f, rect.size.height)];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawText:(NSString *)text inRect:(NSRect)rect atPoint:(NSPoint)point
{
    NSAttributedString *attrText = [[NSAttributedString alloc] initWithString:text attributes:self.textAttributes];
	NSSize size = [attrText size];
    
	if ((point.x + size.width) > rect.size.width)
		point.x = rect.size.width - size.width;
	if ((point.y + size.height) > rect.size.height)
		point.y = rect.size.height - size.height;

	[attrText drawAtPoint:point];
}

- (void)drawText:(NSString *)text inRect:(NSRect)rect alignRight:(CGFloat)y
{
	NSAttributedString *attrText = [[NSAttributedString alloc] initWithString:text attributes:self.textAttributes];
	NSSize size = [attrText size];
    
    NSPoint point = {
        .x = rect.size.width - size.width,
        .y = y,
    };
	if ((point.y + size.height) > rect.size.height)
		point.y = rect.size.height - size.height;
	[attrText drawAtPoint:point];
}

- (void)drawMaxGuide:(NSRect)rect
{
    [NSGraphicsContext saveGraphicsState];
    [self.colorMAX set];

    // draw line
	CGFloat value = rect.size.height * (_maxValue / self.y_range);
    [self.pathSolid removeAllPoints];
	[self.pathSolid moveToPoint:NSMakePoint((CGFloat)0.0, value)];
	[self.pathSolid lineToPoint:NSMakePoint(rect.size.width, value)];
	[self.pathSolid stroke];

	// draw text
	if (value < (rect.size.height / 5))
		value = (rect.size.height / 5);
	else if (value > ((rect.size.height / 5) * 4))
		value = (rect.size.height / 5) * 4;
	NSString *marker = [NSString stringWithFormat:CAP_MAX_MBPS, _maxValue];
	[self drawText:marker inRect:rect atPoint:NSMakePoint((CGFloat)0.0, value)];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawAvgGuide:(NSRect)rect
{
    [NSGraphicsContext saveGraphicsState];
    [self.colorAVG set];

	CGFloat deviation = (CGFloat)[self.viewData standardDeviation];
	CGFloat value =	rect.size.height * (_averageValue / self.y_range);
    
    // draw line
    [self.pathSolid removeAllPoints];
	[self.pathSolid moveToPoint:NSMakePoint(0.0, value)];
	[self.pathSolid lineToPoint:NSMakePoint(rect.size.width, value)];
	[self.pathSolid stroke];

    // draw band
	if (self.showDeviationBand == TRUE) {
        [self.colorDEV set];

		CGFloat dy = rect.size.height * (deviation / self.y_range);
		CGFloat upper = value + dy;
		if (upper > rect.size.height)
			upper = rect.size.height;
		CGFloat lower = value - dy;
		if (lower < 0.0)
			lower = 0.0;

        [self.pathSolid removeAllPoints];
		[self.pathSolid moveToPoint:NSMakePoint((CGFloat)0.0, upper)];
		[self.pathSolid lineToPoint:NSMakePoint((CGFloat)0.0, lower)];
		[self.pathSolid lineToPoint:NSMakePoint(rect.size.width, lower)];
		[self.pathSolid lineToPoint:NSMakePoint(rect.size.width, upper)];
		[self.pathSolid closePath];
		[self.pathSolid fill];
	}

	/* draw text */
	if (value < (rect.size.height / 5))
		value = (rect.size.height / 5);
	else if (value > ((rect.size.height / 5) * 4))
		value = (rect.size.height / 5) * 4;
	NSString *marker = [NSString stringWithFormat:CAP_AVG_MBPS, _averageValue, deviation];
	[self drawText:marker inRect:rect alignRight:value];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawGrid:(NSRect)rect
{
	[NSGraphicsContext saveGraphicsState];
    [self.colorGRID set];
    
	for (int i = 1; i < 5; i++) {
		CGFloat y = (rect.size.height / 5.0) * (CGFloat)i;
		CGFloat x = (rect.size.width / 5.0) * (CGFloat)i;

		// vertical line
        [self.pathDash removeAllPoints];
		[self.pathDash moveToPoint:NSMakePoint(0, y)];
		[self.pathDash lineToPoint:NSMakePoint(rect.size.width, y)];
		[self.pathDash stroke];

		// horizontal line
        [self.pathDash removeAllPoints];
		[self.pathDash moveToPoint:NSMakePoint(x, 0)];
		[self.pathDash lineToPoint:NSMakePoint(x, rect.size.height)];
		[self.pathDash stroke];
	}
    
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawRange:(NSRect)rect
{
	NSString *text = [NSString stringWithFormat:FMT_RANGE, (self.y_range / 5.0), (self.x_range / 5.0), self.FirRange];
	[self drawText:text inRect:rect atPoint:NSMakePoint(0.0, 0.0)];
}

- (void)drawDate:(NSRect)rect;
{
    NSString *text = FMT_NODATA;
    
	if (self.viewData && ![self.viewData isEmpty])
		text = [self.dateFormatter stringFromDate:[self.viewData lastDate]];

    [self drawText:text inRect:rect alignRight:rect.size.height];
}

- (void)drawAllWithSize:(NSRect)rect OffScreen:(BOOL)off
{
	[NSGraphicsContext saveGraphicsState];
    
    // create layer (back buffer)
    [self setLayerContextWithRect:rect];
    
	// clear screen
    [self.colorBG set];
	NSRectFill(rect);
    [self.colorFG set];

	// update x/y axis
	[self updateRange];

	// show matrix
	[self drawGrid:rect];

	// plot packet marker
	if (_showPacketMarker == TRUE)
		[self drawPPS:rect];

	// plot bps graph
    if (self.useHistgram)
        [self drawGraphHistgram:rect];
    else
        [self drawGraphBezier:rect];

	// plot guide line (max, average, ...)
	[self drawMaxGuide:rect];
	[self drawAvgGuide:rect];

	/// graph params
	[self drawRange:rect];

	// date
	[self drawDate:rect];
    
    // rasterize layer
    [self drawLayer];
	[NSGraphicsContext restoreGraphicsState];
}

- (void)setLayerContextWithRect:(NSRect)rect
{
    self.CGContext = [[NSGraphicsContext currentContext] graphicsPort];
    self.Backbuffer = CGLayerCreateWithContext(self.CGContext, rect.size, NULL);
    
    CGContextRef gcBackbuffer = CGLayerGetContext(self.Backbuffer);
    NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithCGContext:gcBackbuffer flipped:FALSE];

    [NSGraphicsContext setCurrentContext:gc];
}

- (void)drawLayer
{
    CGContextDrawLayerAtPoint(self.CGContext, CGPointZero, self.Backbuffer);
    CGLayerRelease(self.Backbuffer);
    self.Backbuffer = NULL;
}

- (void)drawRect:(NSRect)dirty_rect
{
    if (_bounds.size.width != self.resampler.outputSamples) {
        [self purgeData];
        self.resampler.outputSamples = _bounds.size.width;
    }
    
    if ([NSGraphicsContext currentContextDrawingToScreen]) {
        [self drawAllWithSize:_bounds OffScreen:NO];
    }
    else {
        [self drawAllWithSize:dirty_rect OffScreen:YES];
    }
}

- (void)resampleDataInRect:(NSRect)rect
{
	NSDate *end;

    // data is not imported.
    if (!self.inputData)
        return;
    
	// fix up _viewTimeOffset
	end = [self.inputData lastDate];
    if (end == nil) {
        NSLog(@"No timestamp");
        return;
    }
    else if (self.lastResample && [self.lastResample isEqual:end]) {
        NSLog(@"Data is not updated");
        // Not updated.
        return;
    }
    self.lastResample = end;
    
    // add offset
	end = [end dateByAddingTimeInterval:_viewTimeOffset];
	if ([end laterDate:[self.inputData firstDate]] != end) {
        _viewTimeOffset = [[self.inputData firstDate] timeIntervalSinceDate:[self.inputData lastDate]];
	}

	self.resampler.outputTimeLength = _viewTimeLength;
	self.resampler.outputTimeOffset = _viewTimeOffset;
	self.resampler.outputSamples = rect.size.width;
	self.resampler.FIRTimeLength = _FIRTimeLength;
    [self.resampler resampleDataBase:self.inputData atDate:end];

	self.viewData = [self.resampler output];
	self.maxSamples = [self.viewData maxSamples];
	self.maxValue = [self.viewData maxDoubleValue];
	self.averageValue = [self.viewData averageDoubleValue];

	self.GraphOffset = [self.resampler overSample];
	self.XmarkOffset = [self.resampler overSample] / 2;
}

- (void)importData:(TrafficDB *)dataBase
{
    if (self.inputData != dataBase) {
        self.inputData = dataBase;
    }
    [self resampleDataInRect:_bounds];
}

- (void)purgeData
{
	[self.resampler purgeData];
    self.lastResample = nil;
}

- (void)saveFile:(TrafficDB *)dataBase;
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
    [self resampleDataInRect:image_rect];
	[self drawAllWithSize:image_rect OffScreen:YES];
	[NSGraphicsContext restoreGraphicsState];

	// get filename
	panel = [NSSavePanel savePanel];
	[panel setAllowedFileTypes:@[@"png"]];
	[panel setNameFieldStringValue:@"xtcpshow_hardcopy.png"];
	[panel runModal];
	NSLog(@"save to %@%@",
	      [panel directoryURL],
	      [panel nameFieldStringValue]);
    NSDictionary *prop = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:false],
                          NSImageInterlaced, nil];
    
	png = [buffer representationUsingType:NSPNGFileType properties:prop];
	[png writeToURL:[[panel directoryURL] URLByAppendingPathComponent:[panel nameFieldStringValue]]
	      atomically:NO];

	// restore data for display
	[self purgeData];
    [self resampleDataInRect:_bounds];
}
@end
