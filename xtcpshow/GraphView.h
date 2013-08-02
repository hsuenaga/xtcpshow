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

#define RANGE_AUTO 0
#define RANGE_PEEKHOLD 1
#define RANGE_MANUAL 2

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
}
@property (strong) DataQueue *data;
@property (assign) int SMASize;
@property (assign) int viewOffset;
@property (assign) int TargetTimeOffset;
@property (assign) int TargetTimeLength;
@property (assign) float resolution;
- (void)initData;
- (void)redrawGraphImage;

- (void)updateRange;
- (void)setRange:(NSString *)mode withRange:(float)range;

- (void)drawText: (NSString *)t atPoint:(NSPoint)p;
- (void)plotBPS: (float)mbps maxBPS:(float)max_mbps atPos:(unsigned int)n maxPos:(int)max_n;
- (void)plotTrend;
- (float)dataScale;
- (NSRange)viewRange;
- (void)drawAll;
- (void)drawRect:(NSRect)rect;
@end