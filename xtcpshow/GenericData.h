// Copyright (c) 2018
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
//  GenericData.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/30.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#import <Foundation/Foundation.h>

enum enum_data_mode {
    DATA_NOVALUE,
    DATA_DOUBLE,
    DATA_INTEGER,
    DATA_UINTEGER,
    DATA_FRACTION
};

@interface GenericData : NSObject<NSCopying>
@property (readonly, atomic, class) NSUInteger newID;
@property (nonatomic, class) NSFileHandle *debugHandle;

@property (nonatomic, readonly) NSUInteger objectID;
@property (nonatomic) NSDate *timestamp;
@property (nonatomic) NSUInteger numberOfSamples;
@property (nonatomic) NSDate *dataFrom;
@property (nonatomic) NSDate *dataTo;
@property (nonatomic) double doubleValue;
@property (nonatomic) int64_t int64Value;
@property (nonatomic) uint64_t uint64Value;

#pragma mark - initializer
- (id)initWithMode:(enum enum_data_mode)mode numerator:(NSNumber *)nvalue denominator:(NSNumber *)dvalue dataFrom:(NSDate *)from dataTo:(NSDate *)to fromSamples:(NSUInteger)samples;

#pragma mark - allocator
+ (id)dataWithoutValue;
+ (id)dataWithDouble:(double)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples;
+ (id)dataWithDouble:(double)data;
+ (id)dataWithInteger:(NSInteger)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples;
+ (id)dataWithInteger:(NSInteger)data;
+ (id)dataWithUInteger:(NSUInteger)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples;
+ (id)dataWithUInteger:(NSUInteger)data;

#pragma mark - accessor
- (void)addInteger:(int64_t)iValue;
- (void)subInteger:(int64_t)iValue;
- (void)divInteger:(int64_t)iValue;
- (void)mulInteger:(int64_t)iValue;

- (void)addData:(GenericData *)data withSign:(int)sign;
- (void)addData:(GenericData *)data;
- (void)subData:(GenericData *)data;
- (void)mulData:(GenericData *)data;
- (void)divData:(GenericData *)data;

- (BOOL)simplifyNumerator:(uint64_t *)np denominator:(uint64_t *)qp;
- (BOOL)simplifyFraction;

- (void)roundFraction:(uint64_t)denominator;

#pragma mark - debug
+ (void)openDebugFile:(NSString *)fileName;
- (void)dumpTree:(BOOL)root;
- (void)writeDebug:(NSString *)format, ... __attribute__((format(__NSString__, 1, 2)));
@end
