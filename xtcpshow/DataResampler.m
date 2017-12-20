// Copyright (c) 2013
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
//  DataResampler.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//
#include "math.h"

#import "DataResampler.h"
#import "SamplingData.h"

// Gaussian filter.
// larger value is more better and more slow.
#define KZ_STAGE 3

@implementation DataResampler
@synthesize FIR_KZ;

- (id)init
{
    self = [super init];

    NSMutableArray *FIR_Factory = [[NSMutableArray alloc] init];
    for (int i = 0; i < KZ_STAGE; i++) {
        DataQueue *stage = [[DataQueue alloc] init];
        [FIR_Factory addObject:stage];
    }
    FIR_KZ = [NSArray arrayWithArray:FIR_Factory];
    
    return self;
}

- (void)invalidValueException
{
	NSException *ex;

	ex = [NSException exceptionWithName:@"Invalid value"
				     reason:@"Invalid value in DataResampler"
				   userInfo:nil];
	@throw ex;
}

- (void)purgeData
{
	_data = nil;
}

- (NSDate *)roundDate:(NSDate *)date toTick:(NSTimeInterval)tick
{
	NSTimeInterval unixTime;

	unixTime = [date timeIntervalSince1970];
	unixTime = floor(unixTime / tick) * tick;
	return [NSDate dateWithTimeIntervalSince1970:unixTime];
}

- (void)resampleData:(DataQueue *)input
{
	NSTimeInterval dataLength;
	NSDate *start, *end;
	NSUInteger FIR_Samples, maxSamples;
	float bytes2mbps, tick;

	// convert units
	tick = _outputTimeLength / _outputSamples; // [sec/sample]
	FIR_Samples = ceil(_MATimeLength / tick);
	maxSamples = _outputSamples + FIR_Samples;
	bytes2mbps = 8.0f / tick; // [bps]
	bytes2mbps = bytes2mbps / 1000.0f / 1000.0f; // [Mbps]

	// allocate data if need
	if (_data == nil) {
		_data = [[DataQueue alloc] init];
		_data.last_update = nil;

        NSUInteger FIR_tap = FIR_Samples / [FIR_KZ count];
        if (FIR_tap <= 0) {
            FIR_Samples = [FIR_KZ count];
            FIR_tap = 1;
        }
        for (int i = 0; i < [FIR_KZ count]; i++)
            [[FIR_KZ objectAtIndex:i] zeroFill:FIR_tap];
	}

	// get range of time
	dataLength = -(_outputTimeLength + _MATimeLength);
	end = [input.last_update dateByAddingTimeInterval:_outputTimeOffset];
	start = [self roundDate:[end dateByAddingTimeInterval:dataLength] toTick:tick];

	if (!_data.last_update) {
		// 1st time. adjust input date.
		[input seekToDate:start];
		_data.last_update = start;
	}
	else {
		// continue from last update
		start = [start laterDate:_data.lastDate];
		start = [start dateByAddingTimeInterval:tick];
	}
	
	// filter
	for (NSDate *slot = start; [slot laterDate:end] == end;
	     slot = [slot dateByAddingTimeInterval:tick]) {
		SamplingData *sample;
		NSUInteger sample_count = 0;
		float slot_value = 0.0f, remain = 0.0f;
		// Step1: folding(sum) source data before slot
		while ([input nextDate] &&
		       [slot laterDate:[input nextDate]] == slot) {
			SamplingData *source;
			float value, new_value;

			source = [input readNextData];
			value = [source floatValue] + remain;
			new_value = slot_value + value;
			remain = (new_value - slot_value) - value;
			slot_value = new_value;

			sample_count += source.numberOfSamples;
			_data.last_update = source.timestamp;
		}
		sample = [SamplingData dataWithSingleFloat:(slot_value + remain)];

		// Step2: FIR
		if (FIR_Samples > [FIR_KZ count]) {
            for (int i = 0; i < [FIR_KZ count]; i++) {
                [[FIR_KZ objectAtIndex:i] shiftDataWithNewData:sample];
                sample = [SamplingData dataWithSingleFloat:[[FIR_KZ objectAtIndex:i] averageFloatValue]];
            }
		}

		// Step3: convert unit of sample
		sample = [SamplingData dataWithFloat:([sample floatValue] * bytes2mbps) atDate:slot fromSamples:sample_count];

		// finalize and output sample
		[_data addDataEntry:sample withLimit:maxSamples];
	}

	// get additional data(noise) generated by filter
	_overSample = [_data count] - _outputSamples;
	_lastInput = input;
}
@end
