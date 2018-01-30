// Copyright (c) 2017
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
//  TrafficData.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2017/12/22.
//  Copyright © 2017年 SUENAGA Hiroki. All rights reserved.
//
#import <sys/time.h>

#import <Foundation/Foundation.h>

#import "GenericData.h"
#import "TimeConverter.h"
// precision used by smart string representations.
#define PRECISION 1

@interface TrafficData : GenericData
@property (strong, nonatomic, readonly) id parent;
@property (strong, nonatomic, readonly) id next;
@property (strong, nonatomic, readonly) id aux;

#pragma mark - initializer
- (id)initAtTimeval:(struct timeval *)tv withPacketLength:(uint64_t)length;
+ (TrafficData *)sampleOf:(id)parent atTimeval:(struct timeval *)tv withPacketLength:(uint64_t)length auxData:(id)aux;

#pragma mark - basic acessor
- (TrafficData *)addSampleAtTimeval:(struct timeval *)tv withBytes:(NSUInteger)bytes auxData:(id)aux;
- (BOOL)dataAtDate:(NSDate *)date withBytes:(NSUInteger *)bytes withSamples:(NSUInteger *)samples;
- (NSUInteger)bitsAtDate:(NSDate *)date;
- (NSUInteger)bytesAtDate:(NSDate *)date;
- (NSUInteger)samplesAtDate:(NSDate *)date;
- (NSDate *)timestamp;
- (NSUInteger)bytesReceived;

#pragma mark - smart string representations
- (NSString *)bytesString;

#pragma mark - utility
+ (NSDate *)alignTimeval:(struct timeval *)tv withResolution:(NSTimeInterval)resolution;
- (void)alignStartEnd;
- (NSUInteger)msStart;
- (NSUInteger)msEnd;
@end
