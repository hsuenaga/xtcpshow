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

#import "GenericData.h"

static NSUInteger newID = 0;
static NSFileHandle *debugHandle = nil;

#ifdef DEBUG
#define LOG_CONVERT_FRACTION(x) NSLog(@"Fraction is converted: %@", x)
#else
#define LOG_CONVERT_FRACTION(x) /* nothing */
#endif

#define DEBUG_EUCLID

@interface GenericData ()
@property (nonatomic) NSUInteger objectID;
@end

@implementation GenericData {
    enum enum_data_mode mode;
    union {
        struct {
            BOOL negative;
            uint64_t numerator;
            uint64_t denominator;
        } frac;
        double real;
    } value;
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

- (id)initWithMode:(enum enum_data_mode)mvalue numerator:(NSNumber *)nvalue denominator:(NSNumber *)dvalue dataFrom:(NSDate *)from dataTo:(NSDate *)to fromSamples:(NSUInteger)samples
{
    self = [super init];
    self.objectID = [self.class newID];
    switch (mvalue) {
        case DATA_DOUBLE:
            mode = DATA_DOUBLE;
            value.real = nvalue ? [nvalue doubleValue] : 0.0;
            break;
        case DATA_INTEGER:
        {
            mode = DATA_FRACTION;
            int64_t ivalue = nvalue ? [nvalue integerValue] : 0;
            if (ivalue < 0) {
                value.frac.negative = TRUE;
                value.frac.numerator = (uint64_t)(0 - ivalue);
            }
            else {
                value.frac.negative = FALSE;
                value.frac.numerator = (uint64_t)ivalue;
            }
            value.frac.denominator = 1;
            break;
        }
        case DATA_UINTEGER:
            mode = DATA_FRACTION;
            value.frac.negative = FALSE;
            value.frac.numerator = nvalue ? [nvalue unsignedIntegerValue] : 0;
            value.frac.denominator = 1;
            break;
        case DATA_FRACTION:
        {
            mode = DATA_FRACTION;
            int64_t ivalue = nvalue ? [nvalue integerValue] : 0;
            if (ivalue < 0) {
                value.frac.negative = TRUE;
                value.frac.numerator = (uint64_t)(0 - ivalue);
            }
            else {
                value.frac.negative = FALSE;
                value.frac.numerator = (uint64_t)ivalue;
            }
            
            ivalue = dvalue ? [dvalue integerValue] : 1;
            if (ivalue < 0) {
                value.frac.negative = !value.frac.negative;
                value.frac.denominator = (uint64_t)(0 - ivalue);
            }
            else {
                value.frac.denominator = (uint64_t)ivalue;
            }
            break;
        }
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
                  fromSamples:0];
}

+ (id)dataWithoutValue {
    GenericData *new = [self.class alloc];
    return [new initWithMode:DATA_NOVALUE
                   numerator:nil
                 denominator:nil
                    dataFrom:nil
                      dataTo:nil
                 fromSamples:0];
}

+ (id)dataWithDouble:(double)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples
{
    GenericData *new = [self.class alloc];
    return [new initWithMode:DATA_DOUBLE
                   numerator:[NSNumber numberWithDouble:data]
                 denominator:nil
                    dataFrom:date
                      dataTo:nil
                 fromSamples:samples];
    
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
                 fromSamples:samples];
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
                 fromSamples:samples];
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
        value.frac.numerator = (uint64_t)(0 - int64Value);
    }
    else {
        value.frac.negative = FALSE;
        value.frac.numerator = (uint64_t)int64Value;
    }
    value.frac.denominator = 1;
}

- (uint64_t)uint64Value
{
    switch (mode) {
        case DATA_DOUBLE:
            if (value.real < 0.0)
                return 0; // Saturation
            return (uint64_t)round(value.real);
        case DATA_FRACTION:
        {
            if (value.frac.negative)
                return 0; // Saturation
            return (uint64_t)round([self doubleValue]);
        }
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
    value.frac.numerator = uint64Value;
    value.frac.denominator = 1;
}

- (void)addInteger:(int64_t)iValue
{
    BOOL vNegative;
    uint64_t uValue;

    switch (mode) {
        case DATA_DOUBLE:
            value.real = value.real + (double)iValue;
            return;
        case DATA_FRACTION:
            if (iValue < 0) {
                vNegative = TRUE;
                uValue = (uint64_t)((0 - iValue) * value.frac.denominator);
            }
            else {
                vNegative = FALSE;
                uValue = (uint64_t)(iValue * value.frac.denominator);
            }
            if (vNegative == value.frac.negative) {
                value.frac.numerator = value.frac.numerator + uValue;
            }
            else if (value.frac.numerator >= uValue) {
                value.frac.numerator = value.frac.numerator - uValue;
            }
            else {
                value.frac.negative = !value.frac.negative;
                value.frac.numerator = uValue - value.frac.numerator;
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

- (void)subInteger:(int64_t)iValue
{
    return [self addInteger:(0 - iValue)];
}

- (void)divInteger:(int64_t)iValue
{
    uint64_t uValue;
    
    switch (mode) {
        case DATA_DOUBLE:
            value.real /= (double)iValue;
            return;
        case DATA_FRACTION:
            if (iValue < 0) {
                value.frac.negative = !value.frac.negative;
                uValue = (uint64_t)(0 - iValue);
            }
            else {
                uValue = (uint64_t)iValue;
            }
            value.frac.denominator *= uValue;
            [self simplifyFraction];
            return;
        default:
            break;
    }
}

- (void)mulInteger:(int64_t)iValue
{
    uint64_t uValue;
    
    switch (mode) {
        case DATA_DOUBLE:
            value.real *= (double)iValue;
            return;
        case DATA_FRACTION:
            if (iValue < 0) {
                value.frac.negative = !value.frac.negative;
                uValue = (uint64_t)(0 - iValue);
            }
            else {
                uValue = (uint64_t)iValue;
            }
            value.frac.numerator *= uValue;
            [self simplifyFraction];
            return;
        default:
            break;
    }
}

- (void)addData:(GenericData *)data withSign:(int)sign
{
    uint64_t uValue;
    BOOL vNegative;
    
    if (data->mode == DATA_NOVALUE)
        return;
    
    sign = sign < 0 ? -1 : 1;
    self.dataFrom = [self.dataFrom earlierDate:data.dataFrom];
    self.dataTo = [self.dataTo laterDate:data.dataTo];

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
                        value.frac.negative = !value.frac.negative;
                    return;
                default:
                    break;
            }
            break;
        case DATA_DOUBLE:
            value.real += ([data doubleValue] * (double)sign);
            return;
        case DATA_FRACTION:
            if (data->mode == DATA_DOUBLE) {
                LOG_CONVERT_FRACTION(self);
                mode = DATA_DOUBLE;
                value.real = [self doubleValue];
                return [self addData:data withSign:sign];
            }
            
            /* FRACTION against FRACTION */
            vNegative = data->value.frac.negative ? TRUE : FALSE;
            if (sign < 0)
                vNegative = !vNegative;
            uValue = data->value.frac.numerator * value.frac.denominator;
            value.frac.numerator *= data->value.frac.denominator;
            value.frac.denominator *= data->value.frac.denominator;
            if (!vNegative) {
                value.frac.numerator += uValue;
            }
            else if (value.frac.numerator >= uValue) {
                value.frac.numerator -= uValue;
            }
            else {
                value.frac.negative = !value.frac.negative;
                value.frac.numerator = uValue - value.frac.numerator;
            }
            [self simplifyFraction];
            return;
        default:
            break;
    }
    NSException *ex = [NSException exceptionWithName:@"Invalid Value"
                                              reason:@"Data is not a kind of fraction"
                                            userInfo:nil];
    @throw ex;
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
                LOG_CONVERT_FRACTION(self);
                mode = DATA_DOUBLE;
                value.real = [self doubleValue];
                return [self mulData:data];
            }
            
            // FRACTION against FRACTION
            if (data->value.frac.negative)
                value.frac.negative = !value.frac.negative;
            value.frac.numerator *= data->value.frac.numerator;
            value.frac.denominator *= data->value.frac.denominator;
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
                LOG_CONVERT_FRACTION(self);
                mode = DATA_DOUBLE;
                value.real = [self doubleValue];
                return [self divData:data];
            }
            
            // FRACTION against FRACTION
            if (data->value.frac.negative)
                value.frac.negative = !value.frac.negative;
            value.frac.numerator *= data->value.frac.denominator;
            value.frac.denominator *= data->value.frac.numerator;
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

- (BOOL)simplifyNumerator:(uint64_t *)np denominator:(uint64_t *)qp
{
    uint64_t n0 = *np;
    uint64_t q0 = *qp;
    uint64_t n = n0;
    uint64_t q = q0;
retry:
    while (q > 1) {
        uint64_t r = n % q;
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
                return [NSString stringWithFormat:@"%s%llu",
                        value.frac.negative ? "-" : "",
                        value.frac.numerator];
            }
            else {
                return [NSString stringWithFormat:@"%s%llu/%llu",
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
            return [NSString stringWithFormat:@"FRACTION: sign:%s, numerator:%llu, denominator:%llu, dataFrom:%@, dataTo:%@",
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
