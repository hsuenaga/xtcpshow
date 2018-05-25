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
//  GenericTime.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/05/22.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#import "GenericTime.h"

@implementation GenericTime
@synthesize resolution;

- (id)initWithNSTimeInterval:(NSTimeInterval)it withResolution:(uint32_t)res
{
    if (isnan(it))
        return nil;

    self = [super initWithMode:DATA_DOUBLE
                     numerator:[NSNumber numberWithDouble:it] denominator:nil enableSaturation:FALSE];
    self.resolution = res;
    return self;
}

+ (id)timeWithNSDate:(NSDate *)date
{
    NSTimeInterval it;

    if (date)
        it = [date timeIntervalSinceReferenceDate];
    else
        it = NAN;
    return [[self.class alloc] initWithNSTimeInterval:it withResolution:1000];
}

+ (id)timeWithTimeval:(const struct timeval *)tv
{
    NSTimeInterval it;

    if (tv) {
        it = (double)tv->tv_sec + (double)tv->tv_usec * 1.0E-6;
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:it];
        it = [date timeIntervalSinceReferenceDate];
    }
    else {
        it = NAN;
    }

    return [[self.class alloc] initWithNSTimeInterval:it withResolution:1000];
}

+ (id)date
{
    return [self.class timeWithNSDate:[NSDate date]];
}

- (void)setResolution:(uint32_t)resolution
{
    self->resolution = resolution;
    if (resolution > 0)
        [self castToFractionWithDenominator:resolution];
}

- (uint32_t)resolution
{
    return self->resolution;
}

- (NSDate *)NSDate
{
	return [NSDate dateWithTimeIntervalSinceReferenceDate:[self doubleValue]];
}

- (NSUInteger)sec
{
	return [self int64Value];
}

- (void)timeval:(struct timeval *)tv
{
	FractionNumber *usec = [super copy];
	[usec mulInteger:1000000];
	if (tv == NULL)
		return;
	tv->tv_sec = [usec int64Value] / 1000000;
	tv->tv_usec = [usec int64Value] % 1000000;
}

- (FractionNumber *)intervalFrom:(GenericTime *)from
{
	FractionNumber *it = [super copy];
	[it subNumber:from];
	return it;
}

- (GenericTime *)earlierTime:(GenericTime *)rtime
{
    if ([self doubleValue] > [rtime doubleValue])
        return rtime;

    return self;
}

- (GenericTime *)laterTime:(GenericTime *)rtime
{
    if ([self doubleValue] > [rtime doubleValue])
        return self;

    return rtime;
}

- (BOOL)isEqual:(GenericTime *)rtime
{
    if (self == rtime)
        return TRUE;

    if (self.resolution && rtime.resolution)
        return [super isEqual:rtime];

    return FALSE;
}

- (id)copyWithZone:(NSZone *)zone
{
    GenericTime *new = [super copyWithZone:zone];

    return new;
}

- (NSString *)description
{
    return [[self date] description];
}
@end
