//
//  DataQueue.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>
#import <Foundation/Foundation.h>

@class SamplingData;

@interface DataQueue : NSObject {
	NSUInteger refresh_count;
	float add;
	float add_remain;
	float sub;
	float sub_remain;

	SamplingData *last_read;
}
@property (readonly, strong) SamplingData *head;
@property (readonly, strong) SamplingData *tail;
@property (strong) NSDate *last_update;
@property (readonly) NSUInteger count;

//
// protected
//
- (DataQueue *)init;
- (void)addSumState:(float)value;
- (void)subSumState:(float)sub;
- (void)clearSumState;
- (void)refreshSumState;
- (float)sum;

//
// public
//

// add data
- (void)zeroFill:(size_t)size;
- (void)addDataEntry:(SamplingData *)entry;
- (SamplingData *)addDataEntry:(SamplingData *)entry withLimit:(size_t)limit;

// get/delete/shift data
- (SamplingData *)dequeueDataEntry;
- (SamplingData *)shiftDataWithNewData:(SamplingData *)entry;

// read data
- (SamplingData *)readNextData;
- (void)rewind;

// enumerate all data
- (void)enumerateDataUsingBlock:(void(^)(SamplingData *data, NSUInteger idx, BOOL *stop))block;

// copy/clipping queue
- (DataQueue *)copy;

// queue status
- (BOOL)isEmpty;
- (float)maxFloatValue;
- (NSUInteger)maxSamples;
- (float)averageFloatValue;
- (NSDate *)lastDate;
- (NSDate *)firstDate;
- (NSDate *)nextDate;

// debug & exception
- (void)assertCounting;
- (void)invalidValueException;
- (void)invalidChainException:(NSUInteger)count;
@end
