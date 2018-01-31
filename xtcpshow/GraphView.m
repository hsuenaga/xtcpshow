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
#import "GraphViewOperation.h"
#import "ComputeQueue.h"
#import "PID.h"
#import "TrafficIndex.h"
#import "TrafficDB.h"

//
// string constants
//
NSString *const RANGE_AUTO = @"Auto";
NSString *const RANGE_PEAKHOLD = @"PeakHold";
NSString *const RANGE_MANUAL = @"Manual";

NSString *const FIR_NONE = @"NONE";
NSString *const FIR_SMA = @"SMA(1)";
NSString *const FIR_TMA = @"TMA(2)";
NSString *const FIR_GAUS = @"Gausian(3)";

NSString *const FILL_NONE = @"None";
NSString *const FILL_SIMPLE = @"Simple";
NSString *const FILL_RICH = @"Rich";

NSString *const CAP_MAX_SMPL = @" Max %lu [packets/sample]";
NSString *const CAP_MAX_MBPS = @" Max %6.3f [Mbps]";
NSString *const CAP_AVG_MBPS = @" Avg %6.3f [Mbps], StdDev %6.3f [Mbps]";

NSString *const FMT_RANGE = @" VERT %6.3f [Mbps/div] / HORIZ %6.1f [ms/div] / FIR %6.1f [ms]";
NSString *const FMT_DATE = @"yyyy-MM-dd HH:mm:ss.SSS zzz ";
NSString *const FMT_NODATA = @"NO DATA RECORD ";

//
// float constants
//
float const animation_fps = 20.0;
float const magnify_sensitivity = 2.0;
float const scroll_sensitivity = 10.0;
double const time_round = 0.05;

//
// Private Properties
//
@interface GraphView () {
    NSTimeInterval _viewTimeOffset;
}
// Internal Configuration.
@property (nonatomic) float magnifySense;
@property (nonatomic) float scrollSense;

// Offset of viewport. changed by scroll controll.
@property (nonatomic) NSTimeInterval minViewTimeOffset;
@property (nonatomic) NSTimeInterval viewTimeOffset;
@property (nonatomic) NSTimeInterval maxViewTimeOffset;

// Status Update
- (BOOL)updateRangeY;
- (BOOL)updateRangePPS;
@end

//
// class implementation
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
    self.pathBold = [NSBezierPath bezierPath];
    [self.pathBold setLineWidth:2.0];
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
    self.cueAnimation = [NSOperationQueue new];
    self.cueActive = FALSE;
	self.viewData = nil;
	self.showPacketMarker = TRUE;
    self.animationFPS = animation_fps;
	self.magnifySense = magnify_sensitivity;
	self.scrollSense = scroll_sensitivity;
    self.useHistgram = FALSE;
    self.useOutline = TRUE;
    self.fillMode = E_FILL_RICH;
	self.PID = [[PID alloc] init];
    self.PID.kzStage = 3;
    self.minViewTimeOffset = NAN;
    self.maxViewTimeOffset = 0.0;

	return self;
}

- (BOOL)updateRangeY
{
    float new_range;
    float max = [self.viewData maxDoubleValue];
    if (self.range_mode == RANGE_PEAKHOLD) {
        if (self.peak_range < max)
            self.peak_range = max;
        else
            max = self.peak_range;
    }
    
    if (self.range_mode == RANGE_MANUAL) {
        /* manual scaling */
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

    return FALSE;
}

- (BOOL)updateRangePPS
{
    if (self.range_mode == RANGE_AUTO) {
        // auto
        self.pps_range = self.maxSamples;
    }
    else if (self.pps_range < self.maxSamples) {
        // peak hold (no manual settting)
        self.pps_range = self.maxSamples;
    }
    return FALSE;
}

- (void)updateRange
{
	BOOL resample = NO;

	// Y-axis
    if ([self updateRangeY])
        resample = YES;

	// PPS
    if ([self updateRangePPS])
        resample = YES;
	
    // Purge data if required.
    if (resample)
		[self purgeData];
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

- (void)setFIRMode:(NSString *)mode
{
    if (mode == FIR_NONE) {
        self.PID.kzStage = 0;
    }
    else if (mode == FIR_SMA) {
        self.PID.kzStage = 1;
    }
    else if (mode == FIR_TMA) {
        self.PID.kzStage = 2;
    }
    else if (mode == FIR_GAUS) {
        self.PID.kzStage = 3;
    }
    else {
        self.PID.kzStage = 0;
    }
    [self purgeData];
}

- (void)setBPSFillMode:(NSString *)mode
{
    if (mode == FILL_NONE) {
        self.fillMode = E_FILL_NONE;
    }
    else if (mode == FILL_SIMPLE) {
        self.fillMode = E_FILL_SIMPLE;
    }
    else if (mode == FILL_RICH) {
        self.fillMode = E_FILL_RICH;
    }
    [self purgeData];
}

- (void)createRangeButton:(NSPopUpButton *)btn
{
    [btn removeAllItems];
    [btn addItemWithTitle:RANGE_AUTO];
    [btn addItemWithTitle:RANGE_PEAKHOLD];
    [btn addItemWithTitle:RANGE_MANUAL];
    [btn selectItemWithTitle:RANGE_AUTO];
    [self setRange:RANGE_AUTO withRange:0.0];
}

- (void)createFIRButton:(NSPopUpButton *)btn
{
    [btn removeAllItems];
    [btn addItemWithTitle:FIR_NONE];
    [btn addItemWithTitle:FIR_SMA];
    [btn addItemWithTitle:FIR_TMA];
    [btn addItemWithTitle:FIR_GAUS];
    [btn selectItemWithTitle:FIR_GAUS];
}

- (void)createFillButton:(NSPopUpButton *)btn
{
    [btn removeAllItems];
    [btn addItemWithTitle:FILL_NONE];
    [btn addItemWithTitle:FILL_SIMPLE];
    [btn addItemWithTitle:FILL_RICH];
    [btn selectItemWithTitle:FILL_RICH];
}

- (NSTimeInterval)viewTimeLength
{
    return _viewTimeLength;
}

- (void)setViewTimeLength:(NSTimeInterval)viewTimeLength
{
    double old = _viewTimeLength;
    _viewTimeLength = [self saturateDouble:viewTimeLength
                                   withMax:self.maxViewTimeLength
                                   withMin:self.minViewTimeLength
                                   roundBy:time_round];
    if (fabs(old - _viewTimeLength) > time_round)
        [self purgeData];
}

- (NSTimeInterval)FIRTimeLength
{
    return _FIRTimeLength;
}

- (void)setFIRTimeLength:(NSTimeInterval)FIRTimeLength
{
    double old = _FIRTimeLength;
    _FIRTimeLength = [self saturateDouble:FIRTimeLength
                                  withMax:self.maxFIRTimeLength
                                  withMin:self.minFIRTimeLength
                                  roundBy:time_round];
    if (fabs(old - _FIRTimeLength) > time_round)
        [self purgeData];
}

- (NSTimeInterval)viewTimeOffset
{
    return _viewTimeOffset;
}

- (void)setViewTimeOffset:(NSTimeInterval)viewTimeOffset
{
    double old = _viewTimeOffset;
    _viewTimeOffset = [self saturateDouble:viewTimeOffset
                                   withMax:self.maxViewTimeOffset
                                   withMin:self.minViewTimeOffset
                                   roundBy:time_round];
    if (fabs(old - _viewTimeOffset) > time_round)
        [self purgeData];
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

//
// Actions/Events from window server
//
- (void)magnifyWithEvent:(NSEvent *)event
{
    self.viewTimeLength *= 1.0/(1.0 + (event.magnification/self.magnifySense));
    
    [self.controller zoomGesture:self];
}

- (void)scrollWheel:(NSEvent *)event
{
    self.FIRTimeLength -= (event.deltaY/self.scrollSense);
    self.viewTimeOffset -= event.deltaX/self.scrollSense;
    
    [self.controller scrollGesture:self];
}



//
// Computing
//
- (double)saturateDouble:(double)value withMax:(double)max withMin:(double)min roundBy:(double)round
{
    if (!isnan(round))
        value = floor(value/round) * round;
    if (!isnan(min) && value < min)
        value = min;
    if (!isnan(max) && value > max)
        value = max;
    
    return value;
}

- (BOOL)resampleDataInRect:(NSRect)rect
{
	NSDate *end;

    // data is not imported.
    if (!self.inputData) {
        return FALSE;
    }
    
	// fix up _viewTimeOffset
	end = [self.inputData lastDate];
    if (end == nil) {
        NSLog(@"No timestamp");
        return FALSE;
    }
    else if (self.lastResample && [self.lastResample isEqual:end]) {
        NSLog(@"Data is not updated");
        return FALSE;
    }
    self.lastResample = end;
    
    // add offset
	end = [end dateByAddingTimeInterval:self.viewTimeOffset];
	if ([end laterDate:[self.inputData firstDate]] != end) {
        self.viewTimeOffset = [[self.inputData firstDate] timeIntervalSinceDate:[self.inputData lastDate]];
	}

	self.PID.outputTimeLength = self.viewTimeLength;
	self.PID.outputTimeOffset = self.viewTimeOffset;
	self.PID.outputSamples = rect.size.width;
	self.PID.FIRTimeLength = self.FIRTimeLength;
    [self.PID resampleDataBase:self.inputData atDate:end];

	self.viewData = [self.PID output];
	self->_maxSamples = [self.viewData maxSamples];
	self->_maxValue = [self.viewData maxDoubleValue];
	self->_averageValue = [[self.viewData averageData] doubleValue];
	self.GraphOffset = [self.PID overSample];
	self.XmarkOffset = [self.PID overSample] / 2;
    
    return TRUE;
}

- (void)importData:(TrafficDB *)dataBase
{
    if (self.inputData != dataBase) {
        self.inputData = dataBase;
    }
    [self startPlot:FALSE];
}


- (void)purgeData
{
	[self.PID purgeData];
    self.lastResample = nil;
    self.lastBounds = self.bounds;
    [self startPlot:FALSE];
}

- (void)saveFile:(TrafficDB *)dataBase;
{
    NSRect image_rect = [self bounds];
    NSData *pdfData = [self dataWithPDFInsideRect:image_rect];

    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setAllowedFileTypes:@[@"pdf"]];
    [panel setNameFieldStringValue:@"xtcpshow_hardcopy.pdf"];
    [panel runModal];
    NSLog(@"save to %@", [panel URL]);
    [pdfData writeToURL:[panel URL] atomically:TRUE];
}
@end
