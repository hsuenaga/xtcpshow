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

@interface GraphView : NSView {
	BOOL needRedrawImage;
	BOOL needRedrawAll;
	
	float snap_mbps;
	float trend_mbps;
	float y_range;
	float x_range;
	float sma_range;
}
@property (strong) DataQueue *data;
@property (assign) int SMASize;
@property (assign) int viewOffset;
@property (assign) int windowOffset;
@property (assign) int windowSize;
@property (assign) float resolution;
- (void)initData;
- (void)redrawGraphImage;

- (void)updateRange;

- (void)drawText: (NSString *)t atPoint:(NSPoint)p;
- (void)plotBPS: (float)mbps maxBPS:(float)max_mbps atPos:(unsigned int)n maxPos:(int)max_n;
- (void)plotTrend;
- (float)dataScale;
- (NSRange)viewRange;
- (void)drawAll;
- (void)drawRect:(NSRect)rect;
@end