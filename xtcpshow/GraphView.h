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

#define RANGE_AUTO		0
#define RANGE_PEEKHOLD		1
#define RANGE_MANUAL		2

#define LINEAR_SCALING		0
#define DISCRETE_SCALING	1

@interface GraphView : NSView {
	BOOL needRedrawImage;
	BOOL needRedrawAll;

	float snap_mbps;
	float trend_mbps;
	float y_range;
	float x_range;
	float sma_range;

	int range_mode;
	float manual_range;
	float peek_range;
	
	NSGradient *graph_gradient;
}
@property (strong) DataQueue *data;
@property (assign) int SMASize;
@property (assign) int viewOffset;
@property (assign) int TargetTimeOffset;
@property (assign) int TargetTimeLength;
@property (assign) float samplingInterval;
@property (assign) int scalingMode;

- (void)initData;

- (void)updateRange;
- (float)setRange:(NSString *)mode withRange:(float)range;

- (void)drawGraph;
- (void)drawText: (NSString *)t atPoint:(NSPoint)p;
- (void)drawGuide;
- (void)drawGrid;
- (void)drawAll;

- (void)importData:(DataQueue *)data;

- (float)dataScale;
- (NSRange)dataRangeTail;
- (NSRange)viewRange;
- (void)drawRect:(NSRect)rect;

@end