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
//  FractionNumber.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/05/24.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//
#import <stdint.h>
#import "FractionNumber.h"

static NSException *overflowException = nil;
static NSException *invalidValueException = nil;
static BOOL defaultSaturation;
static BOOL preferReal;

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

@interface FractionNumber ()
@property (nonatomic) NSUInteger objectID;

- (uint32_t)uint32add:(NSUInteger)n to:(NSUInteger)q;
- (uint32_t)uint32sub:(NSUInteger)n from:(NSUInteger)q;
- (uint32_t)uint32mul:(NSUInteger)n with:(NSUInteger)q;
- (uint32_t)uint32div:(NSUInteger)n by:(NSUInteger)q;
@end


@implementation FractionNumber {
    enum enum_data_mode mode;
    union {
        struct {
            BOOL negative;
            uint32_t numerator;
            uint32_t denominator;
        } frac;
        double real;
    } lval;
}

+ (void)initialize
{
    overflowException = [NSException exceptionWithName:@"overflow"
                                                reason:@"generic overflow"
                                              userInfo:nil];
    invalidValueException = [NSException exceptionWithName:@"invalidValue"
                                                    reason:@"cannot compute the value"
                                                  userInfo:nil];
    defaultSaturation = TRUE;
    preferReal = FALSE;
}

+ (BOOL)defaultSaturation
{
    return defaultSaturation;
}

+ (void)setDefaultSaturation:(BOOL)val
{
    defaultSaturation = val;
}

+ (BOOL)preferReal
{
    return preferReal;
}

+ (void)setPreferReal:(BOOL)val
{
    preferReal = val;
}

- (id)initWithMode:(enum enum_data_mode)mvalue numerator:(NSNumber *)nvalue denominator:(NSNumber *)dvalue enableSaturation:(BOOL)saturation;
{
    int64_t iValue;
    uint64_t uValue;

    self = [super init];
    self.saturateValue = saturation;
    switch (mvalue) {
        case DATA_DOUBLE:
            mode = DATA_DOUBLE;
            lval.real = nvalue ? [nvalue doubleValue] : 0.0;
            break;
        case DATA_INTEGER:
            mode = DATA_FRACTION;
            iValue = nvalue ? [nvalue integerValue] : 0;
            if (iValue < 0) {
                lval.frac.negative = TRUE;
                iValue = (-iValue);
            }
            else {
                lval.frac.negative = FALSE;
            }
            if (iValue > UINT32_MAX) {
                if (self.saturateValue) {
                    LOG_SAT(self);
                    iValue = UINT32_MAX;
                }
                else
                    @throw overflowException;
            }
            lval.frac.numerator = (uint32_t)iValue;
            lval.frac.denominator = 1;
            break;
        case DATA_UINTEGER:
            mode = DATA_FRACTION;
            lval.frac.negative = FALSE;
            uValue = nvalue ? [nvalue unsignedIntegerValue] : 0;
            if (uValue > UINT32_MAX) {
                if (self.saturateValue) {
                    LOG_SAT(self);
                    uValue = UINT32_MAX;
                }
                else
                    @throw overflowException;
            }
            lval.frac.numerator = (uint32_t)uValue;
            lval.frac.denominator = 1;
            break;
        case DATA_FRACTION:
            mode = DATA_FRACTION;
            iValue = nvalue ? [nvalue integerValue] : 0;
            if (iValue < 0) {
                lval.frac.negative = TRUE;
                iValue = -iValue;
            }
            else {
                lval.frac.negative = FALSE;
            }
            if (iValue > UINT32_MAX) {
                if (self.saturateValue) {
                    LOG_SAT(self);
                    iValue = UINT32_MAX;
                }
                else
                    @throw overflowException;
            }
            lval.frac.numerator = (uint32_t)iValue;

            iValue = dvalue ? [dvalue integerValue] : 1;
            if (iValue < 0) {
                lval.frac.negative = !lval.frac.negative;
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
            lval.frac.denominator = (uint32_t)iValue;
            break;
        case DATA_NOVALUE:
        default:
            mode = DATA_NOVALUE;
            memset(&lval, 0, sizeof(lval));
            break;
    }
    if (preferReal && mode != DATA_NOVALUE)
        [self castToReal];
    return self;
}

- (id)init
{
    return [self initWithMode:DATA_NOVALUE
                    numerator:nil
                  denominator:nil
             enableSaturation:defaultSaturation];
}

+ (id)numberWithoutValue {
    FractionNumber *new = [self.class alloc];
    return [new initWithMode:DATA_NOVALUE
                   numerator:nil
                 denominator:nil
            enableSaturation:defaultSaturation];
}

+ (id)numberWithDouble:(double)data
{
    FractionNumber *new = [self.class alloc];
    return [new initWithMode:DATA_DOUBLE
                   numerator:[NSNumber numberWithDouble:data]
                 denominator:nil
            enableSaturation:defaultSaturation];
}

+ (id)numberWithInteger:(NSInteger)data
{
    FractionNumber *new = [self.class alloc];
    return [new initWithMode:DATA_INTEGER
                   numerator:[NSNumber numberWithInteger:data]
                 denominator:nil
            enableSaturation:defaultSaturation];
}

+ (id)numberWithUInteger:(NSUInteger)data
{
    FractionNumber *new = [self.class alloc];
    return [new initWithMode:DATA_UINTEGER
                   numerator:[NSNumber numberWithInteger:data]
                 denominator:nil
            enableSaturation:defaultSaturation];
}

- (double)doubleValue
{
    switch (mode) {
        case DATA_DOUBLE:
            return lval.real;
        case DATA_FRACTION:
            return (double)lval.frac.numerator / (double)lval.frac.denominator * (lval.frac.negative ? -1.0 : 1.0);
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
    lval.real = doubleValue;
}

- (int64_t)int64Value
{
    switch (mode) {
        case DATA_DOUBLE:
            return (int64_t)round(lval.real);
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
        lval.frac.negative = TRUE;
        int64Value = (-int64Value);
    }
    else {
        lval.frac.negative = FALSE;
    }
    if (int64Value > UINT32_MAX) {
        if (self.saturateValue == TRUE) {
            LOG_SAT(self);
            int64Value = UINT32_MAX;
        }
        else
            @throw overflowException;
    }
    lval.frac.numerator = (uint32_t)int64Value;
    lval.frac.denominator = 1;
}

- (uint64_t)uint64Value
{
    switch (mode) {
        case DATA_DOUBLE:
            if (lval.real < 0.0) {
                if (self.saturateValue) {
                    LOG_SAT(self);
                    return 0;
                }
                else
                    @throw overflowException;
            }
            return (uint64_t)round(lval.real);
        case DATA_FRACTION:
            if (lval.frac.negative) {
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
    lval.frac.negative = FALSE;
    if (uint64Value > UINT32_MAX) {
        if (self.saturateValue) {
            LOG_SAT(self);
            uint64Value = UINT32_MAX;
        }
        else
            @throw overflowException;
    }
    lval.frac.numerator = (uint32_t)uint64Value;
    lval.frac.denominator = 1;
}

- (void)addInteger:(NSInteger)iValue
{
    BOOL vNegative;
    uint32_t uValue;

    switch (mode) {
        case DATA_DOUBLE:
            lval.real = lval.real + (double)iValue;
            return;
        case DATA_FRACTION:
            if (iValue < 0) {
                vNegative = TRUE;
                iValue = (-iValue);
            }
            else {
                vNegative = FALSE;
            }
            uValue = [self uint32mul:iValue with:lval.frac.denominator];

            if (vNegative == lval.frac.negative) {
                lval.frac.numerator = [self uint32add:uValue to:lval.frac.numerator];
            }
            else if (lval.frac.numerator >= uValue) {
                lval.frac.numerator = [self uint32sub:uValue from:lval.frac.numerator];
            }
            else {
                lval.frac.negative = (!lval.frac.negative);
                lval.frac.numerator = [self uint32sub:lval.frac.numerator from:uValue];
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
            lval.real *= (double)iValue;
            return;
        case DATA_FRACTION:
            if (iValue < 0) {
                lval.frac.negative = (!lval.frac.negative);
                iValue = (-iValue);
            }
            lval.frac.numerator = [self uint32mul:iValue with:lval.frac.numerator];
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
            lval.real /= (double)iValue;
            return;
        case DATA_FRACTION:
            if (iValue < 0) {
                lval.frac.negative = (!lval.frac.negative);
                iValue = (-iValue);
            }
            lval.frac.denominator = [self uint32mul:iValue with:lval.frac.denominator];
            [self simplifyFraction];
            return;
        default:
            break;
    }
}

- (void)addNumber:(FractionNumber *)rval withSign:(int)sign
{
    uint32_t uValue;
    BOOL vNegative;
    BOOL simplify = FALSE;

    if (rval->mode == DATA_NOVALUE)
        return;

    sign = sign < 0 ? -1 : 1;
    switch (mode) {
        case DATA_NOVALUE:
            mode = rval->mode;
            lval = rval->lval;
            switch (rval->mode) {
                case DATA_DOUBLE:
                    lval.real *= (double)sign;
                    return;
                case DATA_FRACTION:
                    if (sign < 0)
                        lval.frac.negative =
                        !lval.frac.negative;
                    break;
                default:
                    break;
            }
            if (preferReal)
                [self castToReal];
            break;
        case DATA_DOUBLE:
            lval.real += ([rval doubleValue] * (double)sign);
            break;
        case DATA_FRACTION:
            if (rval->mode == DATA_DOUBLE) {
                [self castToReal];
                return [self addNumber:rval withSign:sign];
            }

            // check signness
            vNegative = rval->lval.frac.negative ? TRUE : FALSE;
            if (sign < 0)
                vNegative = !vNegative;

            // align denominator
            if (lval.frac.denominator != rval->lval.frac.denominator) {
                uValue = [self uint32mul:rval->lval.frac.numerator
                                    with:lval.frac.denominator];
                lval.frac.numerator = [self uint32mul:lval.frac.numerator
                                                  with:rval->lval.frac.denominator];
                lval.frac.denominator = [self uint32mul:lval.frac.denominator
                                                    with:rval->lval.frac.denominator];
                simplify = TRUE;
            }
            else {
                uValue = rval->lval.frac.numerator;
            }

            // add numerator
            if (lval.frac.negative == vNegative) {
                lval.frac.numerator = [self uint32add:uValue to:lval.frac.numerator];
            }
            else if (lval.frac.numerator >= uValue) {
                lval.frac.numerator = [self uint32sub:uValue from:lval.frac.numerator];
            }
            else {
                lval.frac.numerator = [self uint32sub:lval.frac.numerator from:uValue];
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
}

- (void)addNumber:(FractionNumber *)rval
{
    return [self addNumber:rval withSign:1];
}

- (void)subNumber:(FractionNumber *)rval
{
    return [self addNumber:rval withSign:-1];
}

- (void)mulNumber:(FractionNumber *)rval
{
    switch (mode) {
        case DATA_DOUBLE:
            lval.real *= [rval doubleValue];
            return;
        case DATA_FRACTION:
            if (rval->mode == DATA_DOUBLE) {
                [self castToReal];
                return [self mulNumber:rval];
            }

            // FRACTION against FRACTION
            if (rval->lval.frac.negative)
                lval.frac.negative = !lval.frac.negative;
            lval.frac.numerator = [self uint32mul:lval.frac.numerator
                                              with:rval->lval.frac.numerator];
            lval.frac.denominator = [self uint32mul:lval.frac.denominator
                                                with:rval->lval.frac.denominator];
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

- (void)divNumber:(FractionNumber *)rval
{
    switch (mode) {
        case DATA_DOUBLE:
            lval.real /= [rval doubleValue];
            return;
        case DATA_FRACTION:
            if (rval->mode == DATA_DOUBLE) {
                [self castToReal];
                return [self divNumber:rval];
            }

            // FRACTION against FRACTION
            if (rval->lval.frac.negative)
                lval.frac.negative = !lval.frac.negative;
            lval.frac.numerator = [self uint32mul:lval.frac.numerator
                                              with:rval->lval.frac.denominator];
            lval.frac.denominator = [self uint32mul:lval.frac.denominator
                                                with:rval->lval.frac.numerator];
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

- (BOOL)isEqual:(FractionNumber *)rval
{
    if (!rval)
        return FALSE;
    if (self == rval)
        return TRUE;

    if (self->mode != DATA_FRACTION ||
        rval->mode != DATA_FRACTION) {
        /* isEqual() of double is not supported */
        return FALSE;
    }

    FractionNumber *comp = [self copy];
    [comp subNumber:rval];
    if (comp->mode != DATA_FRACTION)
        return FALSE;
    if (comp->lval.frac.numerator == 0)
        return TRUE;
    return FALSE;
}

- (BOOL)simplifyFraction
{
    if (mode != DATA_FRACTION)
        return FALSE;
    if (lval.frac.denominator == 1)
        return TRUE;
    if (lval.frac.numerator == 0) {
        lval.frac.denominator = 1;
        return TRUE;
    }

    return [self simplifyNumerator:&lval.frac.numerator denominator:&lval.frac.denominator];
}

- (void)castToFractionWithDenominator:(uint32_t)denominator;
{
    double dValue;

    switch (mode) {
        case DATA_DOUBLE:
            if (preferReal)
                return;
            dValue = lval.real * (double)denominator;
            break;
        case DATA_FRACTION:
            if (preferReal) {
                [self castToReal];
                return;
            }
            if (lval.frac.numerator == 0) {
                lval.frac.denominator = denominator;
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
            lval.frac.negative = negative;
            lval.frac.numerator = UINT32_MAX;
            lval.frac.denominator = denominator;
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
    lval.frac.negative = negative;
    lval.frac.numerator = numerator;
    lval.frac.denominator = denominator;
}

- (void)castToReal
{
    if (mode == DATA_DOUBLE)
        return;

    LOG_CAST_F2R(self);
    double dValue = [self doubleValue];
    mode = DATA_DOUBLE;
    lval.real = dValue;
}

//
// NSCopying protocol
//
- (id)copyWithZone:(NSZone *)zone
{
    FractionNumber *new = [[self.class allocWithZone:zone] init];

    new->mode = mode;
    new->lval = lval;

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
            return [NSString stringWithFormat:@"%f", lval.real];
        case DATA_FRACTION:
            if (lval.frac.denominator == 1) {
                return [NSString stringWithFormat:@"%s%u",
                        lval.frac.negative ? "-" : "",
                        lval.frac.numerator];
            }
            else {
                return [NSString stringWithFormat:@"%s%u/%u",
                        lval.frac.negative ? "-" : "",
                        lval.frac.numerator, lval.frac.denominator];
            }
            break;
        default:
            break;
    }
    return @"(Unkown)";
}

- (NSString *)debugDescription
{
    return [self description];
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
@end
