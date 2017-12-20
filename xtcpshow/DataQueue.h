// Copyright (c) 2013
// SUENAGA Hiroki <hiroki_suenaga@mac.com>. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.

// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

//
//  DataQueue.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>
#import <Foundation/Foundation.h>

@class DataQueueEntry, SamplingData;

@interface DataQueue : NSObject {
	NSUInteger refresh_count;
	float add;
	float add_remain;
	float sub;
	float sub_remain;
}
@property (strong) NSDate *last_update;
@property (readonly) NSUInteger count;
@property (strong) DataQueueEntry *head;
@property (strong) DataQueueEntry *tail;
@property (strong) DataQueueEntry *last_read;

//
// protected
//
- (DataQueue *)initWithZeroFill:(int)size;
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
- (void)seekToDate:(NSDate *)date;
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
- (float)standardDeviation;

- (NSDate *)lastDate;
- (NSDate *)firstDate;
- (NSDate *)nextDate;

// debug & exception
- (void)assertCounting;
- (void)invalidValueException;
- (void)invalidChainException:(NSUInteger)count;
@end
