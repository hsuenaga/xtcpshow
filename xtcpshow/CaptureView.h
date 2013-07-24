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
#define MIN_FILTER (0.01) // [Mbps]

@class TCPShowModel;

@interface CaptureHistory : NSObject {
	TAILQ_HEAD(hist_head, history_entry) history;
	int max_hist;
	int cur_hist;
}
- (void)setBufferSize:(int)size;
- (int)size;
- (float)max;
- (void)addFloat:(float)value;
- (float)floatAtIndex:(int)index;
- (void)blockForEach:(void (^)(float, int, int))callback;
@end

@interface CaptureView : NSView {
	CaptureHistory *hist;
}
@property (weak) TCPShowModel *model;
- (void)allocHist;
- (void)drawRect:(NSRect)rect;
@end
