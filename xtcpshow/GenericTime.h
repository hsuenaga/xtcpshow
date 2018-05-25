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
//  GenericTime.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/05/22.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#import "FractionNumber.h"

@interface GenericTime : FractionNumber<NSCopying>
@property (nonatomic) uint32_t resolution;

#pragma mark - initializer
- (id)initWithNSTimeInterval:(NSTimeInterval)it withResolution:(uint32_t)res;
+ (id)timeWithNSDate:(NSDate *)date;
+ (id)timeWithTimeval:(const struct timeval *)tv;
+ (id)date;

#pragma mark - acessor
- (NSDate *)NSDate;
- (NSUInteger)sec;
- (void)timeval:(struct timeval *)tv;
- (FractionNumber *)intervalFrom:(GenericTime *)from;

#pragma mark - comparator
- (GenericTime *)earlierTime:(GenericTime *)rtime;
- (GenericTime *)laterTime:(GenericTime *)rtime;
- (BOOL)isEqual:(GenericTime *)rtime;
@end
