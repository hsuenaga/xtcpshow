//
//  GraphData.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>
#import <Cocoa/Cocoa.h>

#define DEF_BUFSIZ 2000
#define MIN_FILTER (0.001) // = 1 [kbps]

@interface GraphData : NSObject {
	TAILQ_HEAD(hist_head, history_entry) history;
	int max_hist;
	int cur_hist;
	int sma_size;
}
- (void)setBufferSize:(int)size;
- (void)setSMASize:(int)size;
- (int)size;
- (float)max;
- (void)addFloat:(float)value;
- (float)floatAtIndex:(int)index;
- (void)forEach:(int (^)(float, int))callback withRange:(int)n withWidth:(int)w;
- (float)maxWithRange:(int)n;

@end