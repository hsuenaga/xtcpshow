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
//  TrafficIndex.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2017/12/21.
//  Copyright © 2017年 SUENAGA Hiroki. All rights reserved.
//
#import <sys/time.h>
#import <Foundation/Foundation.h>
#import "FractionNumber.h"
#import "GenericTime.h"
#import "GenericData.h"
#import "TrafficData.h"

#define NBRANCH 10

@interface TrafficIndex : TrafficData
@property (strong, atomic, readonly) GenericTime *lastDate;
@property (assign, nonatomic, readonly) uint64_t bytesBefore;
@property (assign, nonatomic, readonly) uint64_t samplesBefore;
@property (assign, nonatomic, readonly) NSTimeInterval Resolution;

#pragma mark - initializer
- (id)initWithResolution:(NSTimeInterval)resolusion startAt:(GenericTime *)start endAt:(GenericTime *)end;
+ (id)dataOf:(id)parent withResolution:(NSTimeInterval)Resolution startAt:(GenericTime *)start endAt:(GenericTime *)end;
+ (id)unixDataOf:(id)parent withMsResolution:(NSUInteger)msResolution
         startAt:(struct timeval *)tvStart endAt:(struct timeval *)tvEnd;

#pragma mark - operator
- (TrafficData *)addSampleAtTimeval:(struct timeval *)tv withBytes:(NSUInteger)bytes auxData:(id)aux;
- (TrafficData *)addSampleAtTimevalExtend:(struct timeval *)tv withBytes:(NSUInteger)bytes auxData:(id)aux;

#pragma mark - NSCopying protocol
- (id)copyWithZone:(NSZone *)zone;
@end
