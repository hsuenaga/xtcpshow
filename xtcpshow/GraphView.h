//
//  GraphView.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#import <Cocoa/Cocoa.h>

@class GraphData;

@interface GraphView : NSView {
	BOOL needRedrawImage;
	BOOL needRedrawAll;
	
	GraphData *data;
	NSImage *image;
	NSImage *backbuffer;
	NSBitmapImageRep *image_rep;
	NSBitmapImageRep *backbuffer_rep;
	NSSize image_size;
	float snap_mbps;
	float trend_mbps;
	float view_avg_mbps;
	float view_max_mbps;
	float resolution;
	float y_range;
	float x_range;
	int window_size;
	int sma_size;
}
- (void)allocGraphImage;
- (void)clearGraphImage;
- (void)redrawGraphImage;

- (void)updateRange;

- (void)drawText: (NSString *)t atPoint:(NSPoint)p;
- (void)plotBPS: (float)mbps maxBPS:(float)max_mbps atPos:(unsigned int)n maxPos:(int)max_n;
- (void)plotTrend;
- (void)allocHist;
- (void)setWindowSize:(int)size;
- (void)setSMASize:(int)size;

- (void)drawAll;
- (void)drawRect:(NSRect)rect;

- (void)addSnap:(float)snap trendData:(float)trend resolusion:(float)res;
@end