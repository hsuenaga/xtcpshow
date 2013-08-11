//
//  GraphView.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#import <Cocoa/Cocoa.h>

@class GraphData;
@class DataQueue;
@class DataResampler;

extern NSString *const RANGE_AUTO;
extern NSString *const RANGE_PEEKHOLD;
extern NSString *const RANGE_MANUAL;

@interface GraphView : NSView {
	BOOL needRedrawImage;
	BOOL needRedrawAll;

	float snap_mbps;
	float trend_mbps;
	float y_range;
	float x_range;
	float sma_range;

	NSString *range_mode;
	float manual_range;
	float peak_range;

	NSTimeInterval time_offset; //[sec]
	NSTimeInterval time_length; //[sec]
	NSTimeInterval sma_length; //[sec]

	NSGradient *graph_gradient;
}
@property (strong) DataQueue *data;
@property (assign) int viewOffset;
@property (assign) float samplingInterval;
@property (assign) NSUInteger maxSamples;
@property (assign) float maxValue;
@property (assign) float averageValue;
@property (assign) BOOL showPacketMarker;

- (void)initData;

- (void)updateRange;

// Action from UI
- (float)setRange:(NSString *)mode withRange:(float)range;
- (float)setRange:(NSString *)mode withStep:(int)step;
- (int)stepValueWithRange:(float)range;
- (void)setTargetTimeLength:(int)value;
- (void)setSMALength:(int)value;

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