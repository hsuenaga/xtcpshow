//
//  GraphView.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#import <Cocoa/Cocoa.h>

#define NHIST 500
#define MIN_FILTER (1.0) // [Mbps]

@class GraphData;
@class TCPShowModel;

@interface GraphView : NSView {
	GraphData *data;
	float snap_mbps;
	float trend_mbps;
	float resolution;
	int window_size;
}
@property (weak) TCPShowModel *model;
- (void)allocHist;
- (void)setWindowSize:(int)size;
- (void)drawRect:(NSRect)rect;

- (void)addSnap:(float)snap trendData:(float)trend resolusion:(float)res;
@end