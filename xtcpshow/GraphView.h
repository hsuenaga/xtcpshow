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
extern NSString *const RANGE_PEEKHOLD;
extern NSString *const RANGE_MANUAL;

@interface GraphView : NSView {
	// X, Y Range
	float y_range;
	float x_range;
	float ma_range;

	// range configuration
	NSString *range_mode;
	float manual_range;
	float peak_range;

	// X-axis adjustment
	NSUInteger GraphOffset;
	NSUInteger XmarkOffset;

	// gaphic object cache
	NSGradient *graph_gradient;

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
- (int)stepValueWithRange:(float)range;
- (void)magnifyWithEvent:(NSEvent *)event;
- (void)scrollWheel:(NSEvent *)event;

// Drawing
- (void)drawGraph;
- (void)drawXMark;
- (void)drawText: (NSString *)t atPoint:(NSPoint)p;
- (void)drawGuide;
- (void)drawGrid;
- (void)drawAll;

- (void)importData:(DataQueue *)data;
- (void)drawRect:(NSRect)rect;

@end