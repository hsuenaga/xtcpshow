//
//  CaptureView.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>
#import <Cocoa/Cocoa.h>

#define NHIST 500
#define MIN_FILTER (1.0) // [Mbps]

@class TCPShowModel;

@interface CaptureHistory : NSObject {
	TAILQ_HEAD(hist_head, history_entry) history;
	int max_hist;
	int cur_hist;
}
- (void)setBufferSize:(int)size;
- (int)size;
- (float)max;
- (float)maxWithItems:(int)n;
- (void)addFloat:(float)value;
- (float)floatAtIndex:(int)index;
- (void)blockForEach:(int (^)(float, int))callback WithItems:(int)n;
@end

@interface CaptureView : NSView {
	CaptureHistory *hist;
	int window_size;
}
@property (weak) TCPShowModel *model;
- (void)allocHist;
- (void)addFloatValue:(float)value;
- (void)setWindowSize:(int)size;
- (void)drawRect:(NSRect)rect;
@end
