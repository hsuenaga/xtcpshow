//
//  GraphData.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>
#import <Cocoa/Cocoa.h>

#define DEF_BUFSIZ 1000
#define MIN_FILTER (1.0) // [Mbps]

@interface GraphData : NSObject {
	TAILQ_HEAD(hist_head, history_entry) history;
	int max_hist;
	int cur_hist;
}
- (void)setBufferSize:(int)size;
- (int)size;
- (float)max;
- (void)addFloat:(float)value;
- (float)floatAtIndex:(int)index;
- (void)blockForEach:(int (^)(float, int))callback WithItems:(int)n WithSMA:(int)sma;
- (float)maxWithItems:(int)n withSMA:(int)sma;

@end