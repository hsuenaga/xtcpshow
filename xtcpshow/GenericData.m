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
//  GenericData.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/30.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//
#import <stdint.h>
#import "GenericData.h"

static NSUInteger newID = 0;
static NSFileHandle *debugHandle = nil;
static NSException *overflowException = nil;
static NSException *invalidValueException = nil;
static BOOL defaultSaturation;

#undef DEBUG_EUCLID
#undef DEBUG_CAST
#define DEBUG_SAT

#if defined(DEBUG) && defined(DEBUG_CAST)
#define LOG_CAST_F2R(x) NSLog(@"Cast Fraction To Real: %@", x)
#else
#define LOG_CAST_F2R(x) /* nothing */
#endif

#if defined(DEBUG) && defined(DEBUG_SAT)
#define LOG_SAT(x) NSLog(@"Value is saturated: %@", x);
#else
#define LOG_SAT(x) /* nothing */
#endif

@interface GenericData ()
@property (nonatomic) NSUInteger objectID;

- (uint32_t)uint32add:(NSUInteger)n to:(NSUInteger)q;
- (uint32_t)uint32sub:(NSUInteger)n from:(NSUInteger)q;
- (uint32_t)uint32mul:(NSUInteger)n with:(NSUInteger)q;
- (uint32_t)uint32div:(NSUInteger)n by:(NSUInteger)q;
@end

@implementation GenericData {
    enum enum_data_mode mode;
    union {
        struct {
            BOOL negative;
            uint32_t numerator;
            uint32_t denominator;
        } frac;
        double real;
    } value;
}

+ (void)initialize
{
    newID = 0;
    debugHandle = nil;
    overflowException = [NSException exceptionWithName:@"overflow"
                                                reason:@"generic overflow"
                                              userInfo:nil];
    invalidValueException = [NSException exceptionWithName:@"invalidValue"
                                                    reason:@"cannot compute the value"
                                                  userInfo:nil];
    defaultSaturation = TRUE;
}

+ (BOOL)defaultSaturation
{
    return defaultSaturation;
}

+ (void)setDefaultSaturation:(BOOL)val
{
    defaultSaturation = val;
}

+ (NSUInteger)newID
{
    return newID++;
}

+ (NSFileHandle *)debugHandle
{
    return debugHandle;
}

+ (void)setDebugHandle:(NSFileHandle *)handle
{
    if (debugHandle) {
        [debugHandle synchronizeFile];
        [debugHandle closeFile];
        debugHandle = nil;
    }
    debugHandle = handle;
    [debugHandle truncateFileAtOffset:0];
}

+ (void)openDebugFile:(NSString *)fileName
{
    NSString *path = [NSString stringWithFormat:@"%@/%@", NSHomeDirectory(), fileName];
    
    NSFileManager *fmgr = [NSFileManager defaultManager];
    [fmgr createFileAtPath:path contents:nil attributes:nil];
    GenericData.debugHandle = [NSFileHandle fileHandleForWritingAtPath:path];
}

- (id)initWithMode:(enum enum_data_mode)mvalue numerator:(NSNumber *)nvalue denominator:(NSNumber *)dvalue dataFrom:(NSDate *)from dataTo:(NSDate *)to fromSamples:(NSUInteger)samples enableSaturation:(BOOL)saturation;
{
    int64_t iValue;
    uint64_t uValue;
    
    self = [super init];
    self.objectID = [self.class newID];
    self.saturateValue = saturation;
    switch (mvalue) {
        case DATA_DOUBLE:
            mode = DATA_DOUBLE;
            value.real = nvalue ? [nvalue doubleValue] : 0.0;
            break;
        case DATA_INTEGER:
            mode = DATA_FRACTION;
            iValue = nvalue ? [nvalue integerValue] : 0;
            if (iValue < 0) {
                value.frac.negative = TRUE;
                iValue = (-iValue);
            }
            else {
                value.frac.negative = FALSE;
            }
            if (iValue > UINT32_MAX) {
                if (self.saturateValue) {
                    LOG_SAT(self);
                    iValue = UINT32_MAX;
                }
                else
                    @throw overflowException;
            }
            value.frac.numerator = (uint32_t)iValue;
            value.frac.denominator = 1;
            break;
        case DATA_UINTEGER:
            mode = DATA_FRACTION;
            value.frac.negative = FALSE;
            uValue = nvalue ? [nvalue unsignedIntegerValue] : 0;
            if (uValue > UINT32_MAX) {
                if (self.saturateValue) {
                    LOG_SAT(self);
                    uValue = UINT32_MAX;
                }
                else
                    @throw overflowException;
            }
            value.frac.numerator = (uint32_t)uValue;
            value.frac.denominator = 1;
            break;
        case DATA_FRACTION:
            mode = DATA_FRACTION;
            iValue = nvalue ? [nvalue integerValue] : 0;
            if (iValue < 0) {
                value.frac.negative = TRUE;
                iValue = -iValue;
            }
            else {
                value.frac.negative = FALSE;
            }
            if (iValue > UINT32_MAX) {
                if (self.saturateValue) {
                    LOG_SAT(self);
                    iValue = UINT32_MAX;
                }
                else
                    @throw overflowException;
            }
            value.frac.numerator = (uint32_t)iValue;
            
            iValue = dvalue ? [dvalue integerValue] : 1;
            if (iValue < 0) {
                value.frac.negative = !value.frac.negative;
                iValue = -iValue;
            }
            if (iValue > UINT32_MAX) {
                if (self.saturateValue) {
                    LOG_SAT(self);
                    iValue = UINT32_MAX;
                }
                else
                    @throw overflowException;
            }
            value.frac.denominator = (uint32_t)iValue;
            break;
        case DATA_NOVALUE:
        default:
            mode = DATA_NOVALUE;
            memset(&value, 0, sizeof(value));
            break;
    }
    self.dataFrom = from ? from : [NSDate date];
    self.dataTo = to ? to : self.dataFrom;
    self.numberOfSamples = samples;
    return self;
}

- (id)init
{
    return [self initWithMode:DATA_NOVALUE
                    numerator:nil
                  denominator:nil
                     dataFrom:nil
                       dataTo:nil
                  fromSamples:0
             enableSaturation:defaultSaturation];
}

+ (id)dataWithoutValue {
    GenericData *new = [self.class alloc];
    return [new initWithMode:DATA_NOVALUE
                   numerator:nil
                 denominator:nil
                    dataFrom:nil
                      dataTo:nil
                 fromSamples:0
            enableSaturation:defaultSaturation];
}

+ (id)dataWithDouble:(double)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples
{
    GenericData *new = [self.class alloc];
    return [new initWithMode:DATA_DOUBLE
                   numerator:[NSNumber numberWithDouble:data]
                 denominator:nil
                    dataFrom:date
                      dataTo:nil
                 fromSamples:samples
            enableSaturation:defaultSaturation];
}

+ (id)dataWithDouble:(double)data
{
    return [self.class dataWithDouble:data atDate:nil fromSamples:1];
}

+ (id)dataWithInteger:(NSInteger)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples
{
    GenericData *new = [self.class alloc];
    return [new initWithMode:DATA_INTEGER
                   numerator:[NSNumber numberWithInteger:data]
                 denominator:nil
                    dataFrom:date
                      dataTo:nil
                 fromSamples:samples
            enableSaturation:defaultSaturation];
}

+ (id)dataWithInteger:(NSInteger)data
{
    return [self.class dataWithInteger:data atDate:nil fromSamples:1];
}

+ (id)dataWithUInteger:(NSUInteger)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples
{
    GenericData *new = [self.class alloc];
    return [new initWithMode:DATA_UINTEGER
                   numerator:[NSNumber numberWithInteger:data]
                 denominator:nil
                    dataFrom:date
                      dataTo:nil
                 fromSamples:samples
            enableSaturation:defaultSaturation];
}

+ (id)dataWithUInteger:(NSUInteger)data
{
    return [self.class dataWithUInteger:data atDate:nil fromSamples:1];
}

- (NSDate *)timestamp
{
    return self.dataFrom;
}

- (void)setTimestamp:(NSDate *)timestamp
{
    self.dataFrom = timestamp;
    self.dataTo = self.dataFrom;
    return;
}

- (double)doubleValue
{
    switch (mode) {
        case DATA_DOUBLE:
            return value.real;
        case DATA_FRACTION:
            return (double)value.frac.numerator / (double)value.frac.denominator * (value.frac.negative ? -1.0 : 1.0);
        default:
            break;
    }
    NSException *ex = [NSException exceptionWithName:@"Invalid Value"
                                              reason:@"Unknown Data Type encoded"
                                            userInfo:nil];
    @throw ex;
}

- (void)setDoubleValue:(double)doubleValue
{
    mode = DATA_DOUBLE;
    value.real = doubleValue;
}

- (int64_t)int64Value
{
    switch (mode) {
        case DATA_DOUBLE:
            return (int64_t)round(value.real);
        case DATA_FRACTION:
            return (int64_t)round([self doubleValue]);
        default:
            break;
    }
    NSException *ex = [NSException exceptionWithName:@"Invalid Value"
                                              reason:@"Unknown Data Type encoded"
                                            userInfo:nil];
    @throw ex;
}

- (void)setInt64Value:(int64_t)int64Value
{
    mode = DATA_FRACTION;
    if (int64Value < 0) {
        value.frac.negative = TRUE;
        int64Value = (-int64Value);
    }
    else {
        value.frac.negative = FALSE;
    }
    if (int64Value > UINT32_MAX) {
        if (self.saturateValue == TRUE) {
            LOG_SAT(self);
            int64Value = UINT32_MAX;
        }
        else
            @throw overflowException;
    }
    value.frac.numerator = (uint32_t)int64Value;
    value.frac.denominator = 1;
}

- (uint64_t)uint64Value
{
    switch (mode) {
        case DATA_DOUBLE:
            if (value.real < 0.0) {
                if (self.saturateValue) {
                    LOG_SAT(self);
                    return 0;
                }
                else
                    @throw overflowException;
            }
            return (uint64_t)round(value.real);
        case DATA_FRACTION:
            if (value.frac.negative) {
                if (self.saturateValue) {
                    LOG_SAT(self);
                    return 0;
                }
                else
                    @throw overflowException;
            }
            return (uint64_t)round([self doubleValue]);
        default:
            break;
    }
    NSLog(@"Unknwon mode: %d", mode);
    NSException *ex = [NSException exceptionWithName:@"Invalid Value"
                                              reason:@"Unknown Data Type encoded"
                                            userInfo:nil];
    @throw ex;
}

- (void)setUint64Value:(uint64_t)uint64Value
{
    mode = DATA_FRACTION;
    value.frac.negative = FALSE;
    if (uint64Value > UINT32_MAX) {
        if (self.saturateValue) {
            LOG_SAT(self);
            uint64Value = UINT32_MAX;
        }
        else
            @throw overflowException;
    }
    value.frac.numerator = (uint32_t)uint64Value;
    value.frac.denominator = 1;
}

- (void)addInteger:(NSInteger)iValue
{
    BOOL vNegative;
    uint32_t uValue;

    switch (mode) {
        case DATA_DOUBLE:
            value.real = value.real + (double)iValue;
            return;
        case DATA_FRACTION:
            if (iValue < 0) {
                vNegative = TRUE;
                iValue = (-iValue);
            }
            else {
                vNegative = FALSE;
            }
            uValue = [self uint32mul:iValue with:value.frac.denominator];

            if (vNegative == value.frac.negative) {
                value.frac.numerator = [self uint32add:uValue to:value.frac.numerator];
            }
            else if (value.frac.numerator >= uValue) {
                value.frac.numerator = [self uint32sub:uValue from:value.frac.numerator];
            }
            else {
                value.frac.negative = (!value.frac.negative);
                value.frac.numerator = [self uint32sub:value.frac.numerator from:uValue];
            }
            [self simplifyFraction];
            return;
        default:
            break;
    }
    NSException *ex = [NSException exceptionWithName:@"Invalid Value"
                                              reason:@"Unknown Data Type encoded"
                                            userInfo:nil];
    @throw ex;
}

- (void)subInteger:(NSInteger)iValue
{
    return [self addInteger:(-iValue)];
}

- (void)mulInteger:(NSInteger)iValue
{
    switch (mode) {
        case DATA_DOUBLE:
            value.real *= (double)iValue;
            return;
        case DATA_FRACTION:
            if (iValue < 0) {
                value.frac.negative = (!value.frac.negative);
                iValue = (-iValue);
            }
            value.frac.numerator = [self uint32mul:iValue with:value.frac.numerator];
            [self simplifyFraction];
            return;
        default:
            break;
    }
}


- (void)divInteger:(NSInteger)iValue
{
    switch (mode) {
        case DATA_DOUBLE:
            value.real /= (double)iValue;
            return;
        case DATA_FRACTION:
            if (iValue < 0) {
                value.frac.negative = (!value.frac.negative);
                iValue = (-iValue);
            }
            value.frac.denominator = [self uint32mul:iValue with:value.frac.denominator];
            [self simplifyFraction];
            return;
        default:
            break;
    }
}

- (void)addData:(GenericData *)data withSign:(int)sign
{
    uint32_t uValue;
    BOOL vNegative;
    BOOL simplify = FALSE;
    
    if (data->mode == DATA_NOVALUE)
        return;
    
    sign = sign < 0 ? -1 : 1;
    switch (mode) {
        case DATA_NOVALUE:
            mode = data->mode;
            value = data->value;
            switch (data->mode) {
                case DATA_DOUBLE:
                    value.real *= (double)sign;
                    return;
                case DATA_FRACTION:
                    if (sign < 0)
                        value.frac.negative = (!value.frac.negative);
                    break;
                default:
                    break;
            }
            break;
        case DATA_DOUBLE:
            value.real += ([data doubleValue] * (double)sign);
            break;
        case DATA_FRACTION:
            if (data->mode == DATA_DOUBLE) {
                [self castToReal];
                return [self addData:data withSign:sign];
            }
            
            // check signness
            vNegative = data->value.frac.negative ? TRUE : FALSE;
            if (sign < 0)
                vNegative = (!vNegative);

            // align denominator
            if (value.frac.denominator != data->value.frac.denominator) {
                uValue = [self uint32mul:data->value.frac.numerator
                                    with:value.frac.denominator];
                value.frac.numerator = [self uint32mul:value.frac.numerator
                                                  with:data->value.frac.denominator];
                value.frac.denominator = [self uint32mul:value.frac.denominator
                                                    with:data->value.frac.denominator];
                simplify = TRUE;
            }
            else {
                uValue = data->value.frac.numerator;
            }
            
            // add numerator
            if (value.frac.negative == vNegative) {
                value.frac.numerator = [self uint32add:uValue to:value.frac.numerator];
            }
            else if (value.frac.numerator >= uValue) {
                value.frac.numerator = [self uint32sub:uValue from:value.frac.numerator];
            }
            else {
                value.frac.numerator = [self uint32sub:value.frac.numerator from:uValue];
            }
            
            if (simplify)
                [self simplifyFraction];
            break;
        default:
        {
            NSException *ex = [NSException exceptionWithName:@"Invalid Value"
                                                      reason:@"Data is not a kind of fraction"
                                                    userInfo:nil];
            @throw ex;
            break;
        }
    }
    
    self.dataFrom = [self.dataFrom earlierDate:data.dataFrom];
    self.dataTo = [self.dataTo laterDate:data.dataTo];
    if (sign > 0) {
        self.numberOfSamples += data.numberOfSamples;
    }
    else if (self.numberOfSamples >= data.numberOfSamples) {
        self.numberOfSamples -= data.numberOfSamples;
    }
    else {
        self.numberOfSamples = 0;
    }
}

- (void)addData:(GenericData *)data
{
    return [self addData:data withSign:1];
}

- (void)subData:(GenericData *)data
{
    return [self addData:data withSign:-1];
}

- (void)mulData:(GenericData *)data
{
    switch (mode) {
        case DATA_DOUBLE:
            value.real *= [data doubleValue];
            return;
        case DATA_FRACTION:
            if (data->mode == DATA_DOUBLE) {
                [self castToReal];
                return [self mulData:data];
            }
            
            // FRACTION against FRACTION
            if (data->value.frac.negative)
                value.frac.negative = !value.frac.negative;
            value.frac.numerator = [self uint32mul:value.frac.numerator
                                              with:data->value.frac.numerator];
            value.frac.denominator = [self uint32mul:value.frac.denominator
                                                with:data->value.frac.denominator];
            [self simplifyFraction];
            return;
        default:
            break;
    }
    NSException *ex = [NSException exceptionWithName:@"Invalid Multiply"
                                              reason:@"Invalid Data type"
                                            userInfo:nil];
    @throw ex;
}

- (void)divData:(GenericData *)data
{
    switch (mode) {
        case DATA_DOUBLE:
            value.real /= [data doubleValue];
            return;
        case DATA_FRACTION:
            if (data->mode == DATA_DOUBLE) {
                [self castToReal];
                return [self divData:data];
            }
            
            // FRACTION against FRACTION
            if (data->value.frac.negative)
                value.frac.negative = !value.frac.negative;
            value.frac.numerator = [self uint32mul:value.frac.numerator
                                              with:data->value.frac.denominator];
            value.frac.denominator = [self uint32mul:value.frac.denominator
                                                with:data->value.frac.numerator];
            [self simplifyFraction];
            return;
        default:
            break;
    }
    NSException *ex = [NSException exceptionWithName:@"Invalid Devide"
                                              reason:@"Invalid Data type"
                                            userInfo:nil];
    @throw ex;
}

- (BOOL)simplifyNumerator:(uint32_t *)np denominator:(uint32_t *)qp
{
    uint32_t n0 = *np;
    uint32_t q0 = *qp;
    uint32_t n = n0;
    uint32_t q = q0;
retry:
    while (q > 1) {
        uint32_t r = n % q;
        if (r == 0) {
            n = n0 = (n0 / q);
            q = q0 = (q0 / q);
            continue;
        }
        n = q;
        q = r;
    }
    
    if (n0 != *np || q0 != *qp) {
        *np = n0;
        *qp = q0;
        return TRUE;
    }
#ifdef DEBUG_EUCLID
    NSLog(@"Simplify: %llu/%llu -> Failed: n = %llu", *np, *qp, n);
#endif
    return FALSE;
}

- (BOOL)simplifyFraction
{
    if (mode != DATA_FRACTION)
        return FALSE;
    if (value.frac.denominator == 1)
        return TRUE;
    if (value.frac.numerator == 0) {
        value.frac.denominator = 1;
        return TRUE;
    }
    
    return [self simplifyNumerator:&value.frac.numerator denominator:&value.frac.denominator];
}

- (void)castToFractionWithDenominator:(uint32_t)denominator;
{
    double dValue;
    
    switch (mode) {
        case DATA_DOUBLE:
            dValue = value.real * (double)denominator;
            break;
        case DATA_FRACTION:
            if (value.frac.numerator == 0) {
                value.frac.denominator = denominator;
                return;
            }
            dValue = [self doubleValue] * (double)denominator;
            break;
        default:
            return;
    }
    
    BOOL negative;
    if (dValue < 0.0) {
        negative = TRUE;
        dValue = (-dValue);
    }
    else {
        negative = FALSE;
    }
    if (dValue > (double)UINT32_MAX) {
        if (self.saturateValue) {
            mode = DATA_FRACTION;
            value.frac.negative = negative;
            value.frac.numerator = UINT32_MAX;
            value.frac.denominator = denominator;
            LOG_SAT(self);
            return;
        }
        @throw overflowException;
    }
    
    uint32_t numerator = (uint32_t)round(dValue);
#ifdef DEBUG_CAST
    NSLog(@"round fraction: %s%llu/%llu -> %s%llu/%llu",
          value.frac.negative ? "-" : "", value.frac.numerator, value.frac.denominator,
          negative ? "-" : "", numerator, denominator);
#endif
    mode = DATA_FRACTION;
    value.frac.negative = negative;
    value.frac.numerator = numerator;
    value.frac.denominator = denominator;
}

- (void)castToReal
{
    if (mode == DATA_DOUBLE)
        return;

    LOG_CAST_F2R(self);
    double dValue = [self doubleValue];
    mode = DATA_DOUBLE;
    value.real = dValue;
}

//
// NSCopying protocol
//
- (id)copyWithZone:(NSZone *)zone
{
    GenericData *new = [[self.class allocWithZone:zone] init];
    
    new.dataFrom = self.dataFrom;
    new.dataTo = self.dataTo;
    new.numberOfSamples = self.numberOfSamples;
    new->mode = mode;
    new->value = value;

    return new;
}

//
// runtime support
//
- (NSString *)description
{
    switch (mode) {
        case DATA_NOVALUE:
            return @"(No Value)";
        case DATA_DOUBLE:
            return [NSString stringWithFormat:@"%f", value.real];
        case DATA_FRACTION:
            if (value.frac.denominator == 1) {
                return [NSString stringWithFormat:@"%s%u",
                        value.frac.negative ? "-" : "",
                        value.frac.numerator];
            }
            else {
                return [NSString stringWithFormat:@"%s%u/%u",
                        value.frac.negative ? "-" : "",
                        value.frac.numerator, value.frac.denominator];
            }
            break;
        default:
            break;
    }
    return @"(Unkown)";
}

- (NSString *)debugDescription
{
    switch (mode) {
        case DATA_NOVALUE:
            return [NSString stringWithFormat:@"NOVALUE: dataFrom:%@, dataTo:%@",
                    self.dataFrom, self.dataTo];
        case DATA_DOUBLE:
            return [NSString stringWithFormat:@"DOUBLE: value:%f, dataFrom:%@, dataTo:%@",
                    value.real, self.dataFrom, self.dataTo];
        case DATA_FRACTION:
        {
            return [NSString stringWithFormat:@"FRACTION: sign:%s, numerator:%u, denominator:%u, dataFrom:%@, dataTo:%@",
                    value.frac.negative ? "-" : "+",
                    value.frac.numerator, value.frac.denominator,
                    self.dataFrom, self.dataTo];
        }
        default:
            break;
    }
    return [NSString stringWithFormat:@"Unknown: mode %d, dataFrom:%@, dataTo:%@",
            mode, self.dataFrom, self.dataTo];
}

//
// utilities
//
- (uint32_t)uint32add:(NSUInteger)n to:(NSUInteger)q
{
    if (n > (UINT32_MAX - q)) {
        if (self.saturateValue) {
            LOG_SAT(self);
            return UINT32_MAX;
        }
        else
            @throw overflowException;
    }
    return (uint32_t)(q + n);
}

- (uint32_t)uint32sub:(NSUInteger)n from:(NSUInteger)q
{
    if (q < n) {
        if (self.saturateValue) {
            LOG_SAT(self);
            return 0;
        }
        else
            @throw overflowException;
    }
    
    return (uint32_t)(q - n);
}

- (uint32_t)uint32mul:(NSUInteger)n with:(NSUInteger)q
{
    uint64_t v = (uint64_t)n * (uint64_t)q;
    
    if (v > UINT32_MAX) {
        if (self.saturateValue) {
            LOG_SAT(self);
            return UINT32_MAX;
        }
        else
            @throw overflowException;
    }
    return (uint32_t)(v & 0xffffffff);
}

- (uint32_t)uint32div:(NSUInteger)n by:(NSUInteger)q
{
    if (n == 0) {
        @throw invalidValueException;
    }
    uint64_t v = (uint64_t)q / (uint64_t)n;
    if (v > UINT32_MAX) {
        if (self.saturateValue) {
            LOG_SAT(self);
            return UINT32_MAX;
        }
        else
            @throw overflowException;
    }
    return (uint32_t)(v & 0xffffffff);
}

//
// debug
//
- (void)dumpTree:(BOOL)root
{
    [self writeDebug:@"obj%lu [shape=point];\n", self.objectID];
}

- (void)writeDebug:(NSString *)format, ...
{
    if (!debugHandle) {
        NSLog(@"%@ [obj%lu] No debug handle.", self.class, self.objectID);
        return;
    }

    NSString *contents;
    va_list args;
    va_start(args, format);
    contents = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [debugHandle writeData:[contents dataUsingEncoding:NSUTF8StringEncoding]];
}
@end
