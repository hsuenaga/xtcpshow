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
// Private Properties
//
@interface GraphView ()
@property (readonly, nonatomic) NSGraphicsContext *layerContext;
@property (readonly, nonatomic) NSMutableDictionary *textAttributes;
@property (readonly, nonatomic) NSGradient *gradGraph;
@property (readonly, nonatomic) NSBezierPath *pathSolid;
@property (readonly, nonatomic) NSBezierPath *pathDash;
@property (readonly, nonatomic) NSColor *colorBG;
@property (readonly, nonatomic) NSColor *colorFG;
@property (readonly, nonatomic) NSColor *colorAVG;
@property (readonly, nonatomic) NSColor *colorDEV;
@property (readonly, nonatomic) NSColor *colorBPS;
@property (readonly, nonatomic) NSColor *colorPPS;
@property (readonly, nonatomic) NSColor *colorMAX;
@property (readonly, nonatomic) NSColor *colorGRID;
@property (readonly, nonatomic) NSColor *colorGradStart;
@property (readonly, nonatomic) NSColor *colorGradEnd;
@property (readonly, nonatomic) NSDateFormatter *dateFormatter;

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
- (void)resampleData:(TrafficDB *)dataBase inRect:(NSRect) rect;
@end

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
@implementation GraphView {
    // CoreGraphics / Quartz2D
    CGContextRef CGContext;
    CGContextRef layerCGContext;
    CGLayerRef layer;
}
@synthesize layerContext;
@synthesize textAttributes;
@synthesize gradGraph;
@synthesize pathSolid;
@synthesize pathDash;
@synthesize colorFG;
@synthesize colorBG;
@synthesize colorAVG;
@synthesize colorDEV;
@synthesize colorBPS;
@synthesize colorMAX;
@synthesize colorGradStart;
@synthesize colorGradEnd;
@synthesize colorPPS;
@synthesize colorGRID;
@synthesize dateFormatter;

- (void)defineGraphicComponentsWithFrame:(CGRect)rect
{
    // Colors
    colorFG = [NSColor whiteColor];
    colorBG = [NSColor blackColor];
    colorAVG = [NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:1.0];
    colorDEV = [NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:0.4];
    colorGradStart = [NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:0.0];
    colorGradEnd = [NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:1.0];
    colorBPS = colorGradEnd;
    colorPPS = [NSColor cyanColor];
    colorMAX = [NSColor redColor];
    colorGRID = colorFG;
    
    // Gradiations
    gradGraph = [[NSGradient alloc] initWithStartingColor:colorGradStart endingColor:colorGradEnd];
    
    // Path
    pathSolid = [NSBezierPath bezierPath];
    pathDash = [NSBezierPath bezierPath];
    const CGFloat dash[2] = {5.0, 5.0};
    const NSUInteger count = sizeof(dash)/sizeof(dash[0]);
    [pathDash setLineDash:dash count:count phase:0.0];

    // Texts
    textAttributes = [NSMutableDictionary new];
    [textAttributes setValue:colorFG forKey:NSForegroundColorAttributeName];
    [textAttributes setValue:[NSFont fontWithName:@"Menlo Regular" size:12] forKey:NSFontAttributeName];
    dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:FMT_DATE];
}

- (GraphView *)initWithFrame:(CGRect)aRect
{
	self = [super initWithFrame:aRect];
	if (!self)
		return nil;

    [self defineGraphicComponentsWithFrame:aRect];
	self.data = nil;
	self.showPacketMarker = TRUE;
	self.magnifySense = magnify_sensitivity;
	self.scrollSense = scroll_sensitivity;
    self.useHistgram = FALSE;
    
	resampler = [[DataResampler alloc] init];

	return self;
}

- (void)updateRange
{
	const double round = 0.05; // 50 [ms]
	float max;
	float new_range;
	BOOL resample = NO;

	// Y-axis
	max = [[self data] maxDoubleValue];
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
	_FIRTimeLength = floor(_FIRTimeLength / round) * round;
	if (_FIRTimeLength < _minFIRTimeLength)
		_FIRTimeLength = _minFIRTimeLength;
	else if (_FIRTimeLength > _maxFIRTimeLength)
		_FIRTimeLength = _maxFIRTimeLength;
	new_range = _FIRTimeLength * 1000.0f; // [ms]
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

    if (resample) {
		[resampler purgeData];
    }
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
	_FIRTimeLength -= (event.deltaY/_scrollSense);
	_viewTimeOffset -= event.deltaX/_scrollSense;
	[self updateRange];
	[resampler purgeData];

	[_controller scrollGesture:self];
}

- (void)drawGraphHistgram:(NSRect)rect
{
	[NSGraphicsContext saveGraphicsState];
    
	[_data enumerateDataUsingBlock:^(DerivedData *data, NSUInteger idx, BOOL *stop) {
		NSRect bar;
		CGFloat value = (CGFloat)[data doubleValue];

		if (idx < GraphOffset)
			return;
		idx -= GraphOffset;

		if (idx > rect.size.width) {
			*stop = YES;
			return;
		}
		bar.origin.x = (CGFloat)idx;
		bar.origin.y = 0;
		bar.size.width = 1.0;
		bar.size.height = value * rect.size.height / y_range;
		if (bar.size.height < 1.0)
			return;
		[gradGraph drawInRect:bar angle:90.0];
	}];
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawGraphBezier:(NSRect)rect
{
    [NSGraphicsContext saveGraphicsState];
    [colorBPS set];

    // start from (0.0)
    NSPoint pointStart = {
        .x = 0.0, .y=0.0
    };
    [pathSolid removeAllPoints];
    [pathSolid moveToPoint:pointStart];
    
    // make path
    double scaler = (double)rect.size.height / (double)y_range;
    BOOL __block pathOpen = false;
    [_data enumerateDataUsingBlock:^(DerivedData *data, NSUInteger idx, BOOL *stop) {
        if (idx < GraphOffset)
            return;
        idx -= GraphOffset;
        
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
                [pathSolid lineToPoint:plot];
                pathOpen = true;
                return;
            }
            [pathSolid moveToPoint:plot];
            return;
        }
        else {
            if (plot.y == 0.0) {
                // close the shape
                [pathSolid lineToPoint:plot];
                [gradGraph drawInBezierPath:pathSolid angle:90.0];
                [pathSolid stroke];
                
                // restart from currnet plot
                [pathSolid removeAllPoints];
                [pathSolid moveToPoint:plot];
                pathOpen = false;
                return;
            }
            [pathSolid lineToPoint:plot];
            return;
        }
    }];
    
    // end at (width, 0)
    if (pathOpen) {
        NSPoint pointEnd = {
            .x = rect.size.width,
            .y = 0.0
        };
        [pathSolid lineToPoint:pointEnd];
        [gradGraph drawInBezierPath:pathSolid angle:90.0];
        [pathSolid stroke];
    }
    
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawPPS:(NSRect)rect;
{
	[NSGraphicsContext saveGraphicsState];
    [colorPPS set];

    double scaler = (double)rect.size.height / (double)pps_range;
	[_data enumerateDataUsingBlock:^(DerivedData *data, NSUInteger idx, BOOL *stop) {
		if (idx < XmarkOffset)
			return;
		idx -= XmarkOffset;

		if (idx > rect.size.width) {
			*stop = YES;
			return;
		}
        NSUInteger samples = [data numberOfSamples];
		if (samples == 0)
			return;
		CGFloat value = (CGFloat)samples * scaler;
        [pathSolid removeAllPoints];
		[pathSolid moveToPoint:NSMakePoint((CGFloat)idx, (CGFloat)0.0)];
		[pathSolid lineToPoint:NSMakePoint((CGFloat)idx, value)];
		[pathSolid stroke];
	}];

	[self drawText:[NSString stringWithFormat:CAP_MAX_SMPL, pps_range]
		inRect:rect
	       atPoint:NSMakePoint(0.0f, rect.size.height)];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawText:(NSString *)text inRect:(NSRect)rect atPoint:(NSPoint)point
{
    NSAttributedString *attrText = [[NSAttributedString alloc] initWithString:text attributes:textAttributes];
	NSSize size = [attrText size];
    
	if ((point.x + size.width) > rect.size.width)
		point.x = rect.size.width - size.width;
	if ((point.y + size.height) > rect.size.height)
		point.y = rect.size.height - size.height;

	[attrText drawAtPoint:point];
}

- (void)drawText:(NSString *)text inRect:(NSRect)rect alignRight:(CGFloat)y
{
	NSAttributedString *attrText = [[NSAttributedString alloc] initWithString:text attributes:textAttributes];
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
    [colorMAX set];

    // draw line
	CGFloat value = rect.size.height * (_maxValue / y_range);
    [pathSolid removeAllPoints];
	[pathSolid moveToPoint:NSMakePoint((CGFloat)0.0, value)];
	[pathSolid lineToPoint:NSMakePoint(rect.size.width, value)];
	[pathSolid stroke];

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
    [colorAVG set];

	CGFloat deviation = (CGFloat)[_data standardDeviation];
	CGFloat value =	rect.size.height * (_averageValue / y_range);
    
    // draw line
    [pathSolid removeAllPoints];
	[pathSolid moveToPoint:NSMakePoint(0.0, value)];
	[pathSolid lineToPoint:NSMakePoint(rect.size.width, value)];
	[pathSolid stroke];

    // draw band
	if (_showDeviationBand == TRUE) {
        [colorDEV set];

		CGFloat dy = rect.size.height * (deviation / y_range);
		CGFloat upper = value + dy;
		if (upper > rect.size.height)
			upper = rect.size.height;
		CGFloat lower = value - dy;
		if (lower < 0.0)
			lower = 0.0;

        [pathSolid removeAllPoints];
		[pathSolid moveToPoint:NSMakePoint((CGFloat)0.0, upper)];
		[pathSolid lineToPoint:NSMakePoint((CGFloat)0.0, lower)];
		[pathSolid lineToPoint:NSMakePoint(rect.size.width, lower)];
		[pathSolid lineToPoint:NSMakePoint(rect.size.width, upper)];
		[pathSolid closePath];
		[pathSolid fill];
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
    [colorGRID set];
    
	for (int i = 1; i < 5; i++) {
		CGFloat y = (rect.size.height / 5.0) * (CGFloat)i;
		CGFloat x = (rect.size.width / 5.0) * (CGFloat)i;

		// vertical line
        [pathDash removeAllPoints];
		[pathDash moveToPoint:NSMakePoint(0, y)];
		[pathDash lineToPoint:NSMakePoint(rect.size.width, y)];
		[pathDash stroke];

		// horizontal line
        [pathDash removeAllPoints];
		[pathDash moveToPoint:NSMakePoint(x, 0)];
		[pathDash lineToPoint:NSMakePoint(x, rect.size.height)];
		[pathDash stroke];
	}
    
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawRange:(NSRect)rect
{
	NSString *text = [NSString stringWithFormat:FMT_RANGE, (y_range / 5.0), (x_range / 5.0), ma_range];
	[self drawText:text inRect:rect atPoint:NSMakePoint(0.0, 0.0)];
}

- (void)drawDate:(NSRect)rect;
{
    NSString *text = FMT_NODATA;
    
	if (_data && ![_data isEmpty])
		text = [dateFormatter stringFromDate:[_data lastDate]];

    [self drawText:text inRect:rect alignRight:rect.size.height];
}

- (void)drawAllWithSize:(NSRect)rect OffScreen:(BOOL)off
{
	[NSGraphicsContext saveGraphicsState];
    
    // create layer (back buffer)
    [self setLayerContextWithRect:rect];
    
	// clear screen
    [colorBG set];
	NSRectFill(rect);
    [colorFG set];

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
    CGContext = [[NSGraphicsContext currentContext] graphicsPort];
    layer = CGLayerCreateWithContext(CGContext, rect.size, NULL);
    layerCGContext = CGLayerGetContext(layer);
    layerContext = [NSGraphicsContext graphicsContextWithCGContext:layerCGContext flipped:FALSE];
    [NSGraphicsContext setCurrentContext:layerContext];
}

- (void)drawLayer
{
    CGContextDrawLayerAtPoint(CGContext, CGPointZero, layer);
}

- (void)resampleData:(TrafficDB *)dataBase inRect:(NSRect)rect
{
	NSDate *end;

    if (!resampler) {
        NSLog(@"No resampler object");
        return;
    }
    
	// fix up _viewTimeOffset
	end = [dataBase lastDate];
    if (end == nil) {
        NSLog(@"No timestamp");
        return;
    }
	end = [end dateByAddingTimeInterval:_viewTimeOffset];
	if ([end laterDate:[dataBase firstDate]] != end) {
        _viewTimeOffset = [[dataBase firstDate] timeIntervalSinceDate:[dataBase lastDate]];
	}

	resampler.outputTimeLength = _viewTimeLength;
	resampler.outputTimeOffset = _viewTimeOffset;
	resampler.outputSamples = rect.size.width;
	resampler.FIRTimeLength = _FIRTimeLength;

    [resampler resampleDataBase:dataBase atDate:end];

	_data = [resampler output];
	_maxSamples = [_data maxSamples];
	_maxValue = [_data maxDoubleValue];
	_averageValue = [_data averageDoubleValue];

	GraphOffset = [resampler overSample];
	XmarkOffset = [resampler overSample] / 2;
}

- (void)importData:(TrafficDB *)dataBase
{
    [self resampleData:dataBase inRect:_bounds];
}

- (void)purgeData
{
	[resampler purgeData];
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
    [self resampleData:dataBase inRect:image_rect];
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
    [self resampleData:dataBase inRect:_bounds];
}

- (void)drawRect:(NSRect)dirty_rect
{
	if (_bounds.size.width != resampler.outputSamples) {
		[resampler purgeData];
		resampler.outputSamples = _bounds.size.width;
	}

	if ([NSGraphicsContext currentContextDrawingToScreen]) {
		[self drawAllWithSize:_bounds OffScreen:NO];
	}
	else {
		[self drawAllWithSize:dirty_rect OffScreen:YES];
	}
}
@end
