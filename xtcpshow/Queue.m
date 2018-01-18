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
//  Queue.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/12.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sys/types.h>
#import "Queue.h"

#define DEBUG_COUNTER

#ifdef DEBUG_COUNTER
#define ASSERT_COUNTER(x) [(x) assertCounting]
#else
#define ASSERT_COUNTER(x) // nothing
#endif

//
// QueueEntry
//
@implementation QueueEntry
- (QueueEntry *)initWithData:(id)data withTimestamp:(NSDate *)ts
{
    self = [super init];
    
    self.content = data;
    self.timestamp = ts;
    self.next = nil;
    
    return self;
}
- (QueueEntry *)init
{
    return [self initWithData:nil withTimestamp:nil];
}

+ (QueueEntry *)entryWithData:(id)data withTimestamp:(NSDate *)ts
{
    return [[QueueEntry alloc] initWithData:data withTimestamp:ts];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[QueueEntry alloc]
            initWithData:self.content
            withTimestamp:self.timestamp];
}
@end

//
// Queue
//
@implementation Queue
- (Queue *)initWithSize:(size_t)size
{
    self = [super init];
    self.size = size;
    return self;
}

- (Queue *)init
{
    return [self initWithSize:0];
}

//
// public
//
+ (Queue *)queueWithSize:(size_t)size
{
    if (size == 0)
        return nil;
    
    return [[Queue alloc] initWithSize:size];
}

+ (Queue *)queueWithoutSize
{
    return [[Queue alloc] initWithSize:0];
}

- (QueueEntry *)enqueueEntry:(QueueEntry *)entry
{
    ASSERT_COUNTER(self);
    // enqueue
    if (self.tail) {
        self.tail.next = entry;
        self.tail = entry;
    }
    else {
        self.head = self.tail = entry;
    }
    self.count++;

    // dequeue
    return self.count < self.size ? nil : [self dequeueEntry];
}

- (QueueEntry *)dequeueEntry
{
    ASSERT_COUNTER(self);

    if (!self.head)
        return nil;
    
    QueueEntry *entry = self.head;
    self.head = entry.next;
    entry.next = nil;
    
    if (!self.head)
        self.tail = nil;
    if (self.last_read == entry)
        self.last_read = nil;
    self.count--;

    return entry;
}

- (id)enqueue:(id)data withTimestamp:(NSDate *)ts
{
    QueueEntry *entry;
    
    if (!data)
        return nil;
    entry = [self enqueueEntry:[QueueEntry entryWithData:data withTimestamp:ts]];
    return entry ? entry.content : nil;
}

- (id)dequeue
{
    QueueEntry *entry = [self dequeueEntry];
    return entry ? entry.content : nil;
}

- (id)readNextData
{
    QueueEntry *entry;
    
    if (!self.head)
        return nil;
    
    if (self.last_read && self.last_read.next == nil)
        return nil; // no new data arrived.
    
    if (!self.last_read) {
        entry = self.head;
    }
    else {
        entry = self.last_read.next;
    }
    self.last_read = entry;
    
    return entry.content;
}

- (void)rewind
{
    self.last_read = nil;
}

- (NSDate *)firstDate
{
    if (self.head == nil)
        return nil;
    return [self.head timestamp];
}

- (NSDate *)lastDate
{
    if (self.tail == nil)
        return nil;
    return [self.tail timestamp];
}

- (NSDate *)nextDate
{
    if (!self.head) {
        return nil;
    }
    
    if (!self.last_read) {
        return self.head.timestamp;
    }
    if (!self.last_read.next) {
        return nil;
    }
    return self.last_read.next.timestamp;
}

- (void)seekToDate:(NSDate *)date
{
    if (!self.head)
        return;
    self.last_read = nil;
    
    for (QueueEntry *entry = self.head; entry;
         entry = entry.next)
    {
        NSDate *seek = entry.timestamp;
        
        if ([date laterDate:seek] == date) {
            self.last_read = entry;
            continue;
        }
        break;
    }
}

- (void)enumerateDataUsingBlock:(void (^)(id data, NSUInteger, BOOL *))block
{
    QueueEntry *entry;
    NSUInteger idx;
    BOOL stop = FALSE;

    for (idx = 0, entry =self.head; entry; entry = entry.next) {
        if ((idx + 1) > self.count)
            [self invalidChainException:idx];
        if (!stop)
            block(entry.content, idx, &stop);
        idx++;
    }
    ASSERT_COUNTER(self);
}

- (Queue *)copy
{
    QueueEntry *entry;
    Queue *new = [Queue queueWithSize:_size];
    
    for (entry = self.head; entry; entry = entry.next)
        [new enqueue:[entry copy] withTimestamp:[entry timestamp]];
    ASSERT_COUNTER(self);
    return new;
}

- (BOOL)isEmpty
{
    if (!_head)
        return TRUE;
    
    return FALSE;
}

- (void)assertCounting
{
    QueueEntry *entry;
    NSUInteger idx = 0;
    
    for (entry = self.head; entry; entry = entry.next)
        idx++;
    
    NSAssert(idx == self.count,
             @"counter(%lu) and entries(%lu) are mismatched", self.count, idx);
}

- (void)invalidChainException:(NSUInteger)idx
{
    NSString *message;
    
    message = [NSString stringWithFormat:@"counter(%lu) and entry index(%lu) are mismatched", self.count, idx];
    NSException *ex = [NSException exceptionWithName:@"Invalid Chain" reason:message userInfo:nil];
    
    @throw ex;
}
@end

