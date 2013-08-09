//
//  DataQueue.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>
#import <Foundation/Foundation.h>

@class DataEntry;

@interface DataQueue : NSObject {
	NSUInteger refresh_count;
	float add;
	float add_remain;
	float sub;
	float sub_remain;
}
@property (readonly, strong) DataEntry *head;
@property (readonly, strong) DataEntry *tail;
@property (readonly) NSUInteger count;
@property (assign) float interval; // Average Sampling interval

// protected
- (DataQueue *)init;

// differential sum update.
- (void)addSumState:(float)value;
- (void)subSumState:(float)sub;
- (void)clearSumState;
- (void)refreshSumState;
- (float)sum;

// add data
- (void)addDataEntry:(DataEntry *)entry;
- (DataEntry *)addDataEntry:(DataEntry *)entry withLimit:(size_t)limit;
- (void)addFloatValue:(float)value;
- (float)addFloatValue:(float)value withLimit:(size_t)limit;
- (BOOL)prependFloatValue:(float)value;

// get/delete/shift data
- (DataEntry *)dequeueDataEntry;
- (float)dequeueFloatValue;
- (DataEntry *)shiftDataWithNewData:(DataEntry *)entry;
- (float)shiftFloatValueWithNewValue:(float)newvalue;

// time
- (float)lastSeconds;
- (float)firstSeconds;

// enumerate all data
- (void)enumerateFloatUsingBlock:(void(^)(float value, NSUInteger idx,  BOOL *stop))block;
- (void)enumerateFloatWithTimeUsingBlock:(void(^)(float value, float seconds, NSUInteger idx, BOOL *stop))block;
- (void)replaceValueUsingBlock:(void(^)(float *value, NSUInteger idx, BOOL *stop))block;

// clear queue
- (void)zeroFill:(size_t)size;
- (void)deleteAll;

// copy/clipping queue
- (DataQueue *)duplicate;
- (void)removeFromHead:(size_t)size;
- (void)clipFromHead:(size_t)size;

// queue status
- (BOOL)isEmpty;
- (float)maxFloatValue;
- (float)averageFloatValue;

// debug & exception
- (void)assertCounting;
- (void)invalidValueException;
- (void)invalidChainException:(NSUInteger)count;
@end
