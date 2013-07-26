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
	GraphData *data;
	float snap_mbps;
	float trend_mbps;
	float resolution;
	int window_size;
	int sma_size;
}
- (void)allocHist;
- (void)setWindowSize:(int)size;
- (void)setSMASize:(int)size;
- (void)drawRect:(NSRect)rect;

- (void)addSnap:(float)snap trendData:(float)trend resolusion:(float)res;
@end