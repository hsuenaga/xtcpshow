//
//  GraphView.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#import <Cocoa/Cocoa.h>

@class AppDelegate;
@class GraphData;
@class DataQueue;
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
@property (strong) DataQueue *data;

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

- (void)updateRange;

// Action from UI
- (float)setRange:(NSString *)mode withRange:(float)range;
- (float)setRange:(NSString *)mode withStep:(int)step;
- (int)stepValueFromRange:(float)range;
- (void)magnifyWithEvent:(NSEvent *)event;
- (void)scrollWheel:(NSEvent *)event;

// Drawing
- (void)drawGraph;
- (void)drawPPS;
- (void)drawText:(NSString *)text atPoint:(NSPoint)point;
- (void)drawText:(NSString *)text alignRight:(CGFloat)y;
- (void)drawGuide;
- (void)drawGrid;
- (void)drawRange;
- (void)drawDate;
- (void)drawAll;

- (void)importData:(DataQueue *)data;
- (void)purgeData;
- (void)drawRect:(NSRect)rect;

@end