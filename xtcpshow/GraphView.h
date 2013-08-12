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

	// configuration of data import
	NSTimeInterval time_offset; //[sec] XXX: not used
	NSTimeInterval time_length; //[sec]
	NSTimeInterval sma_length; //[sec]

	// X-axis adjustment
	NSUInteger GraphOffset;
	NSUInteger XmarkOffset;

	// gaphic object cache
	NSGradient *graph_gradient;
}
@property (strong) AppDelegate *controller;
@property (strong) DataQueue *data;

// statistics
@property (assign, readonly) NSUInteger maxSamples;
@property (assign, readonly) float maxValue;
@property (assign, readonly) float averageValue;

// configuration
@property (assign) int maxTimeLength;
@property (assign) int maxMATimeLength;
@property (assign) BOOL showPacketMarker;

- (void)updateRange;

// Action from UI
- (float)setRange:(NSString *)mode withRange:(float)range;
- (float)setRange:(NSString *)mode withStep:(int)step;
- (int)stepValueWithRange:(float)range;
- (void)setTargetTimeLength:(int)value;
- (int)targetTimeLength;
- (void)setMATimeLength:(int)value;
- (int)MATimeLength;
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