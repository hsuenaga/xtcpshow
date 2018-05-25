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
//  FractionNumber.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/05/24.
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

@interface FractionNumber : NSObject<NSCopying>
@property (atomic, class) BOOL defaultSaturation;
@property (atomic, class) BOOL preferReal;
@property (nonatomic) BOOL saturateValue;
@property (nonatomic) double doubleValue;
@property (nonatomic) int64_t int64Value;
@property (nonatomic) uint64_t uint64Value;

#pragma mark - initializer
- (id)initWithMode:(enum enum_data_mode)mode numerator:(NSNumber *)nvalue denominator:(NSNumber *)dvalue  enableSaturation:(BOOL)saturation;

#pragma mark - allocator
+ (id)numberWithoutValue;
+ (id)numberWithDouble:(double)data;
+ (id)numberWithInteger:(NSInteger)data;
+ (id)numberWithUInteger:(NSUInteger)data;

#pragma mark - accessor
- (void)addInteger:(NSInteger)iValue;
- (void)subInteger:(NSInteger)iValue;
- (void)divInteger:(NSInteger)iValue;
- (void)mulInteger:(NSInteger)iValue;

- (void)addNumber:(FractionNumber *)rval withSign:(int)sign;
- (void)addNumber:(FractionNumber *)rval;
- (void)subNumber:(FractionNumber *)rval;
- (void)mulNumber:(FractionNumber *)rval;
- (void)divNumber:(FractionNumber *)rval;

#pragma mark - comparator
- (BOOL)isEqual:(FractionNumber *)rval;

- (BOOL)simplifyNumerator:(uint32_t *)np denominator:(uint32_t *)qp;
- (BOOL)simplifyFraction;

- (void)castToFractionWithDenominator:(uint32_t)denominator;
- (void)castToReal;
@end
