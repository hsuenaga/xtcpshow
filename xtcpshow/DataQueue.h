//
//  DataQueue.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>
#import <Foundation/Foundation.h>

struct DataQueueEntry {
	float data;
	
	STAILQ_ENTRY(DataQueueEntry) chain;
};

@interface DataQueue : NSObject {
	STAILQ_HEAD(DataQueueHead, DataQueueEntry) head;
}
@property (readonly) NSUInteger count;
@property (readonly) float sum;

// add data
- (BOOL)addFloatValue:(float)value;

// get/delete/shift data
- (float)dequeueFloatValue;
- (float)shiftFloatValueWithNewValue:(float)newvalue;

// enumerate all data
- (void)enumerateFloatUsingBlock:(void(^)(float value, NSUInteger idx,  BOOL *stop))block;

// clear queue
- (void)zeroFill:(size_t)size;
- (void)deleteAll;

// clipping queue
- (void)removeFromHead:(size_t)size;
- (void)clipFromHead:(size_t)size;

// queue status
- (BOOL)isEmpty;
- (float)maxFloatValue;
- (float)averageFloatValue;
@end
