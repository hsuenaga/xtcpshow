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

@interface GenericData ()
@property (nonatomic) NSUInteger objectID;
@property (nonatomic) NSUInteger numberOfSamples;
@end

@implementation GenericData {
    enum enum_data_mode mode;
    union union_numerators {
        int64_t integer;
        uint64_t uinteger;
        double real;
    } numerator;
    union union_denominator {
        uint64_t uinteger;
    } denominator;
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
    mode = mvalue;
    switch (mode) {
        case DATA_DOUBLE:
            numerator.real = nvalue ? [nvalue doubleValue] : 0.0;
            denominator.uinteger = 1;
            break;
        case DATA_INTEGER:
            numerator.integer = nvalue ? [nvalue integerValue] : 0;
            denominator.uinteger = 1;
            break;
        case DATA_UINTEGER:
            numerator.uinteger = nvalue ? [nvalue unsignedIntegerValue] : 0;
            denominator.uinteger = 1;
            break;
        case DATA_FRACTION:
            numerator.integer = nvalue ? [nvalue integerValue] : 0;
            denominator.uinteger = dvalue ? [dvalue unsignedIntegerValue] : 1;
            break;
        case DATA_NOVALUE:
        default:
            mode = DATA_NOVALUE;
            numerator.uinteger = 0;
            denominator.uinteger = 0;
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

- (double)doubleValue
{
    switch (mode) {
        case DATA_DOUBLE:
            return numerator.real;
        case DATA_INTEGER:
            return (double)numerator.integer;
        case DATA_UINTEGER:
            return (double)numerator.integer;
        case DATA_FRACTION:
            return (double)numerator.integer / (double)denominator.uinteger;
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
    numerator.real = doubleValue;
    denominator.uinteger = 1;
}

- (int64_t)int64Value
{
    switch (mode) {
        case DATA_DOUBLE:
            return (int64_t)round(numerator.real);
        case DATA_INTEGER:
            return numerator.integer;
        case DATA_UINTEGER:
            return (int64_t)numerator.uinteger;
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
    mode = DATA_INTEGER;
    numerator.integer = int64Value;
    denominator.uinteger = 1;
}

- (uint64_t)uint64Value
{
    switch (mode) {
        case DATA_DOUBLE:
            if (numerator.real < 0.0)
                return 0; // Saturation
            return (uint64_t)round(numerator.real);
        case DATA_INTEGER:
            if (numerator.integer < 0)
                return 0; // Saturation
            return (uint64_t)(numerator.integer);
        case DATA_UINTEGER:
            return numerator.uinteger;
        case DATA_FRACTION:
        {
            if (numerator.integer < 0)
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
    mode = DATA_UINTEGER;
    numerator.uinteger = uint64Value;
    denominator.uinteger = 1;
}

- (void)addInteger:(NSInteger)value
{
    switch (mode) {
        case DATA_DOUBLE:
        {
            numerator.real += (double)value;
            return;
        }
        case DATA_INTEGER:
        {
            numerator.integer += value;
            return;
        }
        case DATA_UINTEGER:
        {
            if (value < 0) {
                value = 0 - value;
                if (numerator.uinteger < value)
                    numerator.uinteger = 0; // saturation;
                else
                    numerator.uinteger -= value;
            }
            else {
                NSUInteger uvalue = numerator.uinteger + value;
                if (uvalue < numerator.uinteger) {
                    numerator.uinteger = NSUIntegerMax; // saturation;
                }
                else
                    numerator.uinteger = uvalue;
            }
            return;
        }
        case DATA_FRACTION:
        {
            value = value * denominator.uinteger;
            numerator.integer += value;
            return;
        }
        default:
            break;
    }
    NSException *ex = [NSException exceptionWithName:@"Invalid Value"
                                              reason:@"Unknown Data Type encoded"
                                            userInfo:nil];
    @throw ex;
}

- (void)addFracNumerator:(NSInteger)value
{
    switch (mode) {
        case DATA_INTEGER:
        case DATA_UINTEGER:
        case DATA_DOUBLE:
            return [self addInteger:value];
        case DATA_FRACTION:
            numerator.integer += value;
            return;
        default:
            break;
    }
    NSException *ex = [NSException exceptionWithName:@"Invalid Value"
                                              reason:@"Data is not a kind of fraction"
                                            userInfo:nil];
    @throw ex;
}

- (void)divInteger:(NSInteger)value
{
    switch (mode) {
        case DATA_DOUBLE:
            numerator.real /= (double)value;
            return;
        case DATA_INTEGER:
            if (numerator.integer % value == 0) {
                numerator.integer /= value;
                return;
            }
            /* fall through */
        case DATA_FRACTION:
            mode = DATA_FRACTION;
            if (value < 0) {
                value = 0 - value;
                numerator.integer = 0 - numerator.integer;
            }
            denominator.uinteger *= value;
            return;
        case DATA_UINTEGER:
            mode = DATA_FRACTION;
            if (value < 0) {
                NSException *ex = [NSException exceptionWithName:@"Invalid Sign"
                                                          reason:@"Devide by negative"
                                                        userInfo:nil];
                @throw ex;
            }
            denominator.uinteger *= value;
            return;
        default:
            break;
    }
}

- (void)mulInteger:(NSInteger)value
{
    switch (mode) {
        case DATA_DOUBLE:
            numerator.real *= (double)value;
            return;
        case DATA_INTEGER:
        case DATA_FRACTION:
            numerator.integer *= value;
            return;
        case DATA_UINTEGER:
            if (value < 0) {
                NSException *ex = [NSException exceptionWithName:@"Invalid Sign"
                                                          reason:@"Mutiply by negative"
                                                        userInfo:nil];
                @throw ex;
            }
            numerator.uinteger *= value;
            return;
        default:
            break;
    }
}

- (void)addData:(GenericData *)data
{
    switch (mode) {
        case DATA_DOUBLE:
            numerator.real += [data doubleValue];
            return;
        case DATA_INTEGER:
            if (data->mode == DATA_FRACTION) {
                mode = DATA_FRACTION;
                denominator.uinteger = data->denominator.uinteger;
                numerator.integer = numerator.integer * denominator.uinteger;
                numerator.integer += data->numerator.integer;
            }
            else {
                numerator.integer += [data int64Value];
            }
            return;
        case DATA_UINTEGER:
            if (data->mode == DATA_FRACTION) {
                mode = DATA_FRACTION;
                denominator.uinteger = data->denominator.uinteger;
                numerator.integer = (int64_t)(numerator.uinteger * denominator.uinteger);
                numerator.integer += data->numerator.integer;
            }
            else {
                NSUInteger uvalue = numerator.uinteger + [data uint64Value];
                if (uvalue < numerator.uinteger)
                    uvalue = NSUIntegerMax;
                numerator.uinteger = uvalue;
            }
            return;
        case DATA_FRACTION:
        {
            if (data->denominator.uinteger == denominator.uinteger) {
                numerator.integer += data->numerator.integer;
            }
            else if (denominator.uinteger % data->denominator.uinteger == 0) {
                NSUInteger q = denominator.uinteger / data->denominator.uinteger;
                
                numerator.integer += data->numerator.integer * q;
            }
            else if (data->denominator.uinteger % denominator.uinteger == 0) {
                NSUInteger q = data->denominator.uinteger / denominator.uinteger;

                denominator.uinteger *= q;
                numerator.integer *= q;
                numerator.integer += data->numerator.integer;
            }
            else {
                NSInteger value = data->numerator.integer * denominator.uinteger;
                
                denominator.uinteger *= data->denominator.uinteger;
                numerator.integer *= data->denominator.uinteger;
                numerator.integer += value;
                [self simplifyFraction];
            }
            return;
        }
        default:
            break;
    }
    NSException *ex = [NSException exceptionWithName:@"Invalid Value"
                                              reason:@"Data is not a kind of fraction"
                                            userInfo:nil];
    @throw ex;
}

- (void)simplifyFraction
{
    if (mode != DATA_FRACTION)
        return;
    
    int sign = 1;
    NSInteger n0 = numerator.integer;
    if (n0 < 0) {
        n0 = 0 - n0;
        sign = -1;
    }
    NSUInteger q0 = denominator.uinteger;

    NSUInteger n = n0;
    NSUInteger q = q0;

    while (TRUE) {
        NSUInteger r = n % q;
        if (r == 0) {
            n = n0 = n0 / q;
            q = q0 = q0 / q;
            continue;
        }
        else if (r == 1) {
            break;
        }
        n = q;
        q = r;
    }
    numerator.integer = n0 * sign;
    denominator.uinteger = q0;
}

//
// NSCopying protocol
//
- (id)copyWithZone:(NSZone *)zone
{
    GenericData *new = [[self.class allocWithZone:zone] init];
    
    new.dataFrom = self.dataFrom;
    new.dataTo = self.dataTo;
    
    new->mode = mode;
    new->numerator = numerator;
    new->denominator = denominator;

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
            return [NSString stringWithFormat:@"%f", numerator.real];
        case DATA_INTEGER:
            return [NSString stringWithFormat:@"%lld", numerator.integer];
        case DATA_UINTEGER:
            return [NSString stringWithFormat:@"%llu", numerator.uinteger];
        case DATA_FRACTION:
            return [NSString stringWithFormat:@"%lld/%llu",
                    numerator.integer, denominator.uinteger];
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
            return [NSString stringWithFormat:@"DOUBLE: numerator:%f, denominator:%llu, dataFrom:%@, dataTo:%@",
                    numerator.real, denominator.uinteger, self.dataFrom, self.dataTo];
        case DATA_INTEGER:
            return [NSString stringWithFormat:@"INTEGER: numerator:%lld, denominator:%llu, dataFrom:%@, dataTo:%@",
                    numerator.integer, denominator.uinteger, self.dataFrom, self.dataTo];
        case DATA_UINTEGER:
            return [NSString stringWithFormat:@"UINTEGER: numerator:%llu, denominator:%llu, dataFrom:%@, dataTo:%@",
                    numerator.uinteger, denominator.uinteger, self.dataFrom, self.dataTo];
        case DATA_FRACTION:
        {
            return [NSString stringWithFormat:@"FRACTION: numerator:%lld, denominator:%llu, dataFrom:%@, dataTo:%@",
                    numerator.integer, denominator.uinteger, self.dataFrom, self.dataTo];
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
