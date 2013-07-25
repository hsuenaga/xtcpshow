//
//  GraphData.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>
#import <Cocoa/Cocoa.h>

#define NHIST 500
#define MIN_FILTER (1.0) // [Mbps]

@interface GraphData : NSObject {
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