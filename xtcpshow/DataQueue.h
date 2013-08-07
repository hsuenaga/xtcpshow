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
	float data; // Sampling data

	STAILQ_ENTRY(DataQueueEntry) chain;
};

@interface DataQueue : NSObject {
	STAILQ_HEAD(DataQueueHead, DataQueueEntry) head;
	float add;
	float add_remain;
	float sub;
	float sub_remain;
}
@property (readonly) NSUInteger count;
@property (assign) float interval; // Average Sampling interval

// differential sum update.
- (void)addSumState:(float)value;
- (void)subSumState:(float)sub;
- (void)clearSumState;
- (void)refreshSumState;
- (float)sum;

// add data
- (BOOL)addFloatValue:(float)value;
- (float)addFloatValue:(float)value withLimit:(size_t)limit;
- (BOOL)prependFloatValue:(float)value;

// get/delete/shift data
- (float)dequeueFloatValue;
- (float)shiftFloatValueWithNewValue:(float)newvalue;

// enumerate all data
- (void)enumerateFloatUsingBlock:(void(^)(float value, NSUInteger idx,  BOOL *stop))block;
- (void)replaceValueUsingBlock:(void(^)(float *value, NSUInteger idx, BOOL *stop))block;

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
