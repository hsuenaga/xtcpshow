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
//  Queue.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/12.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#ifndef Queue_h
#define Queue_h
#import <Foundation/Foundation.h>

@interface QueueEntry : NSObject<NSCopying>
@property (nonatomic) NSDate *timestamp;
@property (nonatomic) id content;
@property (atomic) QueueEntry *next;

- (QueueEntry *)initWithData:(id)data withTimestamp:(NSDate *)ts;
- (QueueEntry *)init;
+ (QueueEntry *)entryWithData:(id)data withTimestamp:(NSDate *)ts;
- (id)copyWithZone:(NSZone *)zone;
@end

@interface Queue : NSObject<NSCopying>
@property (atomic) NSDate *last_used;
@property (nonatomic) NSUInteger count;
@property (nonatomic) size_t size;
@property (atomic) QueueEntry *head;
@property (atomic) QueueEntry *tail;
@property (atomic) QueueEntry *last_read;

//
// protected
//
- (Queue *)init;
- (Queue *)initWithSize:(size_t)size;

//
// public
//
+ (Queue *)queueWithSize:(size_t)size;
+ (Queue *)queueWithoutSize;

// add data
- (QueueEntry *)enqueueEntry:(QueueEntry *)entry;
- (QueueEntry *)dequeueEntry;
- (id)enqueue:(id)entry withTimestamp:(NSDate *)ts;
- (id)dequeue;

// read data
- (id)readNextData;
- (void)rewind;

//
// date
//
- (NSDate *)firstDate;
- (NSDate *)lastDate;
- (NSDate *)nextDate;
- (void)seekToDate:(NSDate *)date;

// enumerate all data
- (void)enumerateDataUsingBlock:(void(^)(id data, NSUInteger idx, BOOL *stop))block;

// queue status
- (BOOL)isEmpty;

// debug & exception
- (void)assertCounting;
- (void)invalidChainException:(NSUInteger)count;
@end

#endif /* Queue_h */
