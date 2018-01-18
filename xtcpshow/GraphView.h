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
//  GraphView.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//
#import <Cocoa/Cocoa.h>

@class AppDelegate;
@class GraphData;
@class Queue;
@class ComputeQueue;
@class DataResampler;

extern NSString *const RANGE_AUTO;
extern NSString *const RANGE_PEAKHOLD;
extern NSString *const RANGE_MANUAL;

@interface GraphView : NSView {
	// X, Y Range
	float y_range;
	float x_range;
	float ma_range;
	NSUInteger pps_range;

	// range configuration
	NSString *range_mode;
	float manual_range;
	float peak_range;

	// X-axis adjustment
	NSUInteger GraphOffset;
	NSUInteger XmarkOffset;

	// gaphic object cache
	NSGradient *graph_gradient;
	NSMutableDictionary *text_attr;

	// data filter
	DataResampler *resampler;
}
@property (strong) AppDelegate *controller;
@property (strong) ComputeQueue *data;

// statistics
@property (assign, readonly) NSUInteger maxSamples;
@property (assign, readonly) float maxValue;
@property (assign, readonly) float averageValue;

// configuration
@property (assign) float magnifySense;
@property (assign) float scrollSense;
@property (assign) NSTimeInterval minViewTimeLength;
@property (assign) NSTimeInterval maxViewTimeLength;
@property (assign) NSTimeInterval viewTimeLength;

@property (assign) NSTimeInterval maxMATimeLength;
@property (assign) NSTimeInterval minMATimeLength;
@property (assign) NSTimeInterval MATimeLength;

@property (assign) NSTimeInterval viewTimeOffset;

@property (assign) BOOL showPacketMarker;
@property (assign) BOOL showDeviationBand;

- (void)updateRange;

// Action from UI
- (float)setRange:(NSString *)mode withRange:(float)range;
- (float)setRange:(NSString *)mode withStep:(int)step;
- (int)stepValueFromRange:(float)range;
- (void)magnifyWithEvent:(NSEvent *)event;
- (void)scrollWheel:(NSEvent *)event;

// Drawing
- (void)drawGraph:(NSRect)rect;
- (void)drawPPS:(NSRect)rect;
- (void)drawText:(NSString *)text inRect:(NSRect)rect atPoint:(NSPoint)point;
- (void)drawText:(NSString *)text inRect:(NSRect)rect alignRight:(CGFloat)y;
- (void)drawMaxGuide:(NSRect)rect;
- (void)drawAvgGuide:(NSRect)rect;
- (void)drawGrid:(NSRect)rect;
- (void)drawRange:(NSRect)rect;
- (void)drawDate:(NSRect)rect;
- (void)drawAllWithSize:(NSRect)rect OffScreen:(BOOL)off;

- (void)importData:(Queue *)data;
- (void)resampleData:(Queue *)data inRect:(NSRect) rect;
- (void)purgeData;
- (void)saveFile:(Queue *)data;
- (void)drawRect:(NSRect)rect;

@end
