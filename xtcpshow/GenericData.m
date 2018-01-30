//
//  GenericData.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/30.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#import "GenericData.h"

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

- (id)initWithMode:(enum enum_data_mode)mode numerator:(NSNumber *)nvalue denominator:(NSNumber *)dvalue
{
    self = [super init];
    mode = mode;
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
    self.numberOfSamples = 0;
    self.dataFrom = [NSDate date];
    self.dataTo = self.dataFrom;
    return self;
}

- (id)init
{
    return [self initWithMode:DATA_NOVALUE
                    numerator:nil
                  denominator:nil];
}

+ (id)dataWithoutValue {
    return [[GenericData alloc] init];
}

+ (id)dataWithDouble:(double)data
{
    GenericData *new = [GenericData alloc];
    return [new initWithMode:DATA_DOUBLE
                   numerator:[NSNumber numberWithDouble:data]
                 denominator:nil];
}

+ (id)dataWithInteger:(NSInteger)data
{
    GenericData *new = [GenericData alloc];
    return [new initWithMode:DATA_INTEGER
                   numerator:[NSNumber numberWithInteger:data]
                 denominator:nil];
}

+ (id)dataWithUInteger:(NSUInteger)data
{
    GenericData *new = [GenericData alloc];
    return [new initWithMode:DATA_UINTEGER
                   numerator:[NSNumber numberWithInteger:data]
                 denominator:nil];
}

+ (id)dataWithFraction:(NSInteger)numerator denominator:(NSInteger)denominator
{
    GenericData *new = [GenericData alloc];
    if (denominator < 0) {
        numerator = 0 - numerator;
        denominator = 0 - denominator;
    }
    return [new initWithMode:DATA_FRACTION
                   numerator:[NSNumber numberWithInteger:numerator]
                 denominator:[NSNumber numberWithInteger:denominator]];
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
    NSException *ex = [NSException exceptionWithName:@"Invalid Value"
                                              reason:@"Unknown Data Type encoded"
                                            userInfo:nil];
    @throw ex;
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
    new.numberOfSamples = self.numberOfSamples;
    
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
            return @"No value";
        case DATA_DOUBLE:
            return [NSString stringWithFormat:@"%f", numerator.real];
        case DATA_INTEGER:
            return [NSString stringWithFormat:@"%lld", numerator.integer];
        case DATA_UINTEGER:
            return [NSString stringWithFormat:@"%llu", numerator.uinteger];
        case DATA_FRACTION:
        {
            return [NSString stringWithFormat:@"%lld/%llu",
                    numerator.integer, denominator.uinteger];
        }
        default:
            break;
    }
    return @"Unkown";
}
@end
