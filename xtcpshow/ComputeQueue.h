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
#import "DerivedData.h"
#import "Queue.h"

@interface ComputeQueueEntry : QueueEntry
@property DerivedData *data;
- (ComputeQueueEntry *)initWithData:(id)data withTimestamp:(NSDate *)ts;
+ (ComputeQueueEntry *)entryWithData:(id)data withTimestamp:(NSDate *)ts;
@end

@interface ComputeQueue : Queue {
    double prec;
	double sumState;
	double add_remain;
}

//
// protected
//
- (ComputeQueue *)initWithZeroFill:(size_t)size;
- (ComputeQueue *)init;
- (void)addSumState:(double)value;
- (void)subSumState:(double)sub;
- (void)clearSumState;
- (double)sum;

//
// allocator
//
+ (ComputeQueue *)queueWithSize:(size_t)size;
+ (ComputeQueue *)queueWithZero:(size_t)size;

// initizlize
- (void)zeroFill;

// queue op
- (DerivedData *)enqueue:(DerivedData *)data withTimestamp:(NSDate *)ts;
- (DerivedData *)dequeue;

// queue status
- (double)maxDoubleValue;
- (NSUInteger)maxSamples;
- (double)averageDoubleValue;
- (double)standardDeviation;

// debug & exception
- (void)invalidValueException;
@end
